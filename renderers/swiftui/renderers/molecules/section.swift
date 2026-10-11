import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SectionMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let title = props.string("title")
        let description = props.string("description")
        let action = props.dictValue?["action"]
        let variant = props.string("variant", default: "default")
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        let hasHeader = !title.isEmpty || !description.isEmpty || action != nil
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            if hasHeader {
                AtomFlowLayout(spacing: theme.density.spacing.space3) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        if !title.isEmpty { AtomKit.typo(title, "h4", onEvent: onEvent) }
                        if !description.isEmpty { AtomKit.typo(description, "body1", color: "muted", onEvent: onEvent) }
                    }
                    if let action = action { RenderChild(action, onEvent: onEvent) }
                }
            }
            if props.bool("divider") {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(inset(props.string("padding", default: "md")))
        .background(variant == "card" ? theme.color.card : (variant == "filled" ? theme.color.muted : AtomKit.clear(theme)))
        .clipShape(shape)
        .overlay(shape.stroke(variant == "bordered" || variant == "card" ? theme.color.border : AtomKit.clear(theme), lineWidth: theme.geometry.borderStandard))
    }

    private func inset(_ token: String) -> CGFloat {
        switch token {
        case "none": return theme.density.spacing.space0
        case "sm": return theme.density.spacing.space3
        case "lg": return theme.density.spacing.space6
        case "xl": return theme.density.spacing.space8
        default: return theme.density.spacing.space4
        }
    }
}

@ViewBuilder
func SectionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SectionMoleculeView(props: props, onEvent: onEvent))
}
