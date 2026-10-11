import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct FlipContainerAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let flipped = props.bool("flipped")
        let action = props.string("onClick")
        let faces = AtomKit.nodes(props, "children")
        ZStack {
            ForEach(faces.indices, id: \.self) { index in
                let isFront = index == 0
                let visible = flipped ? !isFront : isFront
                RenderChild(faces[index], onEvent: onEvent)
                    .opacity(visible ? 1 : 0)
                    .rotation3DEffect(.degrees(flipped == isFront ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    .allowsHitTesting(visible)
            }
        }
        .animation(reduceMotion ? nil : theme.motion.animation(for: theme.motion.expand), value: flipped)
        .contentShape(Rectangle())
        .onTapGesture { if !action.isEmpty { onEvent(action, eventEnvelope(props)) } }
        .accessibilityAddTraits(action.isEmpty ? [] : .isButton)
        .atomAction(action, props)
    }
}

@ViewBuilder
func FlipContainerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FlipContainerAtomView(props: props, onEvent: onEvent))
}
