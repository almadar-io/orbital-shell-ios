import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct DrawerSlotOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    private let closeKey = "CLOSE"
    private let cancelKey = "CANCEL"

    var body: some View {
        let children = props.children()
        if let first = children.first {
            DrawerRenderer(
                props: AtomKit.child(props, [
                    "isOpen": true,
                    "title": .string(props.string("title", default: first.string("title"))),
                    "position": .string(props.string("position", default: "right")),
                    "width": .string(props.string("size", default: "md")),
                    "children": .array(children),
                    "closeEvent": .string(closeKey),
                ]),
                modifier: nil,
                onEvent: { name, envelope in
                    if name == closeKey {
                        onEvent(closeKey, eventEnvelope(props))
                        onEvent(cancelKey, eventEnvelope(props))
                    } else {
                        onEvent(name, eventEnvelope(envelope ?? .dict([:])))
                    }
                }
            )
        }
    }
}

@ViewBuilder
func DrawerSlotRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DrawerSlotOrganismView(props: props, onEvent: onEvent))
}
