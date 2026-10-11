import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ViolationAlertMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var dismissed = false

    var body: some View {
        let violation = props.dictValue?["violation"] ?? .dict([:])
        let kind = violation.string("actionType", default: "measure")
        let severity = props.string("severity", default: kind == "measure" ? "warning" : "error")
        let tone = severity == "error" ? theme.color.error : theme.color.warning
        let compact = props.bool("compact")
        let message = violation.string("message", default: props.string("message", default: "Violation"))
        let citation = "\(violation.string("law")) Art. \(violation.string("article"))"
        let icon = kind == "admin" ? "alert-circle" : (kind == "penalty" ? "shield-alert" : "alert-triangle")
        if !dismissed {
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                AtomKit.icon(icon, "md", color: severity, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomKit.typo(citation, "body2", weight: "semibold", onEvent: onEvent)
                    if !compact {
                        AtomKit.typo(kindLabel(kind), "caption", color: "muted", onEvent: onEvent)
                    }
                    AtomKit.typo(message, "body2", onEvent: onEvent)
                    if !compact {
                        detail("Admin:", violation.string("adminAction"))
                        detail("Penalty:", violation.string("penaltyAction"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if props.bool("dismissible") {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Dismiss", "action": .string(AtomKit.localEvent), "local": true]),
                        modifier: nil,
                        onEvent: { _, _ in dismissed = true }
                    )
                }
            }
            .padding(compact ? theme.density.spacing.space2 : theme.density.spacing.space4)
            .background(tone.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(tone, lineWidth: theme.geometry.borderStandard))
            .accessibilityElement(children: .contain)
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "admin": return "Administrative Action"
        case "penalty": return "Penalty Proceedings"
        default: return "Corrective Measure"
        }
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(spacing: theme.density.spacing.space1) {
                AtomKit.typo(label, "caption", color: "muted", onEvent: onEvent)
                AtomKit.typo(value, "caption", weight: "semibold", onEvent: onEvent)
            }
        }
    }
}

@ViewBuilder
func ViolationAlertRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ViolationAlertMoleculeView(props: props, onEvent: onEvent))
}
