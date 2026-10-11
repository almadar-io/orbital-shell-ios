import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct CommandPaletteMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var query = ""

    private var commands: [AnyCodable] { props.dictValue?["commands"]?.arrayValue ?? [] }

    private func fuzzy(_ needle: String, _ haystack: String) -> Bool {
        if needle.isEmpty { return true }
        var remaining = Array(needle.lowercased())
        for character in haystack.lowercased() where character == remaining.first {
            remaining.removeFirst()
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }

    private func matches(_ command: AnyCodable) -> Bool {
        if fuzzy(query, command.string("label")) { return true }
        return AtomKit.strings(command, "keywords").contains { fuzzy(query, $0) }
    }

    private var groups: [(name: String, items: [AnyCodable])] {
        var order: [String] = []
        var buckets: [String: [AnyCodable]] = [:]
        for command in commands where matches(command) {
            let key = command.string("group")
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(command)
        }
        return order.map { (name: $0, items: buckets[$0] ?? []) }
    }

    var body: some View {
        if props.bool("open") {
            let shown = groups
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                InputRenderer(
                    props: [
                        "inputType": "search",
                        "name": "commandPaletteQuery",
                        "placeholder": .string(props.string("placeholder", default: "Type a command...")),
                        "value": .string(query),
                        "leftIcon": "search",
                        "clearable": .bool(!query.isEmpty),
                        "onChange": .string(AtomKit.localEvent),
                    ],
                    modifier: nil,
                    onEvent: { _, envelope in query = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "" }
                )
                if shown.isEmpty {
                    AtomKit.typo(props.string("emptyLabel", default: "No matching commands"), "body1", color: "muted", align: "center", onEvent: onEvent)
                        .padding(.vertical, theme.density.spacing.space6)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                            ForEach(shown.indices, id: \.self) { index in
                                section(shown[index].name, shown[index].items)
                            }
                        }
                    }
                    .frame(maxHeight: AlmadarSizes.w80)
                }
            }
            .frame(maxWidth: AlmadarSizes.maxWMd, alignment: .leading)
            .atomSurface(theme, padding: theme.density.dialogPadding)
            .atomShadow(theme.elevation.dialogElevation)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    @ViewBuilder
    private func section(_ name: String, _ items: [AnyCodable]) -> some View {
        if !name.isEmpty {
            AtomKit.typo(name, "caption", color: "muted", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.top, theme.density.spacing.space2)
                .padding(.bottom, theme.density.spacing.space1)
        }
        ForEach(items.indices, id: \.self) { index in
            row(items[index])
        }
    }

    private func row(_ command: AnyCodable) -> some View {
        let trigger = command.string("action", default: command.string("event"))
        return HStack(spacing: theme.density.spacing.space2) {
            ButtonRenderer(
                props: AtomKit.child(props, [
                    "variant": "ghost",
                    "label": .string(command.string("label")),
                    "leftIcon": .string(command.string("icon")),
                    "disabled": .bool(command.bool("disabled")),
                    "action": .string(AtomKit.eventOrLocal(trigger)),
                    "local": .bool(trigger.isEmpty),
                ]),
                modifier: nil,
                onEvent: { _, _ in pick(command) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if !command.string("shortcut").isEmpty { AtomKit.badge(command.string("shortcut"), "neutral", onEvent: onEvent) }
        }
    }

    private func pick(_ command: AnyCodable) {
        if command.bool("disabled") { return }
        let event = command.string("event")
        let action = command.string("action")
        let select = props.string("onSelect")
        let change = props.string("onOpenChange")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["commandId": .string(command.string("id"))])) }
        if !action.isEmpty { onEvent(action, eventEnvelope(props, payload: command.dictValue?["actionPayload"] ?? .dict([:]))) }
        if !select.isEmpty { onEvent(select, eventEnvelope(props, payload: ["command": command])) }
        query = ""
        if !change.isEmpty { onEvent(change, eventEnvelope(props, payload: ["open": .bool(false)])) }
    }
}

@ViewBuilder
func CommandPaletteRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CommandPaletteMoleculeView(props: props, onEvent: onEvent))
}
