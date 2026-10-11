import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FormLayoutMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let children = AtomKit.nodes(props, "children")
        let dividers = props.bool("dividers", default: true)
        VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
            ForEach(children.indices, id: \.self) { index in
                if index > 0 && dividers {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                        theme.color.border.frame(height: theme.geometry.borderStandard)
                        RenderChild(children[index], onEvent: onEvent)
                            .padding(.top, theme.density.spacing.space8)
                    }
                } else {
                    RenderChild(children[index], onEvent: onEvent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func FormLayoutRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormLayoutMoleculeView(props: props, onEvent: onEvent))
}
