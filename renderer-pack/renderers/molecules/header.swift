import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct HeaderMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.openURL) private var openURL
    @State private var menuOpen: Bool
    @State private var query = ""

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _menuOpen = State(initialValue: props.bool("isMenuOpen"))
    }

    private var look: String { props.string("look", default: "compact-bar") }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "text"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body2", color: "error", onEvent: onEvent)
        } else {
            VStack(spacing: theme.density.spacing.space0) {
                HStack(spacing: theme.density.spacing.space3) {
                    if props.bool("showMenuToggle", default: true) {
                        ButtonRenderer(
                            props: ["variant": "ghost", "size": "sm", "icon": .string(menuOpen ? "x" : "menu"), "aria-label": .string(menuOpen ? "Close menu" : "Open menu"), "action": "menu-toggle", "local": true],
                            modifier: nil,
                            onEvent: { _, _ in menuOpen.toggle() }
                        )
                    }
                    brand
                    if props.string("variant", default: "mobile") == "desktop" { navigation }
                    Spacer(minLength: theme.density.spacing.space0)
                    if props.bool("showSearch") {
                        InputRenderer(
                            props: ["inputType": "text", "value": .string(query), "placeholder": .string(props.string("searchPlaceholder", default: "Search")), "onChange": "header-search", "local": true],
                            modifier: nil,
                            onEvent: { _, payload in query = AtomKit.scalar(payload?.dictValue?["actionPayload"]?.dictValue?["value"]) ?? "" }
                        )
                    }
                    AtomSlot(props.dictValue?["actions"], onEvent: onEvent)
                    if props.dictValue?["userAvatar"] != nil || !props.string("userName").isEmpty { avatar }
                }
                .padding(.horizontal, theme.density.spacing.space4)
                .padding(.vertical, look == "hero" || look == "editorial-banner" ? theme.density.spacing.space12 : theme.density.spacing.space3)
                .frame(minHeight: look == "compact-bar" ? theme.density.spacing.space12 + theme.density.spacing.space4 : nil)
                .background(theme.color.card)
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var brand: some View {
        let logo = props.dictValue?["logo"]?.stringValue ?? AtomKit.assetURL(props, "logoSrc")
        let name = props.string("brandName", default: "KFlow")
        let variant = look == "hero" || look == "editorial-banner" ? "h1" : (look == "breadcrumb" ? "body2" : "h5")
        let target = AtomKit.navigate(.dict(["href": .string(props.string("brandHref"))]))
        return HStack(spacing: theme.density.spacing.space2) {
            if !logo.isEmpty {
                ImageRenderer(props: ["src": .string(logo), "alt": .string(name), "fit": "contain"], modifier: nil, onEvent: onEvent)
                    .frame(height: theme.density.spacing.space8)
            }
            AtomKit.typo(name, variant, onEvent: onEvent)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !target.event.isEmpty { onEvent(target.event, eventEnvelope(props, payload: target.payload)) }
            else if let url = URL(string: target.href), url.scheme != nil { openURL(url) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(target.event.isEmpty && target.href.isEmpty ? [] : .isButton)
        .accessibilityLabel(name)
        .atomAction(target.event, props)
    }

    private var navigation: some View {
        let items = props.dictValue?["navigationItems"]?.arrayValue ?? []
        return HStack(spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                ButtonRenderer(
                    props: AtomKit.linkProps(props, item, [
                        "variant": item.bool("active") ? "secondary" : "ghost",
                        "size": "sm",
                        "label": .string(item.string("label")),
                        "leftIcon": .string(item.string("icon")),
                    ]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        }
    }

    private var avatar: some View {
        let user = props.dictValue?["userAvatar"]
        let name = props.string("userName")
        return AvatarRenderer(
            props: [
                "src": .string(user.map { AtomKit.assetURL($0, "src") } ?? ""),
                "name": .string(name),
                "initials": .string(user?.string("initials") ?? ""),
                "alt": .string(user?.string("alt") ?? name),
                "size": "sm",
            ],
            modifier: nil,
            onEvent: onEvent
        )
    }
}

@ViewBuilder
func HeaderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(HeaderMoleculeView(props: props, onEvent: onEvent))
}
