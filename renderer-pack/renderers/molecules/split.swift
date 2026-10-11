import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SplitMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let children = Array(props.children().prefix(2))
        let ordered = props.bool("reverse") ? Array(children.reversed()) : children
        let weights = weights(props.string("ratio", default: "1:1"), reversed: props.bool("reverse"))
        let gap = AtomKit.space(theme, props.string("gap", default: "md"))
        let align = props.string("align", default: "stretch")
        let stack = props.bool("stackOnMobile", default: true) && sizeClass == .compact
        if stack {
            VStack(alignment: .leading, spacing: gap) {
                ForEach(ordered.indices, id: \.self) { index in
                    RenderChild(ordered[index], onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        } else {
            AtomRatioLayout(weights: weights, spacing: gap, alignment: align == "center" ? .center : (align == "end" ? .bottom : .top), stretch: align == "stretch") {
                ForEach(ordered.indices, id: \.self) { index in
                    RenderChild(ordered[index], onEvent: onEvent)
                }
            }
        }
    }

    private func weights(_ ratio: String, reversed: Bool) -> [CGFloat] {
        let parts = ratio.split(separator: ":").compactMap { Double($0) }
        let pair = parts.count == 2 ? parts : [1, 1]
        let both = reversed ? Array(pair.reversed()) : pair
        return both.map { CGFloat($0) }
    }
}

@ViewBuilder
func SplitRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SplitMoleculeView(props: props, onEvent: onEvent))
}
