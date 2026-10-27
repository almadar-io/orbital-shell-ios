//! iOS backend code generation.

use orbital_core_base::generate::{Backend, GeneratedFile, GeneratedOutput};
#[cfg(test)]
use orbital_core_base::ir::OirValue;
use orbital_core_base::ir::{
    classify_type, render_default, render_type, OirEntity, OirField, OirModule, OirType,
    TargetLiteralRenderer, TargetTypeRenderer, TypeMappingClass,
};
use orbital_core_base::schema::{OrbitalSchema, ServiceDefinition};
use orbital_core_base::str_utils::{
    escape_double_quoted, sanitize_identifier, split_to_camel_case, split_to_pascal_case,
    to_title_case,
};

const SWIFT_KEYWORDS: &[&str] = &[
    "associatedtype",
    "class",
    "deinit",
    "enum",
    "extension",
    "fileprivate",
    "func",
    "import",
    "init",
    "inout",
    "internal",
    "let",
    "open",
    "operator",
    "private",
    "protocol",
    "public",
    "rethrows",
    "static",
    "struct",
    "subscript",
    "typealias",
    "var",
    "break",
    "case",
    "continue",
    "default",
    "defer",
    "do",
    "else",
    "fallthrough",
    "for",
    "guard",
    "if",
    "in",
    "repeat",
    "return",
    "switch",
    "where",
    "while",
];

/// iOS code generation backend.
#[derive(Debug, Default, Clone)]
pub struct IosBackend {
    /// The schema's resolved form (every `uses` import inlined, every
    /// `TraitReference` flattened to `Inline`) — when set, `generate` bundles
    /// it as `resolved_schema.json` so the in-app kernel (Program B, §159)
    /// mounts without a device-side compiler. `None` for callers with no
    /// resolved schema (existing tests/CLI paths), which emit no extra file.
    resolved_schema: Option<OrbitalSchema>,
}

impl IosBackend {
    /// Create a new iOS backend.
    pub fn new() -> Self {
        Self::default()
    }

    /// Attach the schema's resolved form so `generate` also emits
    /// `resolved_schema.json` into the app bundle's Resources.
    pub fn with_resolved_schema(mut self, schema: OrbitalSchema) -> Self {
        self.resolved_schema = Some(schema);
        self
    }
}

impl Backend for IosBackend {
    fn generate(&self, module: &OirModule) -> GeneratedOutput {
        let mut files = vec![];
        let mut warnings = vec![];

        files.push(generate_entities_file(
            &module.distinct_entities(),
            &module.named_types,
        ));
        files.push(generate_services_file(&module.services));
        files.push(generate_api_client_file(module));
        files.push(generate_slot_role_file());
        files.push(generate_effect_handlers_file());
        files.push(generate_view_model_file(module));
        files.push(generate_await_renders_file(module));
        files.push(generate_splice_file());
        files.push(generate_pattern_renderer_type_file());
        files.push(generate_fallback_renderer_file());
        files.extend(
            crate::pack::pack()
                .sources
                .iter()
                .filter(|(rel, _)| !rel.starts_with(PACK_TESTS_PREFIX))
                .map(|(rel, content)| GeneratedFile {
                    path: format!("Views/core/{rel}"),
                    content: content.clone(),
                }),
        );
        files.extend(generate_pattern_snapshot_test_files(module));
        files.push(generate_app_file(module));
        if let Some(schema) = &self.resolved_schema {
            files.push(generate_resolved_schema_file(schema));
        }

        if module.entities.is_empty() {
            warnings.push("No entities declared in schema.".to_string());
        }
        if module.services.is_empty() {
            warnings.push("No services declared in schema.".to_string());
        }
        if module.traits.is_empty() {
            warnings.push("No traits declared in schema.".to_string());
        }
        if module.pages.is_empty() {
            warnings.push("No pages declared in schema.".to_string());
        }

        GeneratedOutput { files, warnings }
    }

    fn name(&self) -> &'static str {
        "ios"
    }
}

fn generate_entities_file(
    entities: &[OirEntity],
    named_types: &std::collections::BTreeMap<String, OirType>,
) -> GeneratedFile {
    let mut content = String::from("import Foundation\n\n");

    // Named-type declarations (resolver-registered recursive aliases +
    // Phase-3D nominalized anonymous shapes) hoist at file top, before every
    // entity struct that references them by bare name — mirroring the TS
    // shell's `emit_named_type_declarations`.
    let file_hoisted = std::cell::RefCell::new(Vec::new());
    for (name, ty) in named_types {
        oir_type_to_swift_with(ty, name, &file_hoisted);
    }
    for decl in file_hoisted.into_inner() {
        content.push_str(&decl);
        content.push_str("\n\n");
    }

    for entity in entities {
        content.push_str(&generate_entity(entity));
    }

    GeneratedFile {
        path: "Entities.swift".to_string(),
        content,
    }
}

/// Type names the generated Swift (stdlib, Foundation, SwiftUI and the shell's own runtime) uses:
/// an entity struct of the same name would shadow it (`struct Task` breaks `Task { ... }`).
const SWIFT_RESERVED_TYPES: &[&str] = &[
    "Any",
    "AnyCodable",
    "Array",
    "Binding",
    "Bool",
    "Button",
    "Calendar",
    "Character",
    "Color",
    "Data",
    "Date",
    "Dictionary",
    "Double",
    "Environment",
    "Error",
    "Float",
    "Font",
    "Form",
    "Group",
    "Image",
    "Int",
    "JSONDecoder",
    "JSONEncoder",
    "Label",
    "Link",
    "List",
    "Locale",
    "Menu",
    "Never",
    "Notification",
    "Optional",
    "Path",
    "Picker",
    "Range",
    "Result",
    "Section",
    "Set",
    "Shape",
    "Slider",
    "State",
    "Stepper",
    "String",
    "Task",
    "Text",
    "Timer",
    "Toggle",
    "URL",
    "UUID",
    "View",
    "Void",
];

/// The Swift type an entity is declared as: its PascalCase name, or `<Name>Entity` when that
/// name is a type the generated code uses. Only `Entities.swift` names entity types; the wire
/// JSON (field names) is unchanged.
fn swift_entity_type(entity: &str) -> String {
    let name = split_to_pascal_case(entity);
    if SWIFT_RESERVED_TYPES.contains(&name.as_str()) {
        format!("{name}Entity")
    } else {
        name
    }
}

fn generate_entity(entity: &OirEntity) -> String {
    let mut out = String::new();
    let class_name = swift_entity_type(&entity.name);

    // Emit nested enums for enum-valued fields first.
    for field in &entity.fields {
        if let Some(values) = &field.enum_values {
            if !values.is_empty() {
                let enum_name = enum_class_name(&class_name, &field.name);
                out.push_str(&generate_enum(&enum_name, values));
                out.push('\n');
            }
        }
    }

    let hoisted = std::cell::RefCell::new(Vec::new());
    let mut fields_out = String::new();

    for field in entity.fields.iter().filter(|f| f.name != "id") {
        let field_name = sanitize_identifier(&split_to_camel_case(&field.name), SWIFT_KEYWORDS);
        let (type_hint, optional) = type_for_field(entity, field);
        let swift_type = oir_type_to_swift_with(
            &type_hint,
            &format!("{}{}", class_name, split_to_pascal_case(&field.name)),
            &hoisted,
        );
        // Canonicalize optionality onto the type handed to `render_default` so
        // a `Null` default renders `nil` regardless of which of the two
        // optionality spellings (`Optional` wrapper vs. bare `required:
        // false`) `effective_type` collapsed — `OirType::optional` is
        // idempotent, so this never double-wraps.
        let default_ty = if optional {
            OirType::optional(type_hint.clone())
        } else {
            type_hint.clone()
        };
        let default = field.default.as_ref().and_then(|v| {
            match render_default(&SwiftLiteral, v, &default_ty, None) {
                Ok(Some(rendered)) => Some(rendered),
                Ok(None) => None,
                // A comment at the value position is a swiftc error, never a Rust panic.
                Err(mismatch) => Some(format!("/* {} */", mismatch.marker())),
            }
        });

        let opt = if optional { "?" } else { "" };
        let decl = match &default {
            Some(d) => format!("    let {}: {}{} = {}", field_name, swift_type, opt, d),
            None => format!("    let {}: {}{}", field_name, swift_type, opt),
        };
        fields_out.push_str(&decl);
        fields_out.push('\n');
    }

    // Hoisted struct/enum declarations render before the entity struct, the
    // same position as the field enums above.
    for decl in hoisted.into_inner() {
        out.push_str(&decl);
        out.push_str("\n\n");
    }

    out.push_str(&format!(
        "/// {} entity.\n",
        entity.description.as_deref().unwrap_or(&entity.name)
    ));
    out.push_str("struct ");
    out.push_str(&class_name);
    out.push_str(": Codable {\n");
    out.push_str("    let id: String\n");
    out.push_str(&fields_out);

    out.push_str("\n    enum CodingKeys: String, CodingKey {\n");
    out.push_str("        case id\n");
    for field in entity.fields.iter().filter(|f| f.name != "id") {
        out.push_str(&format!(
            "        case {} = \"{}\"\n",
            sanitize_identifier(&split_to_camel_case(&field.name), SWIFT_KEYWORDS),
            escape_double_quoted(&field.name)
        ));
    }
    out.push_str("    }\n");
    out.push_str("}\n\n");
    out
}

fn oir_type_to_swift_with(
    type_: &OirType,
    context_name: &str,
    hoisted: &std::cell::RefCell<Vec<String>>,
) -> String {
    render_type(
        &SwiftRenderer {
            context_name: context_name.to_string(),
            hoisted,
        },
        type_,
        None,
    )
}

fn generate_enum(enum_name: &str, values: &[String]) -> String {
    let mut out = String::new();
    out.push_str("enum ");
    out.push_str(enum_name);
    out.push_str(": String, Codable {\n");
    for value in values {
        let case_name = sanitize_identifier(&split_to_camel_case(value), SWIFT_KEYWORDS);
        out.push_str(&format!(
            "    case {} = \"{}\"\n",
            case_name,
            escape_double_quoted(value)
        ));
    }
    out.push_str("}\n");
    out
}

fn generate_services_file(services: &[orbital_core_base::schema::ServiceRef]) -> GeneratedFile {
    let mut content = String::from("import Foundation\n\n");
    content.push_str("/// Service configuration generated from the schema.\n\n");

    for service_ref in services {
        let Some(def) = service_ref.as_inline() else {
            continue;
        };

        match def {
            ServiceDefinition::Rest(rest) => {
                let class_name = format!("{}RestConfig", split_to_pascal_case(&rest.name));
                content.push_str("struct ");
                content.push_str(&class_name);
                content.push_str(": Codable {\n");
                content.push_str(&format!(
                    "    let baseUrl: String = \"{}\"\n",
                    escape_double_quoted(&rest.base_url)
                ));
                if let Some(headers) = &rest.headers {
                    let header_entries: Vec<String> = headers
                        .iter()
                        .map(|(k, v)| {
                            format!(
                                "        \"{}\": \"{}\"",
                                escape_double_quoted(k),
                                escape_double_quoted(v)
                            )
                        })
                        .collect();
                    content.push_str("    let headers: [String: String] = [\n");
                    content.push_str(&header_entries.join(",\n"));
                    content.push_str("\n    ]\n");
                }
                if let Some(timeout) = rest.timeout {
                    content.push_str(&format!("    let timeout: Int = {}\n", timeout));
                }
                content.push_str("}\n\n");
            }
            ServiceDefinition::Socket(socket) => {
                let class_name = format!("{}SocketConfig", split_to_pascal_case(&socket.name));
                content.push_str("struct ");
                content.push_str(&class_name);
                content.push_str(": Codable {\n");
                content.push_str(&format!(
                    "    let url: String = \"{}\"\n",
                    escape_double_quoted(&socket.url)
                ));
                content.push_str("}\n\n");
            }
            ServiceDefinition::Mcp(mcp) => {
                let class_name = format!("{}McpConfig", split_to_pascal_case(&mcp.name));
                content.push_str("struct ");
                content.push_str(&class_name);
                content.push_str(": Codable {\n");
                content.push_str(&format!(
                    "    let serverPath: String = \"{}\"\n",
                    escape_double_quoted(&mcp.server_path)
                ));
                content.push_str("}\n\n");
            }
        }
    }

    GeneratedFile {
        path: "Services.swift".to_string(),
        content,
    }
}

/// Traits referenced via `@trait.X` by a sibling's render-ui. They paint only inside the host's
/// frame, so they never own `main` (`orbital_core::ir::build_embedded_trait_set`).
fn swift_embedded_traits_set(module: &OirModule) -> String {
    let mut names: Vec<String> = orbital_core_base::ir::build_embedded_trait_set(module)
        .into_iter()
        .collect();
    names.sort();
    let quoted: Vec<String> = names
        .iter()
        .map(|n| format!("\"{}\"", escape_double_quoted(n)))
        .collect();
    format!("[{}]", quoted.join(", "))
}

/// Program B (wave B7, ledger §159): the app's ONLY remaining HTTP surface —
/// posting a kernel-produced server leg and streaming the live-push channel.
/// Every other transport (the old per-shell `sendEvent`/`EventResponse`) is
/// gone; the wire types are the hand-authored bridge's `KernelServerLeg`/
/// `KernelEventResponse` (`OrbitalKernelBridge.swift`, mirrors
/// `orbital_core::EventRequest`/`EventResponse` = `@almadar/core`'s
/// `EventDispatchRequest`/`EventDispatchResponse`, ledger §156) — one wire
/// shape in this project, never a second per-shell struct.
fn generate_api_client_file(_module: &OirModule) -> GeneratedFile {
    let content = include_str!("../hosts/APIClient.swift.tpl");

    GeneratedFile {
        path: "APIClient.swift".to_string(),
        content: content.to_string(),
    }
}

fn generate_effect_handlers_file() -> GeneratedFile {
    let content = include_str!("../runtime/EffectHandlers.swift.tpl")
    .to_string();

    GeneratedFile {
        path: "EffectHandlers.swift".to_string(),
        content,
    }
}

fn generate_slot_role_file() -> GeneratedFile {
    let content = r#"import Foundation

/// Visual layout role for a named UI slot.
///
/// Mirrors `orbital_core::slots::SlotRole` exactly.  Any new arm added there
/// must be added here and the parity test in the Rust crate updated.
enum SlotRole {
    case main
    case sidebar
    case drawer
    case modal
    case overlay
    case toast
    case hudTop
    case hudBottom
    case floating
    case system
}

/// Classify a slot name into its layout role.  Mirrors `orbital_core::slots::slot_role`.
func slotRole(_ name: String) -> SlotRole {
    switch name {
    case "main":
        return .main
    case "content":
        return .main
    case "screen":
        return .main
    case "sidebar":
        return .sidebar
    case "drawer":
        return .drawer
    case "dock":
        return .drawer
    case "modal":
        return .modal
    case "center":
        return .modal
    case "overlay":
        return .overlay
    case "toast":
        return .toast
    case "hud-bottom":
        return .hudBottom
    case "hud":
        return .hudTop
    case "hud-top":
        return .hudTop
    case "floating":
        return .floating
    case "system":
        return .system
    default:
        if name.hasPrefix("overlay.") { return .overlay }
        if name.hasPrefix("hud.") { return .hudTop }
        return .main
    }
}
"#
    .to_string();

    GeneratedFile {
        path: "SlotRole.swift".to_string(),
        content,
    }
}

/// Traits that declare an `INIT` event, in DECLARATION order — only these
/// auto-dispatch on mount, mirroring the TS shell's `generate_auto_init_effect`
/// (a trait with no declared `INIT` handler never sends one). Order matters:
/// `initAllTraits` walks this list once at app start (`ClientCore::
/// init_all_traits_blocking`), so a later trait's `@trait.X` reference to an
/// earlier one resolves as soon as it is indexed.
fn swift_traits_with_init_set(module: &OirModule) -> String {
    let gated = orbital_core_base::ir::gated_only_traits(module);
    let names: Vec<String> = module
        .traits
        .iter()
        .filter(|t| t.events.iter().any(|e| e.key == "INIT"))
        .filter(|t| !gated.contains(&t.name))
        .map(|t| format!("\"{}\"", escape_double_quoted(&t.name)))
        .collect();
    if names.is_empty() {
        "[]".to_string()
    } else {
        format!("[{}]", names.join(", "))
    }
}

/// `["path": [trait, ...]]` — each gated page's INIT-declaring gated-only traits
/// (`orbital_core::ir::gated_page_traits`); they INIT when that page mounts for an
/// authenticated viewer, not at app start.
fn swift_gated_page_traits(module: &OirModule) -> String {
    let declares_init = |name: &str| {
        module
            .traits
            .iter()
            .any(|t| t.name == name && t.events.iter().any(|e| e.key == "INIT"))
    };
    let entries: Vec<String> = orbital_core_base::ir::gated_page_traits(module)
        .into_iter()
        .filter_map(|(path, traits)| {
            let names: Vec<String> = traits
                .iter()
                .filter(|t| declares_init(t))
                .map(|t| format!("\"{}\"", escape_double_quoted(t)))
                .collect();
            (!names.is_empty()).then(|| {
                format!(
                    "\"{}\": [{}]",
                    escape_double_quoted(&path),
                    names.join(", ")
                )
            })
        })
        .collect();
    if entries.is_empty() {
        "[:]".to_string()
    } else {
        format!("[{}]", entries.join(", "))
    }
}

/// Program B (wave B7, ledger §159): the view model owns the in-app kernel
/// handle (`OrbitalKernel`, `orbital-ffi`) and drives every dispatch through
/// it — `sendEvent` never talks HTTP directly. Mirrors `orbital-client`'s
/// `ClientKernel::dispatch` (`crates/orbital-client/src/client_kernel.rs`):
/// the local `response` folds immediately (render-ui IS the UI); the
/// resolved `DispatchMode` then decides whether/how a produced server leg
/// posts (`OrbitalAPI.postServerLeg`) and folds back
/// (`OrbitalKernel.applyServerResponse`).
/// `AwaitRenders.swift`: the compiler's `await_render` predictions (`OirModule::await_render_rows`),
/// read while a server leg is in flight.
fn generate_await_renders_file(module: &OirModule) -> GeneratedFile {
    let rows: Vec<_> = module
        .await_render_rows()
        .into_iter()
        .filter(|row| !orbital_core_base::slots::is_portal_slot(&row.slot))
        .collect();
    let rows = serde_json::to_string(&rows).expect("await-render rows serialize");
    let content = include_str!("../runtime/AwaitRenders.swift.tpl")
    .replace("__ROWS__", &rows);
    GeneratedFile {
        path: "AwaitRenders.swift".to_string(),
        content,
    }
}

