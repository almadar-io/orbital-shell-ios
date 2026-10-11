import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ThemeToggleAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.almadarThemeMode) private var mode

    var body: some View {
        let dark = mode.isDark
        let size = props.string("size", default: "md")
        let name = dark ? "sun" : "moon"
        let target = dark ? "Switch to light theme" : "Switch to dark theme"
        Button(action: mode.toggle) {
            HStack(spacing: theme.density.spacing.space2) {
                Image(systemName: IconMap.resolve(name))
                    .font(AtomKit.font(theme, size == "lg" ? "xl" : (size == "sm" ? "base" : "lg")))
                if props.bool("showLabel") {
                    Text(dark ? "Light" : "Dark").font(AtomKit.font(theme, "sm", .medium))
                }
            }
            .foregroundColor(theme.color.foreground)
            .padding(size == "lg" ? theme.density.spacing.space3 : (size == "sm" ? theme.density.spacing.space2 : theme.density.spacing.space2 + theme.density.spacing.space1 / 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(props.string("aria-label", default: target)))
    }
}

@ViewBuilder
func ThemeToggleRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ThemeToggleAtomView(props: props, onEvent: onEvent))
}
