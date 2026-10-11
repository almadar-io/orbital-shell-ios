import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FlipCardMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        FlipContainerRenderer(
            props: AtomKit.child(props, [
                "flipped": .bool(props.bool("flipped")),
                "onClick": .string(props.string("onFlip")),
                "children": .array([face("front"), face("back")]),
            ]),
            modifier: nil,
            onEvent: onEvent
        )
        .frame(height: AtomKit.tailwindSize(props.string("height", default: "h-64")))
    }

    private func face(_ key: String) -> AnyCodable {
        let content = props.dictValue?[key] ?? .null
        return .dict([
            "type": "box",
            "padding": "lg",
            "rounded": "lg",
            "shadow": "lg",
            "fullWidth": true,
            "fullHeight": true,
            "children": .array([.dict(["type": "center", "fullWidth": true, "fullHeight": true, "children": .array([content])])]),
        ])
    }
}

@ViewBuilder
func FlipCardRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FlipCardMoleculeView(props: props, onEvent: onEvent))
}
