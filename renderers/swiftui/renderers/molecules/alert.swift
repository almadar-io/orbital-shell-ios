import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AlertMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let variant = props.string("variant", default: "info")
        let title = props.string("title")
        let message = AtomKit.text(props, "message")
        let nested = props.children().filter { $0.dictValue != nil }
        let prose = props.children().compactMap { AtomKit.scalar($0) }.joined()
        let dismissEvent = props.string("dismissEvent")
        let tint = AtomKit.tone(theme, variant)
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            AtomKit.icon(props.string("icon", default: glyph(variant)), "md", color: variant, onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !title.isEmpty { AtomKit.typo(title, "h6", onEvent: onEvent) }
                if !nested.isEmpty {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                } else if !prose.isEmpty || !message.isEmpty {
                    AtomKit.typo(prose.isEmpty ? message : prose, "body2", onEvent: onEvent)
                }
                if !AtomKit.nodes(props, "actions").isEmpty {
                    StackRenderer(props: ["direction": "horizontal", "wrap": true, "gap": "sm", "children": props.dictValue?["actions"] ?? .null], modifier: nil, onEvent: onEvent)
                        .padding(.top, theme.density.spacing.space2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dismissEvent.isEmpty {
                ButtonRenderer(props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close alert", "action": .string(dismissEvent)]), modifier: nil, onEvent: onEvent)
            }
        }
        .padding(theme.density.spacing.space3)
        .background(theme.color.surface)
        .clipShape(shape)
        .overlay(shape.stroke(tint, lineWidth: theme.geometry.borderStandard))
        .atomShadow(theme.elevation.cardElevation)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(variant == "error" || variant == "warning" ? .updatesFrequently : [])
    }

    private func glyph(_ variant: String) -> String {
        switch variant {
        case "success": return "check-circle"
        case "warning": return "alert-triangle"
        case "error": return "alert-circle"
        default: return "info"
        }
    }
}

@ViewBuilder
func AlertRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AlertMoleculeView(props: props, onEvent: onEvent))
}
