import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct AtomSpanKey: LayoutValueKey {
    static let defaultValue: [Int] = [1, 1]
}

struct DashboardGridLayout: Layout {
    let maxColumns: Int
    let spacing: CGFloat

    private func columns(_ width: CGFloat) -> Int {
        if width < AlmadarBreakpoints.sm { return 1 }
        if width < AlmadarBreakpoints.md { return min(maxColumns, 2) }
        if width < AlmadarBreakpoints.lg { return min(maxColumns, 3) }
        return maxColumns
    }

    private func plan(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let count = columns(width)
        let cell = (width - spacing * CGFloat(count - 1)) / CGFloat(count)
        var occupied: [[Bool]] = []
        var spots: [(row: Int, column: Int, span: Int, rows: Int)] = []
        for subview in subviews {
            let want = subview[AtomSpanKey.self]
            let span = max(1, min(want[0], count))
            let rows = max(1, want[1])
            var row = 0
            var placed = false
            while !placed {
                while occupied.count < row + rows { occupied.append([Bool](repeating: false, count: count)) }
                for column in 0...(count - span) {
                    let free = (row..<(row + rows)).allSatisfy { r in (column..<(column + span)).allSatisfy { !occupied[r][$0] } }
                    if free {
                        for r in row..<(row + rows) { for c in column..<(column + span) { occupied[r][c] = true } }
                        spots.append((row: row, column: column, span: span, rows: rows))
                        placed = true
                        break
                    }
                }
                if !placed { row += 1 }
            }
        }
        var heights = [CGFloat](repeating: .zero, count: occupied.count)
        for (index, spot) in spots.enumerated() where spot.rows == 1 {
            let wide = cell * CGFloat(spot.span) + spacing * CGFloat(spot.span - 1)
            heights[spot.row] = max(heights[spot.row], subviews[index].sizeThatFits(ProposedViewSize(width: wide, height: nil)).height)
        }
        for (index, spot) in spots.enumerated() where spot.rows > 1 {
            let wide = cell * CGFloat(spot.span) + spacing * CGFloat(spot.span - 1)
            let need = subviews[index].sizeThatFits(ProposedViewSize(width: wide, height: nil)).height
            let have = heights[spot.row..<(spot.row + spot.rows)].reduce(.zero, +) + spacing * CGFloat(spot.rows - 1)
            if need > have {
                let extra = (need - have) / CGFloat(spot.rows)
                for r in spot.row..<(spot.row + spot.rows) { heights[r] += extra }
            }
        }
        var tops: [CGFloat] = []
        var cursor: CGFloat = .zero
        for height in heights {
            tops.append(cursor)
            cursor += height + spacing
        }
        let frames = spots.map { spot -> CGRect in
            let wide = cell * CGFloat(spot.span) + spacing * CGFloat(spot.span - 1)
            let tall = heights[spot.row..<(spot.row + spot.rows)].reduce(.zero, +) + spacing * CGFloat(spot.rows - 1)
            return CGRect(x: CGFloat(spot.column) * (cell + spacing), y: tops[spot.row], width: wide, height: tall)
        }
        return (frames, max(cursor - spacing, .zero))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? AlmadarSizes.maxWScreenMd
        return CGSize(width: width, height: plan(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = plan(width: bounds.width, subviews: subviews).frames
        for (index, frame) in frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }
}

struct DashboardGridOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let cells = props.dictValue?["cells"]?.arrayValue ?? []
        DashboardGridLayout(maxColumns: min(max(props.int("columns", default: 3), 2), 4), spacing: AtomKit.space(theme, props.string("gap", default: "md"))) {
            ForEach(cells.indices, id: \.self) { index in
                BoxRenderer(
                    props: AtomKit.child(props, [
                        "padding": "md",
                        "border": true,
                        "rounded": "xl",
                        "fullWidth": true,
                        "fullHeight": true,
                        "children": .array(cells[index].dictValue?["content"].map { [$0] } ?? []),
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .layoutValue(key: AtomSpanKey.self, value: [cells[index].int("colSpan", default: 1), cells[index].int("rowSpan", default: 1)])
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func DashboardGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DashboardGridOrganismView(props: props, onEvent: onEvent))
}
