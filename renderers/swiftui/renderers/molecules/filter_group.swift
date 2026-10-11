import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FilterGroupMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected: [String: String] = [:]
    @State private var open = false

    private var filters: [AnyCodable] { props.dictValue?["filters"]?.arrayValue ?? [] }
    private var variant: String { props.string("variant", default: "default") }
    private var look: String { props.string("look", default: "toolbar") }

    var body: some View {
        if look == "inline-column-header" {
            EmptyView()
        } else if look == "popover-trigger" || (look == "toolbar" && variant == "default" && sizeClass == .compact) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space2) {
                    ButtonRenderer(
                        props: ["variant": .string(selected.isEmpty ? "ghost" : "secondary"), "size": "sm", "leftIcon": "filter", "label": "Filters", "action": "filters-toggle", "aria-label": .string(open ? "Hide filters" : "Show filters"), "local": true],
                        modifier: nil,
                        onEvent: { _, _ in open.toggle() }
                    )
                    if !selected.isEmpty { AtomKit.badge(String(selected.count), "primary", onEvent: onEvent) }
                }
                if open { controls(vertical: true, icon: false) }
            }
        } else {
            controls(vertical: variant == "vertical", icon: props.bool("showIcon", default: true))
        }
    }

    @ViewBuilder
    private func controls(vertical: Bool, icon: Bool) -> some View {
        let count = selected.count
        let wrapGap = theme.density.spacing.space3
        if vertical {
            VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
                if icon { heading }
                ForEach(filters.indices, id: \.self) { index in field(filters[index], labelled: true) }
                if count > 0 { clearButton("Clear all") }
            }
        } else if variant == "pills" {
            AtomFlowLayout(spacing: wrapGap) {
                if icon { AtomKit.icon("filter", "sm", color: "muted", onEvent: onEvent) }
                ForEach(filters.indices, id: \.self) { index in pills(filters[index]) }
                if count > 0 { clearButton("Clear") }
            }
        } else {
            AtomFlowLayout(spacing: wrapGap) {
                if icon { heading }
                ForEach(filters.indices, id: \.self) { index in field(filters[index], labelled: variant != "compact") }
                if variant == "compact" {
                    ForEach(selected.keys.sorted(), id: \.self) { key in
                        let label = filters.first(where: { $0.string("field") == key })?.string("label") ?? key
                        BadgeRenderer(
                            props: ["label": .string("\(label): \(selected[key] ?? "")"), "variant": "primary", "size": "md", "onRemove": .string("filter-remove-\(key)"), "removeLabel": .string("Remove filter \(label)"), "local": true],
                            modifier: nil,
                            onEvent: { _, _ in choose(key, nil) }
                        )
                    }
                } else if count > 0 {
                    AtomKit.badge("\(count) active", "primary", size: "md", onEvent: onEvent)
                }
                if count > 0 { clearButton("Clear all") }
            }
        }
    }

    private var heading: some View {
        HStack(spacing: theme.density.spacing.space1) {
            AtomKit.icon("filter", "sm", color: "muted", onEvent: onEvent)
            AtomKit.typo("Filters", "overline", color: "muted", onEvent: onEvent)
        }
    }

    private func clearButton(_ label: String) -> some View {
        let event = props.string("clearEvent", default: "CLEAR_FILTERS")
        return ButtonRenderer(
            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "leftIcon": "x", "label": .string(label), "action": .string(event.isEmpty ? "CLEAR_FILTERS" : event)]),
            modifier: nil,
            onEvent: { _, _ in clearAll() }
        )
    }

    private func kind(_ filter: AnyCodable) -> String {
        let raw = filter.string("filterType", default: filter.string("type"))
        switch raw {
        case "date-range": return "daterange"
        case "number-range": return "numberrange"
        default: return raw
        }
    }

    @ViewBuilder
    private func pills(_ filter: AnyCodable) -> some View {
        let name = filter.string("field")
        let options = AtomKit.strings(filter, "options")
        HStack(spacing: theme.density.spacing.space1) {
            AtomKit.typo("\(filter.string("label")):", "small", color: "muted", weight: "medium", onEvent: onEvent)
            segment("All", name: name, value: nil, active: selected[name] == nil)
            ForEach(options, id: \.self) { option in
                segment(option, name: name, value: option, active: selected[name] == option)
            }
        }
    }

    private func segment(_ label: String, name: String, value: String?, active: Bool) -> some View {
        ButtonRenderer(
            props: ["variant": .string(active ? "primary" : "secondary"), "size": "sm", "label": .string(label), "action": .string(props.string("event").isEmpty ? "FILTER" : props.string("event"))],
            modifier: nil,
            onEvent: { _, _ in choose(name, value) }
        )
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder
    private func field(_ filter: AnyCodable, labelled: Bool) -> some View {
        let name = filter.string("field")
        let label = filter.string("label")
        let allLabel = variant == "compact" ? "All \(label)" : "All"
        switch kind(filter) {
        case "date":
            dateInput(name: name, label: labelled ? label : "", key: name)
        case "daterange":
            HStack(spacing: theme.density.spacing.space2) {
                dateInput(name: name + "_from", label: "From", key: name + "_from")
                dateInput(name: name + "_to", label: "To", key: name + "_to")
            }
        case "numberrange":
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if labelled { AtomKit.typo(label, "overline", color: "muted", onEvent: onEvent) }
                slider(filter, bound: "min", fallback: filter.float("min", default: 0))
                slider(filter, bound: "max", fallback: filter.float("max", default: 100))
            }
        case "text":
            InputRenderer(
                props: AtomKit.child(props, [
                    "inputType": "text",
                    "name": .string(name),
                    "label": .string(labelled ? label : ""),
                    "placeholder": .string(label),
                    "value": .string(selected[name] ?? ""),
                    "clearable": true,
                    "onChange": "filter-text",
                    "onClear": "filter-clear",
                ]),
                modifier: nil,
                onEvent: { event, envelope in
                    if event == "filter-clear" { choose(name, nil) } else { choose(name, envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue) }
                }
            )
        default:
            SelectRenderer(
                props: AtomKit.child(props, [
                    "name": .string(name),
                    "label": .string(labelled ? label : ""),
                    "aria-label": .string(label),
                    "placeholder": .string(allLabel),
                    "options": .array([["value": "all", "label": .string(allLabel)]] + AtomKit.strings(filter, "options").map { AnyCodable.dict(["value": .string($0), "label": .string($0)]) }),
                    "value": .string(selected[name] ?? "all"),
                    "onChange": "filter-select",
                ]),
                modifier: nil,
                onEvent: { _, envelope in choose(name, envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue) }
            )
        }
    }

    private func dateInput(name: String, label: String, key: String) -> some View {
        InputRenderer(
            props: AtomKit.child(props, ["inputType": "date", "name": .string(name), "label": .string(label), "value": .string(selected[key] ?? ""), "onChange": "filter-date"]),
            modifier: nil,
            onEvent: { _, envelope in choose(key, envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue) }
        )
    }

    private func slider(_ filter: AnyCodable, bound: String, fallback: Double) -> some View {
        let key = filter.string("field") + "_" + bound
        return RangeSliderRenderer(
            props: AtomKit.child(props, [
                "min": .double(filter.float("min", default: 0)),
                "max": .double(filter.float("max", default: 100)),
                "step": .double(filter.float("step", default: 1)),
                "value": .double(Double(selected[key] ?? "") ?? fallback),
                "showTooltip": true,
                "action": .string("filter-" + key),
                "aria-label": .string(bound == "min" ? "From" : "To"),
            ]),
            modifier: nil,
            onEvent: { _, envelope in
                if let value = envelope?.dictValue?["actionPayload"]?.dictValue?["value"], let text = AtomKit.scalar(value) { choose(key, text) }
            }
        )
    }

    private func choose(_ field: String, _ value: String?) {
        let cleared = value == nil || value == "" || value == "all"
        if cleared { selected.removeValue(forKey: field) } else if let value = value { selected[field] = value }
        let payload: AnyCodable = ["entity": .string(props.string("entity")), "field": .string(field), "value": .string(cleared ? "" : (value ?? "")), "query": .string(props.string("query"))]
        let event = props.string("event")
        if !event.isEmpty && event != "FILTER" { onEvent(event, eventEnvelope(props, payload: payload)) }
        onEvent("FILTER", eventEnvelope(props, payload: payload))
    }

    private func clearAll() {
        selected = [:]
        let payload: AnyCodable = ["entity": .string(props.string("entity")), "query": .string(props.string("query"))]
        let event = props.string("clearEvent")
        if !event.isEmpty && event != "CLEAR_FILTERS" { onEvent(event, eventEnvelope(props, payload: payload)) }
        onEvent("CLEAR_FILTERS", eventEnvelope(props, payload: payload))
    }
}

@ViewBuilder
func FilterGroupRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FilterGroupMoleculeView(props: props, onEvent: onEvent))
}
