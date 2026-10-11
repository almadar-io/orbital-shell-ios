import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SidebarMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var folded: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _folded = State(initialValue: props.bool("defaultCollapsed"))
    }

    private var collapsed: Bool { props.dictValue?["collapsed"] != nil ? props.bool("collapsed") : folded }

    private func toggle() {
        let next = !collapsed
        if props.dictValue?["collapsed"] == nil { folded = next }
        let event = props.string("collapseChangeEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["collapsed": .bool(next)])) }
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body1", color: "error", align: "center", onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                header
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    let items = props.dictValue?["items"]?.arrayValue ?? []
                    ForEach(items.indices, id: \.self) { index in
                        entry(items[index])
                    }
                }
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.vertical, theme.density.spacing.space4)
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.card)
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        let logoClick = props.string("logoClickEvent")
        let brand = props.string("brandName", default: "KFlow")
        let closeEvent = props.string("closeEvent")
        return HStack(spacing: theme.density.spacing.space3) {
            HStack(spacing: theme.density.spacing.space3) {
                logoMark(brand)
                if !collapsed { AtomKit.typo(brand, "large", weight: "bold", onEvent: onEvent) }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !logoClick.isEmpty { onEvent(logoClick, eventEnvelope(props)) } }
            .atomAction(logoClick, props)
            .accessibilityAddTraits(logoClick.isEmpty ? [] : .isButton)
            Spacer(minLength: theme.density.spacing.space0)
            if !props.bool("hideCollapseButton") {
                let event = props.string("collapseChangeEvent")
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": .string(collapsed ? "chevron-right" : "chevron-left"), "aria-label": .string(collapsed ? "Expand sidebar" : "Collapse sidebar"), "action": .string(AtomKit.eventOrLocal(event)), "local": .bool(event.isEmpty)]),
                    modifier: nil,
                    onEvent: { _, _ in toggle() }
                )
            }
            if props.bool("showCloseButton") {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close sidebar", "action": .string(AtomKit.eventOrLocal(closeEvent)), "local": .bool(closeEvent.isEmpty)]),
                    modifier: nil,
                    onEvent: { _, _ in if !closeEvent.isEmpty { onEvent(closeEvent, eventEnvelope(props)) } }
                )
            }
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.vertical, theme.density.spacing.space3)
    }

    @ViewBuilder
    private func logoMark(_ brand: String) -> some View {
        let side = theme.density.spacing.space8
        if let logo = props.dictValue?["logo"] {
            AtomSlot(logo, onEvent: onEvent)
        } else if !AtomKit.assetURL(props, "logoSrc").isEmpty {
            ImageRenderer(props: AtomKit.child(props, ["src": .string(AtomKit.assetURL(props, "logoSrc")), "alt": .string(brand)]), modifier: nil, onEvent: onEvent)
                .frame(width: side, height: side)
        } else {
            AtomKit.typo(String(brand.prefix(1)).uppercased(), "small", color: "inherit", weight: "bold", align: "center", onEvent: onEvent)
                .foregroundColor(theme.color.primaryForeground)
                .frame(width: side, height: side)
                .background(theme.color.primary)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        }
    }

    @ViewBuilder
    private func entry(_ item: AnyCodable) -> some View {
        let active = item.dictValue?["active"] != nil ? item.bool("active") : item.bool("isActive")
        let label = item.string("label")
        let icon = item.string("icon")
        HStack(spacing: theme.density.spacing.space2) {
            ButtonRenderer(
                props: AtomKit.linkProps(props, item, collapsed
                    ? ["variant": .string(active ? "primary" : "ghost"), "icon": .string(icon.isEmpty ? "circle" : icon), "aria-label": .string(label)]
                    : ["variant": .string(active ? "primary" : "ghost"), "label": .string(label), "leftIcon": .string(icon)]),
                modifier: nil,
                onEvent: onEvent
            )
            .accessibilityAddTraits(active ? .isSelected : [])
            if !collapsed {
                Spacer(minLength: theme.density.spacing.space0)
                if let badge = AtomKit.scalar(item.dictValue?["badge"]) { AtomKit.badge(badge, "danger", onEvent: onEvent) }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        let footerNode = props.dictValue?["footerContent"]
        let userNode = props.dictValue?["userSection"]
        if footerNode != nil || userNode != nil {
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomSlot(footerNode, onEvent: onEvent)
                AtomSlot(userNode, onEvent: onEvent)
            }
            .padding(theme.density.spacing.space3)
        }
    }
}

@ViewBuilder
func SidebarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SidebarMoleculeView(props: props, onEvent: onEvent))
}
