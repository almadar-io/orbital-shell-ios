//! iOS Shell implementation.

use orbital_core::shell::{Shell, ShellError};
use orbital_core::str_utils::{split_to_pascal_case, to_title_case};
use std::path::{Path, PathBuf};

/// iOS shell for native SwiftUI projects.
pub struct IosShell {
    template_path: PathBuf,
}

impl IosShell {
    /// Create a new iOS shell, locating the template at runtime.
    pub fn new() -> Self {
        let template_path = Self::find_template_path();
        Self { template_path }
    }

    /// Find the `ios-shell` template directory at runtime.
    fn find_template_path() -> PathBuf {
        // The one template lookup (`ORBITAL_SHELLS_DIR` → beside the binary → the checkout).
        orbital_core::renderer_packs::find_template_dir("ios-shell").unwrap_or_else(|| {
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("template")
        })
    }

    /// Create with an explicit template path.
    pub fn with_template_path(template_path: impl Into<PathBuf>) -> Self {
        Self {
            template_path: template_path.into(),
        }
    }
}

impl Default for IosShell {
    fn default() -> Self {
        Self::new()
    }
}

impl Shell for IosShell {
    fn name(&self) -> &'static str {
        "ios"
    }

    fn description(&self) -> &'static str {
        "Native iOS application with SwiftUI"
    }

    fn extensions(&self) -> &[&'static str] {
        &["swift"]
    }

    fn template_path(&self) -> &Path {
        &self.template_path
    }

    fn generated_dir(&self) -> &str {
        "Sources/OrbitalApp/Generated"
    }

    fn build_command(&self) -> &str {
        "./orb-build.sh"
    }

    fn dev_command(&self) -> &str {
        "./orb-build.sh --run"
    }

    fn test_command(&self) -> &str {
        "xcodebuild test"
    }

    fn validate_structure(&self, output_dir: &Path) -> Result<(), ShellError> {
        let required_files = [
            "project.yml",
            "Sources/OrbitalApp/App.swift",
            "Sources/OrbitalApp/ContentView.swift",
            "Info.plist",
        ];
        for file in &required_files {
            let path = output_dir.join(file);
            if !path.exists() {
                return Err(ShellError::InvalidStructure {
                    path: path.clone(),
                    message: format!("Missing required file: {}", file),
                });
            }
        }
        Ok(())
    }

    fn copy_template(&self, output_dir: &Path) -> Result<(), ShellError> {
        if !self.template_path.exists() {
            return Err(ShellError::NotFound(
                self.template_path.display().to_string(),
            ));
        }
        copy_dir_recursive(&self.template_path, output_dir)?;

        #[cfg(unix)]
        {
            let build_script = output_dir.join("orb-build.sh");
            if build_script.exists() {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = std::fs::metadata(&build_script)?.permissions();
                perms.set_mode(perms.mode() | 0o111);
                std::fs::set_permissions(&build_script, perms)?;
            }
        }

        Ok(())
    }

    fn init_project(&self, target_dir: &Path, project_name: &str) -> Result<(), ShellError> {
        self.copy_template(target_dir)?;
        let gen_dir = target_dir.join(self.generated_dir());
        std::fs::create_dir_all(&gen_dir)?;

        // Apply iOS-specific placeholders after the base copy.
        let replacements = build_replacements(project_name);
        replace_placeholders_in_dir(target_dir, &replacements)?;
        rename_placeholder_dirs(target_dir, &replacements)?;
        Ok(())
    }
}

