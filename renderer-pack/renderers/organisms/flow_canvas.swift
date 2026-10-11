import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

@ViewBuilder
func FlowCanvasRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let orbitals = props.dictValue?["schema"]?.dictValue?["orbitals"]?.arrayValue ?? []
    let openEvent = props.string("openBehaviorEvent")
    AnyView(VStack(alignment: .leading, spacing: 8) {
        if orbitals.isEmpty { AtomKit.typo("No program", "caption", color: "muted", onEvent: onEvent) }
        ForEach(orbitals.indices, id: \.self) { index in
            let orbital = orbitals[index]
            let name = orbital.string("name")
            VStack(alignment: .leading, spacing: 2) {
                if openEvent.isEmpty { AtomKit.typo(name, "body1", weight: "semibold", onEvent: onEvent) }
                else { ButtonRenderer(props: AtomKit.child(props, ["label": .string(name), "variant": "ghost", "action": .string(openEvent), "actionPayload": .dict(["name": .string(name)])]), modifier: nil, onEvent: onEvent) }
                AtomKit.typo(orbital.dictValue?["entity"]?.string("name") ?? "", "caption", color: "muted", onEvent: onEvent)
                AtomKit.badge("\((orbital.dictValue?["traits"]?.arrayValue ?? []).count) traits · \((orbital.dictValue?["pages"]?.arrayValue ?? []).count) pages", "default", onEvent: onEvent)
            }
        }
    })
}
