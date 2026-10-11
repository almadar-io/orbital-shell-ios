import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct BoxAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var revealed = false

    var body: some View {
        let action = props.string("action")
        let hoverEvent = props.string("hoverEvent")
        let radius = AtomKit.radius(theme, props.string("rounded", default: "none"))
        let role: AtomRole = props.string("rounded") == "full" ? .pill : .container
        let shape = AtomKit.shape(theme, role, radius: radius)
        let horizontal = edge("paddingX", fallback: "padding")
        let vertical = edge("paddingY", fallback: "padding")
        let outerX = margin("marginX")
        let outerY = margin("marginY")
        let maxWidth = AtomKit.length(props.string("maxWidth"))
        let content = VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .padding(.horizontal, horizontal)
        .padding(.vertical, vertical)
        .frame(maxWidth: props.bool("fullWidth") ? .infinity : maxWidth, maxHeight: props.bool("fullHeight") ? .infinity : nil, alignment: .topLeading)
        .background(background())
        .clipShape(shape)
        .atomBorder(theme, role, radius: radius, color: props.bool("border") ? theme.color.border : AtomKit.clear(theme), width: theme.geometry.borderStandard)
        .atomElevation(theme, role, radius: radius, shadow())
        .padding(.horizontal, outerX)
        .padding(.vertical, outerY)
        if action.isEmpty && hoverEvent.isEmpty {
            content
        } else {
            content
                .contentShape(shape)
                .onTapGesture {
                    if !action.isEmpty { onEvent(action, eventEnvelope(props)) }
                    if !hoverEvent.isEmpty {
                        revealed.toggle()
                        onEvent(hoverEvent, eventEnvelope(props, payload: ["hovered": .bool(revealed)]))
                    }
                }
                .accessibilityAddTraits(.isButton)
                .atomAction(action.isEmpty ? hoverEvent : action, props)
        }
    }

    private func edge(_ key: String, fallback: String) -> CGFloat {
        let token = props.string(key, default: props.string(fallback, default: "none"))
        return AtomKit.space(theme, token)
    }

    private func margin(_ key: String) -> CGFloat {
        let token = props.string(key, default: props.string("margin", default: "none"))
        return token == "auto" ? theme.density.spacing.space0 : AtomKit.space(theme, token)
    }

    private func background() -> Color {
        switch props.string("bg", default: "transparent") {
        case "primary": return theme.color.primary
        case "secondary": return theme.color.secondary
        case "muted": return theme.color.muted
        case "accent": return theme.color.accent
        case "surface": return theme.color.card
        case "overlay": return theme.color.card.opacity(0.8)
        case "inverse": return theme.color.foreground
        case "gradient": return theme.color.surface
        default: return AtomKit.clear(theme)
        }
    }

    private func shadow() -> AlmadarTheme.ElevationScale.Shadow {
        switch props.string("shadow", default: "none") {
        case "sm": return theme.elevation.cardElevation
        case "md": return theme.elevation.popoverElevation
        case "lg", "xl": return theme.elevation.dialogElevation
        default: return AtomKit.noShadow(theme)
        }
    }
}

@ViewBuilder
func BoxRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BoxAtomView(props: props, onEvent: onEvent))
}
