import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct IconAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var animating = false

    var body: some View {
        let rawName = props.string("icon", default: props.string("name"))
        let dimension = AtomKit.iconSize(theme, props.string("size", default: "md"))
        let animation = props.string("animation", default: "none")
        let label = props.string("aria-label")
        let tint = props.string("color")
        Image(systemName: IconMap.resolve(rawName))
            .resizable()
            .scaledToFit()
            .frame(width: dimension, height: dimension)
            .foregroundColor(tint.isEmpty ? theme.color.foreground : AtomKit.tone(theme, tint))
            .rotationEffect(.degrees(animation == "spin" && animating ? 360 : 0))
            .opacity(animation == "pulse" && animating ? 0.4 : 1)
            .onAppear {
                if animation == "spin" {
                    withAnimation(.linear(duration: theme.motion.durations.dramatic * 2).repeatForever(autoreverses: false)) { animating = true }
                } else if animation == "pulse" {
                    withAnimation(.easeInOut(duration: theme.motion.durations.dramatic).repeatForever(autoreverses: true)) { animating = true }
                }
            }
            .accessibilityHidden(label.isEmpty)
            .accessibilityLabel(Text(label))
    }
}

@ViewBuilder
func IconRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(IconAtomView(props: props, onEvent: onEvent))
}
