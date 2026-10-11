import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct ModalSlotOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let closeKey = "CLOSE"
        let cancelKey = "CANCEL"
        let children = props.children()
        let title = props.string("title", default: children.first?.string("title") ?? "")
        if !children.isEmpty {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.typo(title, "h5", onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close", "action": .string(closeKey)]),
                        modifier: nil,
                        onEvent: { _, _ in
                            onEvent(closeKey, eventEnvelope(props))
                            onEvent(cancelKey, eventEnvelope(props))
                        }
                    )
                }
                .padding(theme.density.dialogPadding)
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                if props.bool("isLoading") {
                    SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
                } else {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
                        AtomChildren(props: props, key: "children", onEvent: onEvent)
                    }
                    .padding(theme.density.dialogPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(theme.color.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            .atomShadow(theme.elevation.dialogElevation)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }
}

@ViewBuilder
func ModalSlotRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ModalSlotOrganismView(props: props, onEvent: onEvent))
}
