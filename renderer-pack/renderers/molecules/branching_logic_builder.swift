import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct BranchingEdgeShape: Shape {
    let start: CGPoint
    let end: CGPoint
    let bend: CGFloat
    let head: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: CGPoint(x: bend, y: start.y), control2: CGPoint(x: bend, y: end.y))
        path.move(to: CGPoint(x: end.x + head, y: end.y - head / 2))
        path.addLine(to: end)
        path.addLine(to: CGPoint(x: end.x + head, y: end.y + head / 2))
        return path
    }
}

struct BranchingLogicBuilderMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var rules: [AnyCodable]
    @State private var graph = false
    private let deleteKey = "DELETE_RULE"
    private let addKey = "ADD_RULE"
    private let editKey = "VIEW_EDIT"
    private let graphKey = "VIEW_GRAPH"
    private let endKey = "end-of-survey"

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _rules = State(initialValue: BranchingLogicBuilderMoleculeView.seed(props))
    }

    private static func seed(_ props: AnyCodable) -> [AnyCodable] { props.dictValue?["rules"]?.arrayValue ?? [] }
    private var questions: [AnyCodable] { props.dictValue?["questions"]?.arrayValue ?? [] }
    private var readOnly: Bool { props.bool("readOnly") }

    private func broken(_ rule: AnyCodable) -> Bool {
        let source = questions.contains { $0.string("id") == rule.string("sourceQuestionId") }
        let target = rule.string("targetQuestionId") == endKey || questions.contains { $0.string("id") == rule.string("targetQuestionId") }
        return !source || !target
    }

    private func commit(_ next: [AnyCodable]) {
        rules = next
        for key in ["onRulesChange", "rulesChangeEvent"] {
            let event = props.string(key)
            if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["rules": .array(next)])) }
        }
    }

    private func change(_ id: String, _ values: [String: AnyCodable]) {
        commit(rules.map { rule in
            guard rule.string("id") == id else { return rule }
            var merged = rule.dictValue ?? [:]
            for (key, value) in values { merged[key] = value }
            return .dict(merged)
        })
    }

    private func chips(_ rule: AnyCodable) -> [String] { AtomKit.strings(rule, "value") }

    var body: some View {
        let brokenCount = rules.filter { broken($0) }.count
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            AtomFlowLayout(spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.icon("route", "md", onEvent: onEvent)
                    AtomKit.typo("Branching logic", "subheading", weight: "semibold", onEvent: onEvent)
                    AtomKit.badge(rules.count == 1 ? "1 rule" : "\(rules.count) rules", "neutral", onEvent: onEvent)
                    if brokenCount > 0 { AtomKit.badge("\(brokenCount) broken", "error", onEvent: onEvent) }
                }
                HStack(spacing: theme.density.spacing.space1) {
                    tab("Rules", "edit-3", editKey, active: !graph)
                    tab("Logic graph", "eye", graphKey, active: graph)
                }
                .padding(theme.density.spacing.space1)
                .background(theme.color.card)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
                .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            }
            if graph { graphView } else { editor }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .onChange(of: AtomKit.sexpr(.array(BranchingLogicBuilderMoleculeView.seed(props)))) { _ in rules = BranchingLogicBuilderMoleculeView.seed(props) }
    }

    private func tab(_ label: String, _ icon: String, _ key: String, active: Bool) -> some View {
        ButtonRenderer(
            props: AtomKit.child(props, ["variant": .string(active ? "primary" : "ghost"), "size": "sm", "leftIcon": .string(icon), "label": .string(label), "action": .string(key)]),
            modifier: nil,
            onEvent: { _, _ in
                graph = key == graphKey
                onEvent(key, eventEnvelope(props))
            }
        )
    }

    @ViewBuilder
    private var editor: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if rules.isEmpty {
                AtomKit.typo(questions.isEmpty ? "Add questions before building branching rules." : "No rules yet. Add a rule to define branching logic.", "body1", color: "muted", align: "center", onEvent: onEvent)
                    .frame(maxWidth: .infinity)
                    .atomSurface(theme, padding: theme.density.cardPaddingLg)
            } else {
                ForEach(rules.indices, id: \.self) { index in row(rules[index]) }
            }
            if !readOnly {
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "leftIcon": "plus", "label": "Add rule", "disabled": .bool(questions.isEmpty), "action": .string(addKey)]),
                    modifier: nil,
                    onEvent: { _, _ in
                        guard let first = questions.first else { return }
                        let fresh: AnyCodable = .dict([
                            "id": .string("rule-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6).lowercased())"),
                            "sourceQuestionId": .string(first.string("id")),
                            "operator": "equals",
                            "value": .string(AtomKit.strings(first, "optionValues").first ?? ""),
                            "targetQuestionId": .string(questions.count > 1 ? questions[1].string("id") : endKey),
                        ])
                        commit(rules + [fresh])
                        onEvent(addKey, eventEnvelope(props))
                    }
                )
                .disabled(questions.isEmpty)
            }
        }
    }

    private func options(end: Bool) -> [AnyCodable] {
        var all = questions.map { AnyCodable.dict(["value": .string($0.string("id")), "label": .string($0.string("label"))]) }
        if end { all.append(.dict(["value": .string(endKey), "label": "End of survey"])) }
        return all
    }

    private func picker(_ name: String, _ choices: [AnyCodable], _ value: String, _ placeholder: String, error: String = "", _ commit: @escaping (String) -> Void) -> some View {
        SelectRenderer(
            props: AtomKit.child(props, [
                "name": .string(name),
                "options": .array(choices),
                "value": .string(value),
                "placeholder": .string(placeholder),
                "disabled": .bool(readOnly),
                "error": .string(error),
                "onValueChange": .string(AtomKit.localEvent),
            ]),
            modifier: nil,
            onEvent: { _, envelope in commit(envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "") }
        )
        .frame(minWidth: AlmadarSizes.w40)
    }

    private func row(_ rule: AnyCodable) -> some View {
        let id = rule.string("id")
        let isBroken = broken(rule)
        return VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            AtomFlowLayout(spacing: theme.density.spacing.space2) {
                AtomKit.typo("If", "label", weight: "semibold", onEvent: onEvent)
                picker("rule-\(id)-source", options(end: false), rule.string("sourceQuestionId"), "Select question", error: isBroken ? "Broken reference" : "") { change(id, ["sourceQuestionId": .string($0)]) }
                picker("rule-\(id)-operator", [
                    .dict(["value": "equals", "label": "equals"]),
                    .dict(["value": "not-equals", "label": "does not equal"]),
                    .dict(["value": "contains", "label": "contains"]),
                    .dict(["value": "in", "label": "is one of"]),
                ], rule.string("operator"), "") { switchOperator(rule, $0) }
                valueControl(rule)
                HStack(spacing: theme.density.spacing.space1) {
                    AtomKit.icon("arrow-right", "sm", onEvent: onEvent)
                    AtomKit.typo("go to", "label", weight: "semibold", onEvent: onEvent)
                }
                picker("rule-\(id)-target", options(end: true), rule.string("targetQuestionId"), "Select target") { change(id, ["targetQuestionId": .string($0)]) }
                if !readOnly {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "trash", "aria-label": "Delete rule", "action": .string(deleteKey), "actionPayload": ["ruleId": .string(id)]]),
                        modifier: nil,
                        onEvent: { _, _ in
                            commit(rules.filter { $0.string("id") != id })
                            onEvent(deleteKey, eventEnvelope(props, payload: ["ruleId": .string(id)]))
                        }
                    )
                }
            }
            if isBroken { AtomKit.badge("Broken reference", "error", onEvent: onEvent) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme, padding: theme.density.spacing.space2)
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(isBroken ? theme.color.error : AtomKit.clear(theme), lineWidth: theme.geometry.borderStandard))
        .verificationContainer(VerificationIds.row(id))
    }

    private func switchOperator(_ rule: AnyCodable, _ next: String) {
        let scalar = AtomKit.scalar(rule.dictValue?["value"]) ?? ""
        let current = chips(rule)
        let isList = rule.dictValue?["value"]?.arrayValue != nil
        let value: AnyCodable
        if next == "in" && !isList {
            value = .array(scalar.isEmpty ? [] : [.string(scalar)])
        } else if next != "in" && isList {
            value = .string(current.first ?? "")
        } else {
            value = rule.dictValue?["value"] ?? .string("")
        }
        change(rule.string("id"), ["operator": .string(next), "value": value])
    }

    @ViewBuilder
    private func valueControl(_ rule: AnyCodable) -> some View {
        let id = rule.string("id")
        let source = questions.first { $0.string("id") == rule.string("sourceQuestionId") }
        let choices = AtomKit.strings(source ?? .dict([:]), "optionValues")
        if rule.string("operator") == "in" {
            let selected = chips(rule)
            AtomFlowLayout(spacing: theme.density.spacing.space1) {
                ForEach(selected, id: \.self) { chip in
                    FilterPillRenderer(
                        props: ["variant": "primary", "size": "sm", "label": .string(chip), "removable": .bool(!readOnly), "removeEvent": .string(AtomKit.localEvent), "local": true],
                        modifier: nil,
                        onEvent: { _, _ in change(id, ["value": .array(selected.filter { $0 != chip }.map { AnyCodable.string($0) })]) }
                    )
                }
                if !choices.isEmpty {
                    picker("rule-\(id)-add", choices.filter { !selected.contains($0) }.map { AnyCodable.dict(["value": .string($0), "label": .string($0)]) }, "", "Add value") { picked in
                        if !picked.isEmpty && !selected.contains(picked) { change(id, ["value": .array((selected + [picked]).map { AnyCodable.string($0) })]) }
                    }
                } else {
                    InputRenderer(
                        props: ["inputType": "text", "name": .string("rule-\(id)-chip"), "placeholder": "Type value, press Enter", "value": "", "disabled": .bool(readOnly), "action": .string(AtomKit.localEvent)],
                        modifier: nil,
                        onEvent: { _, envelope in
                            let typed = (envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            if !typed.isEmpty && !selected.contains(typed) { change(id, ["value": .array((selected + [typed]).map { AnyCodable.string($0) })]) }
                        }
                    )
                    .id(selected.count)
                    .frame(minWidth: AlmadarSizes.w32)
                }
            }
        } else if !choices.isEmpty {
            picker("rule-\(id)-value", choices.map { AnyCodable.dict(["value": .string($0), "label": .string($0)]) }, AtomKit.scalar(rule.dictValue?["value"]) ?? "", "Select value") { change(id, ["value": .string($0)]) }
        } else {
            InputRenderer(
                props: ["inputType": "text", "name": .string("rule-\(id)-value"), "placeholder": "Value", "value": .string(AtomKit.scalar(rule.dictValue?["value"]) ?? ""), "disabled": .bool(readOnly), "onChange": .string(AtomKit.localEvent)],
                modifier: nil,
                onEvent: { _, envelope in change(id, ["value": .string(envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "")]) }
            )
            .frame(minWidth: AlmadarSizes.w32)
        }
    }

    private var graphView: some View {
        let pad = theme.density.spacing.space8
        let nodeW = AlmadarSizes.w44
        let nodeH = theme.density.spacing.space12 + theme.density.spacing.space2
        let gap = AlmadarSizes.w20
        let items: [(id: String, label: String, end: Bool)] = questions.map { (id: $0.string("id"), label: $0.string("label"), end: false) } + [(id: endKey, label: "End of survey", end: true)]
        let width = nodeW + pad * 2 + AlmadarSizes.w56
        let height = pad * 2 + CGFloat(items.count) * (nodeH + gap)
        let top: (String) -> CGFloat? = { id in items.firstIndex(where: { $0.id == id }).map { pad + CGFloat($0) * (nodeH + gap) } }
        return ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                ForEach(rules.indices, id: \.self) { index in
                    let rule = rules[index]
                    if let from = top(rule.string("sourceQuestionId")), let to = top(rule.string("targetQuestionId")) {
                        let startY = from + nodeH / 2
                        let endY = to + nodeH / 2
                        let bend = pad + nodeW + theme.density.spacing.space10 + CGFloat(index % 4) * theme.density.spacing.space8
                        BranchingEdgeShape(start: CGPoint(x: pad + nodeW, y: startY), end: CGPoint(x: pad + nodeW, y: endY), bend: bend, head: theme.density.spacing.space2)
                            .stroke(theme.color.mutedForeground, lineWidth: theme.geometry.borderStandard)
                        AtomMonoText(label(rule), size: "xs")
                            .lineLimit(1)
                            .padding(.horizontal, theme.density.spacing.space1)
                            .frame(maxWidth: AlmadarSizes.w40)
                            .background(theme.color.card)
                            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
                            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(theme.color.border, lineWidth: theme.geometry.borderHairline))
                            .position(x: bend + AlmadarSizes.w20 / 2, y: (startY + endY) / 2)
                    }
                }
                ForEach(items.indices, id: \.self) { index in
                    AtomKit.typo(items[index].label, "label", weight: "semibold", align: "center", truncate: true, onEvent: onEvent)
                        .padding(.horizontal, theme.density.spacing.space2)
                        .frame(width: nodeW, height: nodeH)
                        .background(items[index].end ? theme.color.surface : theme.color.card)
                        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
                        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(items[index].end ? theme.color.error : theme.color.border, lineWidth: items[index].end ? theme.geometry.borderHeavy : theme.geometry.borderStandard))
                        .position(x: pad + nodeW / 2, y: pad + CGFloat(index) * (nodeH + gap) + nodeH / 2)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .accessibilityLabel("Branching logic graph")
    }

    private func label(_ rule: AnyCodable) -> String {
        let value = chips(rule)
        if rule.string("operator") == "in" && rule.dictValue?["value"]?.arrayValue != nil { return "in [" + value.joined(separator: ", ") + "]" }
        return rule.string("operator") + " " + (rule.dictValue?["value"]?.arrayValue != nil ? value.joined(separator: ", ") : (AtomKit.scalar(rule.dictValue?["value"]) ?? ""))
    }
}

@ViewBuilder
func BranchingLogicBuilderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BranchingLogicBuilderMoleculeView(props: props, onEvent: onEvent))
}
