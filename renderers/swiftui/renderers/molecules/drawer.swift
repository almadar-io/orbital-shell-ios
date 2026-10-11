import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DrawerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if props.bool("isOpen", default: true) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                if props.dictValue?["title"] != nil || props.bool("showCloseButton", default: true) {
                    HStack(spacing: theme.density.spacing.space2) {
                        AtomSlot(props.dictValue?["title"], variant: "h4", onEvent: onEvent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if props.bool("showCloseButton", default: true) {
                            ButtonRenderer(
                                props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close", "action": .string(props.string("closeEvent"))]),
                                modifier: nil,
                                onEvent: onEvent
                            )
                        }
                    }
                    .padding(theme.density.spacing.space4)
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                }
                VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.density.spacing.space4)
                if props.dictValue?["footer"] != nil {
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    AtomSlot(props.dictValue?["footer"], onEvent: onEvent)
                        .padding(theme.density.spacing.space4)
                }
            }
            .frame(maxWidth: width, maxHeight: .infinity, alignment: .topLeading)
            .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
            .background(theme.color.card)
            .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
            .overlay(alignment: props.string("position", default: "right") == "left" ? .trailing : .leading) {
                Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderStandard)
            }
            .atomShadow(theme.elevation.dialogElevation)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private var width: CGFloat {
        let requested = props.string("width", default: "md")
        if let explicit = Double(requested.replacingOccurrences(of: "px", with: "")) { return CGFloat(explicit) }
        if requested == "full" || sizeClass == .compact { return .infinity }
        switch requested {
        case "sm": return AlmadarSizes.w80
        case "lg": return AlmadarSizes.maxWLg
        case "xl": return AlmadarSizes.maxW2xl
        default: return AlmadarSizes.w96
        }
    }
}

@ViewBuilder
func DrawerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DrawerMoleculeView(props: props, onEvent: onEvent))
}
