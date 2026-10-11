import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GradientDividerMoleculeView: View {
    let props: AnyCodable
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let raw = props.string("color")
        let center = raw.isEmpty ? theme.color.primary : AtomKit.cssColor(theme, raw)
        Rectangle()
            .fill(LinearGradient(colors: [AtomKit.clear(theme), center, AtomKit.clear(theme)], startPoint: .leading, endPoint: .trailing))
            .frame(height: theme.geometry.borderStandard)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

@ViewBuilder
func GradientDividerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GradientDividerMoleculeView(props: props))
}
