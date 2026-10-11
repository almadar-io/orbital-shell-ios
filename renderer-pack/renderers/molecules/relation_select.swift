import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct RelationSelectMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var value: String
    @State private var open = false
    @State private var query = ""

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _value = State(initialValue: props.string("value"))
    }

    private var options: [AnyCodable] { props.dictValue?["options"]?.arrayValue ?? [] }
    private var selected: AnyCodable? { options.first(where: { AtomKit.scalar($0.dictValue?["value"]) == value }) }

    private func choose(_ next: String) {
        value = next
        open = false
        query = ""
        let event = props.string("onChange")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["value": .string(next)])) }
    }

    var body: some View {
        let event = props.string("onChange")
        let disabled = props.bool("disabled")
        let filtered = options.filter { option in
            let needle = query.lowercased()
            return needle.isEmpty || option.string("label").lowercased().contains(needle) || option.string("description").lowercased().contains(needle)
        }
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            HStack(spacing: theme.density.spacing.space1) {
                ButtonRenderer(
                    props: AtomKit.child(props, [
                        "variant": "secondary",
                        "label": .string(selected?.string("label") ?? props.string("placeholder", default: "Select...")),
                        "rightIcon": .string(open ? "chevron-up" : "chevron-down"),
                        "disabled": .bool(disabled),
                        "isLoading": .bool(props.bool("isLoading")),
                        "action": .string(AtomKit.localEvent),
                        "local": true,
                    ]),
                    modifier: nil,
                    onEvent: { _, _ in if !disabled { open.toggle() } }
                )
                .atomId(props.string("name").isEmpty ? "" : VerificationIds.field(props.string("name")))
                if props.bool("clearable", default: true) && selected != nil && !disabled {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Clear", "action": .string(AtomKit.eventOrLocal(event)), "local": .bool(event.isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in choose("") }
                    )
                }
            }
            if open {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    InputRenderer(
                        props: AtomKit.child(props, ["inputType": "search", "placeholder": .string(props.string("searchPlaceholder", default: "Search...")), "value": .string(query), "onChange": .string(AtomKit.localEvent), "local": true]),
                        modifier: nil,
                        onEvent: { _, envelope in query = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "" }
                    )
                    if filtered.isEmpty {
                        AtomKit.typo(props.string("emptyMessage", default: "No options found"), "small", color: "muted", align: "center", onEvent: onEvent)
                            .padding(theme.density.spacing.space3)
                    }
                    ForEach(filtered.indices, id: \.self) { index in
                        let option = filtered[index]
                        let optionValue = AtomKit.scalar(option.dictValue?["value"]) ?? ""
                        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                            ButtonRenderer(
                                props: AtomKit.child(props, [
                                    "variant": .string(optionValue == value ? "primary" : "ghost"),
                                    "size": "sm",
                                    "label": .string(option.string("label")),
                                    "disabled": .bool(option.bool("disabled")),
                                    "action": .string(AtomKit.eventOrLocal(event)),
                                    "local": .bool(event.isEmpty),
                                    "actionPayload": ["value": .string(optionValue)],
                                ]),
                                modifier: nil,
                                onEvent: { _, _ in choose(optionValue) }
                            )
                            if !option.string("description").isEmpty {
                                AtomKit.typo(option.string("description"), "caption", color: "muted", onEvent: onEvent)
                                    .padding(.horizontal, theme.density.spacing.space3)
                            }
                        }
                    }
                }
                .atomSurface(theme, padding: theme.density.spacing.space2)
            }
            if !props.string("error").isEmpty {
                AtomKit.typo(props.string("error"), "caption", color: "error", onEvent: onEvent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: props.string("value")) { next in value = next }
    }
}

@ViewBuilder
func RelationSelectRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RelationSelectMoleculeView(props: props, onEvent: onEvent))
}
