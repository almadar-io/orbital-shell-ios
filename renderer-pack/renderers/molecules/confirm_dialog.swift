import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ConfirmDialogMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var variant: String { props.string("variant", default: "danger") }

    private var look: (icon: String, tone: String, confirm: String) {
        switch variant {
        case "warning": return ("alert-triangle", "warning", "warning")
        case "info": return ("check", "info", "primary")
        case "default": return ("check", "primary", "primary")
        default: return ("trash-2", "error", "danger")
        }
    }

    private var width: CGFloat? {
        switch props.string("size", default: "sm") {
        case "md": return AlmadarSizes.maxWMd
        case "lg": return AlmadarSizes.maxWLg
        case "xl": return AlmadarSizes.maxWXl
        case "full": return nil
        default: return AlmadarSizes.maxWSm
        }
    }

    var body: some View {
        if props.bool("isOpen", default: true) {
            let loading = props.bool("isLoading")
            let error = AtomKit.errorText(props)
            let tint = AtomKit.tone(theme, look.tone)
            let message = props.dictValue?["message"] ?? props.dictValue?["description"]
            VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                HStack(alignment: .top, spacing: theme.density.spacing.space4) {
                    AtomKit.icon(look.icon, "lg", color: look.tone, onEvent: onEvent)
                        .frame(width: theme.density.spacing.space12, height: theme.density.spacing.space12)
                        .background(tint.opacity(0.15))
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        AtomKit.typo(props.string("title"), "h5", onEvent: onEvent)
                        if let message = message {
                            if let text = message.stringValue {
                                AtomKit.typo(text, "body2", color: "muted", onEvent: onEvent)
                            } else {
                                RenderChild(message, onEvent: onEvent)
                            }
                        }
                        if !error.isEmpty { AtomKit.typo(error, "body2", color: "error", onEvent: onEvent) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: theme.density.spacing.space3) {
                    Spacer(minLength: theme.density.spacing.space0)
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "secondary", "label": .string(props.string("cancelText", default: props.string("cancelLabel", default: "Cancel"))), "disabled": .bool(loading), "action": .string(props.string("onClose"))]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": .string(look.confirm), "label": .string(loading ? "Loading..." : props.string("confirmText", default: props.string("confirmLabel", default: "Confirm"))), "isLoading": .bool(loading), "action": .string(props.string("onConfirm"))]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
            .atomSurface(theme, padding: theme.density.dialogPadding)
            .atomShadow(theme.elevation.dialogElevation)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

@ViewBuilder
func ConfirmDialogRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ConfirmDialogMoleculeView(props: props, onEvent: onEvent))
}
