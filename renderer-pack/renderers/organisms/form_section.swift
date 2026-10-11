import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct FormSectionOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var values: [String: AnyCodable]
    @State private var errors: [String: String] = [:]
    @State private var missing: [String] = []
    @State private var collapsed: Set<String> = []

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _values = State(initialValue: FormSectionOrganismView.seed(props))
    }

    private static func seed(_ props: AnyCodable) -> [String: AnyCodable] {
        var merged: [String: AnyCodable] = [:]
        let entity = props.dictValue?["entity"]
        if let row = entity?.dictValue, entity?.arrayValue == nil { merged = row }
        for (key, value) in props.dictValue?["initialData"]?.dictValue ?? [:] { merged[key] = value }
        var normalized: [String: AnyCodable] = [:]
        for (key, value) in merged {
            normalized[key] = key == "id" ? value : collapse(value)
        }
        return normalized
    }

    private static func collapse(_ value: AnyCodable) -> AnyCodable {
        if let list = value.arrayValue {
            return .array(list.map { item in item.dictValue?["id"].flatMap { AtomKit.scalar($0) }.map { AnyCodable.string($0) } ?? item })
        }
        if let id = value.dictValue?["id"], let text = AtomKit.scalar(id) { return .string(text) }
        return value
    }

    private var fields: [AnyCodable] {
        let overrides = props.dictValue?["fieldOverrides"]?.arrayValue ?? []
        return AtomKit.fieldDefs(props, ["fields"]).map { field in
            guard let override = overrides.first(where: { $0.string("name") == field.string("name") }) else { return field }
            var merged = field.dictValue ?? [:]
            for key in ["label", "placeholder", "hint"] {
                if let value = override.dictValue?[key] { merged[key] = value }
            }
            return .dict(merged)
        }
    }

    private var sections: [AnyCodable] { props.dictValue?["sections"]?.arrayValue ?? [] }
    private var loading: Bool { props.bool("isLoading") }

    var body: some View {
        let gap = AtomKit.space(theme, props.string("gap", default: "md"))
        let error = AtomKit.errorText(props)
        VStack(alignment: .leading, spacing: gap) {
            if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h4", onEvent: onEvent) }
            if !missing.isEmpty {
                AlertRenderer(props: ["variant": "error", "title": .string("Fix \(missing.count) field\(missing.count == 1 ? "" : "s")"), "message": .string(missing.joined(separator: ", "))], modifier: nil, onEvent: onEvent)
            }
            if !error.isEmpty {
                AlertRenderer(props: ["variant": "error", "message": .string(error)], modifier: nil, onEvent: onEvent)
            }
            ForEach(sections.indices, id: \.self) { index in section(sections[index], gap: gap) }
            if props.string("layout", default: "vertical") == "vertical" {
                VStack(alignment: .leading, spacing: gap) { flat }
            } else {
                AtomFlowLayout(spacing: gap) { flat }
            }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
            if !fields.isEmpty || !sections.isEmpty { actions }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .onChange(of: FormSectionOrganismView.seed(props)) { next in
            if !next.isEmpty { values = next }
        }
    }

    @ViewBuilder
    private var flat: some View {
        ForEach(fields.indices, id: \.self) { index in control(fields[index]) }
    }

    @ViewBuilder
    private func section(_ section: AnyCodable, gap: CGFloat) -> some View {
        let id = section.string("id", default: section.string("title"))
        let folded = collapsed.contains(id)
        let entries = (section.dictValue?["fields"]?.arrayValue ?? []).compactMap { AtomKit.normalizedField($0) }
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack {
                if section.bool("collapsible") {
                    ButtonRenderer(
                        props: ["variant": "ghost", "label": .string(section.string("title")), "rightIcon": .string(folded ? "chevron-down" : "chevron-up"), "action": .string("section-toggle-\(id)"), "local": true],
                        modifier: nil,
                        onEvent: { _, _ in if folded { collapsed.remove(id) } else { collapsed.insert(id) } }
                    )
                    .accessibilityValue(folded ? "collapsed" : "expanded")
                } else {
                    AtomKit.typo(section.string("title"), "label", weight: "semibold", onEvent: onEvent)
                }
                Spacer(minLength: theme.density.spacing.space0)
            }
            .padding(theme.density.spacing.space3)
            .background(theme.color.muted)
            if !folded {
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(entries.indices, id: \.self) { index in control(entries[index]) }
                }
                .padding(theme.density.spacing.space4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    private var actions: some View {
        let submitEvent = props.string("submitEvent", default: "SAVE")
        let cancelEvent = props.string("cancelEvent", default: "CANCEL")
        let showCancel = props.dictValue?["showCancel"]?.boolValue ?? !fields.isEmpty
        return HStack(spacing: theme.density.spacing.space2) {
            Spacer(minLength: theme.density.spacing.space0)
            if showCancel {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "secondary", "label": .string(props.string("cancelLabel", default: "Cancel")), "disabled": .bool(loading), "action": .string(cancelEvent)]),
                    modifier: nil,
                    onEvent: { _, _ in cancel(cancelEvent) }
                )
            }
            if props.bool("showSubmit", default: true) {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "primary", "label": .string(props.string("submitLabel", default: "Save")), "isLoading": .bool(loading), "action": .string(submitEvent)]),
                    modifier: nil,
                    onEvent: { _, _ in submit(submitEvent) }
                )
            }
        }
    }

    private func enumOptions(_ field: AnyCodable) -> [AnyCodable] {
        if let options = field.dictValue?["options"]?.arrayValue, !options.isEmpty {
            return options.map { option in
                if option.dictValue != nil { return option }
                return .dict(["value": option, "label": option])
            }
        }
        let labels = field.dictValue?["labels"]?.dictValue ?? [:]
        let listed = AtomKit.strings(field, "values")
        let named = listed.isEmpty ? AtomKit.strings(field.dictValue?["validation"] ?? .null, "enum") : listed
        return named.map { .dict(["value": .string($0), "label": labels[$0] ?? .string($0)]) }
    }

    private func inputType(_ field: AnyCodable) -> String {
        let explicit = field.string("inputType")
        if !explicit.isEmpty { return explicit }
        let type = field.string("type")
        if type == "relation" || field.dictValue?["relation"] != nil { return "relation" }
        if type == "array" { return "array" }
        if type == "enum" || !enumOptions(field).isEmpty { return "select" }
        switch type.lowercased() {
        case "email": return "email"
        case "password": return "password"
        case "url": return "url"
        case "file": return "file"
        case "image": return "image"
        case "money": return "currency"
        case "number", "integer", "float": return "number"
        case "date": return "date"
        case "datetime", "timestamp": return "datetime-local"
        case "boolean": return "checkbox"
        case "textarea", "text": return field.int("max") > 200 ? "textarea" : "text"
        default: return "text"
        }
    }

    private func current(_ field: AnyCodable) -> AnyCodable {
        values[field.string("name")] ?? field.dictValue?["defaultValue"] ?? .string("")
    }

    private func set(_ name: String, _ value: AnyCodable?) {
        if let value = value { values[name] = value } else { values.removeValue(forKey: name) }
        errors.removeValue(forKey: name)
    }

    private func typed(_ envelope: AnyCodable?) -> AnyCodable? {
        envelope?.dictValue?["actionPayload"]?.dictValue?["value"]
    }

    @ViewBuilder
    private func control(_ field: AnyCodable) -> some View {
        let name = field.string("name")
        let label = field.string("label", default: name)
        let kind = inputType(field)
        let value = current(field)
        let text = AtomKit.scalar(value) ?? ""
        let common: [String: AnyCodable] = [
            "name": .string(name),
            "label": .string(label),
            "placeholder": .string(field.string("placeholder")),
            "required": .bool(field.bool("required")),
            "helperText": .string(field.string("hint")),
            "error": .string(errors[name] ?? ""),
            "disabled": .bool(loading),
            "onChange": "form-field-change",
        ]
        switch kind {
        case "checkbox":
            CheckboxRenderer(
                props: .dict(common.merging(["checked": .bool(value.boolValue ?? false), "helperText": ""], uniquingKeysWith: { _, new in new })),
                modifier: nil,
                onEvent: { _, envelope in set(name, envelope?.dictValue?["actionPayload"]?.dictValue?["checked"]) }
            )
        case "select", "relation":
            let options = kind == "relation" ? (props.dictValue?["relationsData"]?.dictValue?[name]?.arrayValue ?? []) : enumOptions(field)
            let many = ["many", "one-to-many", "many-to-many"].contains(field.dictValue?["relation"]?.string("cardinality") ?? "")
            SelectRenderer(
                props: .dict(common.merging([
                    "options": .array(options),
                    "value": many ? .array(AtomKit.strings(.dict(["v": value]), "v").map { AnyCodable.string($0) }) : .string(text),
                    "multiple": .bool(many),
                    "clearable": .bool(kind == "relation" && !field.bool("required")),
                    "placeholder": .string(field.string("placeholder", default: "Select \(label)")),
                    "disabled": .bool(loading || props.dictValue?["relationsLoading"]?.dictValue?[name]?.boolValue == true),
                ], uniquingKeysWith: { _, new in new })),
                modifier: nil,
                onEvent: { _, envelope in set(name, typed(envelope)) }
            )
        case "array":
            TagInputRenderer(
                props: .dict(["value": .array(AtomKit.strings(.dict(["v": value]), "v").map { AnyCodable.string($0) }), "name": .string(name), "placeholder": .string(field.string("placeholder")), "disabled": .bool(loading), "addEvent": "form-tag-add", "removeEvent": "form-tag-remove"]),
                modifier: nil,
                onEvent: { _, envelope in set(name, envelope?.dictValue?["actionPayload"]?.dictValue?["value"]) }
            )
        case "file":
            EmptyView()
        default:
            let entry: String = kind == "currency" ? "number" : (kind == "image" ? "url" : kind)
            let shown = entry == "date" ? String(text.prefix(10)) : (entry == "datetime-local" ? String(text.prefix(16)) : text)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                if kind == "image" && !text.isEmpty {
                    ImageRenderer(props: ["src": .string(text), "alt": .string(label), "aspect": "16/9", "rounded": "md"], modifier: nil, onEvent: onEvent)
                        .frame(maxWidth: AlmadarSizes.maxWXs)
                }
                InputRenderer(
                    props: .dict(common.merging(["inputType": .string(entry), "value": .string(shown), "leftIcon": .string(kind == "currency" ? "dollar-sign" : "")], uniquingKeysWith: { _, new in new })),
                    modifier: nil,
                    onEvent: { _, envelope in
                        let raw = typed(envelope).flatMap { AtomKit.scalar($0) } ?? ""
                        if entry == "number" {
                            if let number = Double(raw.trimmingCharacters(in: .whitespaces)) {
                                set(name, number == number.rounded() && abs(number) < 1e15 ? .int(Int(number)) : .double(number))
                            } else {
                                set(name, nil)
                            }
                        } else {
                            set(name, .string(raw))
                        }
                    }
                )
            }
        }
    }

    private func allFields() -> [AnyCodable] {
        fields + sections.flatMap { ($0.dictValue?["fields"]?.arrayValue ?? []).compactMap { AtomKit.normalizedField($0) } }
    }

    private func problem(_ field: AnyCodable) -> String? {
        let value = current(field)
        let text = AtomKit.scalar(value) ?? ""
        let empty = AtomKit.blank(value) || (value.arrayValue?.isEmpty ?? false)
        if field.bool("required") && empty && inputType(field) != "checkbox" { return "This field is required" }
        if empty { return nil }
        if let number = value.doubleValue, value.stringValue == nil {
            if field.dictValue?["min"] != nil && number < field.float("min") { return "Must be at least \(AtomKit.scalar(field.dictValue?["min"]) ?? "")" }
            if field.dictValue?["max"] != nil && number > field.float("max") { return "Must be at most \(AtomKit.scalar(field.dictValue?["max"]) ?? "")" }
        } else if value.stringValue != nil {
            if field.dictValue?["min"] != nil && text.count < field.int("min") { return "Use at least \(field.int("min")) characters" }
            if field.dictValue?["max"] != nil && text.count > field.int("max") { return "Use at most \(field.int("max")) characters" }
            let pattern = field.string("pattern")
            if !pattern.isEmpty, text.range(of: "^(?:\(pattern))$", options: .regularExpression) == nil { return "Invalid value" }
        }
        return nil
    }

    private func submit(_ event: String) {
        var found: [String: String] = [:]
        var order: [String] = []
        for field in allFields() {
            if let message = problem(field) {
                found[field.string("name")] = message
                order.append(field.string("label", default: field.string("name")))
            }
        }
        errors = found
        missing = order
        if !found.isEmpty {
            let messages = found.keys.sorted().map { AnyCodable.dict(["field": .string($0), "message": .string(found[$0] ?? "")]) }
            onEvent("VALIDATION_FAILED", eventEnvelope(props, payload: ["submitEvent": .string(event), "missing": .array(found.keys.sorted().map { AnyCodable.string($0) }), "messages": .array(messages), "summary": .string("Fix \(found.count) field\(found.count == 1 ? "" : "s")")]))
            return
        }
        var merged = FormSectionOrganismView.seed(props)
        for (key, value) in values { merged[key] = value }
        let payload: AnyCodable = ["data": .dict(merged)]
        onEvent(event, eventEnvelope(props, payload: payload))
        let extra = props.string("onSubmit")
        if !extra.isEmpty { onEvent(extra, eventEnvelope(props, payload: payload)) }
    }

    private func cancel(_ event: String) {
        onEvent(event, eventEnvelope(props))
        let extra = props.string("onCancel")
        if !extra.isEmpty { onEvent(extra, eventEnvelope(props)) }
    }
}

@ViewBuilder
func FormSectionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormSectionOrganismView(props: props, onEvent: onEvent))
}
