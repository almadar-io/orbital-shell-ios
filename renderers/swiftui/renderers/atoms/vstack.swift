import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

@ViewBuilder
func VstackRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StackRenderer(props: props.merging(["direction": "vertical", "action": .string(props.string("action"))]), modifier: modifier, onEvent: onEvent))
}