impl IosShell {
    /// Rung-3 prevention gate (a validate/verify class, run after generation
    /// against the compile's own manifest — never hardcoded paths):
    /// - (a) a generated file's basename must not collide with a
    ///   template-owned `.swift` file under `Sources/OrbitalApp` (the
    ///   template file list is read from `self.template_path()` at check
    ///   time, not hardcoded) — swiftc refuses two same-basename files in
    ///   one module.
    /// - (b) every generated path, resolved under `generated_dir()`, must
    ///   fall under one of the `sources:` roots declared in the copied
    ///   `project.yml` — a file xcodegen's target never compiles is a dead
    ///   generated file.
    ///
    /// `manifest` is the list of logical `GeneratedFile::path` entries this
    /// compile produced (the same list `generate_from_oir` writes to
    /// `.orb-manifest.json`); the caller already holds it in memory from
    /// `GeneratedOutput::files` and passes it straight through.
    pub fn validate_generated_layout(
        &self,
        output_dir: &Path,
        manifest: &[String],
    ) -> Result<(), ShellError> {
        let template_basenames = self.template_swift_basenames()?;

        let project_yml_path = output_dir.join("project.yml");
        let project_yml_text = std::fs::read_to_string(&project_yml_path)?;
        let source_roots = parse_project_yml_sources(&project_yml_text);

        let generated_dir_rel = Path::new(self.generated_dir());

        for entry in manifest {
            let basename = Path::new(entry)
                .file_name()
                .map(|n| n.to_string_lossy().into_owned())
                .unwrap_or_default();
            if template_basenames.contains(&basename) {
                return Err(ShellError::InvalidStructure {
                    path: output_dir.join(entry),
                    message: format!(
                        "generated file '{entry}' collides with template-owned Swift file basename '{basename}'"
                    ),
                });
            }

            let resolved_rel = generated_dir_rel.join(entry);
            let under_a_source_root = source_roots
                .iter()
                .any(|root| resolved_rel.starts_with(root));
            if !under_a_source_root {
                return Err(ShellError::InvalidStructure {
                    path: output_dir.join(&resolved_rel),
                    message: format!(
                        "generated file '{entry}' resolves to '{}', which is not under any `sources:` root declared in project.yml ({source_roots:?})",
                        resolved_rel.display()
                    ),
                });
            }
        }

        Ok(())
    }

    /// Basenames of every `.swift` file the template ships under
    /// `Sources/OrbitalApp` (excluding the same generated/build cruft
    /// `copy_dir_recursive` skips) — read from disk at check time so a
    /// template edit is picked up without touching this check.
    fn template_swift_basenames(&self) -> Result<std::collections::HashSet<String>, ShellError> {
        let mut basenames = std::collections::HashSet::new();
        let root = self.template_path.join("Sources/OrbitalApp");
        if root.exists() {
            collect_swift_basenames(&root, &mut basenames)?;
        }
        Ok(basenames)
    }
}

fn collect_swift_basenames(
    dir: &Path,
    out: &mut std::collections::HashSet<String>,
) -> Result<(), ShellError> {
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if matches!(
            name_str.as_ref(),
            "generated" | "Generated" | "build" | "DerivedData" | ".git"
        ) {
            continue;
        }
        if path.is_dir() {
            collect_swift_basenames(&path, out)?;
        } else if path.extension().and_then(|e| e.to_str()) == Some("swift") {
            out.insert(name_str.into_owned());
        }
    }
    Ok(())
}

/// Minimal line scan for every `sources:` list in a `project.yml` — no yaml
/// crate dependency (none is in this crate's `Cargo.toml`). Collects EVERY
/// `sources:` key's `- <path>` entries across the whole file (one per
/// target — a project with an app target and a `{{APP_CLASS_NAME}}Tests`
/// target declares two), not just the first: each block ends at the first
/// line that dedents back to (or past) its own `sources:` key, then
/// scanning resumes for the next `sources:` occurrence rather than stopping.
fn parse_project_yml_sources(text: &str) -> Vec<PathBuf> {
    let mut roots = Vec::new();
    let mut in_sources = false;
    let mut sources_indent = 0usize;
    for line in text.lines() {
        let indent = line.len() - line.trim_start().len();
        let trimmed = line.trim();
        if trimmed == "sources:" {
            in_sources = true;
            sources_indent = indent;
            continue;
        }
        if !in_sources {
            continue;
        }
        if trimmed.is_empty() {
            continue;
        }
        if indent <= sources_indent {
            in_sources = false;
            continue;
        }
        match trimmed.strip_prefix("- ") {
            Some(rest) => roots.push(PathBuf::from(rest.trim())),
            None => {
                in_sources = false;
            }
        }
    }
    roots
}

fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<(), ShellError> {
    if !dst.exists() {
        std::fs::create_dir_all(dst)?;
    }

    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());
        let file_name = entry.file_name();
        let file_name_str = file_name.to_string_lossy();

        if file_name_str == "generated"
            || file_name_str == "build"
            || file_name_str == "DerivedData"
            || file_name_str == ".git"
        {
            continue;
        }

        if src_path.is_dir() {
            copy_dir_recursive(&src_path, &dst_path)?;
        } else {
            std::fs::copy(&src_path, &dst_path)?;
        }
    }

    Ok(())
}

fn build_replacements(project_name: &str) -> std::collections::HashMap<&'static str, String> {
    let mut map = std::collections::HashMap::new();
    let package = to_package_name(project_name);
    let class_name = split_to_pascal_case(&package);
    let bundle_id = format!("com.orbital.{}", package);
    map.insert("{{APP_NAME}}", package.clone());
    map.insert("{{APP_PACKAGE}}", bundle_id);
    map.insert("{{APP_CLASS_NAME}}", class_name);
    map.insert("{{APP_TITLE}}", to_title_case(project_name));
    map.insert("{{PROJECT_NAME}}", project_name.to_string());
    map
}

fn replace_placeholders_in_dir(
    dir: &Path,
    replacements: &std::collections::HashMap<&str, String>,
) -> Result<(), ShellError> {
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            replace_placeholders_in_dir(&path, replacements)?;
            continue;
        }

        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        let is_text = matches!(
            ext,
            "swift" | "yml" | "yaml" | "json" | "plist" | "md" | "txt" | "sh" | "xcconfig"
        );
        if !is_text {
            continue;
        }

        let content = std::fs::read_to_string(&path)?;
        let mut updated = content;
        for (placeholder, value) in replacements {
            updated = updated.replace(placeholder, value);
        }
        std::fs::write(&path, updated)?;
    }
    Ok(())
}

fn rename_placeholder_dirs(
    dir: &Path,
    replacements: &std::collections::HashMap<&str, String>,
) -> Result<(), ShellError> {
    let mut dirs: Vec<PathBuf> = vec![];
    collect_dirs(dir, &mut dirs)?;
    dirs.sort_by_key(|p| p.components().count());
    dirs.reverse();

    for path in dirs {
        if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
            let mut new_name = name.to_string();
            for (placeholder, value) in replacements {
                new_name = new_name.replace(placeholder, value);
            }
            if new_name != name {
                let new_path = path.with_file_name(new_name);
                std::fs::rename(&path, &new_path)?;
            }
        }
    }
    Ok(())
}

fn collect_dirs(dir: &Path, out: &mut Vec<PathBuf>) -> Result<(), ShellError> {
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            out.push(path.clone());
            collect_dirs(&path, out)?;
        }
    }
    Ok(())
}

