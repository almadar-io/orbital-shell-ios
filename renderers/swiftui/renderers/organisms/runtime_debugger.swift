import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct RuntimeDebuggerOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _open = State(initialValue: !props.bool("defaultCollapsed", default: true))
    }

    var body: some View {
        let orbitals = props.dictValue?["schema"]?.dictValue?["orbitals"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("bug", "sm", color: "warning", onEvent: onEvent)
                AtomKit.typo("Runtime Debugger", "caption", weight: "bold", onEvent: onEvent)
                AtomKit.badge("\(orbitals.count) orbitals", "info", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space0)
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": .string(open ? "chevron-down" : "chevron-up"), "aria-label": .string(open ? "Collapse debugger" : "Expand debugger"), "action": .string(AtomKit.localEvent), "local": true]),
                    modifier: nil,
                    onEvent: { _, _ in open.toggle() }
                )
            }
            .padding(.horizontal, theme.density.spacing.space2)
            .padding(.vertical, theme.density.spacing.space1)
            .background(theme.color.muted)
            if open {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    ForEach(orbitals.indices, id: \.self) { index in
                        orbital(orbitals[index])
                    }
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
                .padding(theme.density.spacing.space2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.card)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func orbital(_ node: AnyCodable) -> some View {
        let traits = node.dictValue?["traits"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            AtomKit.typo(node.string("name"), "caption", weight: "semibold", onEvent: onEvent)
            ForEach(traits.indices, id: \.self) { index in
                let trait = traits[index]
                let states = (trait.dictValue?["stateMachine"]?.dictValue?["states"]?.arrayValue ?? []).map { $0.stringValue ?? $0.string("name") }
                AtomKit.typo((trait.stringValue ?? trait.string("name", default: trait.string("ref"))) + (states.isEmpty ? "" : " [" + states.joined(separator: ", ") + "]"), "caption", color: "muted", onEvent: onEvent)
            }
        }
    }
}

@ViewBuilder
func RuntimeDebuggerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RuntimeDebuggerOrganismView(props: props, onEvent: onEvent))
}
