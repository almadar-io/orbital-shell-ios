import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FormFieldMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        StackRenderer(
            props: AtomKit.child(props, [
                "direction": "vertical",
                "gap": "xs",
                "align": "stretch",
                "children": .array(nodes),
            ]),
            modifier: nil,
            onEvent: onEvent
        )
    }

    private var nodes: [AnyCodable] {
        let error = props.string("error")
        let hint = props.string("hint")
        var all: [AnyCodable] = [AtomKit.node("label", ["text": .string(props.string("label")), "required": .bool(props.bool("required"))])]
        all.append(contentsOf: props.children())
        if !error.isEmpty {
            all.append(AtomKit.node("typography", ["variant": "caption", "color": "error", "content": .string(error)]))
        } else if !hint.isEmpty {
            all.append(AtomKit.node("typography", ["variant": "caption", "color": "muted", "content": .string(hint)]))
        }
        return all
    }
}

@ViewBuilder
func FormFieldRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormFieldMoleculeView(props: props, onEvent: onEvent))
}
