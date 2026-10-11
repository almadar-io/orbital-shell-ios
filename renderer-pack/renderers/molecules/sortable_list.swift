import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SortableListMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var order: [AnyCodable]

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _order = State(initialValue: AtomKit.rows(props, "items"))
    }

    private func move(_ from: Int, _ to: Int) {
        guard order.indices.contains(from), order.indices.contains(to), from != to else { return }
        let item = order.remove(at: from)
        order.insert(item, at: to)
    }

    private func payload(_ from: Int, _ to: Int, _ item: AnyCodable) -> AnyCodable {
        var values: [String: AnyCodable] = props.dictValue?["reorderPayload"]?.dictValue ?? [:]
        values["fromIndex"] = .int(from)
        values["toIndex"] = .int(to)
        values["item"] = item
        return .dict(values)
    }

    private func emit(_ from: Int, _ to: Int, _ item: AnyCodable) {
        let event = props.string("reorderEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: payload(from, to, item))) }
    }

    var body: some View {
        let event = props.string("reorderEvent")
        let template = props.dictValue?["renderItem"]
        List {
            ForEach(order.indices, id: \.self) { index in
                let row = order[index]
                HStack(spacing: theme.density.spacing.space2) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        if let template = template, template.dictValue != nil || template.arrayValue != nil {
                            AtomSlot(AtomRowTemplate.bind(template, row), onEvent: onEvent)
                        } else {
                            AtomRowFields(row: row, onEvent: onEvent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    nudge("chevron-up", "Move up", event: event, from: index, to: index - 1, row: row)
                    nudge("chevron-down", "Move down", event: event, from: index, to: index + 1, row: row)
                }
                .listRowInsets(EdgeInsets())
                .verificationContainer(VerificationIds.row(AtomKit.rowKey(row, index)))
            }
            .onMove { indices, destination in
                guard let from = indices.first else { return }
                let to = destination > from ? destination - 1 : destination
                let item = order[from]
                move(from, to)
                emit(from, to, item)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .frame(minHeight: theme.density.rowHeightNormal * CGFloat(order.count))
        .onChange(of: AtomKit.rows(props, "items")) { next in order = next }
    }

    private func nudge(_ icon: String, _ label: String, event: String, from: Int, to: Int, row: AnyCodable) -> some View {
        ButtonRenderer(
            props: AtomKit.child(props, [
                "variant": "ghost",
                "size": "sm",
                "icon": .string(icon),
                "aria-label": .string(label),
                "disabled": .bool(!order.indices.contains(to)),
                "action": .string(AtomKit.eventOrLocal(event)),
                "local": .bool(event.isEmpty),
                "actionPayload": payload(from, to, row),
            ]),
            modifier: nil,
            onEvent: { name, _ in
                move(from, to)
                if !event.isEmpty { onEvent(name, eventEnvelope(props, payload: payload(from, to, row))) }
            }
        )
    }
}

@ViewBuilder
func SortableListRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SortableListMoleculeView(props: props, onEvent: onEvent))
}
