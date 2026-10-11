import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct IconButtonMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        var values: [String: AnyCodable] = [
            "variant": .string(props.string("variant", default: "ghost")),
            "size": .string(props.string("size", default: "sm")),
            "icon": .string(props.string("icon")),
            "aria-label": .string(props.string("label")),
            "disabled": .bool(props.bool("disabled")),
            "isLoading": .bool(props.bool("isLoading")),
            "action": .string(props.string("action")),
        ]
        if !props.string("href").isEmpty { values["href"] = .string(props.string("href")) }
        if let payload = props.dictValue?["actionPayload"] { values["actionPayload"] = payload }
        return ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: onEvent)
            .accessibilityLabel(props.string("label"))
    }
}

@ViewBuilder
func IconButtonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(IconButtonMoleculeView(props: props, onEvent: onEvent))
}
