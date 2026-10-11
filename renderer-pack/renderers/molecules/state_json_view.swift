import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct StateJsonViewMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var expanded: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _expanded = State(initialValue: props.bool("defaultExpanded"))
    }

    private func quoted(_ text: String) -> String {
        (try? JSONEncoder().encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    private func block(_ key: String, _ rows: [String]) -> String {
        rows.isEmpty ? "  \(quoted(key)): []" : "  \(quoted(key)): [\n" + rows.joined(separator: ",\n") + "\n  ]"
    }

    private var json: String {
        let states = (props.dictValue?["states"]?.arrayValue ?? []).map { "    " + quoted($0.stringValue ?? "") }
        let transitions = (props.dictValue?["transitions"]?.arrayValue ?? []).map { transition in
            "    {\n      \"from\": \(quoted(transition.string("from"))),\n      \"to\": \(quoted(transition.string("to"))),\n      \"event\": \(quoted(transition.string("event")))\n    }"
        }
        return "{\n  \"name\": \(quoted(props.string("name"))),\n  \"initialState\": \(quoted(props.string("initialState"))),\n" + block("states", states) + ",\n" + block("transitions", transitions) + "\n}"
    }

    var body: some View {
        let shape = AtomKit.shape(theme, .container)
        VStack(spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.typo(props.string("label", default: "View Code"), "caption", color: "muted", weight: "medium", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space0)
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "label": .string(expanded ? "Hide JSON" : "Show JSON"), "action": .string(AtomKit.localEvent), "local": true]),
                    modifier: nil,
                    onEvent: { _, _ in expanded.toggle() }
                )
            }
            .padding(theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.muted)
            if expanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    AtomMonoText(json, size: "xs")
                        .padding(theme.density.spacing.space3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(theme.color.background)
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func StateJsonViewRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StateJsonViewMoleculeView(props: props, onEvent: onEvent))
}