fn generate_view_model_file(module: &OirModule) -> GeneratedFile {
    let base_url = module
        .services
        .iter()
        .filter_map(|s| s.as_inline())
        .find_map(|def| match def {
            ServiceDefinition::Rest(r) => Some(r.base_url.clone()),
            _ => None,
        })
        .unwrap_or_else(|| "http://localhost:3030".to_string());
    let traits_with_init = swift_traits_with_init_set(module);
    let embedded_traits = swift_embedded_traits_set(module);
    let known_routes = format!(
        "[{}]",
        module
            .pages
            .iter()
            .map(|p| format!("\"{}\"", escape_double_quoted(&p.path)))
            .collect::<Vec<_>>()
            .join(", ")
    );
    let start_route = module
        .pages
        .first()
        .map(|p| escape_double_quoted(&p.path))
        .unwrap_or_else(|| "/".to_string());

    let content = include_str!("../hosts/OrbitalViewModel.swift.tpl")
    .replace("__TRAITS_WITH_INIT__", &traits_with_init)
    .replace("__GATED_PAGE_TRAITS__", &swift_gated_page_traits(module))
    .replace("__KNOWN_ROUTES__", &known_routes)
    .replace("__EMBEDDED_TRAITS__", &embedded_traits)
    .replace("__START_ROUTE__", &start_route)
    .replace("__HOST_SIGN_IN_ROUTE__", orbital_core_base::schema::HOST_SIGN_IN_ROUTE)
    .replace("__BASE_URL__", &escape_double_quoted(&base_url));

    GeneratedFile {
        path: "OrbitalViewModel.swift".to_string(),
        content,
    }
}

/// Native mirror of `orbital-client`'s `recurse.rs::child_patterns` +
/// `helpers.rs::render_children`/`RenderContext.source_trait`. The SwiftUI
/// renderers (`CorePatternRegistry`, generated, never hand-edited) recurse on
/// their own — there is no per-level render hook to thread a live
/// `trait_content` lookup through — so this splices the WHOLE tree eagerly,
/// once, before a slot's content reaches the registry.
fn generate_splice_file() -> GeneratedFile {
    let content = r#"import Foundation

/// `@trait.X[.slot]` leaf -> `X`. Mirrors `orbital_core::ir::OirBinding::parse`'s
/// `Trait` root: the prefix `@trait.` then the trait name up to the next `.`.
func traitRefName(_ s: String) -> String? {
    guard s.hasPrefix("@trait.") else { return nil }
    let rest = s.dropFirst("@trait.".count)
    guard !rest.isEmpty else { return nil }
    if let dot = rest.firstIndex(of: ".") {
        return String(rest[rest.startIndex..<dot])
    }
    return String(rest)
}

/// Splices `@trait.X` references in `content` against `traitContent`, tagging
/// every typed node with the trait whose subtree it belongs to (the spliced
/// trait inside an `@trait.X` subtree, else `sourceTrait`) so a nested
/// control's own props carry the trait `onEvent` should route to: the native
/// form of the web's per-slot trait context. `nil` in, `nil` out.
func splice(_ content: AnyCodable?, sourceTrait: String, traitContent: [String: AnyCodable]) -> AnyCodable? {
    guard let content = content else { return nil }
    return spliceNode(content, sourceTrait: sourceTrait, traitContent: traitContent, visited: [sourceTrait])
}

private func spliceNode(_ value: AnyCodable, sourceTrait: String, traitContent: [String: AnyCodable], visited: Set<String>) -> AnyCodable {
    guard let dict = value.dictValue else { return value }
    var out: [String: AnyCodable] = [:]
    for (key, v) in dict {
        if key == "children" {
            out[key] = spliceChildren(v, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
        } else {
            out[key] = splicePropValue(v, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
        }
    }
    if dict["type"] != nil {
        out["sourceTrait"] = .string(sourceTrait)
    }
    return .dict(out)
}

/// A `children` value. An array drops null entries and unresolved or cyclic
/// refs; a scalar `@trait.X` ref that resolves to nothing is an empty array
/// (a `.null` child would render as an unsupported pattern). Mirrors the
/// Android `spliceChildren`.
private func spliceChildren(_ value: AnyCodable, sourceTrait: String, traitContent: [String: AnyCodable], visited: Set<String>) -> AnyCodable {
    guard let arr = value.arrayValue else {
        let spliced = splicePropValue(value, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
        if case .null = spliced { return .array([]) }
        return spliced
    }
    return .array(arr.compactMap { child -> AnyCodable? in
        if case .null = child { return nil }
        return spliceChild(child, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
    })
}

/// A `children`-array entry: an unresolved or already-visited (cyclic)
/// `@trait.X` ref is DROPPED — mirrors `recurse.rs::child_patterns`.
private func spliceChild(_ child: AnyCodable, sourceTrait: String, traitContent: [String: AnyCodable], visited: Set<String>) -> AnyCodable? {
    if let name = child.stringValue.flatMap(traitRefName) {
        guard !visited.contains(name), let resolved = traitContent[name] else { return nil }
        return spliceNode(resolved, sourceTrait: name, traitContent: traitContent, visited: visited.union([name]))
    }
    return spliceNode(child, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
}

/// A non-`children` prop value: an unresolved or cyclic `@trait.X` ref
/// becomes `null` (the wire's own convention for "no content").
private func splicePropValue(_ v: AnyCodable, sourceTrait: String, traitContent: [String: AnyCodable], visited: Set<String>) -> AnyCodable {
    if let name = v.stringValue.flatMap(traitRefName) {
        guard !visited.contains(name), let resolved = traitContent[name] else { return .null }
        return spliceNode(resolved, sourceTrait: name, traitContent: traitContent, visited: visited.union([name]))
    }
    if let arr = v.arrayValue {
        return .array(arr.map { splicePropValue($0, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited) })
    }
    return spliceNode(v, sourceTrait: sourceTrait, traitContent: traitContent, visited: visited)
}
"#
    .to_string();

    GeneratedFile {
        path: "Splice.swift".to_string(),
        content,
    }
}

fn generate_pattern_renderer_type_file() -> GeneratedFile {
    let content = r#"import Foundation
import SwiftUI

/// Common renderer signature for all Almadar patterns.
typealias PatternRenderer = (
    _ props: AnyCodable,
    _ modifier: AnyView?,
    _ onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView
"#
    .to_string();

    GeneratedFile {
        path: "Views/PatternRenderer.swift".to_string(),
        content,
    }
}

fn generate_fallback_renderer_file() -> GeneratedFile {
    let content = r#"import Foundation
import SwiftUI

/// Fallback renderer for patterns that do not have a native SwiftUI mapping yet.
struct FallbackRenderer: View {
    let patternName: String
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Unsupported pattern: \(patternName)")
                .font(.headline)
            Text("Props: \(props.stringValue ?? "...")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

func FallbackRendererView(
    patternName: String,
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FallbackRenderer(patternName: patternName, props: props, onEvent: onEvent))
}
"#
    .to_string();

    GeneratedFile {
        path: "Views/core/FallbackRenderer.swift".to_string(),
        content,
    }
}

/// Pack sources under this prefix are the app's unit-test sources, not app sources.
const PACK_TESTS_PREFIX: &str = "bridge/tests/";

/// Width in points of the one phone content column every pattern snapshot is
/// laid out in: a 390pt device minus 16pt horizontal padding per side.
const PATTERN_SNAPSHOT_COLUMN_WIDTH: u32 = 358;

/// Height in points of the phone content area (844pt device minus ~47pt top
/// and ~34pt bottom safe area, rounded) that registry-tier `template`
/// patterns, which fill the viewport, are laid out in.
const PATTERN_SNAPSHOT_VIEWPORT_HEIGHT: u32 = 760;

/// Program C wave C4 (`docs/Almadar_Compiler_Gaps.md` §157) render gate: one
/// `XCTest` method per non-deferred pattern, decoding its embedded fixture
/// (`crate::pack::pack().fixtures`, generated by `almadar-sync pattern-fixtures`) and
/// snapshotting `CorePatternRegistry.renderer(for:)`'s output through
/// swift-snapshot-testing. Fixtures are ALSO written as real bundle
/// resources under `Sources/OrbitalAppTests/Resources/pattern-fixtures/` —
/// INSIDE the `{{APP_CLASS_NAME}}Tests` target's own `sources:` root
/// (`project.yml`), not the app's — so xcodegen's ordinary "non-code file
/// under a sources tree is a resource of that same target" auto-detection
/// bundles them into the TEST target (verified: a path nested under
/// `Sources/OrbitalApp` — which the APP target's `sources:` also covers —
/// gets auto-claimed by the APP target instead, even with an explicit
/// `resources:` entry naming the test target). Xcode's non-folder-reference
/// resource grouping FLATTENS the directory into the bundle root, so the
/// runtime lookup (`loadFixtureProps` below) reads `Bundle(for:)` with no
/// `subdirectory:` — never compile-time string literals — so a fixture edit
/// alone never requires regenerating this file. `@testable import` needs
/// the exact Xcode module name, derived the SAME way
/// `IosShell::build_replacements` derives `{{APP_CLASS_NAME}}` (never
/// duplicated — `to_package_name` is `pub(crate)` in `shell.rs` for this).
/// Patterns the iOS pixel snapshot cannot capture, with the reason. Their renderers still
/// compile in every build; device frames are their proof.
pub const IOS_SNAPSHOT_EXCLUDED: &[(&str, &str)] = &[(
    "map-view",
    "MKMapView segfaults swift-snapshot-testing's drawHierarchy (CoreGraphics image-data lock), whatever its tiles",
)];

pub fn ios_snapshot_excluded(name: &str) -> bool {
    IOS_SNAPSHOT_EXCLUDED
        .iter()
        .any(|(excluded, _)| *excluded == name)
}

fn generate_pattern_snapshot_test_files(module: &OirModule) -> Vec<GeneratedFile> {
    let app_module_name = split_to_pascal_case(&crate::shell::to_package_name(&module.name));

    let mut files: Vec<GeneratedFile> = crate::pack::pack()
        .fixtures
        .iter()
        .map(|(name, content)| GeneratedFile {
            path: format!("Sources/OrbitalAppTests/Resources/pattern-fixtures/{name}.json"),
            content: (*content).to_string(),
        })
        .collect();

    let mut methods = String::new();
    for (name, _content) in crate::pack::pack()
        .fixtures
        .iter()
        .filter(|(n, _)| !ios_snapshot_excluded(n))
    {
        let escaped = escape_double_quoted(name);
        let method_name = format!("test_{}", name.replace('-', "_"));
        let viewport = orbital_core_base::language::pattern_registry::get_component_mapping(name)
            .is_some_and(|m| m.category == "template");
        methods.push_str(&format!(
            "    func {method_name}() {{ assertPatternSnapshot(\"{escaped}\", testName: \"{method_name}\", viewport: {viewport}) }}\n"
        ));
    }

    let content = format!(
        r#"import Foundation
import SwiftUI
import UIKit
import XCTest
import SnapshotTesting
@testable import {app_module_name}

/// Program C wave C4 render gate — one snapshot per non-deferred pattern,
/// driven by the fixtures `almadar-sync pattern-fixtures` embeds. Generated;
/// never hand-edit — re-run `orbital compile --shell ios`.
final class PatternSnapshotTests: XCTestCase {{
    /// Phone content column (390pt device minus 16pt padding per side); the one
    /// width every pattern snapshot is laid out in.
    private static let columnWidth: CGFloat = {PATTERN_SNAPSHOT_COLUMN_WIDTH}

    private func loadFixtureProps(_ patternName: String) -> AnyCodable {{
        let bundle = Bundle(for: PatternSnapshotTests.self)
        guard let url = bundle.url(forResource: patternName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let props = try? JSONDecoder().decode(AnyCodable.self, from: data) else {{
            XCTFail("missing/invalid pattern fixture: \(patternName)")
            return .null
        }}
        return props
    }}

    /// Height of the phone content area; registry-tier `template` patterns fill
    /// the viewport, so they are laid out in this instead of their content size.
    private static let viewportHeight: CGFloat = {PATTERN_SNAPSHOT_VIEWPORT_HEIGHT}

    /// Run-loop time given to async work (AsyncImage failure placeholder,
    /// typewriter completion) before the snapshot is taken.
    private static let settleSeconds: TimeInterval = 0.6

    private func assertPatternSnapshot(_ patternName: String, testName: String, viewport: Bool) {{
        let props = loadFixtureProps(patternName)
        // Pin color scheme + an opaque background: several patterns (an
        // unopened confirm-dialog/overlay, a `List`-backed data-list) render
        // conditionally-empty or system-list content whose background/
        // appearance otherwise varies slightly across separate app launches.
        let content = CorePatternRegistry.renderer(for: patternName)(props, nil, {{ _, _ in }})
            .environment(\.colorScheme, .light)
            .environment(\.orbitalCanvasTarget, .raster)
            .transaction {{ $0.disablesAnimations = true }}
        let hosted: AnyView = viewport
            ? AnyView(content.frame(width: Self.columnWidth, height: Self.viewportHeight).background(Color.white))
            : AnyView(content.frame(width: Self.columnWidth).fixedSize(horizontal: false, vertical: true).background(Color.white))
        let controller = UIHostingController(rootView: hosted)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: Self.columnWidth, height: Self.viewportHeight))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(Self.settleSeconds))
        let size = viewport
            ? CGSize(width: Self.columnWidth, height: Self.viewportHeight)
            : controller.sizeThatFits(in: CGSize(width: Self.columnWidth, height: .greatestFiniteMagnitude))
        window.frame = CGRect(origin: .zero, size: size)
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        assertSnapshot(
            of: controller,
            // 0.99 / 0.98: the component-sized frame has no empty device
            // canvas to dilute the score, so a real pixel change in a small
            // atom must drop precision below the gate; 0.98 perceptual keeps
            // sub-pixel antialiasing noise between launches from tripping it.
            as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
            testName: testName
        )
    }}

{methods}}}
"#
    );

    files.push(GeneratedFile {
        path: "Sources/OrbitalAppTests/PatternSnapshotTests.swift".to_string(),
        content,
    });

    files.push(GeneratedFile {
        path: "Sources/OrbitalAppTests/OrbitalAuthTests.swift".to_string(),
        content: crate::pack::pack()
            .source(&format!("{PACK_TESTS_PREFIX}OrbitalAuthTests.swift"))
            .expect("the pack ships bridge/tests/OrbitalAuthTests.swift")
            .replace("__APP_MODULE__", &app_module_name),
    });

    files
}

/// The page boundary for `access: authenticated`, the native twin of `PageAccessHost`
/// (`@almadar/ui/providers`): the circuit mounts only for an authenticated viewer, keyed by that
/// viewer; any other viewer sees nothing and is sent to the app's declared `signIn` route.
const AUTHENTICATED_PAGE_SWIFT: &str = r#"/// Page boundary of an `access: authenticated` page (twin of the web `PageAccessHost`).
struct AuthenticatedPage<Content: View>: View {
    let path: String
    let signIn: String
    @ObservedObject var viewModel: OrbitalViewModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Color.clear always appears, so the boundary admits even before the page has content.
        ZStack {
            Color.clear
            if viewModel.isAuthenticated {
                content().id(viewModel.session?.uid)
            }
        }
        .onAppear { admit() }
        .onChange(of: viewModel.isAuthenticated) { _ in admit() }
        .onChange(of: viewModel.session?.uid) { _ in admit() }
    }

    /// An authenticated viewer mounts the page's circuit (its first content renders only after
    /// its INIT, so this hangs off the always-present boundary, not the content); anyone else is denied.
    private func admit() {
        if viewModel.isAuthenticated {
            viewModel.mountGatedPage(path: path, viewer: viewModel.session?.uid ?? "launch-token")
        } else {
            denyIfAnonymous()
        }
    }

    private func denyIfAnonymous() {
        if !viewModel.isAuthenticated { viewModel.denyPageAccess(path: path, signIn: signIn) }
    }
}

"#;

fn generate_app_file(module: &OirModule) -> GeneratedFile {
    let app_name = to_title_case(&module.name);

    // One case per declared route, matched verbatim against `path` — mirrors
    // Android's `composable(p.path)`, which also matches the route string
    // verbatim (no `{param}` templating either side).
    let sign_in = escape_double_quoted(
        module
            .site
            .as_ref()
            .and_then(|site| site.sign_in.as_deref())
            .unwrap_or_default(),
    );
    let route_cases: Vec<String> = module
        .pages
        .iter()
        .map(|p| {
            let path = escape_double_quoted(&p.path);
            let name = escape_double_quoted(&p.name);
            let trait_names = p
                .traits
                .iter()
                .map(|t| format!("\"{}\"", escape_double_quoted(&t.trait_name)))
                .collect::<Vec<_>>()
                .join(", ");
            let page = format!("GeneratedPage(pageName: \"{name}\", viewModel: viewModel, traitNames: [{trait_names}])");
            if p.access == Some(orbital_core_base::schema::PageAccess::Authenticated) {
                format!(
                    "                    case \"{path}\":\n                        AuthenticatedPage(path: \"{path}\", signIn: \"{sign_in}\", viewModel: viewModel) {{\n                            {page}\n                        }}"
                )
            } else {
                format!("                    case \"{path}\":\n                        {page}")
            }
        })
        .collect();
    let any_gated = module
        .pages
        .iter()
        .any(|p| p.access == Some(orbital_core_base::schema::PageAccess::Authenticated));
    let authenticated_page = if any_gated {
        AUTHENTICATED_PAGE_SWIFT
    } else {
        ""
    };

    // Use a single destination type for navigation.
    let destination_struct = r#"    enum Destination: Hashable {
        case route(String)
    }
"#;

    let mut routes_block = String::new();
    for case in &route_cases {
        routes_block.push_str(case);
        routes_block.push('\n');
    }
    routes_block.push_str(
        "                    case OrbitalViewModel.hostSignInRoute:\n                        OrbitalSignInView(viewModel: viewModel)\n",
    );
    routes_block.push_str("                    default:\n                        EmptyView()\n");

    let content = format!(
        r#"import Foundation
import SwiftUI

/// Root view generated for {}.
struct GeneratedApp: View {{
    @StateObject private var viewModel = OrbitalViewModel()
    @Environment(\.scenePhase) private var scenePhase
{}
    /// The one route switch: the stack root (`viewModel.rootRoute`) and every pushed
    /// destination render through it, so a replaced root is the same page a push would be.
    @ViewBuilder
    private func page(for path: String) -> some View {{
        switch path {{
{}
        }}
    }}

    var body: some View {{
        Group {{
            if viewModel.isReady {{
                NavigationStack(path: $viewModel.navigationPath) {{
                    page(for: viewModel.rootRoute)
                        .navigationDestination(for: Destination.self) {{ destination in
                            switch destination {{
                            case .route(let path):
                                page(for: path)
                            }}
                        }}
                }}
            }} else {{
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }}
        }}
        .onAppear {{
            // Loads the kernel off the main thread (B7); `initAllTraits`
            // runs once `start()` is ready, not directly here.
            viewModel.start()
            viewModel.setForeground(scenePhase == .active)
        }}
        .onChange(of: scenePhase) {{ phase in
            viewModel.setForeground(phase == .active)
        }}
        .environment(\.almadarTheme, viewModel.theme)
        .environment(\.almadarThemeMode, AlmadarThemeModeControl(isDark: viewModel.themeIsDark, toggle: viewModel.toggleThemeMode))
        .environment(\.almadarCanvasTheme, viewModel.canvasTheme)
        .environment(\.almadarResolvedMotion, viewModel.motion)
        .preferredColorScheme(viewModel.themeIsDark ? .dark : .light)
        .alert("Notice", isPresented: Binding(
            get: {{ viewModel.alertMessage != nil }},
            set: {{ _ in viewModel.alertMessage = nil }}
        )) {{
            Button("OK") {{ viewModel.alertMessage = nil }}
        }} message: {{
            Text(viewModel.alertMessage ?? "")
        }}
    }}
}}

{}/// Generated screen for a single page.
/// Renders `traitContent[trait]` (spliced for `@trait.X` composition) for every live
/// `main` writer as the primary body and attaches every populated non-main slot as a SwiftUI
/// presentation or overlay by its `SlotRole`.
struct GeneratedPage: View {{
    let pageName: String
    @ObservedObject var viewModel: OrbitalViewModel
    @Environment(\.almadarTheme) private var theme
    let traitNames: [String]

    /// Bound traits with a live `main` render, in first-write order.
    private var liveTraits: [String] {{
        viewModel.mainOrderWithAwaiting.filter {{ traitNames.contains($0) }}
    }}

    /// The trait events fall back to and the verify bridge routes to: the most recent
    /// `main` writer on this page, else the last live trait, else the first declared one.
    private var traitName: String {{
        if let writer = viewModel.lastMainWriter, liveTraits.contains(writer) {{ return writer }}
        return liveTraits.last ?? traitNames.first ?? ""
    }}

    private func traitBody(_ name: String) -> AnyView {{
        let content = viewModel.contentWithAwaiting
        let spliced = splice(content[name], sourceTrait: name, traitContent: content)
        let key = name + ":" + (spliced?.dictValue?["type"]?.stringValue ?? "")
        return AnyView(renderSlot(spliced).modifier(AlmadarSlotEnter(content: spliced, contentKey: key)))
    }}

    /// One live writer renders verbatim; two or more stack vertically; none is empty.
    @ViewBuilder
    private var mainBody: some View {{
        let live = liveTraits
        if live.count == 1, let only = live.first {{
            traitBody(only)
        }} else if live.count > 1 {{
            VStack(alignment: .leading, spacing: 24) {{
                ForEach(live, id: \.self) {{ traitBody($0) }}
            }}
        }}
    }}

    /// `payload` is always an `eventEnvelope` (`RenderersCommon.swift`) —
    /// `{{"sourceTrait": …, "actionPayload": …}}`, `actionPayload` absent when
    /// there is none. Dispatches to the trait that authored the control's own
    /// (spliced) props — `envelope.sourceTrait ?? traitName` — with
    /// `envelope.actionPayload`. Mirrors `helpers.rs::queue_event`.
    private func onEvent(_ event: String, _ payload: AnyCodable?) {{
        if event == OrbitalViewModel.navigateEvent {{
            viewModel.navigate(envelope: payload)
            return
        }}
        if event == OrbitalViewModel.signOutEvent {{
            viewModel.signOut()
            return
        }}
        let source = payload?.dictValue?["sourceTrait"]?.stringValue ?? traitName
        let sendPayload = payload?.dictValue?["actionPayload"]
        viewModel.sendEvent(trait: source, event: event, payload: sendPayload)
    }}

    private func renderSlot(_ content: AnyCodable?) -> AnyView {{
        guard let content = content, let typeName = content.dictValue?["type"]?.stringValue else {{ return AnyView(EmptyView()) }}
        return CorePatternRegistry.renderer(for: typeName)(content, AnyView(EmptyView()), onEvent)
    }}

    /// Splices an overlay slot's content, using its own wire `sourceTrait`
    /// (every render-ui root carries one) so a peer trait's modal composes
    /// correctly even though the page's own trait is different.
    private func splicedOverlay(_ content: AnyCodable?) -> AnyCodable? {{
        guard let content = content else {{ return nil }}
        let source = content.dictValue?["sourceTrait"]?.stringValue ?? traitName
        return splice(content, sourceTrait: source, traitContent: viewModel.contentWithAwaiting)
    }}

    @ViewBuilder
    private func overlaySlot(_ entry: (key: String, value: AnyCodable)?) -> some View {{
        if let entry = entry {{
            let content = splicedOverlay(entry.value)
            let role = slotRole(entry.key)
            renderSlot(content)
                .modifier(AlmadarSurfaceEnter(shape: role == .toast ? "toastEnter" : nil, timing: .toast, replayKey: entry.key + ":" + (content?.dictValue?["sourceTrait"]?.stringValue ?? "")))
                .verificationContainer(slotId(entry.key, holding: content))
        }}
    }}

    /// A slot stamped straight onto the one pattern it holds folds into a single accessibility
    /// element whose outer id wins, so that element carries both ids (one tree element per id).
    private func slotId(_ slot: String, holding content: AnyCodable?) -> String {{
        guard let type = content?.dictValue?["type"]?.stringValue else {{ return VerificationIds.slot(slot) }}
        return VerificationIds.ids(VerificationIds.slot(slot), VerificationIds.pattern(type))
    }}

    /// `main` holds one root only with one live writer; several stack inside a `VStack`.
    private var mainSlotId: String {{
        let live = liveTraits
        guard live.count == 1, let only = live.first else {{ return VerificationIds.slot("main") }}
        return slotId("main", holding: viewModel.contentWithAwaiting[only])
    }}

    var body: some View {{
        mainBody
            .modifier(AlmadarSurfaceEnter(shape: "pageEnter", timing: .page, replayKey: pageName))
            .verificationContainer(mainSlotId)
            .task(id: viewModel.paintGeneration) {{ [generation = viewModel.paintGeneration] in
                viewModel.reportPainted(generation)
            }}
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.color.background.ignoresSafeArea())
            .onAppear {{
            for name in traitNames where !name.isEmpty {{
                viewModel.initTrait(trait: name)
            }}
#if DEBUG
            if !traitName.isEmpty {{ viewModel.activePageTrait = traitName }}
#endif
        }}
#if DEBUG
        .onChange(of: traitName) {{ newValue in
            if !newValue.isEmpty {{ viewModel.activePageTrait = newValue }}
        }}
#endif
        // --- non-main slot overlays ---
        .sheet(isPresented: Binding(
            get: {{ viewModel.slotsWithAwaiting.keys.contains(where: {{ slotRole($0) == .modal }}) }},
            set: {{ if !$0 {{ viewModel.dismissSlots {{ slotRole($0) == .modal }} }} }}
        )) {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .modal }}))
        }}
        .sheet(isPresented: Binding(
            get: {{ viewModel.slotsWithAwaiting.keys.contains(where: {{ slotRole($0) == .drawer }}) }},
            set: {{ if !$0 {{ viewModel.dismissSlots {{ slotRole($0) == .drawer }} }} }}
        )) {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .drawer }}))
        }}
        .fullScreenCover(isPresented: Binding(
            get: {{ viewModel.slotsWithAwaiting.keys.contains(where: {{ slotRole($0) == .overlay }}) }},
            set: {{ if !$0 {{ viewModel.dismissSlots {{ slotRole($0) == .overlay }} }} }}
        )) {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .overlay }}))
        }}
        .overlay(alignment: .top) {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .hudTop }}))
        }}
        .overlay(alignment: .bottom) {{
            VStack(spacing: 0) {{
                overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .hudBottom }}))
                overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .toast }}))
                    .padding(.bottom, 16)
            }}
        }}
        .overlay(alignment: .bottomLeading) {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .sidebar }}))
                .frame(maxHeight: .infinity, alignment: .leading)
        }}
        .overlay {{
            overlaySlot(viewModel.slotsWithAwaiting.first(where: {{ slotRole($0.key) == .floating }}))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }}
    }}
}}
"#,
        app_name, destination_struct, routes_block, authenticated_page
    );

    GeneratedFile {
        path: "GeneratedApp.swift".to_string(),
        content,
    }
}

