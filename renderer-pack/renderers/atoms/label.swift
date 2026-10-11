import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct LabelAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let text = AtomKit.text(props, "text").isEmpty ? props.children().compactMap { AtomKit.scalar($0) }.joined() : AtomKit.text(props, "text")
        HStack(spacing: theme.density.spacing.space1) {
            Text(text)
            if props.bool("required") {
                Text("*").foregroundColor(theme.color.error).accessibilityHidden(true)
            }
        }
        .font(AtomKit.font(theme, "sm", .bold))
        .foregroundColor(theme.color.foreground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(props.bool("required") ? "\(text), required" : text))
    }
}

@ViewBuilder
func LabelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LabelAtomView(props: props, onEvent: onEvent))
}
