import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct StatBadgeMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let size = props.string("size", default: "md")
        let compact = size == "sm" || size == "xs"
        let hasValue = props.dictValue?["value"] != nil
        let number = Int(AtomKit.text(props, "value")) ?? 0
        let format = props.string("format", default: "number")
        let asset = AtomKit.assetURL(props, "iconUrl").isEmpty ? AtomKit.assetURL(props, "assetUrl") : AtomKit.assetURL(props, "iconUrl")
        let tint = tone(props.string("variant", default: "default"))
        let inner: CGFloat = size == "lg" ? theme.density.spacing.space4 : (compact ? theme.density.spacing.space2 : theme.density.spacing.space3)
        HStack(spacing: theme.density.spacing.space2) {
            if !asset.isEmpty {
                ImageRenderer(props: ["src": .string(asset), "fit": "contain"], modifier: nil, onEvent: onEvent)
                    .frame(width: theme.density.spacing.space4, height: theme.density.spacing.space4)
            } else if !props.string("icon").isEmpty {
                AtomKit.icon(props.string("icon"), "sm", onEvent: onEvent)
            }
            AtomKit.typo(props.string("label"), "caption", color: "muted", weight: "medium", onEvent: onEvent)
            if hasValue {
                switch format {
                case "hearts", "bar":
                    if props.dictValue?["max"] != nil {
                        HealthBarRenderer(props: AtomKit.child(props, ["current": .int(number), "max": .double(props.float("max")), "format": .string(format), "size": .string(size == "lg" ? "md" : "sm")]), modifier: nil, onEvent: onEvent)
                    }
                case "text":
                    AtomKit.typo(AtomKit.text(props, "value"), "body2", weight: "bold", onEvent: onEvent)
                default:
                    ScoreDisplayRenderer(props: AtomKit.child(props, ["value": .int(number), "size": .string(size == "lg" ? "md" : "sm")]), modifier: nil, onEvent: onEvent)
                }
            }
        }
        .padding(.horizontal, inner)
        .padding(.vertical, inner / 2)
        .background(tint.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(tint.opacity(0.4), lineWidth: theme.geometry.borderStandard))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }

    private func tone(_ variant: String) -> Color {
        switch variant {
        case "primary": return theme.color.primary
        case "success": return theme.color.success
        case "warning": return theme.color.warning
        case "danger": return theme.color.error
        default: return theme.color.border
        }
    }
}

@ViewBuilder
func StatBadgeRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StatBadgeMoleculeView(props: props, onEvent: onEvent))
}
