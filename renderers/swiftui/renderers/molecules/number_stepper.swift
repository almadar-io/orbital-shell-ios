import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct NumberStepperMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var value: Double
    @State private var hold: Task<Void, Never>?

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _value = State(initialValue: props.float("value"))
    }

    private var step: Double { props.float("step", default: 1) }
    private var lower: Double? { props.dictValue?["min"]?.doubleValue }
    private var upper: Double? { props.dictValue?["max"]?.doubleValue }

    private func commit(_ proposed: Double) {
        let unit = step == 0 ? 1 : step
        let snapped = (proposed / unit).rounded() * unit
        let clamped = max(lower ?? -Double.infinity, min(upper ?? Double.infinity, snapped))
        value = clamped
        let event = props.string("action")
        if !event.isEmpty {
            var payload: [String: AnyCodable] = props.dictValue?["actionPayload"]?.dictValue ?? [:]
            payload["value"] = .double(clamped)
            onEvent(event, eventEnvelope(props, payload: .dict(payload)))
        }
    }

    private func hold(_ delta: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard hold == nil else { return }
                hold = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    while !Task.isCancelled {
                        await MainActor.run { commit(value + delta) }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
            }
            .onEnded { _ in
                hold?.cancel()
                hold = nil
            }
    }

    var body: some View {
        let size = props.string("size", default: "md")
        let disabled = props.bool("disabled")
        let atMin = lower.map { value <= $0 } ?? false
        let atMax = upper.map { value >= $0 } ?? false
        HStack(spacing: theme.density.spacing.space0) {
            control("minus", "Decrease", size: size, disabled: disabled || atMin, delta: -step)
            AtomKit.typo(AtomKit.scalar(.double(value)) ?? "", size == "lg" ? "large" : (size == "sm" ? "small" : "body1"), weight: "medium", align: "center", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space2)
                .frame(minWidth: size == "lg" ? theme.density.spacing.space12 : (size == "sm" ? theme.density.spacing.space8 : theme.density.spacing.space10))
                .accessibilityAddTraits(.updatesFrequently)
            control("plus", "Increase", size: size, disabled: disabled || atMax, delta: step)
        }
        .background(theme.color.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .opacity(disabled ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("aria-label", default: props.string("label", default: "Number stepper")))
        .onChange(of: props.float("value")) { next in value = next }
    }

    private func control(_ icon: String, _ label: String, size: String, disabled: Bool, delta: Double) -> some View {
        let event = props.string("action")
        return ButtonRenderer(
            props: AtomKit.child(props, ["variant": "ghost", "size": .string(size), "icon": .string(icon), "aria-label": .string(label), "disabled": .bool(disabled), "action": .string(AtomKit.eventOrLocal(event)), "local": .bool(event.isEmpty)]),
            modifier: nil,
            onEvent: { _, _ in commit(value + delta) }
        )
        .simultaneousGesture(hold(delta))
    }
}

@ViewBuilder
func NumberStepperRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(NumberStepperMoleculeView(props: props, onEvent: onEvent))
}
