import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SwipeableRowMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var offset: CGFloat = 0

    private var itemData: AnyCodable? { props.dictValue?["itemData"] }
    private func list(_ key: String) -> [AnyCodable] { (props.dictValue?[key]?.arrayValue ?? []).filter { AtomKit.actionable($0) } }

    private func fire(_ action: AnyCodable) {
        let routed = AtomKit.route(action, row: itemData)
        guard !routed.event.isEmpty else { return }
        onEvent(routed.event, eventEnvelope(props, payload: routed.payload))
    }

    var body: some View {
        let left = list("leftActions")
        let right = list("rightActions")
        let threshold = CGFloat(props.float("threshold", default: 80))
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: theme.density.spacing.space4)
                    .onChanged { value in
                        let travel = value.translation.width
                        if (travel > 0 && !left.isEmpty) || (travel < 0 && !right.isEmpty) { offset = min(max(travel, -threshold), threshold) }
                    }
                    .onEnded { value in
                        let travel = value.translation.width
                        if travel >= threshold, let action = left.first { fire(action) }
                        if travel <= -threshold, let action = right.first { fire(action) }
                        withAnimation(theme.motion.animation(for: theme.motion.transition)) { offset = 0 }
                    }
            )
            if !left.isEmpty || !right.isEmpty {
                AtomRowActions(owner: props, row: itemData, inline: left + right, menu: [], onEvent: onEvent)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func SwipeableRowRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SwipeableRowMoleculeView(props: props, onEvent: onEvent))
}
