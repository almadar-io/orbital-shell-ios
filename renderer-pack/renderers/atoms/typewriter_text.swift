import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TypewriterTextAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 0

    var body: some View {
        let full = props.string("text")
        let shown = reduceMotion ? full : String(full.prefix(count))
        Text(shown)
            .font(AtomKit.font(theme, "base"))
            .foregroundColor(theme.color.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Text(full))
            .task(id: full) {
                count = 0
                let delay = UInt64(max(props.float("startDelay"), 0) * 1_000_000)
                let step = UInt64(max(props.float("speed", default: 40), 1) * 1_000_000)
                try? await Task.sleep(nanoseconds: delay)
                while count < full.count && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: step)
                    count += 1
                }
            }
    }
}

@ViewBuilder
func TypewriterTextRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TypewriterTextAtomView(props: props, onEvent: onEvent))
}
