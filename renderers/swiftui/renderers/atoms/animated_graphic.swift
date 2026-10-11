import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AnimatedGraphicAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let src = AtomKit.assetURL(props, "src")
        let alt = props.string("alt")
        let width = props.dictValue?["width"]?.doubleValue.map { CGFloat($0) } ?? theme.density.spacing.space12 * 2
        let height = props.dictValue?["height"]?.doubleValue.map { CGFloat($0) } ?? theme.density.spacing.space12 * 2
        let animation = props.string("animation", default: "draw")
        let active = shown || reduceMotion || (props.dictValue?["animate"]?.boolValue ?? false)
        Group {
            if !src.isEmpty {
                AsyncImage(url: URL(string: src)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        placeholder(alt)
                    } else {
                        ProgressView().tint(theme.color.mutedForeground)
                    }
                }
            } else {
                placeholder(alt)
            }
        }
        .frame(width: width, height: height)
        .opacity(active || animation == "pulse" ? 1 : 0)
        .scaleEffect(animation == "pulse" && shown ? 1.05 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: props.float("duration", default: 1200) / 1000).delay(props.float("delay") / 1000), value: active)
        .animation(reduceMotion || animation != "pulse" ? nil : .easeInOut(duration: props.float("duration", default: 1200) / 1000).repeatForever(autoreverses: true), value: shown)
        .onAppear { shown = true }
        .accessibilityLabel(Text(alt))
        .accessibilityHidden(alt.isEmpty)
    }

    private func placeholder(_ alt: String) -> some View {
        AtomKit.shape(theme, .container, radius: theme.geometry.radiusInteractive)
            .fill(theme.color.muted)
            .overlay(Text(alt).font(AtomKit.font(theme, "xs")).foregroundColor(theme.color.mutedForeground))
    }
}

@ViewBuilder
func AnimatedGraphicRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AnimatedGraphicAtomView(props: props, onEvent: onEvent))
}
