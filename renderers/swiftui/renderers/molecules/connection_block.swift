import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ConnectionBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            AtomKit.icon("link-2", "md", color: "success", onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomKit.typo("Building On What You Know", "h6", onEvent: onEvent)
                MarkdownContentRenderer(
                    props: AtomKit.child(props, ["content": .string(props.string("content"))]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.density.spacing.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.success.opacity(0.1))
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.color.success).frame(width: theme.geometry.borderHeavy)
        }
        .clipShape(AtomKit.shape(theme, .container))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ConnectionBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ConnectionBlockMoleculeView(props: props, onEvent: onEvent))
}
