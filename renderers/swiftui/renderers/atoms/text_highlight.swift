import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TextHighlightAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let note = props.string("highlightType") == "note"
        let tint = note ? theme.color.warning : theme.color.primary
        let active = props.bool("isActive")
        let action = props.string("action")
        let hoverEvent = props.string("hoverEvent")
        let annotation = props.string("annotationId")
        let parts = props.children().compactMap { AtomKit.scalar($0) }
        let nested = props.children().contains { $0.dictValue != nil }
        let payload: AnyCodable = ["annotationId": .string(annotation)]
        Group {
            if nested {
                HStack(spacing: theme.density.spacing.space0) { AtomChildren(props: props, key: "children", onEvent: onEvent) }
            } else {
                Text(parts.joined()).font(AtomKit.font(theme, "base"))
            }
        }
        .foregroundColor(theme.color.foreground)
        .padding(.horizontal, theme.density.spacing.space1 / 2)
        .background(active ? tint.opacity(0.1) : theme.color.card)
        .overlay(alignment: .bottom) { Rectangle().fill(tint).frame(height: theme.geometry.borderHeavy * 2) }
        .atomBorder(theme, .container, radius: theme.geometry.radiusInteractive, color: active ? tint : AtomKit.clear(theme), width: theme.geometry.borderHeavy * 2)
        .contentShape(Rectangle())
        .onTapGesture { if !action.isEmpty { onEvent(action, eventEnvelope(props, payload: payload)) } }
        .onLongPressGesture(minimumDuration: 3600, maximumDistance: theme.density.spacing.space12, perform: {}, onPressingChanged: { pressing in
            guard !hoverEvent.isEmpty else { return }
            onEvent(hoverEvent, eventEnvelope(props, payload: ["hovered": .bool(pressing), "annotationId": .string(annotation)]))
        })
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .atomAction(action.isEmpty ? hoverEvent : action, props)
    }
}

@ViewBuilder
func TextHighlightRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TextHighlightAtomView(props: props, onEvent: onEvent))
}