/// Bundle the schema's resolved form (Program B, §159: the in-app
/// `RuntimeKernel` mounts on-device, so it needs the same flattened
/// `OrbitalSchema` `orb verify`/`orb dev` resolve, with no compiler on
/// device). Written under `Sources/OrbitalApp` — the app target's declared
/// `sources:` root in `project.yml` — so xcodegen auto-bundles it as a
/// resource of the app target, the same mechanism that already bundles
/// `Sources/OrbitalAppTests/Resources/pattern-fixtures/*.json` into the
/// test target.
fn generate_resolved_schema_file(schema: &OrbitalSchema) -> GeneratedFile {
    let content = orbital_core_eval::util::canonical_json::to_canonical_string_pretty(schema)
        .unwrap_or_else(|e| format!("{{\"error\": \"failed to serialize resolved schema: {e}\"}}"));
    GeneratedFile {
        path: "Sources/OrbitalApp/Resources/resolved_schema.json".to_string(),
        content,
    }
}

/// The rendering type + optionality for a field: `effective_type()` is the
/// single owner of optionality (unwraps exactly one `Optional` layer, or
/// falls back to `!required` — the two spellings collapse to one flag), then
/// the enum-name override applies on top.
fn type_for_field(entity: &OirEntity, field: &OirField) -> (OirType, bool) {
    let (effective_ty, optional) = field.effective_type();
    let type_hint = if field.enum_values.is_some() {
        let enum_name = enum_class_name(&swift_entity_type(&entity.name), &field.name);
        OirType::Enum { name: enum_name }
    } else {
        effective_ty.clone()
    };
    (type_hint, optional)
}

fn enum_class_name(entity_name: &str, field_name: &str) -> String {
    format!("{}{}", entity_name, split_to_pascal_case(field_name))
}

/// The Swift leaf-renderer behind the shared `orbital_core` walker
/// ([`render_type`]). `context_name` names the `struct` a nested
/// `OirType::Struct` declares; the declaration is HOISTED into `hoisted`
/// (emitted before the entity struct) and the field references it by bare
/// name — a Swift type position cannot carry an inline struct declaration.
/// Nested structs extend the name positionally (`{Entity}{Field}{Nested}…`),
/// so sibling fields in a shared context never collide. The field-layer
/// `enum_values` rewrite happens upstream in [`type_for_field`], not here —
/// Swift ignores the sidecar.
struct SwiftRenderer<'a> {
    context_name: String,
    hoisted: &'a std::cell::RefCell<Vec<String>>,
}

impl TargetTypeRenderer for SwiftRenderer<'_> {
    type Out = String;

    fn string(&self, _enum_values: Option<&[String]>) -> String {
        "String".to_string()
    }
    fn number(&self) -> String {
        "Double".to_string()
    }
    fn integer(&self) -> String {
        "Int".to_string()
    }
    fn boolean(&self) -> String {
        "Bool".to_string()
    }
    fn date(&self) -> String {
        "String".to_string()
    }
    fn json(&self) -> String {
        "AnyCodable".to_string()
    }
    fn enum_ty(&self, name: &str, _enum_values: Option<&[String]>) -> String {
        split_to_pascal_case(name)
    }
    fn trait_ref(&self) -> String {
        "String".to_string()
    }
    fn sexpr(&self) -> String {
        "AnyCodable".to_string()
    }
    fn type_ref(&self, name: &str) -> String {
        // The named declaration hoists at the top of Entities.swift from
        // `OirModule::named_types` (resolver-registered recursive aliases AND
        // Phase-3D nominalized anonymous shapes) — the field references it by
        // bare name, mirroring the TS shell (types.rs `type_ref`).
        name.to_string()
    }
    fn row(&self, entity: &str) -> String {
        swift_entity_type(entity)
    }
    fn array(&self, _inner_ty: &OirType, inner: String) -> String {
        format!("[{}]", inner)
    }
    fn map(&self, _key_ty: &OirType, key: String, _value_ty: &OirType, value: String) -> String {
        format!("[{}: {}]", key, value)
    }
    fn optional(&self, _inner_ty: &OirType, inner: String) -> String {
        format!("{}?", inner)
    }
    fn struct_ty(&self, fields: &[OirField], _additional: Option<&OirType>) -> String {
        let name = self.context_name.clone();
        let parts: Vec<String> = fields
            .iter()
            .map(|f| {
                let (effective_ty, optional) = f.effective_type();
                let child = SwiftRenderer {
                    context_name: format!("{}{}", name, split_to_pascal_case(&f.name)),
                    hoisted: self.hoisted,
                };
                let t = render_type(&child, effective_ty, f.enum_values.as_deref());
                let opt = if optional { "?" } else { "" };
                format!(
                    "let {}: {}{}",
                    sanitize_identifier(&split_to_camel_case(&f.name), SWIFT_KEYWORDS),
                    t,
                    opt
                )
            })
            .collect();
        self.hoisted.borrow_mut().push(format!(
            "struct {}: Codable {{ {} }}",
            name,
            parts.join("; ")
        ));
        name
    }
    fn union_ty(&self, variants: &[OirField]) -> String {
        if variants.is_empty() {
            return self.json();
        }
        let name = self.context_name.clone();
        // A real discriminated union: an enum with associated values, one case
        // per variant. Each variant's struct shape hoists as its own named
        // struct (`{Name}{Variant}`); Swift synthesizes Codable for enums with
        // associated values (Swift 5.5+).
        let cases: Vec<String> = variants
            .iter()
            .map(|v| {
                let case_name = sanitize_identifier(&split_to_camel_case(&v.name), SWIFT_KEYWORDS);
                let variant_name = format!("{}{}", name, split_to_pascal_case(&v.name));
                let child = SwiftRenderer {
                    context_name: variant_name.clone(),
                    hoisted: self.hoisted,
                };
                match &v.field_type {
                    OirType::Struct { fields, additional: _additional } => {
                        let parts: Vec<String> = fields
                            .iter()
                            .map(|f| {
                                let (effective_ty, optional) = f.effective_type();
                                let grandchild = SwiftRenderer {
                                    context_name: format!(
                                        "{}{}",
                                        variant_name,
                                        split_to_pascal_case(&f.name)
                                    ),
                                    hoisted: self.hoisted,
                                };
                                let t = render_type(
                                    &grandchild,
                                    effective_ty,
                                    f.enum_values.as_deref(),
                                );
                                let opt = if optional { "?" } else { "" };
                                format!(
                                    "let {}: {}{}",
                                    sanitize_identifier(
                                        &split_to_camel_case(&f.name),
                                        SWIFT_KEYWORDS
                                    ),
                                    t,
                                    opt
                                )
                            })
                            .collect();
                        self.hoisted.borrow_mut().push(format!(
                            "struct {}: Codable {{ {} }}",
                            variant_name,
                            parts.join("; ")
                        ));
                        format!("case {}({})", case_name, variant_name)
                    }
                    other => {
                        format!("case {}({})", case_name, render_type(&child, other, None))
                    }
                }
            })
            .collect();
        self.hoisted.borrow_mut().push(format!(
            "enum {}: Codable {{\n    {}\n}}",
            name,
            cases.join("\n    ")
        ));
        name
    }

    // Classifications per `docs/Orbital_Type_Chain_Table.md` (Swift column)
    // as amended by Phase 3: Number→Double and the String-carried domains/
    // date are Widening (Integer is the faithful `Int`); Json is Lossy;
    // `type_ref` is the bare hoisted name — Faithful (Phase 3D: every entry's
    // declaration, recursive alias or nominalized anonymous shape, carries
    // the full shape at the top of Entities.swift); `scalar` is the named
    // hoisted 4-case Codable enum — Faithful (Phase 3); `node` is Widening —
    // the json carrier preserves the pattern-tree STRUCTURE, erasing only
    // the pattern TYPE; sexpr is the PERMANENT deliberate Lossy
    // (config/knob-only, no entity-data consequence — gaps §130 item 4);
    // Struct and Union are Faithful (named hoisted `struct` /
    // associated-value enum).
    fn classify_string(&self, _enum_values: Option<&[String]>) -> TypeMappingClass {
        TypeMappingClass::Faithful
    }
    fn classify_number(&self) -> TypeMappingClass {
        TypeMappingClass::Widening
    }
    fn classify_integer(&self) -> TypeMappingClass {
        TypeMappingClass::Faithful
    }
    fn classify_boolean(&self) -> TypeMappingClass {
        TypeMappingClass::Faithful
    }
    fn classify_date(&self) -> TypeMappingClass {
        TypeMappingClass::Widening
    }
    fn classify_json(&self) -> TypeMappingClass {
        TypeMappingClass::Lossy
    }
    fn classify_node(&self) -> TypeMappingClass {
        // The json carrier keeps the pattern tree's STRUCTURE and erases
        // only the pattern TYPE — Widening, not the json arm's Lossy. Typed
        // PatternNode codegen is deferred (rides on named_types).
        TypeMappingClass::Widening
    }
    fn classify_enum_ty(&self, _name: &str, _enum_values: Option<&[String]>) -> TypeMappingClass {
        TypeMappingClass::Faithful
    }
    fn classify_trait_ref(&self) -> TypeMappingClass {
        TypeMappingClass::Widening
    }
    fn classify_sexpr(&self) -> TypeMappingClass {
        // PERMANENT deliberate Lossy — sexprs are config/knob-only, never
        // entity data, so the erasure has no at-rest consequence (§130).
        TypeMappingClass::Lossy
    }
    fn classify_row(&self, _entity: &str) -> TypeMappingClass {
        // Pair decision with `row`: the entity's own struct carries the full shape.
        TypeMappingClass::Faithful
    }
    fn classify_type_ref(&self, _name: &str) -> TypeMappingClass {
        // Pair decision with `type_ref`: the bare name's declaration is
        // hoisted from `named_types` at the top of Entities.swift — Faithful
        // (Phase 3D; same flip TS always had).
        TypeMappingClass::Faithful
    }
    fn classify_array(&self, _inner_ty: &OirType, inner: TypeMappingClass) -> TypeMappingClass {
        inner
    }
    fn classify_map(
        &self,
        _key_ty: &OirType,
        key: TypeMappingClass,
        _value_ty: &OirType,
        value: TypeMappingClass,
    ) -> TypeMappingClass {
        key.meet(value)
    }
    fn classify_optional(&self, _inner_ty: &OirType, inner: TypeMappingClass) -> TypeMappingClass {
        inner
    }
    fn classify_struct_ty(&self, _fields: &[OirField], additional: Option<&OirType>) -> TypeMappingClass {
        if additional.is_some() { TypeMappingClass::Lossy } else { TypeMappingClass::Faithful }
    }
    fn classify_union_ty(&self, variants: &[OirField]) -> TypeMappingClass {
        // A named enum with associated values carries every variant's
        // structure — Faithful (the pair decision with `union_ty`).
        if variants.is_empty() {
            return self.classify_json();
        }
        TypeMappingClass::Faithful
    }
}

