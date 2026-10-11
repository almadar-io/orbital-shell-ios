import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AnimatedRevealAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var emitted = false

    var body: some View {
        let trigger = props.string("trigger", default: "scroll")
        let kind = props.string("animation", default: "fade-up")
        let manual = props.dictValue?["animate"]?.boolValue
        let active = shown || reduceMotion || kind == "none" || (trigger == "manual" && manual == true)
        let distance = theme.density.spacing.space6
        let offset: CGSize = {
            switch kind {
            case "fade-up": return CGSize(width: 0, height: distance)
            case "fade-down": return CGSize(width: 0, height: -distance)
            case "fade-left": return CGSize(width: distance, height: 0)
            case "fade-right": return CGSize(width: -distance, height: 0)
            case "scale-up": return CGSize(width: 0, height: distance / 2)
            default: return .zero
            }
        }()
        let scales = kind == "scale" || kind == "scale-up"
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .opacity(active ? 1 : 0)
        .offset(active ? .zero : offset)
        .scaleEffect(scales && !active ? 0.92 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: props.float("duration", default: 600) / 1000).delay(props.float("delay") / 1000), value: active)
        .onAppear {
            guard trigger == "scroll" else { return }
            if !props.string("enterEvent").isEmpty { onEvent(props.string("enterEvent"), eventEnvelope(props)) }
            if !props.string("revealEvent").isEmpty && !reduceMotion && !emitted {
                emitted = true
                onEvent(props.string("revealEvent"), eventEnvelope(props))
            }
            shown = true
        }
        .onDisappear {
            guard trigger == "scroll" else { return }
            if !props.string("leaveEvent").isEmpty { onEvent(props.string("leaveEvent"), eventEnvelope(props)) }
            if !props.bool("once", default: true) { shown = false }
        }
        .onTapGesture { if trigger == "hover" { shown.toggle() } }
        .atomAction(props.string("revealEvent"), props)
    }
}

@ViewBuilder
func AnimatedRevealRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AnimatedRevealAtomView(props: props, onEvent: onEvent))
}
