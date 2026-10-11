import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ControlButtonAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var held = false

    var body: some View {
        let pressEvent = props.string("pressEvent")
        let releaseEvent = props.string("releaseEvent")
        let disabled = props.bool("disabled")
        let lit = props.dictValue?["pressed"]?.boolValue ?? held
        let side = side(props.string("size", default: "md"))
        let tone = tone(props.string("variant", default: "secondary"))
        let circular = props.string("shape", default: "circle") == "circle"
        let role: AtomRole = circular ? .pill : .container
        let radius = circular ? side / 2 : theme.geometry.radiusInteractive
        let shape = AtomKit.shape(theme, role, radius: radius)
        let icon = props.string("icon")
        let asset = AtomKit.assetURL(props, "assetUrl")
        let label = props.string("label")
        ZStack {
            if !asset.isEmpty {
                AsyncImage(url: URL(string: asset)) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .frame(width: theme.density.spacing.space6, height: theme.density.spacing.space6)
            } else if !icon.isEmpty {
                Image(systemName: IconMap.resolve(icon)).font(AtomKit.font(theme, "xl", .bold))
            } else if !label.isEmpty {
                Text(label).font(AtomKit.font(theme, "base", .bold))
            }
        }
        .foregroundColor(tone.foreground)
        .frame(width: side, height: side)
        .background(tone.background)
        .clipShape(shape)
        .atomBorder(theme, role, radius: radius, color: lit ? theme.color.foreground : tone.border, width: theme.geometry.borderHeavy)
        .scaleEffect(lit ? 0.95 : 1)
        .opacity(disabled ? 0.5 : 1)
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !disabled, !held else { return }
                    held = true
                    if !pressEvent.isEmpty { onEvent(pressEvent, eventEnvelope(props)) }
                }
                .onEnded { _ in
                    guard !disabled, held else { return }
                    held = false
                    if !releaseEvent.isEmpty { onEvent(releaseEvent, eventEnvelope(props)) }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(props.string("aria-label", default: label.isEmpty ? icon : label)))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if !disabled {
                if !pressEvent.isEmpty { onEvent(pressEvent, eventEnvelope(props)) }
                if !releaseEvent.isEmpty { onEvent(releaseEvent, eventEnvelope(props)) }
            }
        }
        .atomAction(pressEvent.isEmpty ? releaseEvent : pressEvent, props)
    }

    private func tone(_ variant: String) -> AtomTone {
        switch variant {
        case "primary":
            return AtomTone(background: theme.color.primary, foreground: theme.color.primaryForeground, border: theme.color.primary, raised: false)
        case "ghost":
            return AtomTone(background: AtomKit.clear(theme), foreground: theme.color.foreground, border: theme.color.border, raised: false)
        default:
            return AtomTone(background: theme.color.secondary, foreground: theme.color.secondaryForeground, border: theme.color.border, raised: false)
        }
    }

    private func side(_ token: String) -> CGFloat {
        let spacing = theme.density.spacing
        switch token {
        case "sm": return spacing.space10
        case "lg": return spacing.space12 + spacing.space6
        case "xl": return spacing.space12 * 2
        default: return spacing.space12 + spacing.space2
        }
    }
}

@ViewBuilder
func ControlButtonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ControlButtonAtomView(props: props, onEvent: onEvent))
}
