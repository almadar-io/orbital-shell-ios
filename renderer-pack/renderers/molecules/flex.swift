import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func FlexRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let direction = props.string("direction", default: "row")
    AnyView(StackRenderer(
        props: AtomKit.child(props, [
            "direction": .string(direction.hasPrefix("col") ? "vertical" : "horizontal"),
            "reverse": .bool(direction.hasSuffix("reverse")),
            "wrap": .bool(props.string("wrap", default: "nowrap") != "nowrap"),
            "align": .string(props.string("align", default: "stretch")),
            "justify": .string(props.string("justify", default: "start")),
            "gap": .string(props.string("gap", default: "none")),
            "flex": .bool(props.bool("grow") || props.float("grow") > 0),
            "children": .array(props.children()),
        ]),
        modifier: nil,
        onEvent: onEvent
    ))
}
