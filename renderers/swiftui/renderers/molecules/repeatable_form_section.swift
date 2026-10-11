import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct RepeatableFormSectionMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var order: [AnyCodable]

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _order = State(initialValue: props.dictValue?["items"]?.arrayValue ?? [])
    }

    private var maximum: Int { props.dictValue?["maxItems"]?.intValue ?? Int.max }
    private var minimum: Int { props.int("minItems") }

    private func addPayload() -> AnyCodable {
        var values: [String: AnyCodable] = ["sectionType": .string(props.string("sectionType")), "index": .int(order.count)]
        if props.bool("trackAddedInState") && !props.string("currentState").isEmpty {
            values["addedInState"] = .string(props.string("currentState"))
            values["addedAt"] = .string(ISO8601DateFormatter().string(from: Date()))
        }
        return .dict(values)
    }

    private func addButton(_ variant: String) -> some View {
        let addKey = "SECTION_ADDED"
        return ButtonRenderer(
            props: AtomKit.child(props, ["variant": .string(variant), "size": "sm", "label": .string(props.string("addLabel", default: "Add")), "leftIcon": "plus", "action": .string(addKey), "actionPayload": addPayload()]),
            modifier: nil,
            onEvent: onEvent
        )
    }

    var body: some View {
        let readOnly = props.bool("readOnly")
        let canAdd = !readOnly && order.count < maximum
        let canRemove = !readOnly && order.count > minimum
        let canReorder = props.bool("allowReorder") && !readOnly
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.typo(props.string("title"), "h4", onEvent: onEvent)
                AtomKit.typo("(\(order.count)" + (maximum == Int.max ? "" : "/\(maximum)") + ")", "caption", color: "muted", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space0)
                if canAdd { addButton("secondary") }
            }
            if order.isEmpty {
                VStack(spacing: theme.density.spacing.space2) {
                    AtomKit.typo(props.string("emptyMessage", default: "No items added yet"), "body1", color: "muted", onEvent: onEvent)
                    if canAdd { addButton("primary") }
                }
                .frame(maxWidth: .infinity)
                .atomSurface(theme, padding: theme.density.spacing.space6)
            } else {
                ForEach(order.indices, id: \.self) { index in
                    item(order[index], index: index, canRemove: canRemove, canReorder: canReorder)
                }
            }
            if order.count < minimum {
                AtomKit.typo(minimum == 1 ? "At least 1 item required" : "At least \(minimum) items required", "caption", color: "warning", onEvent: onEvent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: props.dictValue?["items"]?.arrayValue ?? []) { next in order = next }
    }

    @ViewBuilder
    private func item(_ row: AnyCodable, index: Int, canRemove: Bool, canReorder: Bool) -> some View {
        let removedKey = "SECTION_REMOVED"
        let template = props.dictValue?["renderItem"]
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if props.bool("showAuditInfo") && (!row.string("addedInState").isEmpty || !row.string("addedAt").isEmpty) {
                HStack(spacing: theme.density.spacing.space2) {
                    if !row.string("addedInState").isEmpty { AtomKit.typo("Added in: " + row.string("addedInState"), "caption", color: "muted", onEvent: onEvent) }
                    Spacer(minLength: theme.density.spacing.space0)
                    if !row.string("addedAt").isEmpty { AtomKit.typo(AtomKit.formatted(row.string("addedAt"), format: "datetime"), "caption", color: "muted", onEvent: onEvent) }
                }
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
            HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                if canReorder {
                    VStack(spacing: theme.density.spacing.space0) {
                        shift("chevron-up", "Move up", from: index, to: index - 1)
                        shift("chevron-down", "Move down", from: index, to: index + 1)
                    }
                }
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    if let template = template, template.dictValue != nil || template.arrayValue != nil {
                        AtomSlot(AtomRowTemplate.bind(template, row), onEvent: onEvent)
                    } else {
                        AtomRowFields(row: row, onEvent: onEvent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if canRemove {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "trash-2", "aria-label": "Remove", "action": .string(removedKey), "actionPayload": ["sectionType": .string(props.string("sectionType")), "index": .int(index), "itemId": .string(row.string("id"))]]),
                        modifier: nil,
                        onEvent: { name, _ in
                            order.remove(at: index)
                            onEvent(name, eventEnvelope(props, payload: ["sectionType": .string(props.string("sectionType")), "index": .int(index), "itemId": .string(row.string("id"))]))
                        }
                    )
                }
            }
        }
        .atomSurface(theme)
        .verificationContainer(VerificationIds.row(AtomKit.rowKey(row, index)))
    }

    private func shift(_ icon: String, _ label: String, from: Int, to: Int) -> some View {
        ButtonRenderer(
            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": .string(icon), "aria-label": .string(label), "disabled": .bool(!order.indices.contains(to)), "action": .string(AtomKit.localEvent), "local": true]),
            modifier: nil,
            onEvent: { _, _ in
                guard order.indices.contains(to) else { return }
                order.swapAt(from, to)
            }
        )
    }
}

@ViewBuilder
func RepeatableFormSectionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RepeatableFormSectionMoleculeView(props: props, onEvent: onEvent))
}
