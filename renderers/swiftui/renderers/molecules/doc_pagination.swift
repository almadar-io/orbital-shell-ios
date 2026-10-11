import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocPaginationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let prev = props.dictValue?["prev"]
        let next = props.dictValue?["next"]
        if prev != nil || next != nil {
            HStack(alignment: .top, spacing: theme.density.spacing.space4) {
                if let prev = prev { link(prev, icon: "arrow-left", leading: true) } else { Spacer(minLength: theme.density.spacing.space0) }
                if let next = next { link(next, icon: "arrow-right", leading: false) } else { Spacer(minLength: theme.density.spacing.space0) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
        }
    }

    private func link(_ target: AnyCodable, icon: String, leading: Bool) -> some View {
        let label = target.string("label")
        let category = target.string("category")
        return ButtonRenderer(
            props: AtomKit.linkProps(props, target, [
                "variant": "ghost",
                leading ? "leftIcon" : "rightIcon": .string(icon),
                "label": .string(category.isEmpty ? label : category + " · " + label),
            ]),
            modifier: nil,
            onEvent: onEvent
        )
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .padding(theme.density.spacing.space2)
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }
}

@ViewBuilder
func DocPaginationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocPaginationMoleculeView(props: props, onEvent: onEvent))
}
