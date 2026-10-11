import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ActivationBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var response: String
    @State private var expanded: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _response = State(initialValue: props.string("savedResponse"))
        _expanded = State(initialValue: props.string("savedResponse").isEmpty)
    }

    private var saveEvent: String { props.string("saveEvent", default: "SAVE_ACTIVATION") }

    private func save(_ text: String) {
        onEvent(saveEvent, eventEnvelope(props, payload: ["response": .string(text)]))
        expanded = false
    }

    var body: some View {
        let shape = AtomKit.shape(theme, .container)
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            AtomKit.icon("lightbulb", "lg", color: "primary", onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomKit.typo("Before You Begin...", "h4", color: "primary", onEvent: onEvent)
                AtomKit.typo(props.string("question"), "body1", color: "primary", onEvent: onEvent)
                if expanded {
                    TextareaRenderer(
                        props: AtomKit.child(props, [
                            "value": .string(response),
                            "placeholder": "Jot down your thoughts...",
                            "rows": .int(3),
                            "onChange": .string(AtomKit.localEvent),
                            "local": true,
                        ]),
                        modifier: nil,
                        onEvent: { _, envelope in
                            response = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? response
                        }
                    )
                    HStack(spacing: theme.density.spacing.space2) {
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "primary", "size": "sm", "label": "Continue to Lesson →", "action": .string(saveEvent)]),
                            modifier: nil,
                            onEvent: { _, _ in save(response) }
                        )
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "label": "Skip for now", "action": .string(saveEvent)]),
                            modifier: nil,
                            onEvent: { _, _ in save("") }
                        )
                    }
                } else {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "label": "✓ Answered · Edit response", "action": .string(AtomKit.localEvent), "local": true]),
                        modifier: nil,
                        onEvent: { _, _ in expanded = true }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.density.spacing.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.primary.opacity(0.1))
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.primary, lineWidth: theme.geometry.borderHeavy))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ActivationBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ActivationBlockMoleculeView(props: props, onEvent: onEvent))
}