/// Classify an `OirType` under the Swift renderer's faithfulness table
/// (Phase-1 metadata; the classification never alters rendered output).
pub fn classify_oir_type(type_: &OirType) -> TypeMappingClass {
    let hoisted = std::cell::RefCell::new(Vec::new());
    classify_type(
        &SwiftRenderer {
            context_name: "Ctx".to_string(),
            hoisted: &hoisted,
        },
        type_,
        None,
    )
}

#[cfg(test)]
fn oir_type_to_swift(type_: &OirType, context_name: &str) -> String {
    let hoisted = std::cell::RefCell::new(Vec::new());
    render_type(
        &SwiftRenderer {
            context_name: context_name.to_string(),
            hoisted: &hoisted,
        },
        type_,
        None,
    )
}

/// Render an `OirType` and return the field type reference together with the
/// struct/enum declarations hoisted along the way (emitted before the
/// entity struct).
#[cfg(test)]
fn oir_type_to_swift_hoisted(type_: &OirType, context_name: &str) -> (String, Vec<String>) {
    let hoisted = std::cell::RefCell::new(Vec::new());
    let ty = render_type(
        &SwiftRenderer {
            context_name: context_name.to_string(),
            hoisted: &hoisted,
        },
        type_,
        None,
    );
    (ty, hoisted.into_inner())
}

/// The Swift leaf-renderer behind the shared `orbital_core` default-literal
/// walker ([`render_default`]). Struct/map/json/node/scalar defaults decline
/// (the trait's `object()` default stays `None`) — no default is emitted for
/// those field shapes; the field still renders, just without `= …`.
struct SwiftLiteral;

impl TargetLiteralRenderer for SwiftLiteral {
    type Out = String;

    fn null(&self) -> String {
        "nil".to_string()
    }
    fn bool(&self, b: bool) -> String {
        b.to_string()
    }
    fn integer(&self, i: i64) -> String {
        i.to_string()
    }
    fn number(&self, n: f64) -> String {
        // A Swift `Double` literal: force a fractional digit so a whole
        // number prints `1.0`, never the Int-looking `1`.
        if n.is_finite() && n.fract() == 0.0 {
            format!("{n:.1}")
        } else {
            n.to_string()
        }
    }
    fn string(&self, s: &str) -> String {
        format!("\"{}\"", escape_double_quoted(s))
    }
    fn enum_member(&self, enum_name: &str, member: &str) -> String {
        format!(
            "{}.{}",
            enum_name,
            sanitize_identifier(&split_to_camel_case(member), SWIFT_KEYWORDS)
        )
    }
    fn array(&self, items: Vec<String>) -> String {
        format!("[{}]", items.join(", "))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use orbital_core_base::ir::{OirEvent, OirPage, OirState, OirTrait, OirTraitBinding};
    use orbital_core_base::schema::{RestServiceDefInner, ServiceDefinition, ServiceRef};
    use std::collections::HashMap;

    fn trait_rendering_main(name: &str, children: &[&str]) -> orbital_core_base::ir::OirTrait {
        use orbital_core_base::ir::{OirEffect, OirExpr, OirPattern, OirTransition, OirValue};
        let mut pattern = OirPattern::new("stack");
        pattern.config.insert(
            "children".to_string(),
            OirValue::Array(
                children
                    .iter()
                    .map(|c| OirValue::String(format!("@trait.{c}")))
                    .collect(),
            ),
        );
        let mut t = OirTrait::new(name);
        t.states.push(OirState::initial("idle"));
        let mut tr = OirTransition::new("idle", "idle", "INIT");
        tr.effects.push(OirExpr::effect(OirEffect::RenderUi {
            slot: "main".to_string(),
            pattern,
        }));
        t.transitions.push(tr);
        t
    }

    fn embedding_module() -> OirModule {
        let mut module = OirModule::new("TestApp", "1.0.0");
        module
            .traits
            .push(trait_rendering_main("NoteAppLayout", &["NoteBrowseList"]));
        module
            .traits
            .push(trait_rendering_main("NoteBrowseList", &[]));
        module.traits.push(trait_rendering_main("PeerA", &[]));
        module.traits.push(trait_rendering_main("PeerB", &[]));
        module
    }

    fn awaiting_module() -> OirModule {
        let mut module = OirModule::new("App", "1.0.0");
        let mut browse = OirTrait::new("Browse");
        let mut load = orbital_core_base::ir::OirTransition {
            from: orbital_core_base::ir::OirTransitionFrom::Single("idle".into()),
            to: "loading".into(),
            event: "LOAD".into(),
            guard: None,
            effects: vec![],
            await_render: vec![],
        };
        load.await_render.push(orbital_core_base::ir::AwaitRender {
            trait_name: "Browse".into(),
            slot: "main".into(),
            skeleton: orbital_core_base::ir::SkeletonNode::Shape {
                shape: orbital_core_base::ir::SkeletonShape {
                    variant: "list".into(),
                    rows: Some(3),
                    columns: None,
                    fields: None,
                },
            },
        });
        browse.transitions.push(load);
        module.traits.push(browse);
        module
    }

    #[test]
    fn the_bridge_is_idle_only_once_the_page_painted_the_last_fold() {
        let vm = generate_view_model_file(&awaiting_module()).content;
        let fold = vm.find("private func foldResponse(").unwrap();
        let bump = vm[fold..]
            .find("paintGeneration += 1")
            .expect("every fold bumps the generation");
        let folded = vm[fold..]
            .find("kernel?.setVerifyFolded(paintGeneration)")
            .unwrap();
        assert!(bump < folded, "reported after it is bumped");
        let app = generate_app_file(&awaiting_module()).content;
        assert!(
            app.contains(".task(id: viewModel.paintGeneration) { [generation = viewModel.paintGeneration] in\n                viewModel.reportPainted(generation)"),
            "the page reports the generation it rendered, never a newer one"
        );
        let report = vm.find("func reportPainted(").unwrap();
        assert!(
            vm[report..].find("#if DEBUG").unwrap()
                < vm[report..].find("setVerifyPainted").unwrap(),
            "control: the bridge calls stay out of release builds"
        );
    }

    #[test]
    fn the_await_render_table_embeds_the_compilers_predictions() {
        let file = generate_await_renders_file(&awaiting_module());
        assert_eq!(file.path, "AwaitRenders.swift");
        assert!(
            file.content.contains(r#""requestTrait":"Browse""#),
            "{}",
            file.content
        );
        assert!(
            file.content.contains(r#""from":["idle"]"#),
            "{}",
            file.content
        );
        assert!(file
            .content
            .contains("static func matching(_ awaiting: KernelAwaitingTrait) -> [AwaitRender]"));
        let mut modal = awaiting_module();
        modal.traits[0].transitions[0].await_render[0].slot = "modal".into();
        assert!(
            generate_await_renders_file(&modal)
                .content
                .contains("#\"[]\"#"),
            "a portal slot never opens for a skeleton"
        );
        assert!(
            !file.content.contains("OrbitalViewModel."),
            "control: the table reaches no view-model member (its logger is private)"
        );
        let empty = generate_await_renders_file(&OirModule::new("App", "1.0.0"));
        assert!(
            empty.content.contains("#\"[]\"#"),
            "control: no predictions, an empty table"
        );
    }

    #[test]
    fn the_view_model_paints_row_set_markers_through_the_kernel_resolver() {
        let vm = generate_view_model_file(&awaiting_module()).content;
        assert!(
            vm.contains("var content = traitContent.mapValues(paintedRowSets)"),
            "the main slot paints resolved rows"
        );
        assert!(
            vm.contains("var slots = uiSlots.mapValues(paintedRowSets)"),
            "so does every overlay slot"
        );
        assert!(vm.contains("kernel?.resolvingRowSets(value) ?? value"));
        assert_eq!(
            vm.matches("paintedRowSets(").count(),
            1,
            "control: one resolver call site, the stored content is never rewritten"
        );
    }

    #[test]
    fn the_view_model_shows_a_predicted_skeleton_only_after_the_busy_delay_and_clears_it_with_the_leg(
    ) {
        let vm = generate_view_model_file(&awaiting_module()).content;
        assert!(
            vm.contains("guard theme.motion.awaitingSkeleton"),
            "the theme switch gates it"
        );
        assert!(
            vm.contains("asyncAfter(deadline: .now() + theme.motion.busyDelay)"),
            "after the busy delay"
        );
        assert!(
            vm.contains("beginAwaiting(result.awaiting.flatMap(AwaitRenders.matching), legs: result.serverLegs.count)"),
            "the kernel names the awaiting traits"
        );
        assert!(
            vm.contains("!Self.embeddedTraits.contains($0)"),
            "an embedded trait never owns main"
        );
        assert_eq!(
            vm.matches("self?.endAwaitingLeg(awaitToken)").count(),
            3,
            "every leg's outcome ends its share"
        );
        assert!(vm.contains("var contentWithAwaiting: [String: AnyCodable]"));
        assert!(vm.contains("var slotsWithAwaiting: [String: AnyCodable]"));
        let app = generate_app_file(&awaiting_module()).content;
        assert!(
            app.contains("viewModel.contentWithAwaiting"),
            "main and embedded positions read the skeleton"
        );
        assert!(
            app.contains("viewModel.slotsWithAwaiting.first(where:"),
            "overlay slots too"
        );
        assert!(app.contains("viewModel.dismissSlots { slotRole($0) == .modal }"));
        assert!(
            !app.contains("viewModel.uiSlots"),
            "control: every slot read goes through the awaiting view"
        );
    }

    #[test]
    fn embedded_trait_is_excluded_from_the_main_stack_but_kept_for_the_splice() {
        let vm = generate_view_model_file(&embedding_module()).content;
        assert!(vm.contains("static let embeddedTraits: Set<String> = [\"NoteBrowseList\"]"));
        // control: hosts and non-embedded peers are not in the set
        assert!(!vm.contains("embeddedTraits: Set<String> = [\"NoteAppLayout\""));
        assert!(!vm.contains("\"PeerA\", \"PeerB\"]"));
        let handlers = generate_effect_handlers_file().content;
        let guard = handlers
            .find("if !OrbitalViewModel.embeddedTraits.contains(source)")
            .unwrap();
        let append = handlers
            .find("viewModel?.mainOrder.append(source)")
            .unwrap();
        let index = handlers
            .find("viewModel?.traitContent[source] = content")
            .unwrap();
        assert!(
            index < guard && guard < append,
            "traitContent feeds the splice before the main-owner guard"
        );
    }

    #[test]
    fn module_without_embedding_has_an_empty_embedded_set_so_peers_stack() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        module.traits.push(trait_rendering_main("PeerA", &[]));
        module.traits.push(trait_rendering_main("PeerB", &[]));
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains("static let embeddedTraits: Set<String> = []"));
    }

    #[test]
    fn host_splice_still_reads_trait_content_for_the_embedded_trait() {
        let app = generate_splice_file().content;
        assert!(app.contains("traitContent"));
        assert!(app.contains("@trait."));
    }

    /// Kernel-mode shell: `os/` effects are never compiled into the generated client. They are
    /// unsupported here by design, and must stay out of the client-effect set the handlers cover.
    #[test]
    fn os_effects_are_not_silently_dropped_by_the_ios_shell() {
        use orbital_core_base::ir::{OirEffect, OirExpr, OirTransition};
        let effect = OirEffect::os(
            orbital_core_base::os::OsOp::ReadFile,
            vec![OirExpr::string("/data/secret.txt")],
            None,
            None,
        );
        assert!(
            !orbital_core_base::effect_types::CLIENT_EFFECT_KINDS.contains(&effect.kind()),
            "os/ effects are server-side; the client handlers must not claim them"
        );
        let mut module = OirModule::new("OsApp", "1.0.0");
        let mut t = OirTrait::new("Files");
        t.states.push(OirState::initial("idle"));
        let mut tr = OirTransition::new("idle", "idle", "READ");
        tr.effects.push(OirExpr::effect(effect));
        t.transitions.push(tr);
        module.traits.push(t);
        let output = IosBackend::new().generate(&module);
        let all: String = output.files.iter().map(|f| f.content.as_str()).collect();
        assert!(
            !all.contains("secret.txt") && !all.contains("os/read-file"),
            "the shell runs kernel mode only: os/ is unsupported in generated code, never half-emitted"
        );
        let handlers = output
            .files
            .iter()
            .find(|f| f.path.starts_with("EffectHandlers."))
            .map(|f| f.content.as_str())
            .unwrap_or_default();
        assert!(!handlers.contains("os/"), "{handlers}");
    }

    #[test]
    fn test_backend_name() {
        let backend = IosBackend::new();
        assert_eq!(backend.name(), "ios");
    }

    fn entities_file(module: &OirModule) -> String {
        IosBackend::new()
            .generate(module)
            .files
            .into_iter()
            .find(|f| f.path == "Entities.swift")
            .map(|f| f.content)
            .unwrap_or_default()
    }

    #[test]
    fn test_entities_declared_once_when_module_carries_same_named_clones() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        module.entities.push(OirEntity::new("User"));
        module.entities.push(OirEntity::new("User"));
        assert_eq!(entities_file(&module).matches("struct User:").count(), 1);
    }

