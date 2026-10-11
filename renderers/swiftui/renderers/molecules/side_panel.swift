import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SidePanelMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let closeEvent = props.string("closeEvent", default: props.string("onClose"))
        let right = props.string("position", default: "right") == "right"
        if props.bool("isOpen") {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.typo(props.string("title"), "h6", onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close panel", "action": .string(AtomKit.eventOrLocal(closeEvent)), "local": .bool(closeEvent.isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in if !closeEvent.isEmpty { onEvent(closeEvent, eventEnvelope(props)) } }
                    )
                }
                .padding(theme.density.spacing.space4)
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
                .padding(theme.density.spacing.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
            .background(theme.color.card)
            .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
            .overlay(alignment: right ? .leading : .trailing) {
                Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderHeavy)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(props.string("title"))
        }
    }
}

@ViewBuilder
func SidePanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SidePanelMoleculeView(props: props, onEvent: onEvent))
}
