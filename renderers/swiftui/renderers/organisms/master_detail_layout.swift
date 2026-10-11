import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct MasterDetailLayoutOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let selected = props.bool("hasSelection")
        let width = AtomKit.length(props.string("masterWidth", default: "350px")) ?? 350
        if sizeClass == .compact {
            if selected { detailPane } else { masterPane }
        } else {
            HStack(alignment: .top, spacing: theme.density.spacing.space0) {
                masterPane
                    .frame(width: width)
                    .overlay(alignment: .trailing) { Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderHairline) }
                detailPane
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var masterPane: some View {
        ScrollView {
            slot(props.dictValue?["master"])
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if props.bool("hasSelection") {
            ScrollView {
                slot(props.dictValue?["detail"])
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else if let empty = props.dictValue?["emptyDetail"], !AtomKit.blank(empty) {
            slot(empty)
        } else {
            AtomKit.typo("Select an item", "body2", color: "muted", align: "center", onEvent: onEvent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
                        .stroke(theme.color.border, style: StrokeStyle(lineWidth: theme.geometry.borderHeavy, dash: [theme.density.spacing.space2, theme.density.spacing.space1]))
                )
                .padding(theme.density.spacing.space4)
        }
    }

    @ViewBuilder
    private func slot(_ node: AnyCodable?) -> some View {
        if let nodes = node?.arrayValue {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                ForEach(nodes.indices, id: \.self) { index in RenderChild(nodes[index], onEvent: onEvent) }
            }
        } else if let node = node {
            RenderChild(node, onEvent: onEvent)
        }
    }
}

@ViewBuilder
func MasterDetailLayoutRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MasterDetailLayoutOrganismView(props: props, onEvent: onEvent))
}
