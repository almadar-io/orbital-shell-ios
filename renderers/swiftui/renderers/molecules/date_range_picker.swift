import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DateRangePickerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var from: String
    @State private var to: String
    @State private var active: String = ""

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _from = State(initialValue: props.string("from"))
        _to = State(initialValue: props.string("to"))
    }

    private static let dayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func tokenRange(_ token: String) -> (from: String, to: String)? {
        let calendar = Calendar.current
        let now = Date()
        let end = dayFormat.string(from: now)
        let parts = calendar.dateComponents([.year, .month], from: now)
        var start: Date?
        switch token {
        case "7d": start = calendar.date(byAdding: .day, value: -7, to: now)
        case "30d": start = calendar.date(byAdding: .day, value: -30, to: now)
        case "month": start = calendar.date(from: parts)
        case "quarter":
            var quarter = parts
            quarter.month = ((parts.month ?? 1) - 1) / 3 * 3 + 1
            start = calendar.date(from: quarter)
        case "ytd":
            var year = parts
            year.month = 1
            start = calendar.date(from: year)
        default: return nil
        }
        guard let begin = start else { return nil }
        return (dayFormat.string(from: begin), end)
    }

    private var presets: [(value: String, label: String, range: (from: String, to: String)?)] {
        let given = props.dictValue?["presets"]?.arrayValue
        let source: [AnyCodable] = given ?? [
            .dict(["value": "7d", "label": "Last 7 days"]),
            .dict(["value": "30d", "label": "Last 30 days"]),
            .dict(["value": "month", "label": "This month"]),
            .dict(["value": "quarter", "label": "This quarter"]),
            .dict(["value": "ytd", "label": "Year to date"]),
        ]
        return source.compactMap { item in
            let value = item.string("value")
            var range = DateRangePickerMoleculeView.tokenRange(value)
            if let explicit = item.dictValue?["range"], explicit.dictValue != nil {
                range = (explicit.string("from"), explicit.string("to"))
            }
            guard range != nil else { return nil }
            return (value: value, label: item.string("label", default: value), range: range)
        }
    }

    private func emit(_ nextFrom: String, _ nextTo: String) {
        let event = props.string("event")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["from": .string(nextFrom), "to": .string(nextTo)])) }
    }

    var body: some View {
        let list = presets
        let event = props.string("event")
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            if !list.isEmpty {
                AtomFlowLayout(spacing: theme.density.spacing.space2) {
                    ForEach(list.indices, id: \.self) { index in
                        let preset = list[index]
                        let range = preset.range ?? (from: "", to: "")
                        ButtonRenderer(
                            props: AtomKit.child(props, [
                                "variant": .string(active == preset.value ? "primary" : "secondary"),
                                "size": "sm",
                                "label": .string(preset.label),
                                "action": .string(AtomKit.eventOrLocal(event)),
                                "local": .bool(event.isEmpty),
                            ]),
                            modifier: nil,
                            onEvent: { _, _ in
                                from = range.from
                                to = range.to
                                active = preset.value
                                emit(range.from, range.to)
                            }
                        )
                    }
                }
            }
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                dateField("from", label: props.string("fromLabel", default: "From"), value: from) { value in
                    from = value
                    active = ""
                    emit(value, to)
                }
                dateField("to", label: props.string("toLabel", default: "To"), value: to) { value in
                    to = value
                    active = ""
                    emit(from, value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateField(_ name: String, label: String, value: String, commit: @escaping (String) -> Void) -> some View {
        InputRenderer(
            props: AtomKit.child(props, ["inputType": "date", "name": .string(name), "label": .string(label), "value": .string(value), "onChange": .string(AtomKit.localEvent)]),
            modifier: nil,
            onEvent: { _, envelope in
                if let next = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue { commit(next) }
            }
        )
        .id(name + "-" + value)
    }
}

@ViewBuilder
func DateRangePickerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DateRangePickerMoleculeView(props: props, onEvent: onEvent))
}
