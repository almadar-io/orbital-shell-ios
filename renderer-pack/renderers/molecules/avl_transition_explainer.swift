import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AvlTransitionExplainerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let transition = props.dictValue?["transition"] ?? .dict([:])
        let event = transition.string("event")
        let guardExpr = transition.dictValue?["guard"]
        let effects = transition.dictValue?["effects"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            AtomKit.typo(props.string("orbitalName") + " / " + props.string("traitName"), "caption", color: "muted", onEvent: onEvent)
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.badge(transition.string("from"), "neutral", size: "lg", onEvent: onEvent)
                AtomKit.typo(event, "body1", weight: "semibold", onEvent: onEvent)
                AtomKit.icon("arrow-right", "md", color: "muted", onEvent: onEvent)
                AtomKit.badge(transition.string("to"), "neutral", size: "lg", onEvent: onEvent)
            }
            note(props.dictValue?["annotations"]?.dictValue?["transitions"]?.dictValue?[event])
            if let expr = guardExpr, !isNull(expr) {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomKit.typo("Guard", "overline", color: "muted", onEvent: onEvent)
                    AtomMonoText(AtomKit.sexpr(expr), size: "sm")
                }
            }
            if !effects.isEmpty {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomKit.typo("Effects (\(effects.count))", "overline", color: "muted", onEvent: onEvent)
                    AccordionRenderer(
                        props: AtomKit.child(props, [
                            "items": .array(effects.indices.map { index in
                                let type = effects[index].string("type")
                                return .dict(["id": .string("effect-\(index)"), "header": .string(type), "content": .string(AtomKit.sexpr(.array([.string(type)] + (effects[index].dictValue?["args"]?.arrayValue ?? []))))])
                            }),
                            "multiple": true,
                            "defaultOpenItems": .array(effects.indices.filter { effects[$0].string("type") != "render-ui" }.map { .string("effect-\($0)") }),
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme, padding: theme.density.spacing.space6)
        .accessibilityElement(children: .contain)
    }

    private func isNull(_ value: AnyCodable) -> Bool {
        if case .null = value { return true }
        return false
    }

    @ViewBuilder
    private func note(_ note: AnyCodable?) -> some View {
        if let note = note, !note.string("body").isEmpty {
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !note.string("title").isEmpty { AtomKit.typo(note.string("title"), "small", weight: "semibold", onEvent: onEvent) }
                AtomKit.typo(note.string("body"), "small", color: "secondary", onEvent: onEvent)
            }
        }
    }
}

@ViewBuilder
func AvlTransitionExplainerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AvlTransitionExplainerMoleculeView(props: props, onEvent: onEvent))
}
