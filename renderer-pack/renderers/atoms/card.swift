import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct CardAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let title = props.string("title")
        let subtitle = props.string("subtitle")
        let action = props.string("action")
        let look = props.string("look", default: "elevated")
        let variant = props.string("variant", default: "bordered")
        let padding = padding(look: look)
        let radius: CGFloat = look == "borderless-divider" ? theme.density.spacing.space0 : (look == "chip" ? theme.geometry.radiusPill : (look == "invoice" ? theme.geometry.radiusInteractive : theme.geometry.radiusContainer))
        let role: AtomRole = look == "chip" ? .pill : .container
        let shape = AtomKit.shape(theme, role, radius: radius)
        let flat = look != "elevated"
        let raised = variant == "elevated" || variant == "interactive"
        let card = VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if !title.isEmpty || !subtitle.isEmpty {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    if !title.isEmpty {
                        AtomKit.headingText(theme, title, "lg").foregroundColor(theme.color.cardForeground)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(AtomKit.font(theme, "sm")).foregroundColor(theme.color.mutedForeground)
                    }
                }
                .padding(.bottom, theme.density.spacing.space2)
            }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .atomSurfaceImage(theme, role, radius: radius)
        .background(theme.color.card)
        .atomBackdrop(theme, role, radius: radius)
        .clipShape(shape)
        .atomBorder(theme, role, radius: radius, color: look == "borderless-divider" ? AtomKit.clear(theme) : theme.color.border, width: look == "invoice" ? theme.geometry.borderHeavy : theme.geometry.borderStandard, style: look == "ticket" ? .dashed : nil)
        .overlay(alignment: .bottom) {
            if look == "borderless-divider" {
                Rectangle().fill(theme.color.border).frame(height: theme.geometry.borderHairline)
            }
        }
        .overlay {
            if props.bool("loading") {
                SpinnerRenderer(props: ["overlay": .bool(true)], modifier: nil, onEvent: onEvent)
            }
        }
        .atomElevation(theme, role, radius: radius, elevation(raised: raised, flat: flat))
        if action.isEmpty {
            card
        } else {
            card
                .contentShape(shape)
                .onTapGesture { onEvent(action, eventEnvelope(props)) }
                .accessibilityAddTraits(.isButton)
                .atomAction(action, props)
        }
    }

    private func padding(look: String) -> CGFloat {
        if look == "tile-image-first" { return theme.density.spacing.space0 }
        switch props.string("padding", default: "md") {
        case "none": return theme.density.spacing.space0
        case "sm": return theme.density.cardPaddingSm
        case "lg": return theme.density.cardPaddingLg
        default: return theme.density.cardPaddingMd
        }
    }

    private func elevation(raised: Bool, flat: Bool) -> AlmadarTheme.ElevationScale.Shadow {
        switch props.string("shadow") {
        case "none": return AtomKit.noShadow(theme)
        case "sm": return theme.elevation.cardElevation
        case "md": return theme.elevation.popoverElevation
        case "lg": return theme.elevation.dialogElevation
        default: return raised && !flat ? theme.elevation.cardElevation : AtomKit.noShadow(theme)
        }
    }
}

@ViewBuilder
func CardRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CardAtomView(props: props, onEvent: onEvent))
}
