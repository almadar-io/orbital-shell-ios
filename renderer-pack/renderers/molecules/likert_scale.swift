import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct LikertScaleMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var current: String

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _current = State(initialValue: AtomKit.scalar(props.dictValue?["value"]) ?? "")
    }

    private var options: [AnyCodable] {
        if let given = props.dictValue?["options"]?.arrayValue { return given }
        return [("1", "Strongly Disagree"), ("2", "Disagree"), ("3", "Neutral"), ("4", "Agree"), ("5", "Strongly Agree")].map {
            .dict(["value": .int(Int($0.0) ?? 0), "label": .string($0.1)])
        }
    }

    private func pick(_ option: AnyCodable) {
        guard !props.bool("disabled") else { return }
        current = AtomKit.scalar(option.dictValue?["value"]) ?? ""
        let event = props.string("changeEvent")
        if !event.isEmpty, let value = option.dictValue?["value"] { onEvent(event, eventEnvelope(props, payload: ["value": value])) }
    }

    var body: some View {
        let list = options
        let event = props.string("changeEvent")
        let size = props.string("size", default: "md")
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            if !props.string("question").isEmpty {
                AtomKit.typo(props.string("question"), size == "lg" ? "large" : (size == "sm" ? "small" : "body1"), weight: "medium", onEvent: onEvent)
            }
            if props.string("variant", default: "radios") == "buttons" {
                HStack(spacing: theme.density.spacing.space0) {
                    ForEach(list.indices, id: \.self) { index in
                        let option = list[index]
                        ButtonRenderer(
                            props: AtomKit.child(props, [
                                "variant": .string((AtomKit.scalar(option.dictValue?["value"]) ?? "") == current ? "primary" : "secondary"),
                                "size": .string(size),
                                "label": .string(option.string("label")),
                                "disabled": .bool(props.bool("disabled")),
                                "action": .string(AtomKit.eventOrLocal(event)),
                                "local": .bool(event.isEmpty),
                            ]),
                            modifier: nil,
                            onEvent: { _, _ in pick(option) }
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits((AtomKit.scalar(option.dictValue?["value"]) ?? "") == current ? .isSelected : [])
                    }
                }
            } else {
                let labels = list.map { $0.string("label") }
                let chosenLabel = list.first(where: { (AtomKit.scalar($0.dictValue?["value"]) ?? "") == current })?.string("label") ?? ""
                RadioRenderer(
                    props: AtomKit.child(props, [
                        "options": .array(labels.map { AnyCodable.string($0) }),
                        "value": .string(chosenLabel),
                        "size": .string(size),
                        "disabled": .bool(props.bool("disabled")),
                        "action": .string(AtomKit.eventOrLocal(event)),
                        "local": .bool(event.isEmpty),
                    ]),
                    modifier: nil,
                    onEvent: { _, envelope in
                        let label = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? ""
                        if let option = list.first(where: { $0.string("label") == label }) { pick(option) }
                    }
                )
                .id(chosenLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("aria-label", default: props.string("question", default: "Likert scale")))
        .onChange(of: AtomKit.scalar(props.dictValue?["value"]) ?? "") { next in current = next }
    }
}

@ViewBuilder
func LikertScaleRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LikertScaleMoleculeView(props: props, onEvent: onEvent))
}