    #[test]
    fn test_entities_keeps_distinct_names() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        module.entities.push(OirEntity::new("User"));
        module.entities.push(OirEntity::new("UserProfile"));
        let content = entities_file(&module);
        assert_eq!(content.matches("struct User:").count(), 1);
        assert!(content.contains("struct UserProfile"));
    }

    #[test]
    fn test_generate_produces_files() {
        let backend = IosBackend::new();
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut entity = OirEntity::new("User");
        entity.fields.push(OirField::new("email", OirType::String));
        module.entities.push(entity);

        let output = backend.generate(&module);
        let paths: Vec<_> = output.files.iter().map(|f| f.path.as_str()).collect();
        assert!(paths.contains(&"Entities.swift"));
        assert!(paths.contains(&"Services.swift"));
        assert!(paths.contains(&"APIClient.swift"));
        assert!(paths.contains(&"OrbitalViewModel.swift"));
        assert!(paths.contains(&"EffectHandlers.swift"));
        assert!(paths.contains(&"Splice.swift"));
        assert!(paths.contains(&"Views/PatternRenderer.swift"));
        assert!(paths.contains(&"Views/core/FallbackRenderer.swift"));
        assert!(paths.contains(&"Views/core/RenderersCommon.swift"));
        assert!(paths.contains(&"Views/core/CorePatternRegistry.swift"));
        assert!(paths.contains(&"GeneratedApp.swift"));
    }

    #[test]
    fn test_generate_omits_resolved_schema_without_one() {
        let backend = IosBackend::new();
        let module = OirModule::new("TestApp", "1.0.0");
        let output = backend.generate(&module);
        assert!(!output
            .files
            .iter()
            .any(|f| f.path == "Sources/OrbitalApp/Resources/resolved_schema.json"));
    }

    #[test]
    fn test_generate_with_resolved_schema_emits_resource_file() {
        let schema = orbital_core_base::schema::parse_schema(r#"{"name":"Test","orbitals":[]}"#)
            .expect("minimal schema parses");
        let backend = IosBackend::new().with_resolved_schema(schema);
        let module = OirModule::new("TestApp", "1.0.0");
        let output = backend.generate(&module);
        let resource = output
            .files
            .iter()
            .find(|f| f.path == "Sources/OrbitalApp/Resources/resolved_schema.json")
            .expect("resolved_schema.json not emitted");
        let round_tripped: orbital_core_base::schema::types::OrbitalSchema =
            serde_json::from_str(&resource.content).expect("emitted content is valid JSON");
        assert_eq!(round_tripped.name, "Test");
    }

    #[test]
    fn test_registry_file_contains_fallback_and_known_patterns() {
        let backend = IosBackend::new();
        let module = OirModule::new("TestApp", "1.0.0");
        let output = backend.generate(&module);
        let registry = output
            .files
            .iter()
            .find(|f| f.path == "Views/core/CorePatternRegistry.swift")
            .unwrap();
        assert!(registry.content.contains("struct CorePatternRegistry"));
        assert!(registry.content.contains("FallbackRendererView"));
    }

    #[test]
    fn test_entity_with_enum_and_defaults() {
        let mut entity = OirEntity::new("Task");
        entity.fields.push(OirField::new("title", OirType::String));
        entity.fields.push({
            let mut f = OirField::new("priority", OirType::String);
            f.enum_values = Some(vec!["low".to_string(), "high".to_string()]);
            f
        });
        entity.fields.push({
            let mut f = OirField::new("completed", OirType::Boolean);
            f.default = Some(OirValue::Bool(false));
            f
        });
        entity.fields.push({
            let mut f = OirField::new(
                "tags",
                OirType::Array {
                    inner: Box::new(OirType::String),
                },
            );
            f.required = false;
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains("enum TaskEntityPriority: String, Codable"));
        assert!(content.contains("case low = \"low\""));
        assert!(content.contains("case high = \"high\""));
        assert!(content.contains("let completed: Bool = false"));
        assert!(content.contains("let tags: [String]?"));
    }

    /// The API client's ONLY remaining job is posting a kernel-produced
    /// server leg and streaming live-push — the wire types are the
    /// hand-authored bridge's `KernelServerLeg`/`KernelEventResponse`
    /// (mirrors of `orbital_core::EventRequest`/`EventResponse` =
    /// `@almadar/core`'s `EventDispatchRequest`/`EventDispatchResponse`,
    /// ledger §156), never a second per-shell wire struct. Posts to the
    /// canonical `POST /api/orbitals/:orbital/events` route (A8a,
    /// `orbital-shell-typescript`'s `orbital_route.rs`) — no client-side
    /// per-trait URL table; the route itself resolves the trait to
    /// dispatch from the body.
    #[test]
    fn api_client_posts_canonical_orbital_route() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_api_client_file(&module).content;
        assert!(content.contains("class OrbitalAPI"));
        assert!(content.contains("func postServerLeg"));
        assert!(content.contains("_ leg: KernelServerLeg"));
        assert!(content.contains("KernelEventResponse.self"));
        assert!(content.contains(r#"/api/orbitals/\(encodedOrbital)/events"#));
        assert!(content.contains("orbital: String,"));
        // Control: no baked orbital constant survives.
        assert!(!content.contains("orbitalName"));
        assert!(!content.contains("__ORBITAL_NAME__"));
        // The old per-shell wire structs are gone entirely, not just unused.
        assert!(!content.contains("struct EventResponse"));
        assert!(!content.contains("struct EmittedEvent"));
        assert!(!content.contains("struct TransitionResult"));
        assert!(!content.contains("func sendEvent"));
        assert!(!content.contains("func getState"));
    }

    /// The server-leg URL is built from the dispatch wire's `orbital` (the
    /// kernel's owning orbital for the trait), threaded fold -> view model ->
    /// `OrbitalAPI.postServerLeg`; the bridge decodes it from the wire.
    #[test]
    fn server_leg_url_comes_from_the_dispatch_wire_orbital() {
        let module = OirModule::new("TestApp", "1.0.0");
        let vm = generate_view_model_file(&module).content;
        assert_eq!(
            vm.matches("orbital: routed.orbital, alreadyDelivered: result.alreadyDelivered")
                .count(),
            3,
            "the local-seed, optimistic and persisted legs all post to the wire orbital"
        );
        assert!(vm.contains("api.postServerLeg(leg, orbital: orbital, requestTrait: requestTrait)"));
        let bridge = include_str!("../renderers/swiftui/renderers/bridge/OrbitalKernelBridge.swift");
        assert!(bridge.contains("orbital: wire.orbital,"));
        assert!(bridge.contains("let orbital: String"));
        // Control: a different module name changes nothing about the URL source.
        let other = generate_api_client_file(&OirModule::new("OtherApp", "1.0.0")).content;
        assert_eq!(other, generate_api_client_file(&module).content);
    }

    /// `GET /api/events` streams through `URLSession.bytes(for:)`, decoding
    /// `LiveBroadcastItem`s and reconnecting with backoff on a stream error
    /// — never a crash.
    #[test]
    fn live_push_subscriber_feeds_kernel_and_ignores_own_client_id() {
        let module = OirModule::new("TestApp", "1.0.0");
        let api_content = generate_api_client_file(&module).content;
        assert!(api_content.contains("func openLivePush"));
        assert!(api_content.contains("bytes(for: request)"));
        assert!(api_content.contains("bytes.lines"));
        assert!(api_content.contains("struct LiveBroadcastItem: Decodable"));

        let vm_content = generate_view_model_file(&module).content;
        assert!(vm_content.contains("func handleLivePush"));
        assert!(vm_content.contains("item.originClientId != clientId"));
        assert!(vm_content.contains("kernel.dispatch(trait: trait, entityId: nil, event: item.event, payloadJSON: payloadJSON)"));
    }

    #[test]
    fn test_view_model_generated() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut page = OirPage::new("Home", "/");
        page.traits.push(OirTraitBinding::new("HomeLifecycle"));
        module.pages.push(page);

        let content = generate_view_model_file(&module).content;
        assert!(content.contains("class OrbitalViewModel"));
        assert!(content.contains("func initTrait"));
        assert!(content.contains("func sendEvent"));
        assert!(content.contains("func initAllTraits"));
        assert!(content.contains("func start()"));
    }

    /// The view model carries a `theme: AlmadarTheme` published property,
    /// defaulted to the baked fallback until the kernel snapshot (wave B7)
    /// sets it — see `templates/native-theme-map.ts` (Program C, C1(d)).
    #[test]
    fn test_view_model_carries_almadar_theme() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("@Published var theme: AlmadarTheme = .fallback"));
        assert!(content.contains("set by the kernel snapshot (wave B7)"));
    }

    /// C1c/B7: the view model's `theme` published property is set from the
    /// kernel's OWN snapshot (`orbital_kernel_snapshot`'s `theme` field),
    /// never a local guess or a second resolution — `AlmadarTheme.from` is
    /// called on `snap.theme.tokens` inside `start()`.
    #[test]
    fn theme_comes_from_kernel_snapshot() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("let snap = kernel.snapshot()"));
        assert!(content.contains("self.apply(resolvedTheme: snap.theme)"));
        assert!(content.contains("AlmadarTheme.from(tokens: resolved.tokens"));
    }

    /// Only the traits that declare an `INIT` event auto-dispatch it, and in
    /// DECLARATION order — `initAllTraits` walks this list once at app
    /// start, not a `Set`. The per-trait initial-STATE seed table this used
    /// to sit next to is gone (B7): `initTrait` now reads the kernel's own
    /// resolved state instead of a local guess.
    #[test]
    fn view_model_traits_with_init_declaration_order() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut with_init = OirTrait::new("NoteAppLayout");
        with_init.states.push(OirState::new("editing"));
        with_init.states.push(OirState::initial("browsing"));
        with_init.events.push(OirEvent::new("INIT"));
        module.traits.push(with_init);
        let mut without_init = OirTrait::new("FavoritesLayout");
        without_init.states.push(OirState::initial("idle"));
        module.traits.push(without_init);

        let content = generate_view_model_file(&module).content;
        assert!(content.contains(r#"traitsWithInit: [String] = ["NoteAppLayout"]"#));
        assert!(content.contains("kernel.state(of: trait, entityId: nil)"));
    }

    /// The mount is declared before the first `INIT` fires (mirrors
    /// `ClientCore::init_all_traits_blocking`), so a seed one trait's INIT
    /// emits is held until its receiver's own INIT instead of being dropped.
    #[test]
    fn init_all_traits_declares_the_mount_before_any_init() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let remount = content
            .find("kernel?.remount(traits: OrbitalViewModel.traitsWithInit)")
            .expect("initAllTraits must declare the mount");
        let first_init = content
            .find(r#"sendEvent(trait: trait, event: "INIT")"#)
            .unwrap();
        assert!(remount < first_init, "remount must precede the INIT loop");
    }

    /// The bridge is told the host is mounting before the first `INIT` and mounted after the last,
    /// so `/idle` cannot answer idle between the app launching and its INIT legs being counted.
    #[test]
    fn init_all_traits_brackets_the_init_loop_with_verify_ready() {
        let module = OirModule::new("TestApp", "1.0.0");
        let whole = generate_view_model_file(&module).content;
        let start = whole.find("func initAllTraits()").unwrap();
        let end = start + whole[start..].find("\n    }\n").unwrap();
        let content = whole[..end].to_string();
        let not_ready = content
            .find("kernel?.setVerifyReady(false)")
            .expect("ready=false");
        let remount = content
            .find("kernel?.remount(traits: OrbitalViewModel.traitsWithInit)")
            .unwrap();
        let first_init = content
            .find(r#"sendEvent(trait: trait, event: "INIT")"#)
            .unwrap();
        let ready = content
            .find("kernel?.setVerifyReady(true)")
            .expect("ready=true");
        assert!(not_ready < remount && remount < first_init && first_init < ready);
        assert_eq!(
            whole.matches("setVerifyReady(").count(),
            4,
            "only the INIT brackets (app mount + a gated page mount) flip readiness"
        );
        assert!(inside_debug_block(&content, not_ready));
        assert!(inside_debug_block(&content, ready));
        let gated = &whole[whole.find("func mountGatedPage").unwrap()..];
        assert!(
            gated.find("setVerifyReady(false)").unwrap()
                < gated.find("kernel?.mount(traits: pending)").unwrap()
        );
    }

    /// Control: the readiness bracket is DEBUG-only, so a release shell never references the symbol.
    #[test]
    fn verify_ready_never_escapes_debug() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        for (at, _) in content.match_indices("setVerifyReady(") {
            assert!(
                inside_debug_block(&content, at),
                "setVerifyReady at {at} escapes #if DEBUG"
            );
        }
    }

    /// The view model owns one `OrbitalKernel` handle for its whole
    /// lifetime (B5/B7) — every dispatch/init/live-push path reads it,
    /// never a second kernel or a direct HTTP call for a local dispatch.
    #[test]
    fn view_model_owns_kernel_handle() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("private var kernel: OrbitalKernel?"));
        assert!(content.contains("OrbitalKernel(resolvedSchemaJSON: $0, clientId: clientId)"));
        assert!(content.contains(
            "kernel.dispatch(trait: trait, entityId: nil, event: event, payloadJSON: payloadJSON)"
        ));
    }

    /// `resolved_schema.json` loads on a background queue
    /// (`DispatchQueue.global`), never the main thread — the kernel handle
    /// itself is only ever assigned back on `DispatchQueue.main`.
    #[test]
    fn view_model_loads_resolved_schema_off_main_thread() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("DispatchQueue.global(qos: .userInitiated).async"));
        assert!(content.contains("func loadResolvedSchemaJSON() -> String?"));
        assert!(content
            .contains(r#"Bundle.main.url(forResource: "resolved_schema", withExtension: "json")"#));
    }

    /// A dispatch only posts a server leg when the kernel actually produced
    /// one (`result.serverLegs`) — a plain `set`-only transition, or a
    /// `local` trait, never opens an HTTP request.
    #[test]
    fn view_model_posts_server_leg_only_when_present() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert_eq!(
            content.matches("for routed in result.serverLegs {").count(),
            3,
            "expected the hybridClientOnly, runtimeOptimistic AND persistedAwaited branches to each post only the legs present:\n{content}"
        );
    }

    /// `hybridClientOnly` (a `local` seed) posts only the leg the kernel produced
    /// for its cascade's server-bound traits, and a failed post abandons it
    /// (no snapshot), so the verify bridge's pending count always returns to idle.
    #[test]
    fn view_model_hybrid_local_posts_only_its_cascade_leg_and_accounts_for_it() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let case_start = content
            .find("case .hybridClientOnly:")
            .expect("missing hybridClientOnly arm");
        let case_end = content[case_start..]
            .find("case .runtimeOptimistic:")
            .expect("missing runtimeOptimistic arm");
        let hybrid_arm = &content[case_start..case_start + case_end];
        assert!(hybrid_arm.contains("for routed in result.serverLegs {"));
        assert!(hybrid_arm.contains("postServerLeg(leg"));
        assert!(hybrid_arm.contains("restoreOnServerFailure"));
        assert!(hybrid_arm.contains("posting cascade server leg for local seed"));
    }

    /// Control: a `local` seed with no leg posts nothing (the guard returns
    /// before `postServerLeg`), and the one failure path both restores a
    /// snapshot or abandons the leg, so no branch leaves it uncounted.
    #[test]
    fn view_model_every_leg_branch_ends_in_apply_restore_or_abandon() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert_eq!(
            content
                .matches("            postServerLeg(leg, requestTrait:")
                .count(),
            3
        );
        assert_eq!(content.matches("self?.restoreOnServerFailure(").count(), 3);
        assert!(content
            .contains("kernel?.abandonServerLeg(trait: trait, event: event, error: message)"));
    }

    /// `RuntimeOptimistic` rolls the pre-dispatch snapshot back on a server
    /// disagreement (`kernel.restore`) and reflects the restored state into
    /// `states`, then surfaces the failure as an alert — mirrors
    /// `ClientKernel::dispatch`'s `RuntimeOptimistic` arm.
    #[test]
    fn view_model_restores_on_server_error() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("func restoreOnServerFailure"));
        assert!(content
            .contains("kernel.restore(trait: trait, entityId: entityId, snapshot: snapshot)"));
        assert!(content.contains("states[trait] = snapshot.state"));
        assert!(content.contains("alertMessage = message"));
    }

    /// The server's `EventResponse` folds into the kernel via
    /// `applyServerResponse`, deduped against the locally-already-delivered
    /// `(trait, event)` pairs `dispatch` itself returned — an echo of the
    /// SAME dispatch over live-push (or the leg's own response) must never
    /// re-fire a listener a second time. Replaces the old stateless-server
    /// `emittedEvents` re-dispatch loop entirely.
    #[test]
    fn view_model_applies_server_response_with_echo_dedup() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("kernel.applyServerResponse(responseJSON: posted.json, alreadyDelivered: alreadyDelivered)"));
        // The old stateless re-dispatch loop must be gone entirely, not
        // just unused.
        assert!(!content.contains("response.emittedEvents"));
        assert!(!content.contains("sendEvent(trait: trait, event: ev.event"));
    }

    /// The applied-response branch folds its outcomes' effects through the
    /// SAME `foldResponse` a dispatch uses, and the fold exists once.
    #[test]
    fn applied_server_response_folds_through_the_dispatch_fold() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let success = fold_arm(
            &content,
            "case .success(let posted) where posted.response.success:",
            "case .success(let posted):",
        );
        assert!(success.contains("self.foldResponse(applied.response)"));
        assert!(content.contains("foldResponse(result.response)"));
        assert_eq!(content.matches("func foldResponse(").count(), 1);
        assert_eq!(content.matches("effectHandlers.apply(effect:").count(), 1);
        let failure = fold_arm(
            &content,
            "case .success(let posted):",
            "case .failure(let error):",
        );
        assert!(!failure.contains("foldResponse"));
    }

    #[test]
    fn test_app_generates_navigation() {
        let backend = IosBackend::new();
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut page = OirPage::new("Home", "/");
        page.traits.push(OirTraitBinding::new("HomeLifecycle"));
        module.pages.push(page);

        let output = backend.generate(&module);
        let paths: Vec<_> = output.files.iter().map(|f| f.path.as_str()).collect();
        assert!(paths.contains(&"OrbitalViewModel.swift"));
        assert!(paths.contains(&"EffectHandlers.swift"));

        let app = output
            .files
            .iter()
            .find(|f| f.path == "GeneratedApp.swift")
            .unwrap();
        assert!(app.content.contains("NavigationStack"));
        assert!(app.content.contains("GeneratedPage"));
        assert!(app
            .content
            .contains(".environment(\\.almadarTheme, viewModel.theme)"));
    }

    /// The regression this program exists to fix: the NavigationStack's root
    /// content must be the start page itself (same rule Android uses to pick
    /// `startDestination` — `module.pages.first()`), not a bare title/Spacer.
    #[test]
    fn test_app_root_renders_start_page() {
        let backend = IosBackend::new();
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut notes_page = OirPage::new("Notes", "/notes");
        notes_page
            .traits
            .push(OirTraitBinding::new("NoteAppLayout"));
        module.pages.push(notes_page);
        let mut favorites_page = OirPage::new("Favorites", "/notes/favorites");
        favorites_page
            .traits
            .push(OirTraitBinding::new("FavoritesLayout"));
        module.pages.push(favorites_page);

        let output = backend.generate(&module);
        let app = output
            .files
            .iter()
            .find(|f| f.path == "GeneratedApp.swift")
            .unwrap();

        // Root content of the NavigationStack is a GeneratedPage for the
        // start route, not a standalone title Text.
        assert!(
            app.content.contains(
                "GeneratedPage(pageName: \"Notes\", viewModel: viewModel, traitNames: [\"NoteAppLayout\"])"
            ),
            "root body must render the start page's GeneratedPage:\n{}",
            app.content
        );
        assert!(!app.content.contains("Text(\"TestApp\")"));

        // Exactly one navigationDestination registration (SwiftUI only
        // honors the first — must not repeat one per page).
        assert_eq!(
            app.content
                .matches("navigationDestination(for: Destination.self)")
                .count(),
            1
        );

        // Every declared route appears once in the inner switch, each
        // matched verbatim (mirrors Android's `composable(p.path)`, which
        // also matches its route string verbatim).
        assert_eq!(app.content.matches("case \"/notes\":").count(), 1);
        assert_eq!(app.content.matches("case \"/notes/favorites\":").count(), 1);
        assert!(app.content.contains(
            "GeneratedPage(pageName: \"Favorites\", viewModel: viewModel, traitNames: [\"FavoritesLayout\"])"
        ));

        // Unmatched routes render nothing — no guessed fallback page.
        assert!(app
            .content
            .contains("default:\n                        EmptyView()"));
    }

    #[test]
    fn initial_route_env_navigates_through_the_shared_sink_in_debug_only() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let open = vm.find("func openInitialRouteIfRequested()").unwrap();
        let body = &vm[open..];
        assert!(body.contains(r#"environment["ORBITAL_INITIAL_ROUTE"]"#));
        assert!(body.contains("replaceRoot(with: route)"));
        assert!(!body.contains("navigate(to: route)"));
        let debug_start = vm
            .find("#if DEBUG\n                self.openInitialRouteIfRequested()")
            .unwrap();
        let ready = vm.find("self.isReady = true\n#if DEBUG").unwrap();
        assert!(ready < debug_start);
        let def_if = vm[..open].rfind("#if DEBUG").unwrap();
        let def_endif = vm[..open].rfind("#endif").unwrap_or(0);
        assert!(def_if > def_endif, "the reader sits inside a DEBUG block");
    }

    #[test]
    fn no_initial_route_env_means_no_navigation_and_start_route_is_not_pushed() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let open = vm.find("func openInitialRouteIfRequested()").unwrap();
        let body = &vm[open..open + vm[open..].find("\n    }\n").unwrap()];
        assert!(body.contains("guard let route = ProcessInfo.processInfo.environment[\"ORBITAL_INITIAL_ROUTE\"], !route.isEmpty else { return }"));
        assert!(
            body.contains("if route != OrbitalViewModel.startRoute { replaceRoot(with: route) }")
        );
        let guard_at = body.find("guard let").unwrap();
        let nav_at = body.find("replaceRoot(with: route)").unwrap();
        assert!(guard_at < nav_at);
    }

    /// The initial route REPLACES the stack root (a push leaves a stray back chevron over the
    /// layout): the root view reads `rootRoute`, and `replaceRoot` clears the pushed stack.
    #[test]
    fn initial_route_replaces_the_stack_root_instead_of_pushing() {
        let module = module_with_pages(&[("Home", "/home"), ("Notes", "/notes")]);
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains("@Published var rootRoute: String = OrbitalViewModel.startRoute"));
        let replace = fold_arm(
            &vm,
            "private func replaceRoot(with path: String)",
            "/// Publishes the current route",
        );
        assert!(replace.contains("routeStack = []"));
        assert!(replace.contains("rootRoute = path"));
        assert!(replace.contains("navigationPath = NavigationPath()"));
        assert!(!replace.contains("navigationPath.append"));
        let open = fold_arm(
            &vm,
            "private func openInitialRouteIfRequested()",
            "private func replaceRoot",
        );
        assert!(!open.contains("navigate(to:"));
        let app = generate_app_file(&module).content;
        assert!(app.contains("NavigationStack(path: $viewModel.navigationPath) {\n                    page(for: viewModel.rootRoute)"));
        assert!(
            app.contains("case .route(let path):\n                                page(for: path)")
        );
        // Control: the push entry still pushes, and still feeds the same route switch.
        assert!(vm.contains("navigationPath.append(GeneratedApp.Destination.route(path))"));
        assert_eq!(app.matches("case \"/notes\":").count(), 1);
        assert_eq!(
            app.matches("private func page(for path: String)").count(),
            1
        );
    }

    /// `navigate` must push the typed `Destination.route(...)` the single
    /// `navigationDestination(for: Destination.self)` registration matches —
    /// pushing a bare `String` never routes anywhere.
    #[test]
    fn test_navigate_effect_pushes_destination_route() {
        let content = generate_effect_handlers_file().content;
        assert!(content.contains("viewModel?.navigate(to: path)"));
        assert!(!content.contains("navigationPath.append"));
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(vm.contains("navigationPath.append(GeneratedApp.Destination.route(path))"));
        assert!(!vm.contains("navigationPath.append(path)"));
    }

    #[test]
    fn test_service_config_generation() {
        let mut headers = HashMap::new();
        headers.insert("Authorization".to_string(), "Bearer token".to_string());

        let service_ref = ServiceRef::Inline(ServiceDefinition::Rest(RestServiceDefInner {
            name: "backend".to_string(),
            description: Some("Backend API".to_string()),
            base_url: "https://api.example.com".to_string(),
            headers: Some(headers),
            auth: None,
            timeout: Some(5000),
        }));

        let content = generate_services_file(&[service_ref]).content;
        assert!(content.contains("struct BackendRestConfig"));
        assert!(content.contains("let baseUrl: String = \"https://api.example.com\""));
        assert!(content.contains("\"Authorization\": \"Bearer token\""));
    }

    #[test]
    fn test_reference_field_type() {
        // A relation field stores the referenced row's id — String, per the
        // `orbital_core` default (`render.rs` C1) — never the entity's own
        // type name. A non-required relation carries the same String?
        // optionality every other type gets, via `effective_type`.
        let mut entity = OirEntity::new("Order");
        entity.fields.push(OirField::new(
            "customer",
            OirType::Reference {
                entity: "Customer".to_string(),
            },
        ));
        entity.fields.push({
            let mut f = OirField::new(
                "backupCustomer",
                OirType::Reference {
                    entity: "Customer".to_string(),
                },
            );
            f.required = false;
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains("let customer: String"));
        assert!(content.contains("let backupCustomer: String?"));
    }

    /// Coverage gate: the EffectHandlers `switch` must handle every client-effect kind the kernel
    /// can hand back (orbital_core::effects::CLIENT_EFFECT_KINDS) — no silent `default` fall-through.
    #[test]
    fn effect_handlers_cover_all_client_effect_kinds() {
        let content = generate_effect_handlers_file().content;
        for kind in orbital_core_base::effect_types::CLIENT_EFFECT_KINDS {
            let arm = format!("case \"{kind}\":");
            assert!(
                content.contains(&arm),
                "EffectHandlers.swift missing an arm for client effect `{kind}` (expected `{arm}`)"
            );
        }
    }

    /// A `render-ui` effect indexes `traitContent` by `sourceTrait` (falling
    /// back to `requestTrait`) and never stores a `main`-role render in
    /// `uiSlots` — mirrors `ClientCore::process_response`'s indexing pass.
    #[test]
    fn effect_handlers_index_render_ui_by_source_trait() {
        let content = generate_effect_handlers_file().content;
        assert!(
            content.contains(r#"content.dictValue?["sourceTrait"]?.stringValue ?? requestTrait"#)
        );
        assert!(content.contains("slotRole(slot) == .main"));
        assert!(content.contains("viewModel?.traitContent[source] = content"));
        assert!(content.contains("viewModel?.uiSlots[slot] = content"));
    }

    /// `emit` re-dispatches to the REQUEST trait (the trait the event that
    /// produced this effect was sent to), not the currently-displayed page
    /// trait — mirrors `ClientCore::execute_client_effect(Emit)`.
    #[test]
    fn effect_handlers_emit_redispatches_to_request_trait() {
        let content = generate_effect_handlers_file().content;
        assert!(content.contains(
            r#"viewModel?.sendEvent(trait: requestTrait, event: event, payload: arr[safe: 2])"#
        ));
    }

    /// Every `emit` is posted to the renderer kit's `AlmadarBus` before it re-dispatches, so a
    /// renderer with an event-listen prop (code-block `onSetMode`) hears it — CodeBlock.tsx's bus listen.
    #[test]
    fn effect_handlers_post_every_emit_to_the_renderer_bus() {
        let content = generate_effect_handlers_file().content;
        let post = content.find("AlmadarBus.shared.post(event, arr[safe: 2])").expect("emit posts to the bus");
        let redispatch = content.find("viewModel?.sendEvent(trait: requestTrait, event: event, payload: arr[safe: 2])").unwrap();
        assert!(post < redispatch);
    }

    /// The splice function exists with the `@trait.` token contract:
    /// resolves against `traitContent`, tags typed nodes with `sourceTrait`,
    /// and guards against a trait already on the splice stack (a cycle never
    /// recurses) — mirrors `recurse.rs::child_patterns` + `helpers.rs::
    /// render_children`/`RenderContext.source_trait`.
    #[test]
    fn splice_file_has_trait_token_contract() {
        let content = generate_splice_file().content;
        assert!(content.contains("func splice("));
        assert!(content.contains(r#"s.hasPrefix("@trait.")"#));
        assert!(content.contains(r#"out["sourceTrait"] = .string(sourceTrait)"#));
        assert!(content.contains("visited.contains(name)"));
    }

    /// An unresolved `@trait.X` scalar `children` ref splices to an empty array,
    /// mirroring the Android `spliceChildren`; a `.null` would render as an
    /// unsupported pattern.
    #[test]
    fn splice_drops_a_scalar_children_ref_that_resolves_to_null() {
        let content = generate_splice_file().content;
        let start = content.find("private func spliceChildren(").unwrap();
        let end = start + content[start..].find("private func spliceChild(").unwrap();
        let body = &content[start..end];
        assert!(body.contains("if case .null = spliced { return .array([]) }"));
        assert!(body.contains("if case .null = child { return nil }"));
        // Control: the node still routes `children` through it, every other prop
        // keeps the plain prop splice, and a resolved ref / array path survives.
        assert!(content.contains(r#"if key == "children" {"#));
        assert!(content.contains("out[key] = spliceChildren(v, "));
        assert!(content.contains("out[key] = splicePropValue(v, "));
        assert!(body.contains("return spliced"));
        assert!(body.contains("spliceChild(child, sourceTrait: sourceTrait"));
        let prop = &content[content.find("private func splicePropValue(").unwrap()..];
        assert!(prop.contains("else { return .null }"));
    }

    /// Mount mirrors `ClientKernel`/`ClientCore::init_all_traits_blocking`:
    /// the app root calls `viewModel.start()` exactly once (never per-page),
    /// which loads the kernel then runs `initAllTraits` itself exactly once
    /// — both idempotent.
    #[test]
    fn app_mounts_init_all_traits_once_at_root() {
        let backend = IosBackend::new();
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut page = OirPage::new("Home", "/");
        page.traits.push(OirTraitBinding::new("HomeLifecycle"));
        module.pages.push(page);

        let output = backend.generate(&module);
        let app = output
            .files
            .iter()
            .find(|f| f.path == "GeneratedApp.swift")
            .unwrap();
        assert_eq!(app.content.matches("viewModel.start()").count(), 1);
        // The debug state line must be gone entirely, not just unused.
        assert!(!app.content.contains("Text(\"State:"));

        let view_model = generate_view_model_file(&module).content;
        assert!(view_model.contains("guard !didStart else"));
        assert!(view_model.contains("didStart = true"));
        assert!(view_model.contains("guard !didInitAllTraits else"));
        assert!(view_model.contains("didInitAllTraits = true"));
    }

    /// `GeneratedPage.onEvent` resolves a control's target trait directly
    /// from the `eventEnvelope` every renderer body passes as its payload
    /// (`RenderersCommon.swift`) — no per-trait routing/dispatch table to
    /// keep in sync with the schema (the kernel's bubble, B1, is what makes a
    /// control's emit reach a peer trait's listener; the client never
    /// re-implements that fan-out). iOS twin of Android's
    /// `app_slot_content_routes_events_by_envelope_source_trait`.
    #[test]
    fn app_no_longer_routes_by_source_trait() {
        let backend = IosBackend::new();
        let module = OirModule::new("TestApp", "1.0.0");
        let output = backend.generate(&module);
        let app = output
            .files
            .iter()
            .find(|f| f.path == "GeneratedApp.swift")
            .unwrap();
        assert!(app
            .content
            .contains(r#"payload?.dictValue?["sourceTrait"]?.stringValue ?? traitName"#));
        assert!(!app.content.to_lowercase().contains("routingtable"));
        assert!(!app.content.to_lowercase().contains("sourcetraittable"));
    }

    /// Characterization matrix for the `OirType → Swift` walk (now the shared
    /// `orbital_core::render_type` + `SwiftRenderer`). Pins the arms most
    /// likely to regress in a Swift migration: `Integer → "Int"` (Swift does
    /// NOT merge Integer with Number, unlike Kotlin) and `string`/`enum_ty`
    /// ignoring the `enum_values` sidecar entirely (Swift handles enums at
    /// the field layer via `type_for_field`, not in the type mapper). The
    /// `Struct` arm pins the Phase-2 named-declaration output — bare name at
    /// the field position, declaration hoisted (the old arm spliced
    /// `struct { … }` into type position, which is not Swift).
    #[test]
    fn char_oir_type_to_swift_arms() {
        assert_eq!(oir_type_to_swift(&OirType::String, "Ctx"), "String");
        assert_eq!(oir_type_to_swift(&OirType::Number, "Ctx"), "Double");
        assert_eq!(oir_type_to_swift(&OirType::Integer, "Ctx"), "Int");
        assert_eq!(oir_type_to_swift(&OirType::Boolean, "Ctx"), "Bool");
        assert_eq!(oir_type_to_swift(&OirType::Date, "Ctx"), "String");
        assert_eq!(oir_type_to_swift(&OirType::DateTime, "Ctx"), "String");
        assert_eq!(oir_type_to_swift(&OirType::Json, "Ctx"), "AnyCodable");
        assert_eq!(oir_type_to_swift(&OirType::Trait, "Ctx"), "String");
        assert_eq!(oir_type_to_swift(&OirType::SExpr, "Ctx"), "AnyCodable");
        // Reference: the `orbital_core` default (`render.rs` C1) — a relation
        // field stores the referenced row's id, never the entity's type name.
        assert_eq!(
            oir_type_to_swift(&OirType::reference("Customer"), "Ctx"),
            "String"
        );
        assert_eq!(
            oir_type_to_swift(&OirType::enum_type("Status"), "Ctx"),
            "Status"
        );

        // `string`/`enum_ty` ignore the `enum_values` sidecar (no Some/None
        // divergence) — Swift resolves enums at the field layer instead.
        let vals = vec!["a".to_string(), "b".to_string()];
        let hoisted = std::cell::RefCell::new(Vec::new());
        assert_eq!(
            render_type(
                &SwiftRenderer {
                    context_name: "Ctx".to_string(),
                    hoisted: &hoisted
                },
                &OirType::String,
                Some(&vals)
            ),
            "String"
        );
        assert_eq!(
            render_type(
                &SwiftRenderer {
                    context_name: "Ctx".to_string(),
                    hoisted: &hoisted
                },
                &OirType::enum_type("Status"),
                Some(&vals)
            ),
            "Status"
        );

        // Recursive arms.
        assert_eq!(
            oir_type_to_swift(&OirType::array(OirType::Number), "Ctx"),
            "[Double]"
        );
        assert_eq!(
            oir_type_to_swift(&OirType::map(OirType::String, OirType::Number), "Ctx"),
            "[String: Double]"
        );
        assert_eq!(
            oir_type_to_swift(&OirType::optional(OirType::String), "Ctx"),
            "String?"
        );
        assert_eq!(
            oir_type_to_swift(
                &OirType::optional(OirType::optional(OirType::Integer)),
                "Ctx"
            ),
            "Int?"
        );

        // Struct: one required + one optional field, `; `-joined, `?` suffix
        // only on the optional field. The field position now carries the bare
        // name and the `struct … : Codable` declaration hoists (Phase-2 fix).
        // The optional field keeps its bare (unwrapped) `field_type` with
        // `required = false` — matching how `type_for_field` hands fields to
        // this mapper — so the `?` comes solely from the `required` flag, not
        // from an `OirType::Optional` wrapper (that would double it to `??`).
        let struct_ty = OirType::Struct {
            additional: None,
            fields: vec![OirField::new("userId", OirType::String), {
                let mut f = OirField::new("nickName", OirType::String);
                f.required = false;
                f
            }].into(),
        };
        let (ty, hoisted) = oir_type_to_swift_hoisted(&struct_ty, "UserProfile");
        assert_eq!(ty, "UserProfile");
        assert_eq!(
            hoisted,
            vec!["struct UserProfile: Codable { let userId: String; let nickName: String? }"]
        );

        // Union: a named Codable enum with associated values; each variant's
        // struct shape hoists as its own named struct under `{Name}{Variant}`.
        let union_ty = OirType::Union {
            variants: vec![
                OirField::new(
                    "book",
                    OirType::Struct {
                        additional: None,
                        fields: vec![OirField::new("kind", OirType::String)].into(),
                    },
                ),
                OirField::new(
                    "movie",
                    OirType::Struct {
                        additional: None,
                        fields: vec![OirField::new("kind", OirType::String)].into(),
                    },
                ),
            ].into(),
        };
        let (ty, hoisted) = oir_type_to_swift_hoisted(&union_ty, "UserItem");
        assert_eq!(ty, "UserItem");
        assert_eq!(
            hoisted,
            vec![
                "struct UserItemBook: Codable { let kind: String }",
                "struct UserItemMovie: Codable { let kind: String }",
                "enum UserItem: Codable {\n    case book(UserItemBook)\n    case movie(UserItemMovie)\n}",
            ]
        );
    }

    #[test]
    fn a_row_field_is_the_entity_struct_where_a_reference_field_is_an_id() {
        let mut entity = OirEntity::new("Note");
        entity.fields.push(OirField::new(
            "revisions",
            OirType::array(OirType::row("NoteRevision")),
        ));
        entity.fields.push(OirField::new(
            "tagIds",
            OirType::array(OirType::reference("NoteTag")),
        ));
        let content = generate_entity(&entity);
        assert!(
            content.contains("let revisions: [NoteRevision]"),
            "{content}"
        );
        assert!(content.contains("let tagIds: [String]"), "{content}");
        assert_eq!(
            classify_oir_type(&OirType::row("NoteRevision")),
            TypeMappingClass::Faithful
        );
    }

    #[test]
    fn an_entity_named_like_a_swift_type_is_declared_and_referenced_under_one_renamed_type() {
        let mut task = OirEntity::new("Task");
        let mut status = OirField::new("status", OirType::String);
        status.enum_values = Some(vec!["open".to_string()]);
        task.fields.push(status);
        let content = generate_entity(&task);
        assert!(content.contains("struct TaskEntity"), "{content}");
        assert!(content.contains("enum TaskEntityStatus"), "{content}");
        assert!(
            !content.contains("struct Task:") && !content.contains("struct Task "),
            "{content}"
        );
        let mut board = OirEntity::new("Board");
        board
            .fields
            .push(OirField::new("tasks", OirType::array(OirType::row("Task"))));
        assert!(generate_entity(&board).contains("let tasks: [TaskEntity]"));
    }

    #[test]
    fn control_an_entity_name_no_swift_type_uses_keeps_its_name() {
        let content = generate_entity(&OirEntity::new("Note"));
        assert!(content.contains("struct Note"), "{content}");
        assert!(!content.contains("NoteEntity"), "{content}");
    }

    #[test]
    fn classify_reference_defaults_to_widening() {
        // Pair decision with the deleted `reference` override: the carrier
        // (String, an id) is faithful; the entity shape it erases is the loss.
        assert_eq!(
            classify_oir_type(&OirType::reference("Customer")),
            TypeMappingClass::Widening
        );
    }

    #[test]
    fn struct_field_literal_optional_wrapper_renders_single_question_mark() {
        // A field spelled with a literal `OirType::Optional` wrapper (rather
        // than `required: false`) must still render exactly one `?`:
        // `effective_type()` unwraps the wrapper before `struct_ty` appends
        // its own — the two optionality spellings can never compound to `??`.
        let struct_ty = OirType::Struct {
            additional: None,
            fields: vec![{
                let mut f = OirField::new("nickName", OirType::optional(OirType::String));
                // The wrapper is authoritative regardless of `required`.
                f.required = true;
                f
            }].into(),
        };
        let (_, hoisted) = oir_type_to_swift_hoisted(&struct_ty, "UserProfile");
        assert_eq!(
            hoisted,
            vec!["struct UserProfile: Codable { let nickName: String? }"]
        );
    }

    #[test]
    fn enum_default_renders_case_member() {
        let mut entity = OirEntity::new("Task");
        entity.fields.push({
            let mut f = OirField::new("priority", OirType::String);
            f.enum_values = Some(vec!["low".to_string(), "high".to_string()]);
            f.default = Some(OirValue::String("low".to_string()));
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains("let priority: TaskEntityPriority = TaskEntityPriority.low"));
    }

    #[test]
    fn integer_and_number_defaults_render_correctly() {
        let mut entity = OirEntity::new("Item");
        entity.fields.push({
            let mut f = OirField::new("quantity", OirType::Integer);
            f.default = Some(OirValue::Number(3.0));
            f
        });
        entity.fields.push({
            let mut f = OirField::new("price", OirType::Number);
            f.default = Some(OirValue::Number(100.0));
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains("let quantity: Int = 3"));
        // Swift Double literal: a whole number still prints `.0`, never the
        // Int-looking `100`.
        assert!(content.contains("let price: Double = 100.0"));
    }

    #[test]
    fn array_default_renders_element_by_element() {
        let mut entity = OirEntity::new("Cart");
        entity.fields.push({
            let mut f = OirField::new("counts", OirType::array(OirType::Integer));
            f.default = Some(OirValue::Array(vec![
                OirValue::Number(1.0),
                OirValue::Number(2.0),
            ]));
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains("let counts: [Int] = [1, 2]"));
    }

    /// A field default whose `OirValue` kind cannot possibly inhabit its
    /// declared `OirType` (the validator's job to reject upstream) must
    /// surface as the greppable `orbital_core::ir::LITERAL_TYPE_MISMATCH_MARKER`
    /// comment, never panic and never silently drop the default. Precedent:
    /// std organisms declare `seedRow : <Entity> = {}` — a relation
    /// (Reference/String carrier) defaulting to an Object — which hits
    /// exactly this arm.
    #[test]
    fn literal_mismatch_emits_marker_instead_of_panicking() {
        let mut entity = OirEntity::new("Board");
        entity.fields.push({
            let mut f = OirField::new(
                "seedRow",
                OirType::Reference {
                    entity: "Task".to_string(),
                },
            );
            let mut obj = orbital_core_base::ir::OirObject::new();
            obj.insert("id".to_string(), OirValue::String("x".to_string()));
            f.default = Some(OirValue::Object(obj));
            f
        });

        let content = generate_entity(&entity);
        assert!(content.contains(orbital_core_base::ir::LITERAL_TYPE_MISMATCH_MARKER));
        assert!(content.contains("reference(Task)"));
        assert!(content.contains("got object"));
    }

    /// True when `needle`'s occurrence at `at` sits inside an open `#if DEBUG` block.
    fn inside_debug_block(content: &str, at: usize) -> bool {
        let before = &content[..at];
        before.matches("#if DEBUG").count() > before.matches("#endif").count()
    }

    #[test]
    fn verify_bridge_start_is_debug_only_and_env_gated() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains(r#"env["ORBITAL_VERIFY_BRIDGE"] == "1""#));
        let guard_at = content
            .find(r#"env["ORBITAL_VERIFY_BRIDGE"] == "1""#)
            .unwrap();
        let still_at = content
            .find("UIView.setAnimationsEnabled(false)")
            .expect("verify launches settle without animation");
        assert!(
            guard_at < still_at,
            "control: a normal launch keeps its animations"
        );
        assert!(content.contains(r#"env["ORBITAL_VERIFY_PORT"]"#));
        assert!(content.contains("?? 7357"));
        for needle in [
            "startVerifyBridgeIfRequested()",
            "kernel.startVerifyBridge(",
            "handleVerifyDispatch(",
        ] {
            let mut found = 0;
            for (at, _) in content.match_indices(needle) {
                found += 1;
                assert!(
                    inside_debug_block(&content, at),
                    "`{needle}` at {at} escapes #if DEBUG"
                );
            }
            assert!(found > 0, "`{needle}` never emitted");
        }
    }

    #[test]
    fn verify_bridge_starts_after_the_kernel_mounts_and_before_the_first_init() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let start = content.find("self.startVerifyBridgeIfRequested()").unwrap();
        let init_all = content.find("self.initAllTraits()").unwrap();
        let mounted = content.find("self.kernel = kernel").unwrap();
        assert!(mounted < start && start < init_all);
    }

    #[test]
    fn verify_dispatch_routes_through_send_event_with_scope_or_active_page() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains("guard let trait = traitScope ?? activePageTrait"));
        assert!(content.contains("sendEvent(trait: trait, event: event, payload: payload)"));
        assert!(!content.contains(
            "kernel.dispatch(trait: trait, entityId: nil, event: event, payloadJSON: json"
        ));
    }

    #[test]
    fn page_passes_every_bound_trait_so_a_non_leading_trait_can_own_main() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut page = OirPage::new("Browse", "/threadposts");
        page.traits.push(OirTraitBinding::new("AuthorPresence"));
        page.traits.push(OirTraitBinding::new("ThreadPostBrowse"));
        module.pages.push(page);
        let app = generate_app_file(&module).content;
        assert!(app.contains(
            "GeneratedPage(pageName: \"Browse\", viewModel: viewModel, traitNames: [\"AuthorPresence\", \"ThreadPostBrowse\"])"
        ));
        assert!(app.contains("viewModel.mainOrderWithAwaiting.filter { traitNames.contains($0) }"));
        // control: a one-trait page keeps a one-element list
        let mut single = OirModule::new("TestApp", "1.0.0");
        let mut p = OirPage::new("Home", "/");
        p.traits.push(OirTraitBinding::new("HomeLifecycle"));
        single.pages.push(p);
        assert!(generate_app_file(&single)
            .content
            .contains("traitNames: [\"HomeLifecycle\"])"));
    }

    #[test]
    fn view_model_tracks_live_main_writers_in_first_write_order() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(vm.contains("@Published var mainOrder: [String] = []"));
        assert!(vm.contains("@Published var lastMainWriter: String?"));
        let content = generate_effect_handlers_file().content;
        let append =
            "if viewModel?.mainOrder.contains(source) == false { viewModel?.mainOrder.append(source) }";
        let remove = "viewModel?.mainOrder.removeAll(where: { $0 == source })";
        assert!(
            content.contains(append),
            "a new writer is appended; a re-render keeps its position"
        );
        assert!(content.contains(remove), "a clear removes only that trait");
        assert!(content.contains("viewModel?.lastMainWriter = source"));
        assert!(content.contains(
            "if viewModel?.lastMainWriter == source { viewModel?.lastMainWriter = nil }"
        ));
        let overlay = content.find("viewModel?.uiSlots[slot] = content").unwrap();
        assert!(
            content.find(append).unwrap() < overlay,
            "only the main branch marks a main owner"
        );
        // control: no previous-writer fallback and no single-slot overwrite of other writers
        assert!(!content.contains("mainOrder = ["));
        assert!(!content.contains("mainOrder.removeAll()"));
    }

    #[test]
    fn page_stacks_live_writers_verbatim_for_one_and_vertically_for_many() {
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut page = OirPage::new("Browse", "/threadposts");
        page.traits.push(OirTraitBinding::new("AuthorPresence"));
        page.traits.push(OirTraitBinding::new("ThreadPostBrowse"));
        module.pages.push(page);
        let app = generate_app_file(&module).content;
        assert!(app
            .contains("if live.count == 1, let only = live.first {\n            traitBody(only)"));
        assert!(app.contains("} else if live.count > 1 {\n            VStack(alignment: .leading, spacing: 24) {\n                ForEach(live, id: \\.self) { traitBody($0) }"));
        assert!(app.contains("mainBody\n            .modifier(AlmadarSurfaceEnter(shape: \"pageEnter\", timing: .page, replayKey: pageName))\n            .verificationContainer(mainSlotId)"));
        // the theme motion: each writer plays the slot entry, the toast slot its surface shape
        assert!(app.contains("renderSlot(spliced).modifier(AlmadarSlotEnter(content: spliced, contentKey: key))"));
        assert!(app.contains("AlmadarSurfaceEnter(shape: role == .toast ? \"toastEnter\" : nil, timing: .toast"));
        // control: nothing live renders no body; the old first-declared fallback is gone
        assert!(!app.contains("traitContent[traitName]"));
        assert!(!app.contains("mainTraits"));
    }

    #[test]
    fn page_active_trait_follows_the_most_recent_main_writer() {
        let app = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(app.contains(
            "if let writer = viewModel.lastMainWriter, liveTraits.contains(writer) { return writer }"
        ));
        assert!(app.contains("return liveTraits.last ?? traitNames.first ?? \"\""));
    }

    #[test]
    fn page_publishes_its_trait_as_the_active_one_in_debug_builds_only() {
        let module = OirModule::new("TestApp", "1.0.0");
        let app = generate_app_file(&module);
        let at = app
            .content
            .find("viewModel.activePageTrait = traitName")
            .expect("page sets activePageTrait");
        assert!(inside_debug_block(&app.content, at));
    }

    #[test]
    fn kernel_bridge_declares_the_verify_bridge_symbols_and_wraps_them_in_debug() {
        let bridge = include_str!("../renderers/swiftui/renderers/bridge/OrbitalKernelBridge.swift");
        for symbol in orbital_ffi::kernel_c_api::VERIFY_BRIDGE_C_SYMBOLS {
            assert!(
                bridge.contains(&format!("@_silgen_name(\"{symbol}\")")),
                "missing {symbol}"
            );
        }
        for needle in [
            "orbital_verify_bridge_start(handle",
            "orbital_verify_bridge_stop(handle",
            "orbital_verify_bridge_set_dispatch_callback(handle",
            "orbital_verify_bridge_set_route(handle",
            "orbital_verify_bridge_set_ready(handle",
        ] {
            let at = bridge
                .find(needle)
                .unwrap_or_else(|| panic!("wrapper calling {needle} missing"));
            assert!(inside_debug_block(bridge, at), "{needle} escapes #if DEBUG");
        }
    }

    /// Item 2 of G-ORB-COMPILER-038 stays open: a renderer's `eventEnvelope` copies the node's
    /// own `sourceTrait` prop, and only the splice stamps nested nodes with it.
    #[test]
    fn envelope_routing_still_depends_on_the_splice_stamp() {
        let envelope = crate::pack::pack()
            .source("RenderersCommon.swift")
            .expect("the pack ships RenderersCommon.swift");
        assert!(envelope.contains(r#"props.dictValue?["sourceTrait"]"#));
        let splice = generate_splice_file().content;
        assert!(splice.contains(r#"out["sourceTrait"] = .string(sourceTrait)"#));
    }

    #[test]
    fn api_base_url_override_is_debug_only_and_env_gated() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let at = content
            .find(r#"environment["ORBITAL_API_BASE_URL"]"#)
            .expect("launch-env override missing");
        assert!(
            inside_debug_block(&content, at),
            "override escapes #if DEBUG"
        );
        assert!(content.contains("OrbitalAPI(baseUrl: OrbitalViewModel.resolvedBaseUrl())"));
        let resolver = content.find("static func resolvedBaseUrl()").unwrap();
        let tail = &content[resolver..];
        let fallback = tail
            .find("return BASE_URL")
            .expect("compiled-in fallback missing");
        let override_at = tail.find(r#"environment["ORBITAL_API_BASE_URL"]"#).unwrap();
        assert!(
            override_at < fallback,
            "override must be consulted before the baked URL"
        );
    }

    #[test]
    fn auth_token_launch_env_is_debug_only_and_reaches_the_api_client() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let read = content
            .find(r#"environment["ORBITAL_AUTH_TOKEN"]"#)
            .expect("launch-env auth token missing");
        assert!(
            inside_debug_block(&content, read),
            "token read escapes #if DEBUG"
        );
        let apply = content
            .find("api.setAuthToken(token)")
            .expect("token never reaches the API client");
        assert!(
            inside_debug_block(&content, apply),
            "token apply escapes #if DEBUG"
        );
        let api = generate_api_client_file(&module).content;
        assert!(api.contains(
            r#"request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")"#
        ));
    }

    #[test]
    fn auth_token_launch_env_control_nothing_sets_the_token_outside_debug() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert_eq!(content.matches("setAuthToken(token)").count(), 1);
        assert_eq!(
            content
                .matches(r#"environment["ORBITAL_AUTH_TOKEN"]"#)
                .count(),
            1
        );
        let api = generate_api_client_file(&module).content;
        assert!(api.contains("if let authToken = authToken {"));
        assert!(!api.contains("ORBITAL_AUTH_TOKEN"));
    }

    #[test]
    fn native_sign_in_restores_the_session_before_the_first_init_and_binds_it_to_the_api_and_kernel(
    ) {
        let content = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let restore = content
            .find("self.restoreSession()")
            .expect("session never restored");
        let init = content.find("self.initAllTraits()").expect("INIT missing");
        assert!(
            restore < init,
            "the stored session must be adopted before the first INIT"
        );
        assert!(content.contains("sessionBinding.apply(next)"));
        assert!(content.contains("store: KeychainSessionStore("));
        assert!(content.contains("extension OrbitalAPI: BearerSink {}"));
        assert!(content.contains("extension OrbitalKernel: ViewerSink {}"));
        assert!(content.contains(r#"static let hostSignInRoute = "/login""#));
    }

    #[test]
    fn native_sign_in_identity_change_reconnects_live_push_and_reinits_only_after_ready() {
        let content = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let apply = content.find("private func applySession").unwrap();
        let body = &content[apply..];
        assert!(body.contains("guard identityChanged, reinit, isReady else { return }"));
        assert!(body.find("openLivePush()").unwrap() < body.find("initAllTraits()").unwrap());
        assert!(body.contains("didInitAllTraits = false"));
    }

    #[test]
    fn native_sign_in_control_the_verify_persona_token_keeps_the_stored_session_out() {
        let content = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let restore = content.find("private func restoreSession()").unwrap();
        let body = &content[restore..];
        let guard_at = body
            .find("hasLaunchToken = OrbitalViewModel.launchAuthToken() != nil")
            .unwrap();
        assert!(
            inside_debug_block(&content, restore + guard_at),
            "persona override read escapes #if DEBUG"
        );
        assert!(body.contains("if !hasLaunchToken {\n            auth.loadStoredSession()"));
    }

    #[test]
    fn native_sign_in_emulator_override_is_debug_only() {
        let content = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let at = content
            .find(r#"environment["ORBITAL_AUTH_EMULATOR_HOST"]"#)
            .expect("override missing");
        assert!(
            inside_debug_block(&content, at),
            "emulator override escapes #if DEBUG"
        );
        assert_eq!(
            content
                .matches(r#"environment["ORBITAL_AUTH_EMULATOR_HOST"]"#)
                .count(),
            1
        );
    }

    #[test]
    fn native_sign_in_live_push_reads_the_current_token_on_every_reconnect() {
        let api = generate_api_client_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(api.contains("if let authToken = self?.authToken {"));
        assert!(
            !api.contains("let authToken = self.authToken"),
            "a token captured once goes stale after a refresh"
        );
    }

    #[test]
    fn native_sign_in_host_route_renders_before_the_undeclared_default_and_pages_cannot_shadow_it()
    {
        let content = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let host = content
            .find("case OrbitalViewModel.hostSignInRoute:")
            .expect("host route missing");
        assert!(content[host..].contains("OrbitalSignInView(viewModel: viewModel)"));
        assert!(host < content.find("default:").unwrap());
    }

    fn access_module(signed_in_route: Option<&str>) -> OirModule {
        let mut module = OirModule::new("TestApp", "1.0.0");
        let mut private = OirPage::new("Account", "/account");
        private.access = Some(orbital_core_base::schema::PageAccess::Authenticated);
        let mut public = OirPage::new("Home", "/home");
        public.access = Some(orbital_core_base::schema::PageAccess::Public);
        module.pages = vec![private, public, OirPage::new("About", "/about")];
        module.site = signed_in_route.map(|route| orbital_core_base::schema::SiteMeta {
            sign_in: Some(route.to_string()),
            ..Default::default()
        });
        module
    }

    #[test]
    fn page_access_an_authenticated_page_mounts_through_the_boundary_with_the_declared_sign_in() {
        let app = generate_app_file(&access_module(Some("/login"))).content;
        assert!(app.contains(
            "case \"/account\":\n                        AuthenticatedPage(path: \"/account\", signIn: \"/login\", viewModel: viewModel) {\n                            GeneratedPage(pageName: \"Account\""
        ));
        assert!(app.contains("struct AuthenticatedPage<Content: View>: View {"));
        assert!(app.contains("content().id(viewModel.session?.uid)"));
        assert!(app.contains(".onChange(of: viewModel.isAuthenticated)"));
        assert!(app.contains("ZStack {\n            Color.clear\n"), "the boundary always renders a view, so onAppear fires for a denied viewer and before the page has content");
    }

    fn gated_trait_module() -> OirModule {
        let mut module = access_module(Some("/login"));
        for name in ["AccountView", "HomeView"] {
            let mut t = orbital_core_base::ir::OirTrait::new(name);
            t.events.push(orbital_core_base::ir::OirEvent::new("INIT"));
            module.traits.push(t);
        }
        let bind = |name: &str| orbital_core_base::ir::OirTraitBinding {
            trait_name: name.to_string(),
            trait_id: None,
            config: None,
        };
        module.pages[0].traits = vec![bind("AccountView")];
        module.pages[1].traits = vec![bind("HomeView")];
        module
    }

    #[test]
    fn page_access_a_gated_only_trait_inits_when_its_page_mounts_for_a_viewer_not_at_app_start() {
        let module = gated_trait_module();
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains(r#"traitsWithInit: [String] = ["HomeView"]"#));
        assert!(
            vm.contains(r#"gatedPageTraits: [String: [String]] = ["/account": ["AccountView"]]"#)
        );
        assert!(vm.contains("func mountGatedPage(path: String, viewer: String)"));
        assert!(vm.contains("kernel?.mount(traits: pending)"));
        assert!(vm.contains("pendingGatedMount = (path, viewer)"));
        let app = generate_app_file(&module).content;
        assert!(app.contains(r#"viewModel.mountGatedPage(path: path, viewer: viewModel.session?.uid ?? "launch-token")"#));
        assert!(app.contains(".onAppear { admit() }"));
        assert!(app.contains(
            "ZStack {\n            Color.clear\n            if viewModel.isAuthenticated {"
        ));
        assert!(app.contains(".onChange(of: viewModel.session?.uid) { _ in admit() }"));
    }

    #[test]
    fn page_access_control_an_ungated_app_inits_every_trait_at_start() {
        let mut module = gated_trait_module();
        module.pages[0].access = None;
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains(r#"traitsWithInit: [String] = ["AccountView", "HomeView"]"#));
        assert!(vm.contains("gatedPageTraits: [String: [String]] = [:]"));
    }

    #[test]
    fn page_access_control_public_and_undeclared_pages_render_directly() {
        let app = generate_app_file(&access_module(Some("/login"))).content;
        for route in ["/home", "/about"] {
            let arm = fold_arm(&app, &format!("case \"{route}\":"), "GeneratedPage(");
            assert!(
                !arm.contains("AuthenticatedPage"),
                "{route} must not be gated"
            );
        }
        let ungated = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(!ungated.contains("AuthenticatedPage"));
    }

    #[test]
    fn page_access_without_a_declared_sign_in_names_none_and_denial_stays_empty() {
        let app = generate_app_file(&access_module(None)).content;
        assert!(app
            .contains("AuthenticatedPage(path: \"/account\", signIn: \"\", viewModel: viewModel)"));
        let vm = generate_view_model_file(&access_module(None)).content;
        assert!(vm.contains(
            "guard !signIn.isEmpty, (routeStack.last ?? rootRoute) == path else { return }"
        ));
    }

    #[test]
    fn page_access_viewer_is_authenticated_by_a_session_or_the_debug_persona_token() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let body = fold_arm(&vm, "var isAuthenticated: Bool {", "func denyPageAccess");
        assert!(body.contains("if session != nil { return true }"));
        assert!(body.contains("OrbitalViewModel.launchAuthToken() != nil"));
    }

    #[test]
    fn theme_mode_the_host_provides_the_toggle_through_the_environment_and_the_kernel() {
        let app = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(app.contains(".environment(\\.almadarThemeMode, AlmadarThemeModeControl(isDark: viewModel.themeIsDark, toggle: viewModel.toggleThemeMode))"));
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let toggle = fold_arm(&vm, "func toggleThemeMode()", "var isAuthenticated");
        assert!(toggle.contains(r#"kernel.setThemeMode(themeIsDark ? "light" : "dark")"#));
        assert!(toggle.contains("apply(resolvedTheme: snap.theme)"));
        assert!(toggle.contains("canvasTheme = snap.canvasTheme"));
        assert!(toggle.contains("motion = snap.motion"), "the mode switch re-reads the resolved motion");
        assert!(app.contains(".environment(\\.almadarResolvedMotion, viewModel.motion)"));
        assert!(
            !toggle.contains("sendEvent"),
            "the toggle is a local control, not a bus event"
        );
    }

    #[test]
    fn native_sign_in_files_and_tests_are_emitted_and_the_host_gates_nothing() {
        let module = OirModule::new("TestApp", "1.0.0");
        let out = IosBackend::new().generate(&module);
        let find = |path: &str| {
            out.files
                .iter()
                .find(|f| f.path == path)
                .unwrap_or_else(|| panic!("{path} not emitted"))
        };
        let auth = &find("Views/core/bridge/OrbitalAuth.swift").content;
        let view = &find("Views/core/bridge/OrbitalSignInView.swift").content;
        assert!(
            auth.contains("accounts:signInWithPassword")
                && auth.contains("accounts:signInWithCustomToken")
        );
        assert!(auth.contains("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"));
        let tests = &find("Sources/OrbitalAppTests/OrbitalAuthTests.swift").content;
        assert!(
            !tests.contains("__APP_MODULE__"),
            "module placeholder left in the emitted test"
        );
        let app_module = split_to_pascal_case(&crate::shell::to_package_name(&module.name));
        assert!(tests.contains(&format!("@testable import {app_module}")));
        for source in [auth, view] {
            for forbidden in ["navigationPath", "navigate(", "routeStack", "rootRoute"] {
                assert!(
                    !source.contains(forbidden),
                    "host auth code must not route from auth state: {forbidden}"
                );
            }
        }
    }

    #[test]
    fn api_base_url_override_control_baked_url_is_still_the_default() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        assert!(content.contains(r#"private static let BASE_URL = "http://localhost:3030""#));
        assert!(!content.contains("OrbitalAPI(baseUrl: BASE_URL)"));
    }

    fn fold_arm<'a>(content: &'a str, arm: &str, next: &str) -> &'a str {
        let start = content.find(arm).unwrap_or_else(|| panic!("missing {arm}"));
        let end = content[start..]
            .find(next)
            .unwrap_or_else(|| panic!("missing {next}"));
        &content[start..start + end]
    }

    #[test]
    fn every_server_leg_failure_branch_restores() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let optimistic = fold_arm(
            &content,
            "case .runtimeOptimistic:",
            "case .persistedAwaited:",
        );
        assert!(optimistic.contains("restoreOnServerFailure("));
        let persisted = fold_arm(
            &content,
            "case .persistedAwaited:",
            "private enum ServerLegOutcome",
        );
        assert!(
            persisted.contains("self?.restoreOnServerFailure(message: message, trait: leg.targetTrait ?? requestTrait, event: result.seed.event, entityId: entityId, snapshot: result.snapshot)"),
            "persistedAwaited failure must restore:\n{persisted}"
        );
    }

    #[test]
    fn server_leg_success_branch_never_restores() {
        let module = OirModule::new("TestApp", "1.0.0");
        let content = generate_view_model_file(&module).content;
        let success = fold_arm(
            &content,
            "case .success(let posted) where posted.response.success:",
            "case .success(let posted):",
        );
        assert!(!success.contains("restore"));
        assert!(success.contains("kernel.applyServerResponse("));
        let transport = fold_arm(
            &content,
            "case .failure(let error):",
            "/// `RuntimeOptimistic` rollback",
        );
        assert!(transport.contains("outcome(.failed("));
    }

    fn module_with_pages(paths: &[(&str, &str)]) -> OirModule {
        let mut module = OirModule::new("TestApp", "1.0.0");
        for (name, path) in paths {
            module.pages.push(OirPage::new(*name, *path));
        }
        module
    }

    #[test]
    fn floating_slot_fills_the_page_and_adds_no_hit_area_of_its_own() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let at = page
            .find("slotRole($0.key) == .floating })")
            .expect("floating layer");
        let layer = &page[at..];
        assert!(layer.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"));
        assert!(
            !page.contains(".overlay(alignment: .center)"),
            "floating must not be centered by the host"
        );
        assert!(
            !page.contains("contentShape"),
            "an empty floating area must not swallow page taps"
        );
        assert!(!page.contains("Color.clear"));
    }

    #[test]
    fn page_body_is_full_bleed_top_leading_with_the_theme_background_to_every_safe_area_edge() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let at = page.find("struct GeneratedPage: View").expect("page");
        let body = &page[at..];
        assert!(body
            .contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"));
        assert!(body.contains(".background(theme.color.background.ignoresSafeArea())"));
        assert!(body.contains("@Environment(\\.almadarTheme) private var theme"));
    }

    #[test]
    fn page_body_adds_no_flexible_spacer_or_inset_padding_of_its_own() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let at = page.find("struct GeneratedPage: View").expect("page");
        let end = page[at..]
            .find("// --- non-main slot overlays ---")
            .expect("overlays");
        let body = &page[at..at + end];
        assert!(
            !body.contains("Spacer()"),
            "a Spacer under the body pushes layout content to the top and eats height"
        );
        assert!(
            !body.contains(".padding()"),
            "the web page has no inset around its layout"
        );
    }

    #[test]
    fn floating_control_sibling_overlays_keep_their_own_alignment() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(page.contains(".overlay(alignment: .top)"));
        assert!(page.contains(".overlay(alignment: .bottomLeading)"));
    }

    #[test]
    fn page_stamps_main_and_every_overlay_slot_with_its_canonical_name() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(page.contains(".verificationContainer(mainSlotId)"));
        assert!(page.contains(".verificationContainer(slotId(entry.key, holding: content))"));
        // One root per slot folds into one accessibility element, so it carries both ids
        // (G-VERIFY-076); several stacked roots keep the bare slot id.
        assert!(page.contains(
            "return VerificationIds.ids(VerificationIds.slot(slot), VerificationIds.pattern(type))"
        ));
        assert!(page.contains("guard live.count == 1, let only = live.first else { return VerificationIds.slot(\"main\") }"));
        for role in [
            "modal",
            "drawer",
            "overlay",
            "hudTop",
            "hudBottom",
            "toast",
            "sidebar",
            "floating",
        ] {
            assert!(
                page.contains(&format!("slotRole($0.key) == .{role} }}))")),
                "overlay role {role} not routed through the stamping helper"
            );
        }
    }

    #[test]
    fn overlay_stamp_exists_only_when_the_slot_is_populated_and_is_never_a_literal() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert_eq!(
            page.matches("VerificationIds.slot(").count(),
            3,
            "slotId's two arms + main's stacked case"
        );
        let helper = fold_arm(&page, "private func overlaySlot(", "var body: some View");
        let guard_at = helper.find("if let entry = entry").unwrap();
        let stamp_at = helper.find("slotId(entry.key, holding: content)").unwrap();
        assert!(guard_at < stamp_at);
        assert!(!page.contains("VerificationIds.slot(\"modal\")"));
        assert!(!page.contains("VerificationIds.slot(\"toast\")"));
    }

    #[test]
    fn page_routes_navigate_to_navigation_before_kernel_dispatch() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let on_event = fold_arm(&page, "private func onEvent(", "private func renderSlot(");
        let nav = on_event
            .find("if event == OrbitalViewModel.navigateEvent")
            .expect("navigate branch");
        let route = on_event
            .find("viewModel.navigate(envelope: payload)")
            .unwrap();
        let dispatch = on_event.find("viewModel.sendEvent(").unwrap();
        assert!(nav < route && route < dispatch);
        assert!(on_event[nav..dispatch].contains("return"));
    }

    /// The system event `UI:SIGN_OUT` (`@almadar/core` `SYSTEM_UI_EVENTS`) ends the session in the
    /// host and never reaches the kernel (G-PATTERN-SYNC-031).
    #[test]
    fn page_routes_sign_out_to_the_session_before_kernel_dispatch() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let on_event = fold_arm(&page, "private func onEvent(", "private func renderSlot(");
        let branch = on_event.find("if event == OrbitalViewModel.signOutEvent").expect("sign-out branch");
        let session = on_event.find("viewModel.signOut()").unwrap();
        let dispatch = on_event.find("viewModel.sendEvent(").unwrap();
        assert!(branch < session && session < dispatch);
        assert!(on_event[branch..dispatch].contains("return"));
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(vm.contains("static let signOutEvent = \"SIGN_OUT\""));
    }

    #[test]
    fn page_still_sends_every_other_event_to_the_kernel() {
        let page = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        let on_event = fold_arm(&page, "private func onEvent(", "private func renderSlot(");
        assert!(on_event
            .contains("viewModel.sendEvent(trait: source, event: event, payload: sendPayload)"));
        assert_eq!(on_event.matches("navigateEvent").count(), 1);
    }

    #[test]
    fn navigate_event_is_one_constant_and_the_effect_shares_the_navigation_entry() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(vm.contains("static let navigateEvent = \"NAVIGATE\""));
        assert_eq!(vm.matches("navigationPath.append(").count(), 1);
        let effects = generate_effect_handlers_file().content;
        assert!(effects.contains("viewModel?.navigate(to: path)"));
    }

    #[test]
    fn navigate_logs_an_undeclared_route_and_a_missing_url_without_crashing() {
        let module = module_with_pages(&[("Home", "/"), ("Notes", "/notes")]);
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains("private static let knownRoutes: [String] = [\"/\", \"/notes\"]"));
        let nav = fold_arm(
            &vm,
            "func navigate(to path: String)",
            "func navigate(envelope",
        );
        assert!(nav.contains("if !OrbitalViewModel.knownRoutes.contains(path)"));
        assert!(nav.contains("eventLog.error(\"navigate to undeclared route"));
        assert!(nav.contains("navigationPath.append(GeneratedApp.Destination.route(path))"));
        let envelope = fold_arm(&vm, "func navigate(envelope", "private func syncRoute()");
        assert!(envelope.contains("eventLog.error(\"NAVIGATE dropped: no actionPayload.url\")"));
        assert!(envelope.contains("return\n"));
    }

    #[test]
    fn server_leg_failure_without_a_snapshot_abandons_and_with_one_restores() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let restore = fold_arm(
            &vm,
            "private func restoreOnServerFailure(",
            "alertMessage = message",
        );
        let restored = restore.find("kernel.restore(trait: trait").unwrap();
        let else_at = restore.find("} else {").unwrap();
        let abandon = restore
            .find("kernel?.abandonServerLeg(trait: trait, event: event, error: message)")
            .unwrap();
        assert!(restored < else_at && else_at < abandon);
        let success = fold_arm(
            &vm,
            "case .success(let posted) where posted.response.success:",
            "case .success(let posted):",
        );
        assert!(!success.contains("abandonServerLeg"));
    }

    #[test]
    fn route_is_published_on_every_navigation_change_in_debug_builds_only() {
        let module = module_with_pages(&[("Home", "/home"), ("Notes", "/notes")]);
        let vm = generate_view_model_file(&module).content;
        assert!(vm.contains("private static let startRoute = \"/home\""));
        assert!(vm.contains("didSet { syncRoute() }"));
        for needle in [
            "publishRoute()",
            "kernel?.setVerifyRoute(routeStack.last ?? rootRoute)",
        ] {
            for (at, _) in vm.match_indices(needle) {
                assert!(inside_debug_block(&vm, at), "`{needle}` escapes #if DEBUG");
            }
        }
        let sync = fold_arm(
            &vm,
            "private func syncRoute()",
            "/// Mirrors `ClientKernel`",
        );
        assert!(sync.contains("routeStack.removeLast(routeStack.count - navigationPath.count)"));
    }

    #[test]
    fn start_route_without_pages_is_the_bare_root() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(vm.contains("private static let startRoute = \"/\""));
        assert!(vm.contains("private static let knownRoutes: [String] = []"));
    }

    #[test]
    fn kernel_bridge_wraps_abandon_and_set_route() {
        let bridge = include_str!("../renderers/swiftui/renderers/bridge/OrbitalKernelBridge.swift");
        assert!(bridge.contains("@_silgen_name(\"orbital_kernel_abandon_server_leg\")"));
        let at = bridge
            .find("orbital_verify_bridge_set_route(handle, $0)")
            .unwrap();
        assert!(inside_debug_block(bridge, at));
        let abandon = bridge
            .find("orbital_kernel_abandon_server_leg(handle, traitPtr, eventPtr, errorPtr)")
            .unwrap();
        assert!(!inside_debug_block(bridge, abandon));
    }

    /// Snapshots are component-sized in one shared column: no per-pattern or
    /// full-device frame, strict precision.
    #[test]
    fn pattern_snapshots_use_one_column_width_and_strict_tolerance() {
        let test = snapshot_test_source();
        assert!(test.contains("private static let columnWidth: CGFloat = 358"));
        assert!(test.contains(".frame(width: Self.columnWidth)"));
        assert!(test.contains("precision: 0.99, perceptualPrecision: 0.98"));
        // Control: the old loose gate and full-device frame are gone.
        assert!(!test.contains("precision: 0.75"));
        assert!(!test.contains(".fixed(width: 390, height: 844)"));
        assert!(
            !test.contains("layout: .sizeThatFits"),
            "value-level layout strategy is replaced by the hosted controller"
        );
    }

    fn snapshot_test_source() -> String {
        generate_pattern_snapshot_test_files(&OirModule::new("SnapApp", "1.0.0"))
            .into_iter()
            .find(|f| f.path == "Sources/OrbitalAppTests/PatternSnapshotTests.swift")
            .expect("snapshot test file")
            .content
    }

    /// The harness hosts the view in a window, lets async work settle, and
    /// disables animations so snapshots are deterministic.
    #[test]
    fn pattern_snapshots_host_in_window_and_settle_async_work() {
        let test = snapshot_test_source();
        assert!(test.contains("UIHostingController"));
        assert!(test.contains("UIWindow("));
        assert!(test.contains("window.makeKeyAndVisible()"));
        assert!(
            test.contains("RunLoop.main.run(until: Date().addingTimeInterval(Self.settleSeconds))")
        );
        assert!(test.contains("private static let settleSeconds: TimeInterval = 0.6"));
        assert!(test.contains(".transaction { $0.disablesAnimations = true }"));
        assert!(test.contains("as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size)"));
    }

    /// Non-template patterns size to content; only registry-tier `template`
    /// patterns get the fixed phone-content viewport height.
    #[test]
    fn viewport_layout_is_decided_by_registry_tier_not_name() {
        use orbital_core_base::language::pattern_registry::get_component_mapping;
        let test = snapshot_test_source();
        assert!(test.contains(&format!(
            "private static let viewportHeight: CGFloat = {PATTERN_SNAPSHOT_VIEWPORT_HEIGHT}"
        )));
        assert!(test.contains("controller.sizeThatFits(in: CGSize(width: Self.columnWidth, height: .greatestFiniteMagnitude))"));
        let mut templates = 0;
        for (name, _) in crate::pack::pack()
            .fixtures
            .iter()
            .filter(|(n, _)| !ios_snapshot_excluded(n))
        {
            let method = format!("test_{}", name.replace('-', "_"));
            let is_template = get_component_mapping(name).is_some_and(|m| m.category == "template");
            let expected = format!(
                "func {method}() {{ assertPatternSnapshot(\"{name}\", testName: \"{method}\", viewport: {is_template}) }}"
            );
            assert!(
                test.contains(&expected),
                "missing/incorrect call for {name}"
            );
            templates += usize::from(is_template);
        }
        assert!(
            templates > 0,
            "fixture set must include template-tier patterns"
        );
        assert!(
            templates < crate::pack::pack().fixtures.len(),
            "control: non-template patterns keep content sizing"
        );
        assert!(test.contains("auth_layout() { assertPatternSnapshot(\"auth-layout\", testName: \"test_auth_layout\", viewport: true)"));
        assert!(test.contains("viewport: false) }"));
    }

    /// G-ORB-174: a display-link loop drives the kernel's tick clock; it exists only when the
    /// schema declares a tick, and its output folds through the dispatch fold, never a copy.
    #[test]
    fn frame_loop_calls_the_kernel_frame_api_and_folds_through_the_dispatch_fold() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let run = vm.find("private func runFrame(nowMs: UInt64)").unwrap();
        let body = &vm[run..run + vm[run..].find("\n    }\n").unwrap()];
        assert!(body.contains("kernel.frame(nowMs: nowMs)"));
        assert!(body.contains("foldFrame(frame)"));
        let fold = vm.find("private func foldFrame(").unwrap();
        let fold_body = &vm[fold..fold + vm[fold..].find("\n    }\n").unwrap()];
        assert!(fold_body.contains("foldResponse(frame.response"));
        assert!(fold_body.contains(
            "fold(result: dispatch.result, requestTrait: dispatch.trait, entityId: nil)"
        ));
        assert_eq!(
            vm.matches("private func foldResponse(").count(),
            1,
            "one response fold"
        );
        assert_eq!(
            vm.matches("private func fold(result:").count(),
            1,
            "one dispatch fold"
        );
    }

    #[test]
    fn frame_loop_is_skipped_when_the_schema_declares_no_tick_and_waits_for_the_kernel() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let start = vm.find("private func startFrameLoop(").unwrap();
        let body = &vm[start..start + vm[start..].find("\n    }\n").unwrap()];
        let guard = body
            .find("guard kernel.tickCount > 0 else { return }")
            .unwrap();
        let make = body.find("OrbitalFrameLoop {").unwrap();
        assert!(guard < make, "the tick-count gate precedes the loop");
        let init = vm.find("self.initAllTraits()").unwrap();
        let begin = vm.find("self.startFrameLoop(kernel: kernel)").unwrap();
        assert!(init < begin, "no frame can run before every trait's INIT");
        let run = vm.find("private func runFrame(nowMs: UInt64)").unwrap();
        assert!(
            vm[run..].starts_with("private func runFrame(nowMs: UInt64) {\n        guard isReady")
        );
    }

    #[test]
    fn background_pauses_the_loop_and_the_clock_and_foreground_resumes_both() {
        let vm = generate_view_model_file(&OirModule::new("TestApp", "1.0.0")).content;
        let at = vm.find("private func applyForeground()").unwrap();
        let body = &vm[at..at + vm[at..].find("\n    }\n").unwrap()];
        let on = body.find("if isForeground {").unwrap();
        let off = body.find("} else {").unwrap();
        let resume = body.find("kernel.frameResume()").unwrap();
        let start = body.find("frameLoop.start()").unwrap();
        let stop = body.find("frameLoop.stop()").unwrap();
        let pause = body.find("kernel.framePause()").unwrap();
        assert!(
            on < resume && resume < start && start < off,
            "foreground: resume the clock, then start the link"
        );
        assert!(
            off < stop && stop < pause,
            "background: stop the link, then pause the clock"
        );
        let app = generate_app_file(&OirModule::new("TestApp", "1.0.0")).content;
        assert!(app.contains("@Environment(\\.scenePhase) private var scenePhase"));
        assert!(app.contains("viewModel.setForeground(phase == .active)"));
    }

    #[test]
    fn kernel_bridge_wraps_the_frame_api_and_the_frame_loop_is_a_display_link() {
        let bridge = include_str!("../renderers/swiftui/renderers/bridge/OrbitalKernelBridge.swift");
        for sym in [
            "orbital_kernel_frame",
            "orbital_kernel_frame_pause",
            "orbital_kernel_frame_resume",
            "orbital_kernel_tick_count",
        ] {
            assert!(
                bridge.contains(&format!("@_silgen_name(\"{sym}\")")),
                "{sym}"
            );
        }
        assert!(bridge.contains("func frame(nowMs: UInt64) -> KernelFrameOutcome"));
        assert!(bridge.contains("CADisplayLink(target: self, selector: #selector(step(_:)))"));
        assert!(bridge.contains("displayLink.add(to: .main, forMode: .common)"));
    }

    #[test]
    fn an_excluded_pattern_gets_no_snapshot_method_but_keeps_its_fixture() {
        let test = snapshot_test_source();
        assert!(ios_snapshot_excluded("map-view"));
        assert!(!test.contains("func test_map_view()"));
        assert!(crate::pack::pack()
            .fixtures
            .iter()
            .any(|(n, _)| *n == "map-view"));
    }

    #[test]
    fn control_a_capturable_pattern_keeps_its_snapshot_method() {
        assert!(!ios_snapshot_excluded("button"));
        assert!(snapshot_test_source().contains("func test_button()"));
    }

}
