import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func AvlTransitionDetailRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    // AvlTransitionDetail.tsx on a phone: the from → event → to header, the guard and each effect as text; with stepEvent, a Step button
    // asking the host to play this transition (UI:{stepEvent} { orbital, trait, from, event, payload }). Circuit boards and the payload editor are web-only.
    let transition = props.dictValue?["transition"] ?? .dict([:])
    let orbital = props.string("orbital")
    let trait = props.string("trait")
    let stepEvent = props.string("stepEvent")
    let from = transition.string("from")
    let event = transition.string("event")
    let effects = transition.dictValue?["effects"]?.arrayValue ?? []
    let guardExpr = transition.dictValue?["guard"]
    AnyView(VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
            AtomKit.badge(from, "default", size: "lg", onEvent: onEvent)
            AtomKit.typo(event, "body1", weight: "semibold", onEvent: onEvent)
            AtomKit.typo("→", "h5", color: "muted", onEvent: onEvent)
            AtomKit.badge(transition.string("to"), "default", size: "lg", onEvent: onEvent)
        }
        if !stepEvent.isEmpty {
            ButtonRenderer(props: AtomKit.child(props, ["label": "Step", "variant": "primary", "size": "sm", "leftIcon": "skip-forward", "action": .string(stepEvent), "actionPayload": .dict(["orbital": .string(orbital), "trait": .string(trait), "from": .string(from), "event": .string(event), "payload": .dict([:])])]), modifier: nil, onEvent: onEvent)
        }
        if let guardExpr, guardExpr != .null {
            AtomKit.typo("Guard", "overline", color: "muted", onEvent: onEvent)
            AtomKit.typo(AtomKit.sexpr(guardExpr), "caption", onEvent: onEvent)
        }
        if !effects.isEmpty { AtomKit.typo("Effects (\(effects.count))", "overline", color: "muted", onEvent: onEvent) }
        ForEach(effects.indices, id: \.self) { index in
            let effect = effects[index]
            HStack(spacing: 6) {
                AtomKit.badge(effect.string("type"), "primary", onEvent: onEvent)
                AtomKit.typo(AtomKit.sexpr(effect.dictValue?["args"] ?? .array([])), "caption", color: "muted", onEvent: onEvent)
            }
        }
    })
}
