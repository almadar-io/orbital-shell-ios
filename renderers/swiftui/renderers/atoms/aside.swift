import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AsideAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.density.spacing.space3)
        .background(theme.color.surface)
        .atomClip(theme, .container)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(props.string("aria-label")))
    }
}

@ViewBuilder
func AsideRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AsideAtomView(props: props, onEvent: onEvent))
}
