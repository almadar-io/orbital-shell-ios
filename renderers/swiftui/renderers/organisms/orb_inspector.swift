import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

@ViewBuilder
func OrbInspectorRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let node = props.dictValue?["node"] ?? .dict([:])
    let program = props.dictValue?["schema"]?.string("name") ?? ""
    let closeEvent = props.string("onClose")
    AnyView(VStack(alignment: .leading, spacing: 4) {
        HStack {
            AtomKit.typo(node.string("orbitalName", default: "Nothing selected"), "body1", weight: "semibold", onEvent: onEvent)
            Spacer(minLength: 0)
            if !closeEvent.isEmpty { ButtonRenderer(props: AtomKit.child(props, ["label": "Close", "variant": "ghost", "size": "sm", "action": .string(closeEvent)]), modifier: nil, onEvent: onEvent) }
        }
        AtomKit.typo(program, "caption", color: "muted", onEvent: onEvent)
        ForEach([("Trait", "traitName"), ("State", "stateName"), ("Event", "transitionEvent")], id: \.1) { row in
            if !node.string(row.1).isEmpty { AtomKit.typo("\(row.0): \(node.string(row.1))", "caption", onEvent: onEvent) }
        }
    })
}
