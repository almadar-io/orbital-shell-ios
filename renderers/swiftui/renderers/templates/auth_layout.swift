import Foundation
import SwiftUI

// tier: templates — CONTENT ONLY

struct AuthLayoutTemplateView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var appName: String { props.string("appName", default: "My App") }

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= AlmadarBreakpoints.lg
            HStack(spacing: theme.density.spacing.space0) {
                if props.bool("showBranding", default: true) && wide {
                    branding.frame(width: proxy.size.width / 2)
                }
                form(wide: wide, roomy: proxy.size.width >= AlmadarBreakpoints.sm)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var branding: some View {
        ZStack(alignment: .topLeading) {
            theme.color.primary
            if !AtomKit.assetURL(props, "backgroundImage").isEmpty {
                ImageRenderer(props: ["src": .string(AtomKit.assetURL(props, "backgroundImage")), "alt": "", "fit": "cover"], modifier: nil, onEvent: onEvent)
            }
            LinearGradient(colors: [theme.color.primary.opacity(0.9), theme.color.primaryHover.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(theme.color.primaryForeground.opacity(0.05))
                .frame(width: AlmadarSizes.w96, height: AlmadarSizes.w96)
                .offset(x: AlmadarSizes.w32, y: AlmadarSizes.w32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            Circle()
                .fill(theme.color.primaryForeground.opacity(0.05))
                .frame(width: AlmadarSizes.w64, height: AlmadarSizes.w64)
                .offset(x: AlmadarSizes.w16, y: -AlmadarSizes.w16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                brand(onPrimary: true)
                Spacer(minLength: theme.density.spacing.space0)
                if let custom = props.dictValue?["brandingContent"] {
                    RenderChild(custom, onEvent: onEvent)
                } else {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                        AtomKit.typo("Welcome to \(appName)", "h1", color: "inherit", onEvent: onEvent)
                        AtomKit.typo("Sign in to access your dashboard and manage your account.", "large", color: "inherit", onEvent: onEvent)
                            .opacity(0.8)
                            .frame(maxWidth: AlmadarSizes.maxWMd, alignment: .leading)
                    }
                    .foregroundColor(theme.color.primaryForeground)
                }
                Spacer(minLength: theme.density.spacing.space0)
            }
            .padding(theme.density.spacing.space12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipped()
    }

    private func form(wide: Bool, roomy: Bool) -> some View {
        ScrollView {
            VStack(spacing: theme.density.spacing.space0) {
                if !wide {
                    brand(onPrimary: false)
                        .padding(.bottom, theme.density.spacing.space8)
                }
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            }
            .frame(maxWidth: AlmadarSizes.maxWMd)
            .padding(roomy ? theme.density.spacing.space12 : theme.density.spacing.space6)
            .frame(maxWidth: .infinity)
        }
        .background(theme.color.background)
    }

    @ViewBuilder
    private func brand(onPrimary: Bool) -> some View {
        HStack(spacing: theme.density.spacing.space3) {
            if let logo = props.dictValue?["logo"] {
                RenderChild(logo, onEvent: onEvent)
            } else {
                AtomKit.typo(String(appName.prefix(1)).uppercased(), "large", color: "inherit", weight: "bold", onEvent: onEvent)
                    .foregroundColor(theme.color.primaryForeground)
                    .frame(width: theme.density.spacing.space10, height: theme.density.spacing.space10)
                    .background(onPrimary ? theme.color.primaryForeground.opacity(0.2) : theme.color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            }
            AtomKit.typo(appName, "h3", color: onPrimary ? "inherit" : "primary", onEvent: onEvent)
                .foregroundColor(onPrimary ? theme.color.primaryForeground : theme.color.foreground)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEvent(AtomKit.navigateEvent, eventEnvelope(props, payload: ["href": "/", "url": "/"])) }
        .accessibilityAddTraits(.isButton)
        .atomAction(AtomKit.navigateEvent, props)
    }
}

@ViewBuilder
func AuthLayoutRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AuthLayoutTemplateView(props: props, onEvent: onEvent))
}
