import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct DialogAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let shape = AtomKit.shape(theme, .container)
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .padding(theme.density.dialogPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.card)
        .clipShape(shape)
        .atomBorder(theme, .container, color: theme.color.border, width: theme.geometry.borderStandard)
        .atomElevation(theme, .container, theme.elevation.dialogElevation)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(Text(props.string("aria-label")))
    }
}

@ViewBuilder
func DialogRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DialogAtomView(props: props, onEvent: onEvent))
}