/// Exposed `pub(crate)` so `backend.rs` can derive the exact Xcode module
/// name (`{{APP_CLASS_NAME}}`) a generated test file needs for
/// `@testable import` — the SAME derivation `build_replacements` uses for
/// the template's placeholder substitution, never duplicated.
pub(crate) fn to_package_name(s: &str) -> String {
    s.to_lowercase()
        .replace(['-', ' '], "_")
        .replace(|c: char| !c.is_alphanumeric() && c != '_', "")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shell_properties() {
        let shell = IosShell::new();
        assert_eq!(shell.name(), "ios");
        assert_eq!(shell.extensions(), &["swift"]);
        assert_eq!(shell.generated_dir(), "Sources/OrbitalApp/Generated");
    }

    #[test]
    fn test_to_package_name() {
        assert_eq!(to_package_name("My-App"), "my_app");
        assert_eq!(to_package_name("hello world"), "hello_world");
    }

    /// Sets up a fake template (`Sources/OrbitalApp/{App.swift,ContentView.swift}`)
    /// and a fake output dir (`project.yml` declaring `sources: [Sources/OrbitalApp]`)
    /// under a unique scratch dir, returning `(shell, output_dir)`. Callers must
    /// remove the returned dirs' shared parent when done.
    fn layout_test_fixture(tag: &str) -> (IosShell, PathBuf) {
        let base = std::env::temp_dir().join(format!("orbital_ios_layout_test_{tag}"));
        let _ = std::fs::remove_dir_all(&base);
        let template_dir = base.join("template");
        let output_dir = base.join("output");
        std::fs::create_dir_all(template_dir.join("Sources/OrbitalApp")).unwrap();
        std::fs::write(
            template_dir.join("Sources/OrbitalApp/App.swift"),
            "// template",
        )
        .unwrap();
        std::fs::write(
            template_dir.join("Sources/OrbitalApp/ContentView.swift"),
            "// template",
        )
        .unwrap();
        std::fs::create_dir_all(&output_dir).unwrap();
        std::fs::write(
            output_dir.join("project.yml"),
            "name: Test\ntargets:\n  Test:\n    sources:\n      - Sources/OrbitalApp\n",
        )
        .unwrap();
        (IosShell::with_template_path(template_dir), output_dir)
    }

    #[test]
    fn validate_generated_layout_detects_template_basename_collision() {
        let (shell, output_dir) = layout_test_fixture("collision");
        let manifest = vec!["App.swift".to_string()];
        let err = shell
            .validate_generated_layout(&output_dir, &manifest)
            .expect_err("App.swift must collide with the template-owned App.swift");
        assert!(matches!(err, ShellError::InvalidStructure { .. }));
        let _ = std::fs::remove_dir_all(output_dir.parent().unwrap());
    }

    #[test]
    fn validate_generated_layout_passes_non_colliding_basename() {
        let (shell, output_dir) = layout_test_fixture("no_collision");
        let manifest = vec!["GeneratedApp.swift".to_string()];
        shell
            .validate_generated_layout(&output_dir, &manifest)
            .expect("GeneratedApp.swift does not collide with any template basename");
        let _ = std::fs::remove_dir_all(output_dir.parent().unwrap());
    }

    #[test]
    fn validate_generated_layout_detects_path_outside_sources_root() {
        let base = std::env::temp_dir().join("orbital_ios_layout_test_outside_root");
        let _ = std::fs::remove_dir_all(&base);
        let template_dir = base.join("template");
        let output_dir = base.join("output");
        std::fs::create_dir_all(template_dir.join("Sources/OrbitalApp")).unwrap();
        std::fs::create_dir_all(&output_dir).unwrap();
        // Declares a sources root that does NOT cover the shell's generated_dir
        // ("Sources/OrbitalApp/Generated"), so any manifest entry must fail.
        std::fs::write(
            output_dir.join("project.yml"),
            "name: Test\ntargets:\n  Test:\n    sources:\n      - Other/Root\n",
        )
        .unwrap();
        let shell = IosShell::with_template_path(template_dir);
        let manifest = vec!["SomeFile.swift".to_string()];
        let err = shell
            .validate_generated_layout(&output_dir, &manifest)
            .expect_err("generated_dir is not under the declared sources root");
        assert!(matches!(err, ShellError::InvalidStructure { .. }));
        let _ = std::fs::remove_dir_all(&base);
    }

    fn template_file(rel: &str) -> String {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("template")
            .join(rel);
        std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("read {}: {e}", path.display()))
    }

    #[test]
    fn template_ships_the_generic_verify_driver_and_no_notes_specific_ui_test() {
        let project = template_file("project.yml");
        assert!(project.contains("{{APP_CLASS_NAME}}VerifyDriver:"));
        assert!(project.contains("Sources/OrbitalAppVerifyDriver"));
        assert!(!project.contains("UITests"));
        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("template/Sources");
        assert!(!root.join("OrbitalAppUITests").exists());
        assert!(root
            .join("OrbitalAppVerifyDriver/VerifyDriver.swift")
            .is_file());
    }

    #[test]
    fn driver_types_into_the_fields_input_and_answers_instead_of_crashing_without_focus() {
        let driver = template_file("Sources/OrbitalAppVerifyDriver/VerifyDriver.swift");
        let body = &driver[driver.find("private func type(").unwrap()..];
        let body = &body[..body.find("\n    }\n").unwrap()];
        assert!(
            body.contains("let input = editable(target)"),
            "a field id stamps its container"
        );
        assert!(
            body.contains("guard waitForKeyboardFocus(input) else {"),
            "XCUITest ends the driver on a type with no keyboard focus, so the route checks first"
        );
        assert!(body.contains("input.typeText(text)"));
        assert!(
            !body.contains("app.typeText("),
            "control: never typed into the app at large"
        );
        assert!(driver.contains("private func editable(_ element: XCUIElement) -> XCUIElement {"));
    }

    #[test]
    fn verify_driver_never_queries_xcuielement_hittability() {
        let driver = template_file("Sources/OrbitalAppVerifyDriver/VerifyDriver.swift");
        let code: String = driver
            .lines()
            .filter(|l| !l.trim_start().starts_with("//"))
            .collect::<Vec<_>>()
            .join("\n");
        assert!(
            !code.contains(".isHittable"),
            "isHittable raises a test failure that ends the driver"
        );
        assert!(
            !code.contains("target.tap()"),
            "element tap() needs an activation point; tap the frame centre"
        );
        assert!(
            code.contains("point(visible.midX, visible.midY)"),
            "taps, presses and swipes act on the frame centre"
        );
        assert!(code.contains("withOffset(CGVector(dx: x, dy: y))"));
        assert!(code.contains("frame.intersection(screen)"));
    }

    #[test]
    fn verify_driver_serves_every_documented_route_and_launches_with_the_bridge_env() {
        let driver = template_file("Sources/OrbitalAppVerifyDriver/VerifyDriver.swift");
        for route in ["/longpress", "/swipe"] {
            assert!(
                driver.contains(&format!(r#"case ("POST", "{route}"):"#)),
                "{route}"
            );
        }
        assert!(
            driver.contains("press(forDuration: 0.8)"),
            "a long press holds past the threshold"
        );
        assert!(
            driver.contains("thenDragTo"),
            "a swipe drags across the element"
        );
        for route in [
            "/health",
            "/tree",
            "/tap",
            "/type",
            "/screenshot",
            "/relaunch",
            "/stop",
        ] {
            assert!(
                driver.contains(&format!("\"{route}\"")),
                "driver lacks {route}"
            );
        }
        assert!(driver.contains(r#""ORBITAL_VERIFY_BRIDGE": "1""#));
        assert!(driver.contains("environment.merge(overrides) { _, new in new }"));
        assert!(driver.contains(r#"body["env"]"#));
        assert!(driver.contains("app.launchEnvironment = environment"));
        assert!(driver.contains("if !request.body.isEmpty {"));
        assert!(driver.contains(r#"env["ORBITAL_VERIFY_PORT"]"#));
        assert!(driver.contains(r#"env["ORBITAL_DRIVER_PORT"]"#));
        assert!(driver.contains("?? 7358"));
        assert!(driver.contains(r#".matching(identifier: within).firstMatch"#));
        assert!(!driver.contains("New Note"));
    }

    #[test]
    fn orb_build_delegates_device_lifecycle_to_the_shared_script_and_adds_driver_mode() {
        let build = template_file("orb-build.sh");
        assert!(build.contains("ios-device.sh"));
        assert!(
            !build.contains("simctl"),
            "simctl logic must live only in scripts/native/ios-device.sh"
        );
        assert!(build.contains(r#""$1" == "--driver""#));
        assert!(build.contains("test-without-building"));
        assert!(build.contains(r#"-only-testing:"${APP_NAME}VerifyDriver""#));
        assert!(build.contains("TEST_RUNNER_ORBITAL_DRIVER_PORT"));
        assert!(!build.contains("--uitest"));
    }

}
