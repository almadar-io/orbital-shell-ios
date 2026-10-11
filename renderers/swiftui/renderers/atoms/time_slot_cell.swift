import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TimeSlotCellAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let time = props.string("time")
        let action = props.string("onClick")
        let occupied = props.bool("isOccupied")
        let cell = VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, minHeight: theme.density.rowHeightSpacious + theme.density.spacing.space3, alignment: .topLeading)
        .padding(theme.density.spacing.space1)
        .background(occupied ? theme.color.muted.opacity(0.3) : AtomKit.clear(theme))
        .contentShape(Rectangle())
        if action.isEmpty {
            cell.accessibilityElement(children: .contain).accessibilityLabel(Text(props.string("aria-label", default: time)))
        } else {
            Button(action: { onEvent(action, eventEnvelope(props, payload: ["time": .string(time)])) }) { cell }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(props.string("aria-label", default: time)))
                .atomAction(action, props)
        }
    }
}

@ViewBuilder
func TimeSlotCellRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TimeSlotCellAtomView(props: props, onEvent: onEvent))
}
