import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AtomFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in placed.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0 && cursor.x + size.width > width {
                cursor = CGPoint(x: 0, y: cursor.y + rowHeight + spacing)
                rowHeight = 0
            }
            origins.append(cursor)
            cursor.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, cursor.x - spacing)
        }
        return (CGSize(width: widest, height: cursor.y + rowHeight), origins)
    }
}

struct StackAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let horizontal = props.string("direction", default: "vertical") == "horizontal"
        let gap = AtomKit.space(theme, props.string("gap", default: "md"))
        let align = props.string("align", default: "stretch")
        let justify = props.string("justify", default: "start")
        let action = props.string("action")
        let children = props.bool("reverse") ? Array(props.children().reversed()) : props.children()
        let grow = props.bool("flex")
        let stack = Group {
            if props.bool("wrap") && horizontal {
                AtomFlowLayout(spacing: gap) { rows(children, horizontal: horizontal, align: align, distribute: true) }
            } else if horizontal {
                HStack(alignment: crossVertical(align), spacing: gap) {
                    lead(justify)
                    rows(children, horizontal: true, align: align, distribute: true)
                    trail(justify)
                }
            } else {
                VStack(alignment: crossHorizontal(align), spacing: gap) {
                    if grow { lead(justify) }
                    rows(children, horizontal: false, align: align, distribute: grow)
                    if grow { trail(justify) }
                }
            }
        }
        .frame(maxWidth: grow ? .infinity : nil, maxHeight: grow ? .infinity : nil)
        if action.isEmpty {
            stack
        } else {
            stack
                .contentShape(Rectangle())
                .onTapGesture { onEvent(action, eventEnvelope(props)) }
                .accessibilityAddTraits(.isButton)
                .atomAction(action, props)
        }
    }

    @ViewBuilder
    private func rows(_ children: [AnyCodable], horizontal: Bool, align: String, distribute: Bool) -> some View {
        let justify = props.string("justify", default: "start")
        ForEach(children.indices, id: \.self) { index in
            if distribute && index > 0 && (justify == "between" || justify == "around" || justify == "evenly") { Spacer(minLength: theme.density.spacing.space0) }
            RenderChild(children[index], onEvent: onEvent)
                .frame(maxWidth: !horizontal && align == "stretch" ? .infinity : nil, maxHeight: horizontal && align == "stretch" ? .infinity : nil, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func lead(_ justify: String) -> some View {
        if justify == "center" || justify == "end" || justify == "around" || justify == "evenly" { Spacer(minLength: theme.density.spacing.space0) }
    }

    @ViewBuilder
    private func trail(_ justify: String) -> some View {
        if justify == "center" || justify == "start" || justify == "around" || justify == "evenly" { Spacer(minLength: theme.density.spacing.space0) }
    }

    private func crossHorizontal(_ token: String) -> HorizontalAlignment {
        switch token {
        case "center": return .center
        case "end": return .trailing
        default: return .leading
        }
    }

    private func crossVertical(_ token: String) -> VerticalAlignment {
        switch token {
        case "center": return .center
        case "end": return .bottom
        case "baseline": return .firstTextBaseline
        default: return .top
        }
    }
}

@ViewBuilder
func StackRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StackAtomView(props: props, onEvent: onEvent))
}
