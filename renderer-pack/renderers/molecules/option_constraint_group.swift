import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct OptionConstraintGroupMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var chosen: [String]

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _chosen = State(initialValue: AtomKit.strings(props, "selected"))
    }

    private var constraint: AnyCodable { props.dictValue?["constraint"] ?? .dict(["type": "single"]) }
    private var single: Bool { constraint.string("type", default: "single") == "single" }
    private var low: Int? { constraint.dictValue?["min"]?.intValue }
    private var high: Int? { constraint.dictValue?["max"]?.intValue }

    private var hint: String {
        if single { return constraint.bool("required") ? "Required, pick 1" : "Optional, pick up to 1" }
        switch (low, high) {
        case let (min?, max?) where min > 0 && max > 0: return min == max ? "Pick exactly \(min)" : "Pick \(min)-\(max)"
        case let (min?, _) where min > 0: return "Pick at least \(min)"
        case let (_, max?) where max > 0: return "Pick up to \(max)"
        default: return "Optional"
        }
    }

    private var problem: String? {
        if single {
            if constraint.bool("required") && chosen.isEmpty { return "Pick 1 option" }
            if chosen.count > 1 { return "Pick only 1 option" }
            return nil
        }
        if let min = low, chosen.count < min { return "Pick at least \(min - chosen.count) more" }
        if let max = high, chosen.count > max { return "Remove \(chosen.count - max) options" }
        return nil
    }

    private func toggle(_ id: String) {
        if single {
            chosen = chosen.contains(id) ? [] : [id]
        } else {
            chosen = chosen.contains(id) ? chosen.filter { $0 != id } : chosen + [id]
        }
        let event = props.string("changeEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["selected": .array(chosen.map { AnyCodable.string($0) })])) }
    }

    var body: some View {
        let event = props.string("changeEvent")
        let options = props.dictValue?["options"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            HStack(alignment: .firstTextBaseline, spacing: theme.density.spacing.space2) {
                AtomKit.typo(props.string("title"), "label", weight: "semibold", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space0)
                AtomKit.typo(hint, "caption", color: single && constraint.bool("required") ? "error" : "muted", onEvent: onEvent)
            }
            if !props.string("description").isEmpty { AtomKit.typo(props.string("description"), "caption", color: "muted", onEvent: onEvent) }
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let id = option.string("id")
                let on = chosen.contains(id)
                let blocked = option.bool("disabled") || option.bool("outOfStock")
                ChoiceButtonRenderer(
                    props: AtomKit.child(props, [
                        "text": .string(label(option)),
                        "icon": .string(single ? (on ? "check-circle" : "circle") : (on ? "check-square" : "square")),
                        "selected": .bool(on),
                        "disabled": .bool(blocked),
                        "action": .string(AtomKit.eventOrLocal(event)),
                        "local": .bool(event.isEmpty),
                    ]),
                    modifier: nil,
                    onEvent: { _, _ in toggle(id) }
                )
            }
            if let problem = problem { AtomKit.typo(problem, "caption", color: "error", onEvent: onEvent) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("title"))
        .id(props.string("groupId"))
        .onChange(of: AtomKit.strings(props, "selected")) { next in chosen = next }
    }

    private func label(_ option: AnyCodable) -> String {
        var text = option.string("label")
        if let delta = option.dictValue?["priceDelta"]?.doubleValue {
            text += "  " + (delta >= 0 ? "+" : "-") + "$" + String(format: "%.2f", abs(delta))
        }
        if option.bool("outOfStock") { text += "  (Out of stock)" }
        return text
    }
}

@ViewBuilder
func OptionConstraintGroupRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(OptionConstraintGroupMoleculeView(props: props, onEvent: onEvent))
}
