import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ReflectionBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var note: String
    @State private var expanded = false

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _note = State(initialValue: props.string("savedNote"))
    }

    private var saveEvent: String { props.string("saveEvent", default: "SAVE_REFLECTION") }

    private func save() {
        onEvent(saveEvent, eventEnvelope(props, payload: ["index": .int(props.int("index")), "note": .string(note)]))
        expanded = false
    }

    var body: some View {
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            AtomKit.icon("pause-circle", "md", color: "warning", onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomKit.typo("Pause & Reflect", "body1", color: "warning", weight: "medium", onEvent: onEvent)
                AtomKit.typo(props.string("prompt"), "body2", onEvent: onEvent)
                if expanded {
                    TextareaRenderer(
                        props: AtomKit.child(props, [
                            "value": .string(note),
                            "placeholder": "Your thoughts...",
                            "rows": .int(2),
                            "onChange": .string(AtomKit.localEvent),
                            "local": true,
                        ]),
                        modifier: nil,
                        onEvent: { _, envelope in
                            note = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? note
                        }
                    )
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "label": "Save & Continue", "action": .string(saveEvent)]),
                        modifier: nil,
                        onEvent: { _, _ in save() }
                    )
                } else {
                    ButtonRenderer(
                        props: AtomKit.child(props, [
                            "variant": "ghost",
                            "size": "sm",
                            "label": .string(props.string("savedNote").isEmpty ? "Answer this question" : "✓ Answered · Edit"),
                            "action": .string(AtomKit.localEvent),
                            "local": true,
                        ]),
                        modifier: nil,
                        onEvent: { _, _ in expanded = true }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.density.spacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.warning.opacity(0.1))
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.color.warning).frame(width: theme.geometry.borderHeavy)
        }
        .clipShape(AtomKit.shape(theme, .container))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ReflectionBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ReflectionBlockMoleculeView(props: props, onEvent: onEvent))
}
