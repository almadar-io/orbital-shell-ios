import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct NotificationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var dismissed = false

    var body: some View {
        let variant = props.string("variant", default: "info")
        let tone = AtomKit.tone(theme, variant)
        let dismissEvent = props.string("dismissEvent")
        let actionEvent = props.string("actionEvent")
        let actionLabel = props.string("actionLabel")
        let hasAction = !actionLabel.isEmpty && !actionEvent.isEmpty
        let icon = variant == "success" ? "check-circle" : (variant == "error" ? "alert-circle" : (variant == "warning" ? "alert-triangle" : "info"))
        let duration = props.float("duration", default: 5000)
        if !dismissed {
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                AtomKit.icon(icon, "md", color: variant, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h6", onEvent: onEvent) }
                    AtomKit.typo(props.string("message"), "small", onEvent: onEvent)
                    if hasAction {
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "label": .string(actionLabel), "action": .string(actionEvent)]),
                            modifier: nil,
                            onEvent: { _, _ in onEvent(actionEvent, eventEnvelope(props)) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let badge = AtomKit.scalar(props.dictValue?["badge"]) {
                    AtomKit.badge(badge, "default", onEvent: onEvent)
                }
                if props.bool("dismissible", default: true) {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Dismiss toast", "action": .string(AtomKit.eventOrLocal(dismissEvent)), "local": .bool(dismissEvent.isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in dismiss(dismissEvent) }
                    )
                }
            }
            .padding(theme.density.cardPaddingSm)
            .background(theme.color.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(alignment: .leading) {
                Rectangle().fill(tone).frame(width: theme.geometry.borderHeavy * 2)
            }
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(tone, lineWidth: theme.geometry.borderStandard))
            .atomShadow(theme.elevation.toastElevation)
            .accessibilityElement(children: .contain)
            .task(id: duration) {
                guard duration > 0, !hasAction, !dismissEvent.isEmpty else { return }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000))
                if !Task.isCancelled { dismiss(dismissEvent) }
            }
        }
    }

    private func dismiss(_ event: String) {
        dismissed = true
        if !event.isEmpty { onEvent(event, eventEnvelope(props)) }
    }
}

@ViewBuilder
func NotificationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(NotificationMoleculeView(props: props, onEvent: onEvent))
}
