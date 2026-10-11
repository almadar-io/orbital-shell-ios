import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct CommitRowMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var sha: String { props.string("sha") }

    private func kindIcon(_ kind: String) -> String {
        switch kind {
        case "user": return "user"
        case "agent": return "sparkles"
        case "restore": return "rotate-ccw"
        case "undo": return "undo"
        case "redo": return "redo"
        case "snapshot": return "camera"
        case "merge": return "git-commit"
        default: return ""
        }
    }

    var body: some View {
        let selected = props.bool("selected")
        let select = props.string("selectEvent")
        let restore = props.string("restoreEvent")
        HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            summary
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if !select.isEmpty { onEvent(select, eventEnvelope(props, payload: ["sha": .string(sha)])) } }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .atomAction(select, props)
            if !restore.isEmpty && !props.bool("current") {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "rotate-ccw", "label": "Restore", "action": .string(restore), "actionPayload": ["sha": .string(sha)]]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        }
        .padding(.horizontal, theme.density.spacing.space2)
        .padding(.vertical, theme.density.spacing.space1)
        .background(selected ? theme.color.muted : AtomKit.clear(theme))
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        .verificationContainer(VerificationIds.row(sha))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space1) {
                if !kindIcon(props.string("kind")).isEmpty { AtomKit.icon(kindIcon(props.string("kind")), "xs", color: "muted", onEvent: onEvent) }
                AtomKit.typo(props.string("message"), "caption", truncate: true, onEvent: onEvent)
            }
            AtomFlowLayout(spacing: theme.density.spacing.space1) {
                AtomMonoText(sha.count > 7 ? String(sha.prefix(7)) : sha, size: "xs", color: theme.color.mutedForeground)
                if !props.string("author").isEmpty { AtomKit.typo(props.string("author"), "caption", color: "muted", onEvent: onEvent) }
                if !props.string("timestamp").isEmpty { AtomKit.typo(props.string("timestamp"), "caption", color: "muted", onEvent: onEvent) }
                if props.dictValue?["additions"] != nil { AtomKit.badge("+\(props.int("additions"))", "success", onEvent: onEvent) }
                if props.dictValue?["deletions"] != nil { AtomKit.badge("-\(props.int("deletions"))", "error", onEvent: onEvent) }
                if props.bool("current") { AtomKit.badge("Current", "default", onEvent: onEvent) }
            }
        }
    }
}

@ViewBuilder
func CommitRowRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CommitRowMoleculeView(props: props, onEvent: onEvent))
}
