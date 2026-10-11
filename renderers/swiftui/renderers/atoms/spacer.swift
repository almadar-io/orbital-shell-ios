import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct SpacerAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let size = props.string("size", default: "auto")
        let length = AtomKit.space(theme, size)
        if size == "auto" {
            Spacer().accessibilityHidden(true)
        } else if props.string("axis", default: "horizontal") == "horizontal" {
            Spacer().frame(width: length).accessibilityHidden(true)
        } else {
            Spacer().frame(height: length).accessibilityHidden(true)
        }
    }
}

@ViewBuilder
func SpacerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SpacerAtomView(props: props, onEvent: onEvent))
}
