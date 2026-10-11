import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct UISlotRendererOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "text"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Error loading data", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
    }
}

@ViewBuilder
func UiSlotRendererRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(UISlotRendererOrganismView(props: props, onEvent: onEvent))
}
