import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct WizardContainerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var internalStep = 0

    private var steps: [AnyCodable] { props.dictValue?["steps"]?.arrayValue ?? [] }

    private var current: Int {
        var index = internalStep
        if let raw = props.dictValue?["currentStep"], let parsed = Int(AtomKit.scalar(raw) ?? "") { index = parsed }
        return min(max(index, 0), max(steps.count - 1, 0))
    }

    private var backToken: String { props.string("backEvent").isEmpty ? AtomKit.localEvent + ".back" : props.string("backEvent") }
    private var nextToken: String { props.string("nextEvent").isEmpty ? AtomKit.localEvent + ".next" : props.string("nextEvent") }
    private var completeToken: String { props.string("completeEvent").isEmpty ? AtomKit.localEvent + ".complete" : props.string("completeEvent") }

    private func titles() -> [AnyCodable] {
        steps.enumerated().map { index, step in
            let fallback = "Step \(index + 1) of \(steps.count)"
            let title = step.string("title", default: step.string("name", default: fallback))
            return .dict(["id": .string(step.string("id", default: step.string("tabId", default: "step-\(index)"))), "title": .string(title)])
        }
    }

    private func handle(_ event: String) {
        let index = current
        if event == backToken, index > 0, props.bool("allowBack", default: true) {
            if !props.string("backEvent").isEmpty { onEvent(event, eventEnvelope(props, payload: ["step": .int(index - 1)])) }
            internalStep = index - 1
        } else if event == nextToken || event == completeToken {
            let last = index == steps.count - 1
            if last {
                if !props.string("completeEvent").isEmpty { onEvent(props.string("completeEvent"), eventEnvelope(props, payload: ["step": .int(index)])) }
            } else {
                if !props.string("nextEvent").isEmpty { onEvent(props.string("nextEvent"), eventEnvelope(props, payload: ["step": .int(index + 1)])) }
                internalStep = index + 1
            }
        }
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let compact = props.bool("compact")
        let index = current
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body1", color: "error", align: "center", onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                if props.bool("showProgress", default: true) {
                    WizardProgressRenderer(
                        props: AtomKit.child(props, ["steps": .array(titles()), "currentStep": .int(index), "allowNavigation": .bool(props.bool("allowBack", default: true)), "compact": .bool(compact)]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
                if !compact && index < steps.count {
                    let step = steps[index]
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo(step.string("title", default: step.string("name", default: "Step \(index + 1) of \(steps.count)")), "h4", onEvent: onEvent)
                        if !step.string("description").isEmpty { AtomKit.typo(step.string("description"), "body2", color: "muted", onEvent: onEvent) }
                    }
                    .padding(.horizontal, theme.density.spacing.space6)
                    .padding(.vertical, theme.density.spacing.space3)
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                }
                if index < steps.count {
                    AtomSlot(steps[index].dictValue?["content"], onEvent: onEvent)
                        .padding(compact ? theme.density.spacing.space4 : theme.density.spacing.space6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                WizardNavigationRenderer(
                    props: AtomKit.child(props, [
                        "currentStep": .int(index),
                        "totalSteps": .int(steps.count),
                        "compact": .bool(compact),
                        "showBack": .bool(props.bool("allowBack", default: true)),
                        "onBack": .string(backToken),
                        "onNext": .string(nextToken),
                        "onComplete": .string(completeToken),
                    ]),
                    modifier: nil,
                    onEvent: { event, _ in handle(event) }
                )
            }
        }
    }
}

@ViewBuilder
func WizardContainerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(WizardContainerMoleculeView(props: props, onEvent: onEvent))
}
