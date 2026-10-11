import Foundation
import SwiftUI

// tier: templates — CONTENT ONLY

struct DashboardLayoutTemplateView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var menuOpen = false
    @State private var searchOpen = false
    @State private var expanded: Set<String> = []

    private var mode: String { props.string("layoutMode", default: "sidebar") }
    private var items: [AnyCodable] { props.dictValue?["navItems"]?.arrayValue ?? [] }
    private var appName: String { props.string("appName", default: "App") }
    private var compact: Bool { sizeClass == .compact }
    private var offCanvas: Bool { compact || mode == "drawer" }

    private var activeHref: String {
        let path = props.string("currentPath")
        var best = ""
        for item in items {
            let own = [item.string("href")] + (item.dictValue?["children"]?.arrayValue ?? []).map { $0.string("href") }
            for href in own where !href.isEmpty {
                if path == href { return href }
                if path.hasPrefix(href + "/") && href.count > best.count { best = href }
            }
        }
        return best
    }

    var body: some View {
        VStack(spacing: theme.density.spacing.space0) {
            if mode != "minimal" { header }
            if menuOpen && offCanvas && (mode == "sidebar" || mode == "drawer" || mode == "topnav") {
                navigation(items)
                    .padding(theme.density.spacing.space3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
                    .background(theme.color.card)
                    .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
            }
            HStack(alignment: .top, spacing: theme.density.spacing.space0) {
                if mode == "sidebar" && !offCanvas { sidebar }
                VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
                    ForEach(props.children().indices, id: \.self) { index in
                        RenderChild(props.children()[index], onEvent: onEvent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(compact ? theme.density.spacing.space3 : theme.density.spacing.space6)
            }
            if mode == "bottomnav" { bottomBar }
        }
        .background(theme.color.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space2) {
                brand
                AtomKit.typo(appName, "label", truncate: true, onEvent: onEvent)
            }
            .padding(theme.density.spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            navigation(items)
                .padding(theme.density.spacing.space3)
            if let content = props.dictValue?["sidebarContent"] {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                RenderChild(content, onEvent: onEvent).padding(theme.density.spacing.space2)
            }
            Spacer(minLength: theme.density.spacing.space0)
            if let footer = props.dictValue?["sidebarFooter"] {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                RenderChild(footer, onEvent: onEvent).padding(theme.density.spacing.space4)
            }
        }
        .frame(width: theme.density.spacing.space12 * 5, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
        .background(theme.color.card)
        .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
        .overlay(alignment: .trailing) { Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderHairline) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    @ViewBuilder
    private var brand: some View {
        if let logo = props.dictValue?["logo"] {
            RenderChild(logo, onEvent: onEvent)
        } else {
            AtomKit.typo(String(appName.prefix(1)).uppercased(), "small", color: "inherit", weight: "semibold", onEvent: onEvent)
                .foregroundColor(theme.color.primaryForeground)
                .frame(width: theme.density.spacing.space8, height: theme.density.spacing.space8)
                .background(theme.color.primary)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        }
    }

    private func navigation(_ list: [AnyCodable]) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            ForEach(list.indices, id: \.self) { index in navRow(list[index], nested: false) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }

    private func navRow(_ item: AnyCodable, nested: Bool) -> AnyView {
        let children = item.dictValue?["children"]?.arrayValue ?? []
        let href = item.string("href")
        let childActive = children.contains(where: { $0.string("href") == activeHref })
        let active = href == activeHref || childActive
        let route = AtomKit.navigate(item)
        let key = href.isEmpty ? item.string("label") : href
        let open = expanded.contains(key) || childActive
        let badge = AtomKit.scalar(item.dictValue?["badge"]) ?? ""
        return AnyView(VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            HStack(spacing: theme.density.spacing.space1) {
                if children.isEmpty {
                    ButtonRenderer(
                        props: AtomKit.child(props, [
                            "variant": .string(active ? "primary" : "ghost"),
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
                } else {
                    ButtonRenderer(
                        props: [
                            "variant": .string(active ? "primary" : "ghost"),
                            "label": .string(item.string("label")),
                            "leftIcon": .string(item.string("icon")),
                            "rightIcon": .string(open ? "chevron-up" : "chevron-down"),
                            "action": .string("nav-toggle-\(key)"),
                            "local": true,
                        ],
                        modifier: nil,
                        onEvent: { _, _ in if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) } }
                    )
                    .accessibilityValue(open ? "expanded" : "collapsed")
                }
                if !badge.isEmpty { AtomKit.badge(badge, active ? "primary" : "default", onEvent: onEvent) }
            }
            if open {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    ForEach(children.indices, id: \.self) { index in navRow(children[index], nested: true) }
                }
                .padding(.leading, theme.density.spacing.space4)
            }
        })
    }

    @ViewBuilder
    private var header: some View {
        let searchable = props.bool("showSearch") || !props.string("searchEvent").isEmpty
        let notifications = props.dictValue?["notifications"]?.arrayValue
        let unread = (notifications ?? []).filter { $0.dictValue?["read"]?.boolValue != true }.count
        let user = props.dictValue?["user"]
        HStack(spacing: theme.density.spacing.space2) {
            if offCanvas && (mode == "sidebar" || mode == "drawer" || mode == "topnav") {
                ButtonRenderer(
                    props: ["variant": "ghost", "icon": .string(menuOpen ? "x" : "menu"), "aria-label": .string(menuOpen ? "Close menu" : "Open menu"), "action": "nav-menu-toggle", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in menuOpen.toggle() }
                )
            }
            if compact && !searchOpen {
                AtomKit.typo(appName, "label", weight: "medium", truncate: true, onEvent: onEvent)
            } else if mode == "drawer" || (mode == "topnav" && !compact) {
                HStack(spacing: theme.density.spacing.space2) {
                    brand
                    AtomKit.typo(appName, "label", onEvent: onEvent)
                }
            }
            if mode == "topnav" && !compact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.density.spacing.space1) {
                        ForEach(items.indices, id: \.self) { index in
                            TopNavItemRenderer(props: AtomKit.child(props, ["item": items[index], "activeHref": .string(activeHref), "tone": "solid"]), modifier: nil, onEvent: onEvent)
                        }
                    }
                }
                .accessibilityLabel("Main navigation")
            }
            if searchable && (!compact || searchOpen) {
                InputRenderer(
                    props: AtomKit.child(props, [
                        "inputType": "search",
                        "leftIcon": "search",
                        "placeholder": "Search",
                        "action": .string(props.string("searchEvent")),
                        "name": .string(props.string("searchEvent").isEmpty ? "dashboard-search" : ""),
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .frame(maxWidth: compact ? .infinity : 448)
            }
            if searchable && compact {
                ButtonRenderer(
                    props: ["variant": "ghost", "icon": .string(searchOpen ? "x" : "search"), "aria-label": "Search", "action": "dashboard-search-toggle", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in searchOpen.toggle() }
                )
            }
            Spacer(minLength: theme.density.spacing.space0)
            if let actions = props.dictValue?["headerActions"] { RenderChild(actions, onEvent: onEvent) }
            if props.bool("showThemeToggle", default: true) {
                ThemeToggleRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
            ForEach((props.dictValue?["topBarActions"]?.arrayValue ?? []).indices, id: \.self) { index in
                topBarAction((props.dictValue?["topBarActions"]?.arrayValue ?? [])[index])
            }
            if notifications != nil && !props.string("notificationClickEvent").isEmpty {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "icon": "bell", "aria-label": "Notifications", "action": .string(props.string("notificationClickEvent"))]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .overlay(alignment: .topTrailing) {
                    if unread > 0 { AtomKit.badge(unread > 99 ? "99+" : String(unread), "danger", onEvent: onEvent) }
                }
            }
            if let user = user, !user.string("name").isEmpty {
                userMenu(user)
            }
        }
        .padding(.horizontal, compact ? theme.density.spacing.space3 : theme.density.spacing.space4)
        .frame(minHeight: theme.density.spacing.space12 + theme.density.spacing.space4)
        .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
        .background(theme.color.card)
        .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.color.border).frame(height: theme.geometry.borderHairline) }
    }

    private func userMenuEntry(_ action: AnyCodable) -> some View {
        let event = action.string("event")
        let routed = AtomKit.route(action, row: nil)
        return ButtonRenderer(
            props: AtomKit.child(props, [
                "variant": .string(action.string("variant") == "danger" ? "danger" : "ghost"),
                "size": "sm",
                "leftIcon": .string(action.string("icon")),
                "label": .string(action.string("label")),
                "action": .string(event.isEmpty ? routed.event : event),
                "actionPayload": event.isEmpty ? (routed.payload ?? .null) : .null,
                "href": .string(event.isEmpty ? "" : action.string("navigatesTo")),
            ]),
            modifier: nil,
            onEvent: onEvent
        )
    }

    private func userMenu(_ user: AnyCodable) -> some View {
        let entries = props.dictValue?["userMenuItems"]?.arrayValue ?? []
        let signOutEvent = props.string("onSignOut")
        return Menu {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                AtomKit.typo(user.string("name"), "small", weight: "medium", onEvent: onEvent)
                if !user.string("email").isEmpty { AtomKit.typo(user.string("email"), "caption", color: "muted", onEvent: onEvent) }
            }
            ForEach(entries.indices, id: \.self) { index in userMenuEntry(entries[index]) }
            ButtonRenderer(
                props: AtomKit.child(props, ["variant": "danger", "size": "sm", "leftIcon": "log-out", "label": "Sign out", "action": .string(AtomKit.signOutEvent)]),
                modifier: nil,
                onEvent: { _, _ in
                    if !signOutEvent.isEmpty { onEvent(signOutEvent, eventEnvelope(props)) }
                    onEvent(AtomKit.signOutEvent, eventEnvelope(props))
                }
            )
        } label: {
            HStack(spacing: theme.density.spacing.space2) {
                AvatarRenderer(props: ["src": .string(AtomKit.assetURL(user, "avatar")), "name": .string(user.string("name")), "size": "sm"], modifier: nil, onEvent: onEvent)
                if !compact {
                    AtomKit.typo(user.string("name"), "small", weight: "medium", onEvent: onEvent)
                    AtomKit.icon("chevron-down", "sm", color: "muted", onEvent: onEvent)
                }
            }
        }
        .accessibilityLabel(user.string("name"))
    }

    private func topBarAction(_ action: AnyCodable) -> some View {
        let routed = AtomKit.route(action, row: nil)
        let badge = AtomKit.scalar(action.dictValue?["badge"]) ?? ""
        let label = action.string("label", default: action.string("icon"))
        return ButtonRenderer(
            props: AtomKit.child(props, ["variant": "ghost", "icon": .string(action.string("icon")), "aria-label": .string(label), "action": .string(routed.event), "actionPayload": routed.payload ?? .null]),
            modifier: nil,
            onEvent: onEvent
        )
        .overlay(alignment: .topTrailing) {
            if !badge.isEmpty && badge != "0" {
                AtomKit.badge(badge, action.string("variant") == "danger" ? "danger" : (action.string("variant") == "primary" ? "primary" : "default"), onEvent: onEvent)
            }
        }
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: theme.density.spacing.space0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let active = item.string("href") == activeHref
                let route = AtomKit.navigate(item)
                StackRenderer(
                    props: AtomKit.child(props, [
                        "direction": "vertical",
                        "align": "center",
                        "gap": "none",
                        "action": .string(route.event),
                        "actionPayload": route.payload ?? .null,
                        "children": .array([
                            ["type": "icon", "icon": .string(item.string("icon")), "size": "md", "color": .string(active ? "primary" : "muted")],
                            ["type": "typography", "content": .string(item.string("label")), "variant": "caption", "color": .string(active ? "primary" : "muted")],
                        ]),
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.vertical, theme.density.spacing.space2)
        .background(theme.color.card)
        .overlay(alignment: .top) { Rectangle().fill(theme.color.border).frame(height: theme.geometry.borderHairline) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}

@ViewBuilder
func DashboardLayoutRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DashboardLayoutTemplateView(props: props, onEvent: onEvent))
}
