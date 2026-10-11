import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FloatingActionButtonMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var expanded = false

    var body: some View {
        let actions = props.dictValue?["actions"]?.arrayValue ?? []
        let position = props.string("position", default: "bottom-right")
        let leading = position.hasSuffix("left")
        let top = position.hasPrefix("top")
        let horizontal: HorizontalAlignment = leading ? .leading : (position.hasSuffix("center") ? .center : .trailing)
        VStack(alignment: leading ? .leading : .trailing, spacing: theme.density.spacing.space3) {
            if expanded && actions.count > 1 {
                ForEach(actions.indices, id: \.self) { index in
                    HStack(spacing: theme.density.spacing.space2) {
                        if !leading { chip(actions[index].string("label")) }
                        round(
                            ButtonRenderer(
                                props: AtomKit.child(props, [
                                    "variant": .string(actions[index].string("variant", default: "primary")),
                                    "size": "lg",
                                    "icon": .string(actions[index].string("icon")),
                                    "aria-label": .string(actions[index].string("label")),
                                    "action": .string(actions[index].string("event")),
                                    "actionPayload": ["actionId": .string(actions[index].string("id"))],
                                ]),
                                modifier: nil,
                                onEvent: { name, envelope in
                                    expanded = false
                                    onEvent(name, eventEnvelope(props, payload: envelope?.dictValue?["actionPayload"]))
                                }
                            )
                        )
                        if leading { chip(actions[index].string("label")) }
                    }
                }
            }
            main(actions)
        }
        .padding(theme.density.spacing.space6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: horizontal, vertical: top ? .top : .bottom))
    }

    @ViewBuilder
    private func main(_ actions: [AnyCodable]) -> some View {
        if actions.isEmpty {
            if !props.string("icon").isEmpty {
                round(
                    ButtonRenderer(
                        props: AtomKit.child(props, [
                            "variant": .string(props.string("variant", default: "primary")),
                            "size": "lg",
                            "icon": .string(props.string("icon")),
                            "aria-label": .string(props.string("aria-label", default: props.string("label", default: "Action"))),
                            "action": .string(props.string("action")),
                            "actionPayload": props.dictValue?["actionPayload"] ?? .null,
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                )
            }
        } else if actions.count == 1 {
            round(
                ButtonRenderer(
                    props: AtomKit.child(props, [
                        "variant": .string(actions[0].string("variant", default: "primary")),
                        "size": "lg",
                        "icon": .string(actions[0].string("icon", default: "plus")),
                        "aria-label": .string(actions[0].string("label")),
                        "action": .string(actions[0].string("event")),
                        "actionPayload": ["actionId": .string(actions[0].string("id"))],
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
            )
        } else {
            round(
                ButtonRenderer(
                    props: AtomKit.child(props, [
                        "variant": .string(expanded ? "secondary" : "primary"),
                        "size": "lg",
                        "icon": .string(expanded ? "x" : "plus"),
                        "aria-label": .string(expanded ? "Close actions" : "Open actions"),
                        "action": "fab-toggle",
                        "local": true,
                    ]),
                    modifier: nil,
                    onEvent: { _, _ in expanded.toggle() }
                )
            )
            .accessibilityValue(expanded ? "expanded" : "collapsed")
        }
    }

    private func round(_ button: AnyView) -> some View {
        button
            .clipShape(Circle())
            .atomShadow(theme.elevation.popoverElevation)
    }

    private func chip(_ label: String) -> some View {
        AtomKit.typo(label, "small", onEvent: onEvent)
            .padding(.horizontal, theme.density.spacing.space2)
            .padding(.vertical, theme.density.spacing.space1)
            .background(theme.color.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
            .atomShadow(theme.elevation.cardElevation)
    }
}

@ViewBuilder
func FloatingActionButtonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FloatingActionButtonMoleculeView(props: props, onEvent: onEvent))
}
