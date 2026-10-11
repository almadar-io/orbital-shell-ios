import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct BadgeAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let variant = props.string("variant", default: "default")
        let size = props.string("size", default: "sm")
        let rawLabel = AtomKit.text(props, "label")
        let amount = AtomKit.scalar(props.dictValue?["amount"])
        let text = amount.map { rawLabel.isEmpty ? $0 : "\(rawLabel) \($0)" } ?? rawLabel
        let icon = props.string("icon")
        let removeEvent = props.string("onRemove")
        let (fill, ink, edge): (Color, Color, Color) = palette(variant)
        let key = size == "lg" ? "base" : (size == "md" ? "sm" : "xs")
        if !text.isEmpty || !icon.isEmpty || !removeEvent.isEmpty {
            HStack(spacing: theme.density.spacing.space1) {
                if !icon.isEmpty { Image(systemName: IconMap.resolve(icon)) }
                if !text.isEmpty { Text(text) }
                if !removeEvent.isEmpty {
                    Button(action: { onEvent(removeEvent, eventEnvelope(props)) }) {
                        Image(systemName: IconMap.resolve("x"))
                    }
                    .accessibilityLabel(Text(props.string("removeLabel", default: text.isEmpty ? "Remove" : "Remove: \(text)")))
                    .atomAction(removeEvent, props)
                }
            }
            .font(AtomKit.font(theme, key, .bold))
            .foregroundColor(ink)
            .padding(.horizontal, size == "lg" ? theme.density.spacing.space3 : theme.density.spacing.space2)
            .padding(.vertical, size == "sm" ? theme.density.spacing.space1 / 2 : theme.density.spacing.space1)
            .background(fill)
            .atomClip(theme, .pill)
            .atomBorder(theme, .pill, color: edge, width: theme.geometry.borderHairline)
            .accessibilityElement(children: removeEvent.isEmpty ? .combine : .contain)
        }
    }

    private func palette(_ variant: String) -> (Color, Color, Color) {
        let none = AtomKit.clear(theme)
        switch variant {
        case "primary": return (theme.color.primary, theme.color.primaryForeground, none)
        case "secondary": return (theme.color.secondary, theme.color.secondaryForeground, none)
        case "success": return (theme.color.success.opacity(0.1), theme.color.foreground, theme.color.success)
        case "warning": return (theme.color.warning.opacity(0.1), theme.color.foreground, theme.color.warning)
        case "danger", "error": return (theme.color.error.opacity(0.1), theme.color.foreground, theme.color.error)
        case "info": return (theme.color.info.opacity(0.1), theme.color.foreground, theme.color.info)
        case "neutral": return (theme.color.muted, theme.color.mutedForeground, theme.color.border)
        default: return (theme.color.muted, theme.color.foreground, theme.color.border)
        }
    }
}

@ViewBuilder
func BadgeRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BadgeAtomView(props: props, onEvent: onEvent))
}
