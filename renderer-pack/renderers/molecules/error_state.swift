import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ErrorStateMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let title = props.string("title", default: "Something went wrong")
        let message = props.string("message", default: props.string("description", default: "An error occurred"))
        let retry = props.string("retryEvent")
        VStack(spacing: theme.density.spacing.space2) {
            AtomKit.icon("alert-circle", "lg", color: "error", onEvent: onEvent)
                .padding(theme.density.spacing.space3)
                .background(theme.color.error.opacity(0.1))
                .clipShape(Circle())
            AtomKit.typo(title, "h3", align: "center", onEvent: onEvent)
            AtomKit.typo(message, "small", color: "muted", align: "center", onEvent: onEvent)
            if !retry.isEmpty {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "secondary", "label": "Retry", "action": .string(retry)]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .padding(.top, theme.density.spacing.space2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.density.spacing.space12)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ErrorStateRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ErrorStateMoleculeView(props: props, onEvent: onEvent))
}
