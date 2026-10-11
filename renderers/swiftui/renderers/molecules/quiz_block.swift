import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct QuizBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                AtomKit.icon("help-circle", "sm", color: "primary", onEvent: onEvent)
                AtomKit.typo(props.string("question"), "body1", weight: "medium", onEvent: onEvent)
            }
            if revealed {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                AtomKit.typo(props.string("answer"), "body1", onEvent: onEvent)
                    .padding(.leading, theme.density.spacing.space6)
            }
            ButtonRenderer(
                props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "label": .string(revealed ? "Hide answer" : "Show answer"), "rightIcon": .string(revealed ? "chevron-up" : "chevron-down"), "action": .string(AtomKit.localEvent), "local": true]),
                modifier: nil,
                onEvent: { _, _ in revealed.toggle() }
            )
            .padding(.leading, theme.density.spacing.space6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func QuizBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(QuizBlockMoleculeView(props: props, onEvent: onEvent))
}
