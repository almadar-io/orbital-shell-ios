import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GridMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var columns: Int {
        guard let raw = props.dictValue?["cols"] else { return 1 }
        if let text = raw.stringValue { return text == "none" ? 1 : (Int(text) ?? 1) }
        if let number = raw.intValue { return max(number, 1) }
        let base = raw.dictValue?["base"] ?? raw.dictValue?["sm"] ?? raw.dictValue?["md"]
        return max(base?.intValue ?? 1, 1)
    }

    var body: some View {
        let gap = props.string("gap", default: "md")
        let spacing = AtomKit.space(theme, props.string("colGap", default: gap))
        AtomGridLayout(minWidth: theme.density.spacing.space4, maxColumns: 0, fixedColumns: columns, spacing: spacing) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .padding(.vertical, AtomKit.space(theme, props.string("rowGap", default: gap)) - spacing)
        .frame(maxWidth: .infinity)
    }
}

@ViewBuilder
func GridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GridMoleculeView(props: props, onEvent: onEvent))
}
