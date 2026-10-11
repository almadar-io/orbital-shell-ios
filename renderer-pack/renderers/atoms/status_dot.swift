import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct StatusDotAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        let status = props.string("status", default: "offline")
        let tint = AtomKit.statusColor(theme, status)
        let side = side(props.string("size", default: "md"))
        let pulse = props.bool("pulse") && !reduceMotion
        AtomKit.shape(theme, .pill, radius: side / 2)
            .fill(tint)
            .frame(width: side, height: side)
            .overlay(AtomKit.shape(theme, .pill, radius: side / 2).stroke(tint.opacity(pulse && pulsing ? 0 : 0.4), lineWidth: theme.geometry.borderHeavy * 2).scaleEffect(pulse && pulsing ? 1.8 : 1))
            .onAppear {
                if pulse { withAnimation(.easeOut(duration: theme.motion.durations.dramatic * 2).repeatForever(autoreverses: false)) { pulsing = true } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(props.string("label", default: status)))
    }

    private func side(_ token: String) -> CGFloat {
        switch token {
        case "sm": return theme.density.spacing.space2
        case "lg": return theme.density.spacing.space3
        default: return theme.density.spacing.space2 + theme.density.spacing.space1 / 2
        }
    }
}

@ViewBuilder
func StatusDotRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StatusDotAtomView(props: props, onEvent: onEvent))
}
