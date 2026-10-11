import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct PresenceAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let show = props.bool("show")
        let kind = props.string("animation")
        let animate = props.bool("animate", default: true)
        ZStack {
            if show {
                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
                .transition(animate ? transition(kind) : .identity)
            }
        }
        .animation(animate ? theme.motion.animation(for: show ? theme.motion.enter : theme.motion.exit) : nil, value: show)
    }

    private func transition(_ kind: String) -> AnyTransition {
        switch kind {
        case "slide-up", "toast": return .move(edge: .bottom).combined(with: .opacity)
        case "drawer": return .move(edge: .trailing)
        case "modal", "popover": return .scale.combined(with: .opacity)
        default: return .opacity
        }
    }
}

@ViewBuilder
func PresenceRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PresenceAtomView(props: props, onEvent: onEvent))
}
