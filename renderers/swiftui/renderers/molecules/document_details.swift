import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocumentDetailsMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var editing: String?
    @State private var draft = ""

    private var fields: [AnyCodable] { AtomKit.fieldDefs(props, ["fields"]) }
    private var record: AnyCodable { props.dictValue?["entity"] ?? .dict([:]) }
    private var recordId: String { AtomKit.scalar(record.dictValue?["id"]) ?? "" }
    private var editable: Bool { !props.string("metaCommitEvent").isEmpty }

    var body: some View {
        if !fields.isEmpty {
            let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomKit.typo(props.string("title", default: "Details"), "overline", color: "secondary", weight: "medium", onEvent: onEvent)
                ForEach(fields.indices, id: \.self) { index in field(fields[index]) }
            }
            .padding(theme.density.spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.card)
            .clipShape(shape)
            .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            .accessibilityElement(children: .contain)
        }
    }

    private func label(_ field: AnyCodable) -> String { field.string("label", default: field.string("name")) }

    private func kind(_ field: AnyCodable, _ raw: AnyCodable?) -> String {
        let declared = field.string("kind")
        if !declared.isEmpty { return declared }
        if field.string("type") == "image" { return "image" }
        if !AtomKit.strings(field, "options").isEmpty { return "select" }
        if case .some(.bool) = raw { return "boolean" }
        if field.string("format") == "boolean" { return "boolean" }
        if raw?.arrayValue != nil || raw?.dictValue != nil { return "readonly" }
        return "text"
    }

    private func chipLabel(_ item: AnyCodable, _ field: AnyCodable) -> String {
        if let dict = item.dictValue {
            for key in ["name", "title", "label"] { if let text = AtomKit.scalar(dict[key]), !text.isEmpty { return text } }
            return AtomKit.scalar(dict["id"]) ?? ""
        }
        let text = AtomKit.scalar(item) ?? ""
        return AtomKit.labelled(text, field)
    }

    private func chipId(_ item: AnyCodable) -> String {
        AtomKit.scalar(item.dictValue?["id"]) ?? (AtomKit.scalar(item) ?? "")
    }

    @ViewBuilder
    private func field(_ field: AnyCodable) -> some View {
        let name = field.string("name")
        let raw = AtomKit.cell(record, name)
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            HStack(spacing: theme.density.spacing.space1) {
                if !field.string("icon").isEmpty { AtomKit.icon(field.string("icon"), "xs", color: "muted", onEvent: onEvent) }
                AtomKit.typo(label(field), "caption", color: "muted", onEvent: onEvent)
            }
            value(field, name: name, raw: raw)
        }
    }

    @ViewBuilder
    private func value(_ field: AnyCodable, name: String, raw: AnyCodable?) -> some View {
        let type = kind(field, raw)
        let empty = AtomKit.blank(raw)
        switch type {
        case "image":
            if empty { AtomKit.typo("\u{2014}", "small", color: "secondary", onEvent: onEvent) } else {
                ImageRenderer(props: ["src": .string(AtomKit.assetURL(.dict(["u": raw ?? .null]), "u")), "alt": .string(label(field)), "aspect": "16/9", "rounded": "md", "bordered": true], modifier: nil, onEvent: onEvent)
                    .frame(maxHeight: theme.density.spacing.space12 * 3)
            }
        case "boolean":
            SwitchRenderer(
                props: ["label": .string(label(field)), "checked": .bool(raw?.boolValue ?? false), "disabled": .bool(!editable), "name": .string(name), "onChange": "document-field-toggle"],
                modifier: nil,
                onEvent: { _, envelope in commit(name, envelope?.dictValue?["actionPayload"]?.dictValue?["checked"], current: raw) }
            )
        case "select":
            SelectRenderer(
                props: [
                    "name": .string(name),
                    "options": .array(AtomKit.strings(field, "options").map { AnyCodable.dict(["value": .string($0), "label": .string(AtomKit.labelled($0, field))]) }),
                    "value": .string(AtomKit.scalar(raw) ?? ""),
                    "disabled": .bool(!editable),
                    "aria-label": .string(label(field)),
                    "onChange": "document-field-select",
                ],
                modifier: nil,
                onEvent: { _, envelope in commit(name, envelope?.dictValue?["actionPayload"]?.dictValue?["value"], current: raw) }
            )
        default:
            if type == "readonly" || !editable {
                readonly(field, name: name, raw: raw)
            } else if editing == name {
                HStack(spacing: theme.density.spacing.space1) {
                    InputRenderer(
                        props: ["inputType": "text", "name": .string(name), "value": .string(draft), "onChange": "document-field-draft", "action": "document-field-commit"],
                        modifier: nil,
                        onEvent: { event, envelope in
                            let typed = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? ""
                            if event == "document-field-commit" { commit(name, .string(typed.trimmingCharacters(in: .whitespaces)), current: raw) } else { draft = typed }
                        }
                    )
                    ButtonRenderer(
                        props: ["variant": "ghost", "size": "sm", "icon": "check", "aria-label": .string("Save \(label(field))"), "action": .string("document-field-save-\(name)"), "local": true],
                        modifier: nil,
                        onEvent: { _, _ in commit(name, .string(draft.trimmingCharacters(in: .whitespaces)), current: raw) }
                    )
                }
            } else {
                AtomKit.typo(empty ? "\u{2014}" : AtomKit.fieldText(record, field), "small", color: empty ? "muted" : "primary", onEvent: onEvent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft = AtomKit.scalar(raw) ?? ""
                        editing = name
                    }
                    .accessibilityAddTraits(.isButton)
                    .verificationId(VerificationIds.field(name))
            }
        }
    }

    @ViewBuilder
    private func readonly(_ field: AnyCodable, name: String, raw: AnyCodable?) -> some View {
        if AtomKit.blank(raw) || (raw?.arrayValue?.isEmpty ?? false) {
            AtomKit.typo("\u{2014}", "small", color: "secondary", onEvent: onEvent)
        } else if let list = raw?.arrayValue {
            chips(list, field: field, name: name)
        } else if raw?.dictValue != nil, let single = raw {
            chips([single], field: field, name: name)
        } else {
            AtomKit.typo(AtomKit.fieldText(record, field), "small", onEvent: onEvent)
        }
    }

    private func chips(_ items: [AnyCodable], field: AnyCodable, name: String) -> some View {
        let event = props.string("relationEvent")
        return AtomFlowLayout(spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                if event.isEmpty {
                    AtomKit.badge(chipLabel(item, field), "default", onEvent: onEvent)
                } else {
                    ButtonRenderer(
                        props: AtomKit.child(props, [
                            "variant": "secondary",
                            "size": "sm",
                            "label": .string(chipLabel(item, field)),
                            "action": .string(event),
                            "actionPayload": ["field": .string(name), "id": .string(chipId(item)), "name": .string(chipLabel(item, field))],
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
        }
    }

    private func commit(_ name: String, _ next: AnyCodable?, current: AnyCodable?) {
        editing = nil
        let event = props.string("metaCommitEvent")
        guard !event.isEmpty, let next = next, next != current else { return }
        onEvent(event, eventEnvelope(props, payload: ["id": .string(recordId), "patch": .dict(["id": .string(recordId), name: next])]))
    }
}

@ViewBuilder
func DocumentDetailsRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocumentDetailsMoleculeView(props: props, onEvent: onEvent))
}
