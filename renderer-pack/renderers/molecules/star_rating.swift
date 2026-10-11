import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct StarRatingMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let maxStars = max(props.int("max", default: 5), 1)
        let value = props.float("value", default: 0)
        let readOnly = props.bool("readOnly")
        let half = props.string("precision", default: "full") == "half"
        let side: CGFloat = props.string("size", default: "md") == "sm" ? theme.density.spacing.space4 : (props.string("size", default: "md") == "lg" ? theme.density.spacing.space8 : theme.density.spacing.space6)
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(0..<maxStars, id: \.self) { index in
                let fill = max(0, min(1, value - Double(index)))
                ZStack(alignment: .leading) {
                    AtomStarShape().stroke(theme.color.foreground.opacity(0.3), lineWidth: theme.geometry.borderStandard)
                    AtomStarShape().fill(theme.color.warning).mask(alignment: .leading) { Rectangle().frame(width: side * fill) }
                }
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .onTapGesture { if !readOnly { pick(half ? (value == Double(index) + 1 ? Double(index) + 0.5 : Double(index) + 1) : Double(index) + 1) } }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(props.string("aria-label", default: props.string("label", default: "Rating")))
        .accessibilityValue("\(value) of \(maxStars)")
        .accessibilityAddTraits(readOnly ? .isImage : .isButton)
        .accessibilityAdjustableAction { direction in
            guard !readOnly else { return }
            let step = half ? 0.5 : 1
            pick(direction == .increment ? min(Double(maxStars), value + step) : max(0, value - step))
        }
        .atomAction(readOnly ? "" : props.string("action"), props)
    }

    private func pick(_ next: Double) {
        let event = props.string("action")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["value": .double(next)])) }
    }
}

@ViewBuilder
func StarRatingRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StarRatingMoleculeView(props: props, onEvent: onEvent))
}
