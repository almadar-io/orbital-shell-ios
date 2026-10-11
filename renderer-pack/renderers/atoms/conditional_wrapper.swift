import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ConditionalWrapperAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let visible = isVisible()
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            if visible {
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            } else if let fallback = props.dictValue?["fallback"] {
                RenderChild(fallback, onEvent: onEvent)
            }
        }
        .animation(props.bool("animate") ? theme.motion.animation(for: theme.motion.transition) : nil, value: visible)
    }

    private func isVisible() -> Bool {
        guard props.dictValue?["context"] != nil else { return false }
        guard let condition = props.dictValue?["condition"] else { return true }
        return condition.boolValue ?? false
    }
}

@ViewBuilder
func ConditionalWrapperRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ConditionalWrapperAtomView(props: props, onEvent: onEvent))
}
