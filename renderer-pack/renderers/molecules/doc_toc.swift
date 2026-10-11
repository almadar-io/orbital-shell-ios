import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocTocMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let active = props.string("activeId")
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let isActive = item.string("id") == active
                ButtonRenderer(
                    props: AtomKit.linkProps(props, .dict(["href": .string("#" + item.string("id"))]), [
                        "variant": "ghost",
                        "size": "sm",
                        "label": .string(item.string("label")),
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, item.int("level") >= 3 ? theme.density.spacing.space4 : theme.density.spacing.space0)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(isActive ? theme.color.accent : AtomKit.clear(theme))
                        .frame(width: theme.geometry.borderHeavy * 2)
                }
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func DocTocRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocTocMoleculeView(props: props, onEvent: onEvent))
}
