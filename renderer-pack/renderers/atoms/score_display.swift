import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ScoreDisplayAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let number = props.dictValue?["value"]?.doubleValue ?? props.dictValue?["score"]?.doubleValue ?? 0
        let formatter = NumberFormatter()
        let locale = props.string("locale")
        let shown: String = {
            formatter.numberStyle = .decimal
            if !locale.isEmpty { formatter.locale = Locale(identifier: locale) }
            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        }()
        let label = props.string("label")
        let icon = props.string("icon")
        let asset = AtomKit.assetURL(props, "assetUrl")
        let key = sizeKey(props.string("size", default: "md"))
        HStack(spacing: theme.density.spacing.space2) {
            if !asset.isEmpty {
                AsyncImage(url: URL(string: asset)) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .frame(width: theme.density.spacing.space5, height: theme.density.spacing.space5)
            } else if !icon.isEmpty {
                Image(systemName: IconMap.resolve(icon))
            }
            if !label.isEmpty { Text(label).foregroundColor(theme.color.mutedForeground) }
            Text(shown).monospacedDigit().foregroundColor(theme.color.foreground)
        }
        .font(AtomKit.font(theme, key, .bold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label.isEmpty ? "Score" : label))
        .accessibilityValue(Text(shown))
    }

    private func sizeKey(_ token: String) -> String {
        switch token {
        case "sm": return "sm"
        case "lg": return "2xl"
        case "xl": return "4xl"
        default: return "lg"
        }
    }
}

@ViewBuilder
func ScoreDisplayRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ScoreDisplayAtomView(props: props, onEvent: onEvent))
}
