import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct OverlayAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let action = props.string("action")
        ZStack {
            if props.bool("isVisible", default: true) {
                Group {
                    if props.bool("blur") {
                        Rectangle().fill(.ultraThinMaterial).overlay(theme.color.scrim)
                    } else {
                        theme.color.scrim
                    }
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if !action.isEmpty { onEvent(action, eventEnvelope(props)) } }
                .accessibilityHidden(action.isEmpty)
                .accessibilityAddTraits(action.isEmpty ? [] : .isButton)
                .accessibilityLabel(Text("Dismiss"))
                .atomAction(action, props)
                .transition(.opacity)
            }
        }
        .animation(theme.motion.animation(for: theme.motion.enter), value: props.bool("isVisible", default: true))
    }
}

@ViewBuilder
func OverlayRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(OverlayAtomView(props: props, onEvent: onEvent))
}
