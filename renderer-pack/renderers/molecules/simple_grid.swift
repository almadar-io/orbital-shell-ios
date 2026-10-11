import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SimpleGridMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let children = props.children()
        let fixed = props.int("cols")
        let minimum = AtomKit.length(props.string("minChildWidth", default: "250")) ?? 250
        AtomGridLayout(
            minWidth: fixed > 0 ? 140 : minimum,
            maxColumns: props.int("maxCols"),
            fixedColumns: fixed,
            spacing: AtomKit.space(theme, props.string("gap", default: "md"))
        ) {
            ForEach(children.indices, id: \.self) { index in
                RenderChild(children[index], onEvent: onEvent)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

@ViewBuilder
func SimpleGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SimpleGridMoleculeView(props: props, onEvent: onEvent))
}
