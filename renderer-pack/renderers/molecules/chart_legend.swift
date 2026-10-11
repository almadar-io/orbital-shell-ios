import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ChartLegendMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let gap = AtomKit.space(theme, "md")
        if props.string("direction", default: "horizontal") == "vertical" {
            VStack(alignment: .leading, spacing: gap) { entries(items) }
        } else {
            AtomFlowLayout(spacing: gap) { entries(items) }
        }
    }

    private func entries(_ items: [AnyCodable]) -> some View {
        ForEach(items.indices, id: \.self) { index in
            HStack(spacing: theme.density.spacing.space1) {
                Circle()
                    .fill(AtomKit.cssColor(theme, items[index].string("color")))
                    .frame(width: swatch, height: swatch)
                    .accessibilityHidden(true)
                AtomKit.typo(items[index].string("label"), "small", color: "muted", onEvent: onEvent)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var swatch: CGFloat { theme.density.spacing.space2 + theme.density.spacing.space1 / 2 }
}

@ViewBuilder
func ChartLegendRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ChartLegendMoleculeView(props: props, onEvent: onEvent))
}
