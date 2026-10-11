import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct FilterPillAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let label = AtomKit.text(props, "label").isEmpty ? props.children().compactMap { AtomKit.scalar($0) }.joined() : AtomKit.text(props, "label")
        let icon = props.string("icon")
        let clickEvent = props.string("clickEvent", default: props.string("onClick"))
        let removeEvent = props.string("removeEvent", default: props.string("onRemove"))
        let size = props.string("size", default: "sm")
        let (fill, edge) = palette(props.string("variant", default: "default"))
        let payload: AnyCodable = ["label": .string(label)]
        HStack(spacing: theme.density.spacing.space1) {
            Button(action: { if !clickEvent.isEmpty { onEvent(clickEvent, eventEnvelope(props, payload: payload)) } }) {
                HStack(spacing: theme.density.spacing.space1) {
                    if !icon.isEmpty { Image(systemName: IconMap.resolve(icon)) }
                    Text(label)
                }
            }
            .buttonStyle(.plain)
            .disabled(clickEvent.isEmpty)
            .atomAction(clickEvent, props)
            if props.bool("removable", default: true) && !removeEvent.isEmpty {
                Button(action: { onEvent(removeEvent, eventEnvelope(props, payload: payload)) }) {
                    Image(systemName: IconMap.resolve("x"))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove filter"))
                .atomAction(removeEvent, props)
            }
        }
        .font(AtomKit.font(theme, size == "lg" ? "base" : (size == "md" ? "sm" : "xs"), .bold))
        .foregroundColor(theme.color.foreground)
        .padding(.horizontal, size == "lg" ? theme.density.spacing.space3 : theme.density.spacing.space2)
        .padding(.vertical, size == "sm" ? theme.density.spacing.space1 / 2 : theme.density.spacing.space1)
        .background(fill)
        .atomClip(theme, .pill)
        .atomBorder(theme, .pill, color: edge, width: theme.geometry.borderHairline)
    }

    private func palette(_ variant: String) -> (Color, Color) {
        switch variant {
        case "primary": return (theme.color.primary.opacity(0.1), theme.color.primary)
        case "secondary": return (theme.color.secondary.opacity(0.1), theme.color.secondary)
        case "success": return (theme.color.success.opacity(0.1), theme.color.success)
        case "warning": return (theme.color.warning.opacity(0.1), theme.color.warning)
        case "danger": return (theme.color.error.opacity(0.1), theme.color.error)
        case "info": return (theme.color.info.opacity(0.1), theme.color.info)
        default: return (theme.color.muted, theme.color.border)
        }
    }
}

@ViewBuilder
func FilterPillRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FilterPillAtomView(props: props, onEvent: onEvent))
}
