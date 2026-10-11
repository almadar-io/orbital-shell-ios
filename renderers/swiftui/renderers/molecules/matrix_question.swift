import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct MatrixQuestionMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var answers: [String: String]

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        var start: [String: String] = [:]
        for (key, value) in props.dictValue?["values"]?.dictValue ?? [:] { start[key] = AtomKit.scalar(value) ?? "" }
        _answers = State(initialValue: start)
    }

    private var columns: [AnyCodable] {
        if let given = props.dictValue?["columns"]?.arrayValue { return given }
        return [("1", "Strongly Disagree"), ("2", "Disagree"), ("3", "Neutral"), ("4", "Agree"), ("5", "Strongly Agree")].map {
            .dict(["value": .int(Int($0.0) ?? 0), "label": .string($0.1)])
        }
    }

    var body: some View {
        let rows = props.dictValue?["rows"]?.arrayValue ?? []
        let cols = columns
        let event = props.string("changeEvent")
        let compact = props.string("size", default: "md") == "sm"
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h4", onEvent: onEvent) }
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .center, horizontalSpacing: theme.density.spacing.space2, verticalSpacing: compact ? theme.density.spacing.space1 : theme.density.spacing.space2) {
                    GridRow {
                        AtomKit.typo("", "caption", onEvent: onEvent)
                        ForEach(cols.indices, id: \.self) { index in
                            AtomKit.typo(cols[index].string("label"), "caption", color: "muted", weight: "medium", align: "center", onEvent: onEvent)
                        }
                    }
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent).gridCellUnsizedAxes(.horizontal)
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        let row = rows[rowIndex]
                        let rowId = row.string("id")
                        GridRow {
                            AtomKit.typo(row.string("label"), compact ? "small" : "body1", onEvent: onEvent)
                                .gridColumnAlignment(.leading)
                            ForEach(cols.indices, id: \.self) { colIndex in
                                let column = cols[colIndex]
                                let value = AtomKit.scalar(column.dictValue?["value"]) ?? ""
                                let on = answers[rowId] == value
                                ButtonRenderer(
                                    props: AtomKit.child(props, [
                                        "variant": "ghost",
                                        "size": .string(compact ? "sm" : "md"),
                                        "icon": .string(on ? "check-circle" : "circle"),
                                        "aria-label": .string(row.string("label") + ": " + column.string("label")),
                                        "disabled": .bool(props.bool("disabled")),
                                        "action": .string(AtomKit.eventOrLocal(event)),
                                        "local": .bool(event.isEmpty),
                                    ]),
                                    modifier: nil,
                                    onEvent: { _, _ in
                                        answers[rowId] = value
                                        if !event.isEmpty, let raw = column.dictValue?["value"] {
                                            onEvent(event, eventEnvelope(props, payload: ["rowId": .string(rowId), "value": raw]))
                                        }
                                    }
                                )
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func MatrixQuestionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MatrixQuestionMoleculeView(props: props, onEvent: onEvent))
}
