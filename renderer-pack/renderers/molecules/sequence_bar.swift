import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SequenceBarMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func named(_ event: String, _ callback: String) -> String {
        let declared = props.string(event)
        return declared.isEmpty ? props.string(callback) : declared
    }

    private func slot(_ index: Int) -> some View {
        let slots = props.dictValue?["slots"]?.arrayValue ?? []
        let item = index < slots.count && slots[index].dictValue != nil ? slots[index] : nil
        let playing = props.bool("playing")
        let feedback = (props.dictValue?["slotFeedback"]?.arrayValue ?? []).indices.contains(index) ? (props.dictValue?["slotFeedback"]?.arrayValue ?? [])[index].stringValue ?? "" : ""
        let dropEvent = named("slotDropEvent", "onSlotDrop")
        let removeEvent = named("slotRemoveEvent", "onSlotRemove")
        var values: [String: AnyCodable] = [
            "slotNumber": .int(index + 1),
            "size": .string(props.string("size", default: "lg")),
            "locked": .bool(playing),
            "selected": .bool(props.int("currentStep", default: -1) == index),
            "draggable": .bool(!playing && item != nil),
            "feedback": .string(feedback),
            "dropEvent": .string(dropEvent),
            "removeEvent": .string(item == nil ? "" : removeEvent),
        ]
        if let item = item { values["equippedItem"] = item }
        if let colors = props.dictValue?["categoryColors"] { values["categoryColors"] = colors }
        return TraitSlotRenderer(
            props: AtomKit.child(props, values),
            modifier: nil,
            onEvent: { name, envelope in
                guard !playing else { return }
                if name == dropEvent {
                    onEvent(name, eventEnvelope(props, payload: ["slotNumber": .int(index), "itemId": .string(envelope?.dictValue?["actionPayload"]?.string("itemId") ?? "")]))
                } else if name == removeEvent {
                    onEvent(name, eventEnvelope(props, payload: ["slotNumber": .int(index)]))
                }
            }
        )
    }

    var body: some View {
        let step = props.int("currentStep", default: -1)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.density.spacing.space2) {
                ForEach(0..<max(props.int("maxSlots"), 0), id: \.self) { index in
                    if index > 0 {
                        AtomKit.typo("\u{2192}", "large", color: step >= 0 && index <= step ? "primary" : "muted", onEvent: onEvent)
                    }
                    slot(index)
                }
            }
            .padding(theme.density.spacing.space2)
        }
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func SequenceBarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SequenceBarMoleculeView(props: props, onEvent: onEvent))
}
