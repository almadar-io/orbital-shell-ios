import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ActionTileMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var action: AnyCodable { props.dictValue?["action"] ?? .null }

    private func category(_ key: String) -> Color? {
        let given = props.dictValue?["categoryColors"]?.dictValue?[action.string("category")]?.string(key) ?? ""
        return given.isEmpty ? nil : AtomKit.cssColor(theme, given)
    }

    private func padding(_ size: String) -> (h: CGFloat, v: CGFloat) {
        switch size {
        case "sm": return (theme.density.spacing.space2, theme.density.spacing.space1)
        case "lg": return (theme.density.spacing.space4, theme.density.spacing.space3)
        default: return (theme.density.spacing.space3, theme.density.spacing.space2)
        }
    }

    private func iconVariant(_ size: String) -> String {
        switch size {
        case "sm": return "large"
        case "lg": return "h2"
        default: return "h3"
        }
    }

    private func labelVariant(_ size: String) -> String {
        switch size {
        case "sm": return "caption"
        case "lg": return "body1"
        default: return "small"
        }
    }

    private var payload: String {
        (try? JSONEncoder().encode(action)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    var body: some View {
        let size = props.string("size", default: "md")
        let disabled = props.bool("disabled")
        let pad = padding(size)
        let shape = AtomKit.shape(theme, .container)
        let iconUrl = AtomKit.assetURL(action, "iconUrl")
        let tile = VStack(spacing: theme.density.spacing.space1) {
            if !iconUrl.isEmpty {
                ImageRenderer(props: AtomKit.child(props, ["src": .string(iconUrl), "alt": "", "fit": "contain"]), modifier: nil, onEvent: onEvent)
                    .frame(width: theme.density.spacing.space8, height: theme.density.spacing.space8)
            } else {
                AtomKit.typo(action.string("iconEmoji", default: "\u{2726}"), iconVariant(size), onEvent: onEvent)
            }
            AtomKit.typo(action.string("name"), labelVariant(size), weight: "medium", onEvent: onEvent)
        }
        .padding(.horizontal, pad.h)
        .padding(.vertical, pad.v)
        .background(disabled ? theme.color.muted : (category("bg") ?? theme.color.card))
        .clipShape(shape)
        .overlay(shape.stroke(disabled ? theme.color.border : (category("border") ?? theme.color.border), lineWidth: theme.geometry.borderHeavy))
        .opacity(disabled ? 0.4 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(action.string("name"))
        if disabled {
            tile
        } else {
            tile.draggable(payload)
        }
    }
}

@ViewBuilder
func ActionTileRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ActionTileMoleculeView(props: props, onEvent: onEvent))
}
