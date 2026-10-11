import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct TopNavItemMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let item = props.dictValue?["item"] ?? .dict([:])
        let children = item.dictValue?["children"]?.arrayValue ?? []
        let active = isActive(item) || children.contains(where: { isActive($0) })
        if children.isEmpty {
            entry(item, active: active)
        } else {
            Menu {
                ForEach(children.indices, id: \.self) { index in
                    entry(children[index], active: isActive(children[index]))
                }
            } label: {
                HStack(spacing: theme.density.spacing.space1) {
                    AtomKit.typo(item.string("label"), "small", color: "inherit", onEvent: onEvent)
                    AtomKit.icon("chevron-down", "xs", onEvent: onEvent)
                }
                .foregroundColor(active ? theme.color.primaryForeground : theme.color.mutedForeground)
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.vertical, theme.density.spacing.space1)
                .frame(minHeight: theme.density.buttonHeightMd)
                .background(active ? theme.color.primary : AtomKit.clear(theme))
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
            }
            .verificationId(VerificationIds.actionOverflow)
            .accessibilityAddTraits(active ? .isSelected : [])
        }
    }

    private func isActive(_ item: AnyCodable) -> Bool {
        let href = item.string("href")
        return item.bool("active") || (!href.isEmpty && href == props.string("activeHref"))
    }

    @ViewBuilder
    private func entry(_ item: AnyCodable, active: Bool) -> some View {
        let soft = props.string("tone", default: "solid") == "soft"
        let route = AtomKit.navigate(item)
        HStack(spacing: theme.density.spacing.space1) {
            ButtonRenderer(
                props: AtomKit.child(props, [
                    "variant": .string(active ? (soft ? "secondary" : "primary") : "ghost"),
                    "label": .string(item.string("label")),
                    "leftIcon": .string(item.string("icon")),
                    "action": .string(route.event),
                    "actionPayload": route.payload ?? .null,
                    "href": .string(route.href),
                ]),
                modifier: nil,
                onEvent: onEvent
            )
            .accessibilityAddTraits(active ? .isSelected : [])
            if let badge = AtomKit.scalar(item.dictValue?["badge"]), !badge.isEmpty {
                AtomKit.badge(badge, active ? "primary" : "default", onEvent: onEvent)
            }
        }
    }
}

@ViewBuilder
func TopNavItemRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TopNavItemMoleculeView(props: props, onEvent: onEvent))
}
