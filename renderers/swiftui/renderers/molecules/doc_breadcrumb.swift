import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocBreadcrumbMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        AtomFlowLayout(spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { index in
                crumb(items[index], index: index, last: index == items.count - 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("aria-label", default: "Breadcrumb"))
    }

    @ViewBuilder
    private func crumb(_ item: AnyCodable, index: Int, last: Bool) -> some View {
        let label = item.string("label")
        let linked = !last && !(item.string("href").isEmpty && item.string("event").isEmpty && item.string("action").isEmpty)
        HStack(spacing: theme.density.spacing.space1) {
            if index > 0 { AtomKit.icon("chevron-right", "xs", color: "muted", onEvent: onEvent) }
            if linked {
                ButtonRenderer(props: AtomKit.linkProps(props, item, ["variant": "link", "size": "sm", "label": .string(label)]), modifier: nil, onEvent: onEvent)
            } else {
                AtomKit.typo(label, "caption", color: last ? "primary" : "muted", weight: last ? "medium" : "", onEvent: onEvent)
                    .accessibilityAddTraits(last ? .isHeader : [])
            }
        }
    }
}

@ViewBuilder
func DocBreadcrumbRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocBreadcrumbMoleculeView(props: props, onEvent: onEvent))
}
