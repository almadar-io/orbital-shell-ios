import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func FeatureGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let items = props.dictValue?["items"]?.arrayValue ?? []
    AnyView(SimpleGridRenderer(
        props: AtomKit.child(props, [
            "cols": .int(props.int("columns", default: 3)),
            "gap": .string(props.string("gap", default: "md")),
            "children": .array(items.map { (item: AnyCodable) -> AnyCodable in
                var node = item.dictValue ?? [:]
                node["type"] = "feature-card"
                return AtomKit.child(props, node)
            }),
        ]),
        modifier: nil,
        onEvent: onEvent
    ))
}
