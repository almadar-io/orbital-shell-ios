import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct UISlotComponentOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    private var fallbackVariant: String {
        switch props.string("slot") {
        case "main": return "table"
        case "sidebar": return "card"
        case "modal", "drawer": return "form"
        default: return "text"
        }
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let children = props.children()
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.child(props, ["spec": props.dictValue?["awaitingSkeleton"] ?? .string(fallbackVariant)]), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Error loading data", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else if !children.isEmpty {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        } else if let fallback = props.dictValue?["fallback"] {
            RenderChild(fallback, onEvent: onEvent)
        }
    }
}

@ViewBuilder
func UiSlotComponentRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(UISlotComponentOrganismView(props: props, onEvent: onEvent))
}
