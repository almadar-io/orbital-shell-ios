import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

@ViewBuilder
func LayersPanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let orbitals = props.dictValue?["schema"]?.dictValue?["orbitals"]?.arrayValue ?? []
    let selected = props.string("selectedId")
    let selectEvent = props.string("onSelect")
    AnyView(VStack(alignment: .leading, spacing: 4) {
        ForEach(orbitals.indices, id: \.self) { index in
            let name = orbitals[index].string("name")
            ButtonRenderer(props: AtomKit.child(props, ["label": .string(name), "variant": .string(selected == name ? "secondary" : "ghost"), "action": .string(selectEvent), "actionPayload": .dict(["id": .string(name)])]), modifier: nil, onEvent: onEvent)
            ForEach((orbitals[index].dictValue?["traits"]?.arrayValue ?? []).indices, id: \.self) { t in
                let trait = (orbitals[index].dictValue?["traits"]?.arrayValue ?? [])[t]
                AtomKit.typo(trait.string("name", default: trait.string("ref")), "caption", color: "muted", onEvent: onEvent)
            }
            ForEach((orbitals[index].dictValue?["pages"]?.arrayValue ?? []).indices, id: \.self) { p in
                AtomKit.typo((orbitals[index].dictValue?["pages"]?.arrayValue ?? [])[p].string("path"), "caption", color: "muted", onEvent: onEvent)
            }
        }
    })
}
