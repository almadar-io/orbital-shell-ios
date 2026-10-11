import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct DockLayoutOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var sidebarLocal = false
    @State private var bottomLocal = false
    @State private var secondaryLocal = false
    @State private var open = ""

    private func slot(_ key: String) -> AnyCodable? {
        guard let value = props.dictValue?[key] else { return nil }
        if case .null = value { return nil }
        return value
    }

    private func collapsed(_ key: String, _ local: Bool) -> Bool {
        props.dictValue?[key]?.boolValue ?? local
    }

    private func percent(_ key: String, _ fallback: Double) -> CGFloat {
        CGFloat(min(max(props.float(key, default: fallback), 0), 100)) / 100
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = props.dictValue?["compact"]?.boolValue ?? (proxy.size.width < AlmadarBreakpoints.lg)
            if compact {
                compactDock
            } else {
                desktop(proxy.size)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func control(_ icon: String, _ label: String, expanded: Bool? = nil, event: String = "", collapsed: Bool? = nil, _ action: @escaping () -> Void) -> some View {
        var values: [String: AnyCodable] = [
            "variant": "ghost",
            "size": "sm",
            "icon": .string(icon),
            "aria-label": .string(label),
            "aria-expanded": .bool(expanded ?? false),
            "action": .string(AtomKit.eventOrLocal(event)),
            "local": .bool(event.isEmpty),
        ]
        if let collapsed = collapsed { values["actionPayload"] = .dict(["collapsed": .bool(collapsed)]) }
        return ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: { _, _ in action() })
    }

    private func edge(_ vertical: Bool) -> some View {
        DividerRenderer(props: ["orientation": .string(vertical ? "vertical" : "horizontal")], modifier: nil, onEvent: onEvent)
    }

    private func gutter(_ icon: String, _ label: String, expanded: Bool, event: String, _ action: @escaping () -> Void) -> some View {
        VStack(spacing: theme.density.spacing.space0) {
            control(icon, label, expanded: expanded, event: event, collapsed: expanded, action)
                .padding(.top, theme.density.spacing.space1)
            Spacer(minLength: theme.density.spacing.space0)
        }
        .frame(width: theme.density.spacing.space8)
        .frame(maxHeight: .infinity)
        .background(theme.color.surface)
    }

    private func desktop(_ size: CGSize) -> some View {
        let sidebarShown = slot("sidebar") != nil && !collapsed("sidebarCollapsed", sidebarLocal)
        let secondaryShown = slot("secondarySidebar") != nil && !collapsed("secondarySidebarCollapsed", secondaryLocal)
        let bottomShown = slot("bottomPanel") != nil && !collapsed("bottomPanelCollapsed", bottomLocal)
        let sidebarWidth = max(size.width * percent("sidebarWidth", 20), CGFloat(props.float("sidebarMinSize", default: 160)))
        let bottomHeight = max(size.height * percent("bottomPanelHeight", 30), CGFloat(props.float("bottomPanelMinSize", default: 120)))
        return VStack(spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space0) {
                if let rail = slot("rail") {
                    RenderChild(rail, onEvent: onEvent)
                        .frame(width: slot("railWidth") == nil ? nil : CGFloat(props.float("railWidth")))
                        .frame(maxHeight: .infinity, alignment: .top)
                    edge(true)
                }
                if let sidebar = slot("sidebar") {
                    if sidebarShown {
                        ScrollView { RenderChild(sidebar, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
                            .frame(width: sidebarWidth)
                        edge(true)
                    }
                    gutter("panel-left", sidebarShown ? "Collapse sidebar" : "Expand sidebar", expanded: sidebarShown, event: props.string("onSidebarCollapsedChange")) { sidebarLocal = sidebarShown }
                    edge(true)
                }
                mainRow(secondaryShown: secondaryShown)
            }
            .frame(maxHeight: .infinity)
            if slot("bottomPanel") != nil {
                edge(false)
                HStack(spacing: theme.density.spacing.space0) {
                    Spacer(minLength: theme.density.spacing.space0)
                    control(bottomShown ? "chevron-down" : "chevron-up", bottomShown ? "Collapse bottom panel" : "Expand bottom panel", expanded: bottomShown, event: props.string("onBottomPanelCollapsedChange"), collapsed: bottomShown) { bottomLocal = bottomShown }
                }
                .padding(.horizontal, theme.density.spacing.space1)
                .background(theme.color.surface)
            }
            if bottomShown, let bottom = slot("bottomPanel") {
                edge(false)
                ScrollView { RenderChild(bottom, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
                    .frame(height: bottomHeight)
            }
            if let status = slot("statusBar") {
                edge(false)
                RenderChild(status, onEvent: onEvent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.color.background)
            }
        }
    }

    private func mainRow(secondaryShown: Bool) -> some View {
        HStack(spacing: theme.density.spacing.space0) {
            ScrollView {
                if let main = slot("main") { RenderChild(main, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let secondary = slot("secondarySidebar") {
                edge(true)
                gutter("panel-right", secondaryShown ? "Collapse secondary sidebar" : "Expand secondary sidebar", expanded: secondaryShown, event: props.string("onSecondarySidebarCollapsedChange")) { secondaryLocal = secondaryShown }
                if secondaryShown {
                    edge(true)
                    ScrollView { RenderChild(secondary, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
                        .frame(width: CGFloat(props.float("secondarySidebarWidth", default: 280)))
                }
            }
        }
    }

    private var compactDock: some View {
        ZStack {
            VStack(spacing: theme.density.spacing.space0) {
                if slot("rail") != nil || slot("sidebar") != nil || slot("secondarySidebar") != nil || slot("bottomPanel") != nil || slot("topBarActions") != nil {
                    topBar
                    edge(false)
                }
                ScrollView {
                    if let main = slot("main") { RenderChild(main, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
                }
                .frame(maxHeight: .infinity)
                if let status = slot("statusBar") {
                    edge(false)
                    RenderChild(status, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !open.isEmpty { panel }
        }
    }

    private var topBar: some View {
        HStack(spacing: theme.density.spacing.space1) {
            if slot("rail") != nil || slot("sidebar") != nil { control("menu", "Open menu") { open = "left" } }
            Spacer(minLength: theme.density.spacing.space0)
            if slot("bottomPanel") != nil {
                control(props.string("bottomPanelIcon", default: "chevron-up"), props.string("bottomPanelLabel", default: "Expand bottom panel")) { open = "bottom" }
            }
            if slot("secondarySidebar") != nil {
                control(props.string("secondarySidebarIcon", default: "panel-right"), props.string("secondarySidebarLabel", default: "Expand secondary sidebar")) { open = "secondary" }
            }
            if let actions = slot("topBarActions") { RenderChild(actions, onEvent: onEvent) }
        }
        .padding(.horizontal, theme.density.spacing.space2)
        .padding(.vertical, theme.density.spacing.space1)
        .background(theme.color.surface)
    }

    private var panel: some View {
        let fromLeft = open == "left"
        let content = open == "left" ? (slot("rail") ?? slot("sidebar")) : (open == "secondary" ? slot("secondarySidebar") : slot("bottomPanel"))
        let title = open == "left" ? "Menu" : (open == "secondary" ? props.string("secondarySidebarLabel", default: "Expand secondary sidebar") : props.string("bottomPanelLabel", default: "Expand bottom panel"))
        return ZStack(alignment: fromLeft ? .leading : .trailing) {
            theme.color.scrim
                .ignoresSafeArea()
                .onTapGesture { open = "" }
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.typo(title, "h4", onEvent: onEvent).frame(maxWidth: .infinity, alignment: .leading)
                    control("x", "Close") { open = "" }
                }
                .padding(theme.density.spacing.space4)
                edge(false)
                ScrollView {
                    if let content = content { RenderChild(content, onEvent: onEvent).frame(maxWidth: .infinity, alignment: .topLeading) }
                }
            }
            .frame(maxWidth: AlmadarSizes.w96, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.color.card)
            .atomShadow(theme.elevation.dialogElevation)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

@ViewBuilder
func DockLayoutRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DockLayoutOrganismView(props: props, onEvent: onEvent))
}
