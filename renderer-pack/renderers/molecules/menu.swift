import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct MenuMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        Menu {
            AtomSlot(props.dictValue?["header"], onEvent: onEvent)
            ForEach(items.indices, id: \.self) { index in
                entry(items[index], index: index)
            }
            AtomSlot(props.dictValue?["footer"], onEvent: onEvent)
        } label: {
            AtomSlot(props.dictValue?["trigger"], onEvent: onEvent)
        }
        .accessibilityElement(children: .contain)
    }

    private func entry(_ item: AnyCodable, index: Int) -> AnyView {
        let label = item.string("label")
        let id = item.string("id", default: "item-" + label.lowercased().split(separator: " ").joined(separator: "-") + "-\(index)")
        let nested = item.dictValue?["subMenu"]?.arrayValue ?? []
        if item.string("type") == "divider" {
            return AnyView(DividerRenderer(props: [:], modifier: nil, onEvent: onEvent))
        }
        if !nested.isEmpty {
            return AnyView(Menu {
                ForEach(nested.indices, id: \.self) { position in entry(nested[position], index: position) }
            } label: {
                AtomKit.typo(label, "small", onEvent: onEvent)
            })
        }
        var values: [String: AnyCodable] = [
            "variant": .string(item.string("variant") == "danger" ? "danger" : "ghost"),
            "size": "sm",
            "label": .string(label),
            "disabled": .bool(item.bool("disabled")),
        ]
        if !item.string("icon").isEmpty { values["leftIcon"] = .string(item.string("icon")) }
        let target: AnyCodable = item.string("href").isEmpty && !item.string("url").isEmpty ? .dict(["href": .string(item.string("url"))]) : item
        var built = AtomKit.linkProps(props, target, values)
        if !item.string("event").isEmpty { built = built.merging(["actionPayload": ["itemId": .string(id), "label": .string(label)]]) }
        return AnyView(HStack(spacing: theme.density.spacing.space2) {
            ButtonRenderer(props: built, modifier: nil, onEvent: onEvent)
            if let badge = AtomKit.scalar(item.dictValue?["badge"]) { AtomKit.badge(badge, "default", onEvent: onEvent) }
        })
    }
}

@ViewBuilder
func MenuRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MenuMoleculeView(props: props, onEvent: onEvent))
}
