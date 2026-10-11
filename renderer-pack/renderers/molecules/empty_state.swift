import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct EmptyStateMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let variant = props.string("variant")
        let look = props.string("look", default: "icon-only")
        let destructive = props.bool("destructive") || variant == "error"
        let success = variant == "success"
        let iconName = alias(props.string("icon"))
        let title = props.string("title", default: props.string("message", default: "No items"))
        let description = props.string("description")
        let actionLabel = props.string("actionLabel")
        let actionEvent = props.string("actionEvent")
        let tint = destructive ? "error" : (success ? "success" : "muted")
        let halo = destructive ? theme.color.error.opacity(0.1) : (success ? theme.color.success.opacity(0.1) : theme.color.muted)
        VStack(spacing: theme.density.spacing.space2) {
            if !iconName.isEmpty && look != "text-only" {
                AtomKit.icon(iconName, look == "icon-only" ? "lg" : "xl", color: tint, onEvent: onEvent)
                    .padding(theme.density.spacing.space3)
                    .background(halo)
                    .clipShape(Circle())
                    .padding(.bottom, theme.density.spacing.space2)
            }
            AtomKit.typo(title, "h3", color: destructive ? "error" : (success ? "success" : "primary"), align: "center", onEvent: onEvent)
            if !description.isEmpty {
                AtomKit.typo(description, "small", color: "muted", align: "center", onEvent: onEvent)
            }
            if !actionLabel.isEmpty && !actionEvent.isEmpty {
                ButtonRenderer(props: AtomKit.child(props, ["label": .string(actionLabel), "variant": destructive ? "danger" : "primary", "action": .string(actionEvent)]), modifier: nil, onEvent: onEvent)
                    .padding(.top, theme.density.spacing.space3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.density.spacing.space8)
        .accessibilityElement(children: .contain)
    }

    private func alias(_ name: String) -> String {
        switch name {
        case "check": return "check-circle"
        case "error": return "x-circle"
        case "warning": return "alert-circle"
        default: return name
        }
    }
}

@ViewBuilder
func EmptyStateRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(EmptyStateMoleculeView(props: props, onEvent: onEvent))
}
