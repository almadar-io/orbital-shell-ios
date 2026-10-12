import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func ActivityRailRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    // ActivityRail.tsx compact form (phones): one labelled row per item; the active item is primary; picking emits UI:{onChange} { id }.
    let items = props.dictValue?["items"]?.arrayValue ?? []
    let active = props.string("active")
    let changeEvent = props.string("onChange")
    AnyView(VStack(alignment: .leading, spacing: 4) {
        ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            let id = item.string("id")
            ButtonRenderer(props: AtomKit.child(props, ["variant": .string(active == id ? "primary" : "ghost"), "leftIcon": .string(item.string("icon")), "label": .string(item.string("label")), "action": .string(changeEvent), "actionPayload": .dict(["id": .string(id)])]), modifier: nil, onEvent: onEvent)
                .accessibilityAddTraits(active == id ? .isSelected : [])
        }
        AtomChildren(props: props, key: "footer", onEvent: onEvent)
    })
}
