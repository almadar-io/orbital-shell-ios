import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct DialogueBubbleAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let speaker = props.string("speaker")
        let full = AtomKit.text(props, "text")
        let revealed = props.dictValue?["revealedChars"]?.intValue
        let shown = revealed.map { String(full.prefix(max($0, 0))) } ?? full
        let portrait = AtomKit.assetURL(props, "portrait")
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            if !portrait.isEmpty {
                AsyncImage(url: URL(string: portrait)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    theme.color.muted
                }
                .frame(width: theme.density.spacing.space12, height: theme.density.spacing.space12)
                .atomClip(theme, .pill, radius: theme.density.spacing.space12 / 2)
                .atomBorder(theme, .pill, radius: theme.density.spacing.space12 / 2, color: moodColor(), width: theme.geometry.borderHeavy)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !speaker.isEmpty {
                    Text(speaker).font(AtomKit.font(theme, "sm", .bold)).foregroundColor(theme.color.warning)
                }
                Text(shown).font(AtomKit.font(theme, "sm")).foregroundColor(theme.color.foreground)
            }
            Spacer(minLength: theme.density.spacing.space0)
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.vertical, theme.density.spacing.space3)
        .background(theme.color.background.opacity(0.8))
        .atomClip(theme, .container)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(speaker.isEmpty ? full : "\(speaker): \(full)"))
    }

    private func moodColor() -> Color {
        switch props.string("mood", default: "neutral") {
        case "happy": return theme.color.success
        case "concerned": return theme.color.info
        case "angry": return theme.color.error
        default: return theme.color.warning
        }
    }
}

@ViewBuilder
func DialogueBubbleRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DialogueBubbleAtomView(props: props, onEvent: onEvent))
}
