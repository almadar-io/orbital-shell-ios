import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct AtomSplitLayout: Layout {
    let horizontal: Bool
    let ratio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: horizontal ? nil : proposal.width, height: horizontal ? proposal.height : nil)) }
        if horizontal { return CGSize(width: proposal.width ?? sizes.reduce(0) { $0 + $1.width }, height: sizes.map { $0.height }.max() ?? 0) }
        return CGSize(width: proposal.width ?? sizes.map { $0.width }.max() ?? 0, height: sizes.reduce(0) { $0 + $1.height })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let handle = subviews[1].sizeThatFits(.unspecified)
        let extent = horizontal ? bounds.width : bounds.height
        let thickness = horizontal ? handle.width : handle.height
        let first = max((extent - thickness) * ratio, 0)
        let second = max(extent - thickness - first, 0)
        if horizontal {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: ProposedViewSize(width: first, height: bounds.height))
            subviews[1].place(at: CGPoint(x: bounds.minX + first, y: bounds.minY), proposal: ProposedViewSize(width: thickness, height: bounds.height))
            subviews[2].place(at: CGPoint(x: bounds.minX + first + thickness, y: bounds.minY), proposal: ProposedViewSize(width: second, height: bounds.height))
        } else {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), proposal: ProposedViewSize(width: bounds.width, height: first))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + first), proposal: ProposedViewSize(width: bounds.width, height: thickness))
            subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.minY + first + thickness), proposal: ProposedViewSize(width: bounds.width, height: second))
        }
    }
}

struct SplitPaneOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var share: Double
    @State private var extent: CGFloat = 0
    @State private var origin: Double?

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _share = State(initialValue: props.float("ratio", default: 50))
    }

    private var horizontal: Bool { props.string("direction", default: "horizontal") != "vertical" }

    private func bounded(_ value: Double) -> Double {
        guard extent > 0 else { return min(max(value, 0), 100) }
        let floor = Double(props.float("minSize", default: 100)) / Double(extent) * 100
        return min(max(value, floor), 100 - floor)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard extent > 0 else { return }
                let start = origin ?? share
                origin = start
                let travel = horizontal ? value.translation.width : value.translation.height
                share = bounded(start + Double(travel / extent) * 100)
            }
            .onEnded { _ in origin = nil }
    }

    var body: some View {
        let grip = theme.geometry.borderHeavy * 2
        AtomSplitLayout(horizontal: horizontal, ratio: CGFloat(bounded(share) / 100)) {
            AtomSlot(props.dictValue?["left"], onEvent: onEvent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            Rectangle()
                .fill(theme.color.border)
                .frame(width: horizontal ? grip : nil, height: horizontal ? nil : grip)
                .padding(props.bool("resizable", default: true) ? theme.density.spacing.space1 : theme.density.spacing.space0)
                .contentShape(Rectangle())
                .gesture(props.bool("resizable", default: true) ? drag : nil)
                .accessibilityHidden(true)
            AtomSlot(props.dictValue?["right"], onEvent: onEvent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
        .background(GeometryReader { proxy in
            AtomKit.clear(theme)
                .onAppear { extent = horizontal ? proxy.size.width : proxy.size.height }
                .onChange(of: horizontal ? proxy.size.width : proxy.size.height) { next in extent = next }
        })
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func SplitPaneRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SplitPaneOrganismView(props: props, onEvent: onEvent))
}
