import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AvatarAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let sizeToken = props.string("size", default: "md")
        let diameter = diameter(sizeToken)
        let action = props.string("action")
        let name = props.string("name")
        let accessibleName = props.string("alt", default: name.isEmpty ? props.string("initials") : name)
        let avatar = ZStack(alignment: .bottomTrailing) {
            face(diameter: diameter, sizeToken: sizeToken)
                .frame(width: diameter, height: diameter)
                .atomClip(theme, .pill, radius: diameter / 2)
                .atomBorder(theme, .pill, radius: diameter / 2, color: theme.color.border, width: theme.geometry.borderStandard)
            if !props.string("status").isEmpty {
                AtomKit.shape(theme, .pill, radius: diameter / 8)
                    .fill(AtomKit.statusColor(theme, props.string("status")))
                    .frame(width: diameter / 4, height: diameter / 4)
                    .atomBorder(theme, .pill, radius: diameter / 8, color: theme.color.card, width: theme.geometry.borderHeavy)
                    .accessibilityLabel(Text(props.string("status")))
            }
        }
        .overlay(alignment: .topTrailing) {
            let badge = AtomKit.text(props, "badge")
            if !badge.isEmpty {
                Text(badge)
                    .font(AtomKit.font(theme, "xs", .bold))
                    .foregroundColor(theme.color.primaryForeground)
                    .padding(.horizontal, theme.density.spacing.space1)
                    .background(theme.color.primary)
                    .atomClip(theme, .pill)
                    .atomBorder(theme, .pill, color: theme.color.card, width: theme.geometry.borderHeavy)
                    .offset(x: theme.density.spacing.space1, y: -theme.density.spacing.space1)
            }
        }
        if action.isEmpty {
            avatar.accessibilityElement(children: .combine).accessibilityLabel(Text(accessibleName))
        } else {
            Button(action: { onEvent(action, eventEnvelope(props)) }) { avatar }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(accessibleName))
                .atomAction(action, props)
        }
    }

    @ViewBuilder
    private func face(diameter: CGFloat, sizeToken: String) -> some View {
        let src = AtomKit.assetURL(props, "src")
        let name = props.string("name")
        let initials = props.string("initials", default: AtomKit.initials(name))
        let glyph = props.string("icon", default: "user")
        let fontKey = sizeToken == "xs" ? "xs" : (sizeToken == "sm" ? "sm" : (sizeToken == "lg" ? "lg" : (sizeToken == "xl" ? "xl" : "base")))
        if !src.isEmpty {
            AsyncImage(url: URL(string: src)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    fallback(initials: initials, glyph: glyph, fontKey: fontKey)
                } else {
                    theme.color.muted
                }
            }
        } else {
            fallback(initials: initials, glyph: glyph, fontKey: fontKey)
        }
    }

    @ViewBuilder
    private func fallback(initials: String, glyph: String, fontKey: String) -> some View {
        if !initials.isEmpty && props.string("icon").isEmpty {
            theme.color.primary.overlay(
                Text(String(initials.prefix(2)).uppercased())
                    .font(AtomKit.font(theme, fontKey, .bold))
                    .foregroundColor(theme.color.primaryForeground)
            )
        } else {
            theme.color.muted.overlay(
                Image(systemName: IconMap.resolve(glyph)).foregroundColor(theme.color.foreground)
            )
        }
    }

    private func diameter(_ token: String) -> CGFloat {
        let spacing = theme.density.spacing
        switch token {
        case "xs": return spacing.space6
        case "sm": return spacing.space8
        case "lg": return spacing.space12
        case "xl": return spacing.space8 * 2
        default: return spacing.space10
        }
    }
}

@ViewBuilder
func AvatarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AvatarAtomView(props: props, onEvent: onEvent))
}
