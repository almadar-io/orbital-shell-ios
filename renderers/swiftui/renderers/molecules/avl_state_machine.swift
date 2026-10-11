import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AvlStateMachineMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var trait: AnyCodable { props.dictValue?["trait"] ?? .dict([:]) }
    private var states: [AnyCodable] { trait.dictValue?["states"]?.arrayValue ?? [] }
    private var transitions: [AnyCodable] { trait.dictValue?["transitions"]?.arrayValue ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            if props.bool("showHeader", default: true) { header }
            if states.isEmpty {
                AtomKit.typo("No state machine", "caption", color: "muted", align: "center", onEvent: onEvent)
                    .padding(theme.density.spacing.space6)
                    .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, style: StrokeStyle(lineWidth: theme.geometry.borderStandard, dash: [theme.density.spacing.space1])))
            } else {
                AtomKit.typo("States", "overline", color: "muted", onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    ForEach(states.indices, id: \.self) { index in stateRow(states[index]) }
                }
                AtomKit.typo("Transitions", "overline", color: "muted", onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    ForEach(transitions.indices, id: \.self) { index in transitionRow(transitions[index]) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, props.string("direction", default: "ltr") == "rtl" ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        let fields = AtomKit.strings(props, "entityFields")
        return VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            AtomKit.typo(trait.string("name"), "body1", weight: "semibold", onEvent: onEvent)
            AtomKit.typo("on \(trait.string("linkedEntity")) · \(states.count) states · \(transitions.count) transitions", "caption", color: "muted", onEvent: onEvent)
            if !fields.isEmpty { AtomMonoText(trait.string("linkedEntity") + " { " + fields.joined(separator: ", ") + " }", size: "xs", color: theme.color.mutedForeground) }
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(AtomKit.strings(trait, "listenedEvents"), id: \.self) { event in AtomKit.badge("listens " + event, "info", onEvent: onEvent) }
                ForEach(AtomKit.strings(trait, "emittedEvents"), id: \.self) { event in AtomKit.badge("emits " + event, "default", onEvent: onEvent) }
            }
        }
    }

    private func note(_ group: String, _ key: String) -> AnyCodable? {
        props.dictValue?["annotations"]?.dictValue?[group]?.dictValue?[key]
    }

    private func stateRow(_ state: AnyCodable) -> some View {
        let name = state.string("name")
        let active = name == props.string("activeState")
        let selected = name == props.string("selectedState")
        let pending = name == props.string("pendingSourceState")
        let visited = AtomKit.strings(props, "visitedStates")
        let visit = visited.firstIndex(of: name).map { $0 + 1 }
        let emphasis = active || selected || pending
        let event = props.string("stateClickEvent")
        return VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            HStack(spacing: theme.density.spacing.space2) {
                if state.bool("isInitial") { AtomKit.icon("circle-dot", "xs", color: "primary", label: "Initial state", onEvent: onEvent) }
                AtomKit.typo(name, "body2", weight: active ? "semibold" : "medium", onEvent: onEvent)
                if state.bool("isTerminal") { AtomKit.badge("terminal", "default", onEvent: onEvent) }
                Spacer(minLength: theme.density.spacing.space2)
                if let visit = visit, !active { AtomKit.badge("\(visit)", "default", onEvent: onEvent) }
                if active { AtomKit.badge("now", "primary", onEvent: onEvent) }
            }
            if let text = note("states", name), !text.string("body").isEmpty { AtomKit.typo(text.string("body"), "caption", color: "secondary", onEvent: onEvent) }
        }
        .padding(theme.density.spacing.space3)
        .background(theme.color.card)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(emphasis ? theme.color.primary : theme.color.border, style: StrokeStyle(lineWidth: emphasis ? theme.geometry.borderHeavy * 2 : theme.geometry.borderStandard, dash: pending ? [theme.density.spacing.space1] : [])))
        .contentShape(Rectangle())
        .onTapGesture { if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["stateId": .string(name)])) } }
        .accessibilityAddTraits(event.isEmpty ? [] : .isButton)
        .accessibilityValue(active ? "current" : "")
        .atomAction(event, props)
        .verificationContainer(VerificationIds.row(name))
    }

    private func transitionRow(_ transition: AnyCodable) -> some View {
        let index = transition.int("index")
        let fired = props.dictValue?["activeTransition"]?.intValue == index
        let next = !fired && !props.string("activeState").isEmpty && transition.string("from") == props.string("activeState")
        let guardExpr = transition.dictValue?["guard"]
        let event = props.string("transitionClickEvent")
        let effects = transition.dictValue?["effects"]?.arrayValue ?? []
        return VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.typo(transition.string("from"), "caption", color: "muted", onEvent: onEvent)
                AtomKit.icon("arrow-right", "xs", color: "muted", onEvent: onEvent)
                AtomKit.typo(transition.string("to"), "caption", color: "muted", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space2)
                AtomKit.typo(transition.string("event"), "body2", color: fired ? "primary" : "primary", weight: fired ? "semibold" : "medium", onEvent: onEvent)
            }
            if let expr = guardExpr, !isNull(expr) { AtomMonoText("guard " + AtomKit.sexpr(expr), size: "xs", color: theme.color.mutedForeground) }
            if !effects.isEmpty {
                HStack(spacing: theme.density.spacing.space1) {
                    ForEach(effects.indices, id: \.self) { position in AtomKit.badge(effects[position].string("type"), "default", onEvent: onEvent) }
                }
            }
            if let text = note("transitions", transition.string("event")), !text.string("body").isEmpty { AtomKit.typo(text.string("body"), "caption", color: "secondary", onEvent: onEvent) }
        }
        .padding(theme.density.spacing.space3)
        .background(fired ? theme.color.primary.opacity(0.1) : AtomKit.clear(theme))
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(fired ? theme.color.primary : theme.color.border, style: StrokeStyle(lineWidth: theme.geometry.borderStandard, dash: next ? [theme.density.spacing.space1] : [])))
        .contentShape(Rectangle())
        .onTapGesture {
            if !event.isEmpty {
                onEvent(event, eventEnvelope(props, payload: ["index": .int(index), "event": .string(transition.string("event")), "from": .string(transition.string("from")), "to": .string(transition.string("to"))]))
            }
        }
        .accessibilityAddTraits(event.isEmpty ? [] : .isButton)
        .accessibilityValue(fired ? "fired" : "")
        .atomAction(event, props)
        .verificationContainer(VerificationIds.row("transition-\(index)"))
    }

    private func isNull(_ value: AnyCodable) -> Bool {
        if case .null = value { return true }
        return false
    }
}

@ViewBuilder
func AvlStateMachineRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AvlStateMachineMoleculeView(props: props, onEvent: onEvent))
}
