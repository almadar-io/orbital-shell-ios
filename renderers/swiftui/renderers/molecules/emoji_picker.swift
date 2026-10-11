import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct EmojiPickerSection {
    let category: String
    var items: [AlmadarEmojiItem]
}

struct EmojiPickerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open = false
    @State private var query = ""

    private var matches: [AlmadarEmojiItem] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        if needle.isEmpty { return AlmadarEmoji.items }
        return AlmadarEmoji.items.filter { item in
            item.label.lowercased().contains(needle) || item.keywords.contains { $0.lowercased().contains(needle) }
        }
    }

    private func sections(_ items: [AlmadarEmojiItem]) -> [EmojiPickerSection] {
        var out: [EmojiPickerSection] = []
        for item in items {
            if let last = out.last, last.category == item.category {
                out[out.count - 1].items.append(item)
            } else {
                out.append(EmojiPickerSection(category: item.category, items: [item]))
            }
        }
        return out
    }

    private func pick(_ glyph: String) {
        let event = props.string("pickEvent")
        open = false
        query = ""
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["emoji": .string(glyph)])) }
    }

    private var panel: some View {
        let event = props.string("pickEvent")
        let groups = sections(matches)
        return VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            InputRenderer(
                props: AtomKit.child(props, ["inputType": "search", "placeholder": .string(props.string("searchPlaceholder", default: "Search emoji")), "aria-label": .string(props.string("searchPlaceholder", default: "Search emoji")), "value": .string(query), "onChange": .string(AtomKit.localEvent), "local": true]),
                modifier: nil,
                onEvent: { _, envelope in query = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "" }
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    ForEach(0..<groups.count, id: \.self) { index in
                        let group = groups[index]
                        AtomKit.typo(group.category, "caption", color: "muted", weight: "semibold", onEvent: onEvent)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: AtomKit.iconSize(theme, "xl")), spacing: theme.density.spacing.space0)], alignment: .leading, spacing: theme.density.spacing.space0) {
                            ForEach(0..<group.items.count, id: \.self) { cell in
                                let glyph = group.items[cell].id
                                ButtonRenderer(
                                    props: AtomKit.child(props, [
                                        "variant": "ghost",
                                        "size": "sm",
                                        "label": .string(glyph),
                                        "aria-label": .string(group.items[cell].label),
                                        "action": .string(AtomKit.eventOrLocal(event)),
                                        "local": .bool(event.isEmpty),
                                        "actionPayload": ["emoji": .string(glyph)],
                                    ]),
                                    modifier: nil,
                                    onEvent: { _, _ in pick(glyph) }
                                )
                                .frame(width: AtomKit.iconSize(theme, "xl"), height: AtomKit.iconSize(theme, "xl"))
                            }
                        }
                    }
                    if groups.isEmpty {
                        AtomKit.typo(props.string("emptyMessage", default: "No emoji found"), "small", color: "muted", align: "center", onEvent: onEvent)
                            .frame(maxWidth: .infinity)
                            .padding(theme.density.spacing.space3)
                    }
                }
            }
            .frame(maxHeight: AlmadarSizes.w64)
        }
        .frame(width: AlmadarSizes.w80)
        .atomSurface(theme, padding: theme.density.spacing.space2)
    }

    var body: some View {
        let label = props.string("triggerLabel", default: "Add emoji")
        let above = props.string("position", default: "top") == "top"
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            if open && above { panel }
            ButtonRenderer(
                props: AtomKit.child(props, [
                    "variant": "ghost",
                    "icon": .string(props.string("triggerIcon", default: "smile")),
                    "aria-label": .string(label),
                    "action": .string(AtomKit.localEvent),
                    "local": true,
                ]),
                modifier: nil,
                onEvent: { _, _ in open.toggle() }
            )
            if open && !above { panel }
        }
    }
}

@ViewBuilder
func EmojiPickerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(EmojiPickerMoleculeView(props: props, onEvent: onEvent))
}
