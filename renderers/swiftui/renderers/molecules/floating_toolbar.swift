import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FloatingToolbarMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var items: [AnyCodable] { props.dictValue?["items"]?.arrayValue ?? [] }

    var body: some View {
        let position = props.string("position", default: "bottom-center")
        let horizontal: HorizontalAlignment = position.hasSuffix("left") ? .leading : (position.hasSuffix("right") ? .trailing : .center)
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { index in
                ButtonRenderer(props: buttonProps(items[index]), modifier: nil, onEvent: onEvent)
            }
            if !props.children().isEmpty && !items.isEmpty {
                DividerRenderer(props: ["orientation": "vertical"], modifier: nil, onEvent: onEvent)
                    .frame(height: theme.density.spacing.space6)
            }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .padding(theme.density.spacing.space1)
        .background(theme.color.card.opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .atomShadow(theme.elevation.popoverElevation)
        .accessibilityElement(children: .contain)
        .padding(theme.density.spacing.space6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: horizontal, vertical: position.hasPrefix("top") ? .top : .bottom))
    }

    private func buttonProps(_ item: AnyCodable) -> AnyCodable {
        let action = item.string("action", default: item.string("event"))
        let payload = item.dictValue?["actionPayload"] ?? .dict(["actionId": .string(item.string("id"))])
        return AtomKit.child(props, [
            "variant": .string(item.bool("active") ? "primary" : "ghost"),
            "size": "sm",
            "icon": .string(item.string("icon")),
            "aria-label": .string(item.string("label")),
            "aria-pressed": .bool(item.bool("active")),
            "disabled": .bool(item.bool("disabled")),
            "action": .string(AtomKit.eventOrLocal(action)),
            "local": .bool(action.isEmpty),
            "actionPayload": payload,
        ])
    }
}

@ViewBuilder
func FloatingToolbarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FloatingToolbarMoleculeView(props: props, onEvent: onEvent))
}
