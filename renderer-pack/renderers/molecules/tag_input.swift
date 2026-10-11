import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct TagInputMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var tags: [String]
    @State private var draft = ""

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _tags = State(initialValue: TagInputMoleculeView.incoming(props))
    }

    var body: some View {
        let disabled = props.bool("disabled")
        let helper = props.string("helperText")
        let removeEvent = props.string("removeEvent")
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            if !tags.isEmpty {
                AtomFlowLayout(spacing: theme.density.spacing.space1) {
                    ForEach(tags.indices, id: \.self) { index in
                        BadgeRenderer(
                            props: AtomKit.child(props, [
                                "label": .string(tags[index]),
                                "variant": .string(props.string("variant", default: "default")),
                                "size": "sm",
                                "onRemove": .string(disabled ? "" : AtomKit.eventOrLocal(removeEvent)),
                                "local": .bool(removeEvent.isEmpty),
                                "removeLabel": .string("Remove tag: \(tags[index])"),
                                "actionPayload": removal(index),
                            ]),
                            modifier: nil,
                            onEvent: { _, _ in remove(index) }
                        )
                    }
                }
            }
            InputRenderer(
                props: AtomKit.child(props, [
                    "inputType": "text",
                    "name": .string(props.string("name", default: "tag")),
                    "placeholder": .string(props.string("placeholder", default: "Add a tag")),
                    "disabled": .bool(disabled),
                    "value": .string(draft),
                    "onChange": "tag-draft",
                    "action": "tag-commit",
                ]),
                modifier: nil,
                onEvent: { name, envelope in
                    let typed = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? ""
                    if name == "tag-commit" { commit(typed) } else { draft = typed }
                }
            )
            if !helper.isEmpty { AtomKit.typo(helper, "caption", color: "muted", onEvent: onEvent) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: TagInputMoleculeView.incoming(props)) { tags = $0 }
    }

    private static func incoming(_ props: AnyCodable) -> [String] {
        AtomKit.strings(props, "value")
    }

    private func removal(_ index: Int) -> AnyCodable {
        var next = tags
        next.remove(at: index)
        return ["tag": .string(tags[index]), "index": .int(index), "value": .array(next.map { AnyCodable.string($0) })]
    }

    private func commit(_ typed: String) {
        let tag = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !tag.isEmpty else { return }
        if props.bool("unique", default: true) && tags.contains(tag) { return }
        let next = tags + [tag]
        tags = next
        let event = props.string("addEvent")
        if !event.isEmpty {
            onEvent(event, eventEnvelope(props, payload: ["tag": .string(tag), "value": .array(next.map { AnyCodable.string($0) })]))
        }
    }

    private func remove(_ index: Int) {
        guard tags.indices.contains(index) else { return }
        let payload = removal(index)
        tags.remove(at: index)
        let event = props.string("removeEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: payload)) }
    }
}

@ViewBuilder
func TagInputRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TagInputMoleculeView(props: props, onEvent: onEvent))
}
