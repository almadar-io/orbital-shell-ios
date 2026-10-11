import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocSidebarCategoryView: View {
    let owner: AnyCodable
    let item: AnyCodable
    let depth: Int
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var expanded: Bool

    init(owner: AnyCodable, item: AnyCodable, depth: Int, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.owner = owner
        self.item = item
        self.depth = depth
        self.onEvent = onEvent
        _expanded = State(initialValue: DocSidebarCategoryView.holdsActive(item))
    }

    static func holdsActive(_ node: AnyCodable) -> Bool {
        (node.dictValue?["items"]?.arrayValue ?? []).contains { $0.bool("active") || holdsActive($0) }
    }

    var body: some View {
        let children = item.dictValue?["items"]?.arrayValue ?? []
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.icon(expanded ? "chevron-down" : "chevron-right", "xs", color: "muted", onEvent: onEvent)
                    AtomKit.typo(item.string("label"), "caption", color: "muted", weight: "semibold", onEvent: onEvent)
                    Spacer(minLength: theme.density.spacing.space0)
                }
                .padding(.horizontal, theme.density.spacing.space2)
                .padding(.vertical, theme.density.spacing.space2)
                .contentShape(Rectangle())
                .onTapGesture { expanded.toggle() }
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(expanded ? "expanded" : "collapsed")
                if expanded {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                        ForEach(children.indices, id: \.self) { index in
                            DocSidebarCategoryView(owner: owner, item: children[index], depth: depth + 1, onEvent: onEvent)
                        }
                    }
                    .padding(.leading, theme.density.spacing.space4)
                }
            }
        } else if item.string("href").isEmpty {
            AtomKit.typo(item.string("label"), "body2", color: "muted", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.vertical, theme.density.spacing.space2)
                .padding(.leading, depth > 0 ? theme.density.spacing.space2 : theme.density.spacing.space0)
        } else {
            ButtonRenderer(
                props: AtomKit.linkProps(owner, item, [
                    "variant": item.bool("active") ? "secondary" : "ghost",
                    "size": "sm",
                    "label": .string(item.string("label")),
                ]),
                modifier: nil,
                onEvent: onEvent
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, depth > 0 ? theme.density.spacing.space2 : theme.density.spacing.space0)
            .accessibilityAddTraits(item.bool("active") ? .isSelected : [])
        }
    }
}

struct DocSidebarMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { index in
                DocSidebarCategoryView(owner: props, item: items[index], depth: 0, onEvent: onEvent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func DocSidebarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocSidebarMoleculeView(props: props, onEvent: onEvent))
}
