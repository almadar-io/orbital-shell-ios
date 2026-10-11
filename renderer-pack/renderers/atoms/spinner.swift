import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct SpinnerAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let spinner = ProgressView()
            .controlSize(control(props.string("size", default: "md")))
            .tint(theme.color.foreground)
            .accessibilityLabel(Text("Loading"))
        if props.bool("overlay") {
            spinner
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.color.background.opacity(0.6))
        } else {
            spinner
        }
    }

    private func control(_ token: String) -> ControlSize {
        switch token {
        case "xs": return .mini
        case "sm": return .small
        case "lg": return .large
        default: return .regular
        }
    }
}

@ViewBuilder
func SpinnerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SpinnerAtomView(props: props, onEvent: onEvent))
}
