import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ChangeListMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var items: [AnyCodable] {
        (props.dictValue?["changes"]?.arrayValue ?? []).filter { item in
            !item.string("title").isEmpty && ["added", "modified", "removed"].contains(item.string("type"))
        }
    }

    private func style(_ type: String) -> (icon: String, tone: String, label: String) {
        switch type {
        case "added": return ("plus-circle", "success", "Added")
        case "removed": return ("minus-circle", "error", "Removed")
        default: return ("edit-3", "warning", "Modified")
        }
    }

    var body: some View {
        let list = items
        if list.isEmpty {
            AtomKit.typo("No changes in this version.", "body2", color: "muted", align: "center", onEvent: onEvent)
                .padding(.vertical, theme.density.spacing.space6)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                ForEach(list.indices, id: \.self) { index in
                    entry(list[index])
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func entry(_ change: AnyCodable) -> some View {
        let look = style(change.string("type"))
        let inspect = props.string("inspectEvent")
        return VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon(look.icon, "sm", color: look.tone, onEvent: onEvent)
                AtomKit.typo(change.string("title"), "body2", weight: "semibold", truncate: true, onEvent: onEvent)
                AtomKit.badge(look.label, look.tone, onEvent: onEvent)
            }
            if !change.string("description").isEmpty {
                AtomKit.typo(change.string("description"), "caption", color: "muted", onEvent: onEvent)
            }
            if change.string("type") == "modified" && (!change.string("before").isEmpty || !change.string("after").isEmpty) {
                HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                    if !change.string("before").isEmpty { side("Before", change.string("before"), tone: "error") }
                    if !change.string("after").isEmpty { side("After", change.string("after"), tone: "success") }
                }
            }
            if !inspect.isEmpty {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "external-link", "label": "Inspect", "action": .string(inspect), "actionPayload": ["title": .string(change.string("title")), "type": .string(change.string("type"))]]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme, padding: theme.density.spacing.space3)
        .accessibilityElement(children: .contain)
    }

    private func side(_ title: String, _ text: String, tone: String) -> some View {
        let tint = AtomKit.tone(theme, tone)
        return VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomKit.typo(title, "caption", color: "muted", weight: "semibold", onEvent: onEvent)
            AtomMonoText(text, size: "xs")
        }
        .padding(theme.density.spacing.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(tint.opacity(0.2), lineWidth: theme.geometry.borderStandard))
    }
}

@ViewBuilder
func ChangeListRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ChangeListMoleculeView(props: props, onEvent: onEvent))
}
