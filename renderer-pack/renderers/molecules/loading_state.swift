import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct LoadingStateMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let title = props.string("title")
        let message = props.string("message", default: "Loading...")
        let full = props.bool("fullPage")
        VStack(spacing: theme.density.spacing.space3) {
            SpinnerRenderer(props: ["size": "lg"], modifier: nil, onEvent: onEvent)
            if !title.isEmpty { AtomKit.typo(title, "h3", align: "center", onEvent: onEvent) }
            AtomKit.typo(message, "small", color: "muted", align: "center", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, maxHeight: full ? .infinity : nil)
        .padding(.vertical, theme.density.spacing.space12)
        .background(full ? theme.color.background.opacity(0.8) : AtomKit.clear(theme))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

@ViewBuilder
func LoadingStateRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LoadingStateMoleculeView(props: props, onEvent: onEvent))
}
