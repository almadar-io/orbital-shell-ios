import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct BreadcrumbMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private enum Crumb {
        case item(AnyCodable, Int)
        case collapsed
    }

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let limit = props.int("maxItems")
        let all: [Crumb] = items.indices.map { Crumb.item(items[$0], $0) }
        let crumbs: [Crumb] = limit > 0 && items.count > limit ? [all[0], .collapsed] + Array(all.suffix(limit - 1)) : all
        let separator = props.string("separator", default: "chevron-right")
        AtomFlowLayout(spacing: theme.density.spacing.space2) {
            ForEach(crumbs.indices, id: \.self) { position in
                let last = position == crumbs.count - 1
                HStack(spacing: theme.density.spacing.space2) {
                    switch crumbs[position] {
                    case .collapsed:
                        AtomKit.typo("\u{2026}", "small", color: "muted", onEvent: onEvent)
                    case .item(let item, let index):
                        crumb(item, index: index, last: last)
                    }
                    if !last { AtomKit.icon(separator, "sm", color: "muted", onEvent: onEvent) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("aria-label", default: "Breadcrumb"))
    }

    @ViewBuilder
    private func crumb(_ item: AnyCodable, index: Int, last: Bool) -> some View {
        let label = item.string("label")
        let href = item.string("href", default: item.string("path"))
        let event = item.string("event", default: props.string("itemEvent"))
        let icon = item.string("icon")
        if last {
            HStack(spacing: theme.density.spacing.space1) {
                if !icon.isEmpty { AtomKit.icon(icon, "sm", onEvent: onEvent) }
                AtomKit.typo(label, "small", weight: "medium", truncate: true, onEvent: onEvent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isSelected)
        } else if !event.isEmpty || !href.isEmpty {
            let route = event.isEmpty ? AtomKit.navigate(item) : (event: event, payload: Optional<AnyCodable>.none, href: "")
            ButtonRenderer(
                props: AtomKit.child(props, [
                    "variant": "link",
                    "label": .string(label),
                    "leftIcon": .string(icon),
                    "action": .string(route.event),
                    "href": .string(route.href),
                    "actionPayload": route.payload ?? ["label": .string(label), "href": .string(href), "index": .int(index)],
                ]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            AtomKit.typo(label, "small", color: "muted", truncate: true, onEvent: onEvent)
        }
    }
}

@ViewBuilder
func BreadcrumbRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BreadcrumbMoleculeView(props: props, onEvent: onEvent))
}
