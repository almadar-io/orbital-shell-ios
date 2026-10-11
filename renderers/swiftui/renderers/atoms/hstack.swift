import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

@ViewBuilder
func HstackRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StackRenderer(props: props.merging(["direction": "horizontal", "action": .string(props.string("action"))]), modifier: modifier, onEvent: onEvent))
}
