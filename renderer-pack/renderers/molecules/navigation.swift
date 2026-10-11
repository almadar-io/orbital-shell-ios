import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct NavigationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open: Set<String> = []

    var body: some View {
        let error = AtomKit.errorText(props)
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let horizontal = props.string("orientation", default: "horizontal") == "horizontal"
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body1", color: "error", align: "center", onEvent: onEvent)
        } else if horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: theme.density.spacing.space1) { entries(items) }
            }
            .accessibilityElement(children: .contain)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) { entries(items) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func entries(_ items: [AnyCodable]) -> some View {
        ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            let id = item.string("id", default: item.string("label"))
            let sub = item.dictValue?["subMenu"]?.arrayValue ?? []
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                HStack(spacing: theme.density.spacing.space1) {
                    if sub.isEmpty {
                        ButtonRenderer(props: AtomKit.linkProps(props, item, base(item)), modifier: nil, onEvent: onEvent)
                    } else {
                        ButtonRenderer(
                            props: AtomKit.child(props, base(item).merging(["rightIcon": .string(open.contains(id) ? "chevron-up" : "chevron-down"), "action": .string(AtomKit.localEvent), "local": true])),
                            modifier: nil,
                            onEvent: { _, _ in if open.contains(id) { open.remove(id) } else { open.insert(id) } }
                        )
                    }
                    if let badge = AtomKit.scalar(item.dictValue?["badge"]) { AtomKit.badge(badge, "danger", onEvent: onEvent) }
                }
                .accessibilityAddTraits(item.bool("isActive") ? .isSelected : [])
                if open.contains(id) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        ForEach(sub.indices, id: \.self) { position in
                            ButtonRenderer(props: AtomKit.linkProps(props, sub[position], base(sub[position], active: false)), modifier: nil, onEvent: onEvent)
                        }
                    }
                    .padding(.leading, theme.density.spacing.space4)
                }
            }
        }
    }

    private func base(_ item: AnyCodable, active: Bool? = nil) -> [String: AnyCodable] {
        let on = active ?? item.bool("isActive")
        var values: [String: AnyCodable] = [
            "variant": .string(on ? "primary" : "ghost"),
            "size": "sm",
            "label": .string(item.string("label")),
            "disabled": .bool(item.bool("disabled")),
        ]
        if !item.string("icon").isEmpty { values["leftIcon"] = .string(item.string("icon")) }
        return values
    }
}

extension Dictionary where Key == String, Value == AnyCodable {
    func merging(_ extra: [String: AnyCodable]) -> [String: AnyCodable] {
        self.merging(extra) { _, new in new }
    }
}

@ViewBuilder
func NavigationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(NavigationMoleculeView(props: props, onEvent: onEvent))
}
