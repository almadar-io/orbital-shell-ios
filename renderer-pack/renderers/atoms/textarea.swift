import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TextareaAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        AtomTextEntry(props: props, onEvent: onEvent, multiline: true, changeEvent: props.string("onChange"), submitEvent: props.string("action"))
    }
}

@ViewBuilder
func TextareaRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TextareaAtomView(props: props, onEvent: onEvent))
}
