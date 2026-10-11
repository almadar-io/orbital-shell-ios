import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct BloomQuizBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var revealed = false

    private var level: String { props.string("level", default: "remember") }

    private func tint() -> Color {
        switch level {
        case "understand": return theme.color.info
        case "apply": return theme.color.success
        case "analyze": return theme.color.warning
        case "evaluate": return theme.color.accent
        case "create": return theme.color.primary
        default: return theme.color.muted
        }
    }

    private func pillFill() -> Color {
        switch level {
        case "understand": return theme.color.info
        case "apply": return theme.color.success
        case "analyze": return theme.color.warning
        case "evaluate": return theme.color.accent
        case "create": return theme.color.primary
        default: return theme.color.secondary
        }
    }

    private func pillInk() -> Color {
        switch level {
        case "understand": return theme.color.infoForeground
        case "apply": return theme.color.successForeground
        case "analyze": return theme.color.warningForeground
        case "evaluate": return theme.color.accentForeground
        case "create": return theme.color.primaryForeground
        default: return theme.color.secondaryForeground
        }
    }

    private func reveal() {
        if !revealed {
            onEvent(props.string("answerEvent", default: "ANSWER_BLOOM"), eventEnvelope(props, payload: ["index": .int(props.int("index")), "level": .string(level)]))
        }
        revealed.toggle()
    }

    var body: some View {
        let shape = AtomKit.shape(theme, .container)
        let hasIndex = props.dictValue?["index"] != nil
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            HStack(spacing: theme.density.spacing.space2) {
                if hasIndex {
                    AtomKit.typo("Question \(props.int("index") + 1)", "small", color: "muted", weight: "medium", onEvent: onEvent)
                }
                AtomKit.ink(theme, level.prefix(1).uppercased() + level.dropFirst(), "xs", weight: .medium, color: pillInk())
                    .padding(.horizontal, theme.density.spacing.space2)
                    .padding(.vertical, theme.density.spacing.space1)
                    .background(pillFill())
                    .atomClip(theme, .pill)
                Spacer(minLength: theme.density.spacing.space0)
                if props.bool("isAnswered") {
                    AtomKit.icon("check-circle", "md", color: "success", onEvent: onEvent)
                }
            }
            MarkdownContentRenderer(
                props: AtomKit.child(props, ["content": .string(props.string("question"))]),
                modifier: nil,
                onEvent: onEvent
            )
            ButtonRenderer(
                props: AtomKit.child(props, ["variant": "primary", "size": "sm", "label": .string(revealed ? "Hide Answer" : "Reveal Answer"), "action": .string(props.string("answerEvent", default: "ANSWER_BLOOM"))]),
                modifier: nil,
                onEvent: { _, _ in reveal() }
            )
            if revealed {
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    AtomKit.typo("ANSWER:", "caption", color: "muted", weight: "medium", onEvent: onEvent)
                    MarkdownContentRenderer(
                        props: AtomKit.child(props, ["content": .string(props.string("answer"))]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
                .padding(theme.density.spacing.space3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.color.card)
                .clipShape(shape)
                .overlay(shape.stroke(theme.color.primary, lineWidth: theme.geometry.borderStandard))
            }
        }
        .padding(theme.density.spacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint().opacity(level == "remember" ? 1 : 0.1))
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.primary, lineWidth: theme.geometry.borderStandard))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func BloomQuizBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BloomQuizBlockMoleculeView(props: props, onEvent: onEvent))
}
