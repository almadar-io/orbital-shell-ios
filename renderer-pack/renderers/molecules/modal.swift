import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ModalMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    /// A host that composes the body in SwiftUI (not as nodes) hands it here; `children` still render first.
    let content: AnyView?
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void, content: AnyView? = nil) {
        self.props = props
        self.onEvent = onEvent
        self.content = content
    }

    var body: some View {
        if props.bool("isOpen", default: true) {
            let title = props.string("title")
            let framedContent = VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                if !title.isEmpty || props.bool("showCloseButton", default: true) {
                    HStack(spacing: theme.density.spacing.space2) {
                        AtomKit.typo(title, "h4", onEvent: onEvent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if props.bool("showCloseButton", default: true) {
                            ButtonRenderer(
                                props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close", "action": .string(props.string("closeEvent")), "local": .bool(props.bool("local"))]),
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
                    if let content = content { content }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(theme.density.dialogPadding)
                if props.dictValue?["footer"] != nil {
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    HStack(spacing: theme.density.spacing.space2) {
                        Spacer(minLength: theme.density.spacing.space0)
                        AtomSlot(props.dictValue?["footer"], onEvent: onEvent)
                    }
                    .padding(theme.density.spacing.space4)
                }
            }
            ViewThatFits(in: .horizontal) {
                framed(framedContent, floor: widthFloor)
                framed(framedContent, floor: nil)
            }
        }
    }

    private func framed<Content: View>(_ content: Content, floor: CGFloat?) -> some View {
        let full = props.string("look", default: "centered-card") == "full-screen" || props.string("size", default: "md") == "full"
        return content
            .frame(minWidth: floor, maxWidth: width, alignment: .topLeading)
            .atomSurfaceImage(theme, .container, radius: full ? theme.density.spacing.space0 : theme.geometry.radiusContainer)
            .background(theme.color.card)
            .atomBackdrop(theme, .container, radius: full ? theme.density.spacing.space0 : theme.geometry.radiusContainer)
            .clipShape(RoundedRectangle(cornerRadius: full ? theme.density.spacing.space0 : theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: full ? theme.density.spacing.space0 : theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            .atomShadow(theme.elevation.dialogElevation)
            .modifier(AlmadarSurfaceEnter(shape: "modalEnter", timing: .modal))
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
    }

    private var widthFloor: CGFloat? {
        if sizeClass == .compact || props.string("look", default: "centered-card") != "centered-card" { return nil }
        switch props.string("size", default: "md") {
        case "sm": return AlmadarSizes.minWModalSm
        case "lg": return AlmadarSizes.minWModalLg
        case "xl": return AlmadarSizes.minWModalXl
        case "full": return nil
        default: return AlmadarSizes.minWModalMd
        }
    }

    private var width: CGFloat {
        if sizeClass == .compact || props.string("look", default: "centered-card") != "centered-card" { return .infinity }
        switch props.string("size", default: "md") {
        case "sm": return AlmadarSizes.maxWMd
        case "lg": return AlmadarSizes.maxW3xl
        case "xl": return AlmadarSizes.maxW5xl
        case "full": return .infinity
        default: return AlmadarSizes.maxW2xl
        }
    }
}

@ViewBuilder
func ModalRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ModalMoleculeView(props: props, onEvent: onEvent))
}
