import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct WizardNavigationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func button(_ variant: String, _ label: String, _ event: String, icon: String, trailing: Bool, disabled: Bool) -> some View {
        var values: [String: AnyCodable] = [
            "variant": .string(variant),
            "label": .string(label),
            "action": .string(event),
            "local": .bool(event.hasPrefix(AtomKit.localEvent)),
            "disabled": .bool(disabled),
            "actionPayload": ["currentStep": .int(props.int("currentStep")), "totalSteps": .int(props.int("totalSteps"))],
        ]
        if !icon.isEmpty { values[trailing ? "rightIcon" : "leftIcon"] = .string(icon) }
        return ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: onEvent)
    }

    var body: some View {
        let current = props.int("currentStep")
        let total = props.int("totalSteps")
        let valid = props.bool("isValid", default: true)
        let compact = props.bool("compact")
        let last = current == total - 1
        VStack(spacing: theme.density.spacing.space0) {
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            HStack(spacing: theme.density.spacing.space2) {
                if props.bool("showBack", default: true) {
                    button("secondary", props.string("backLabel", default: "Back"), props.string("onBack", default: "WIZARD_BACK"), icon: "chevron-left", trailing: false, disabled: current == 0)
                }
                Spacer(minLength: theme.density.spacing.space2)
                AtomKit.typo("Step \(current + 1) of \(total)", "caption", color: "muted", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space2)
                if last && props.bool("showComplete", default: true) {
                    button("primary", props.string("completeLabel", default: "Complete"), props.string("onComplete", default: "WIZARD_COMPLETE"), icon: "", trailing: false, disabled: !valid)
                } else if !last && props.bool("showNext", default: true) {
                    button("primary", props.string("nextLabel", default: "Next"), props.string("onNext", default: "WIZARD_NEXT"), icon: "chevron-right", trailing: true, disabled: !valid)
                }
            }
            .padding(.horizontal, compact ? theme.density.spacing.space4 : theme.density.spacing.space6)
            .padding(.vertical, compact ? theme.density.spacing.space2 : theme.density.spacing.space4)
        }
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func WizardNavigationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(WizardNavigationMoleculeView(props: props, onEvent: onEvent))
}
