import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TimerDisplayAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blink = false

    var body: some View {
        let seconds = props.float("seconds", default: 90)
        let running = props.bool("running", default: true)
        let threshold = props.dictValue?["lowThreshold"]?.doubleValue
        let low = threshold.map { seconds <= $0 && seconds > 0 } ?? false
        let size = props.string("size", default: "md")
        let asset = AtomKit.assetURL(props, "iconAsset")
        let shown = text(seconds)
        HStack(spacing: theme.density.spacing.space1) {
            if !asset.isEmpty {
                AsyncImage(url: URL(string: asset)) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .frame(width: theme.density.spacing.space4, height: theme.density.spacing.space4)
            }
            Text(shown).monospacedDigit()
        }
        .font(AtomKit.font(theme, size == "lg" ? "2xl" : (size == "sm" ? "sm" : "lg"), .bold, mono: true))
        .foregroundColor(low ? theme.color.error : theme.color.foreground)
        .padding(.horizontal, size == "lg" ? theme.density.spacing.space4 : (size == "sm" ? theme.density.spacing.space2 : theme.density.spacing.space3))
        .padding(.vertical, theme.density.spacing.space1)
        .background(theme.color.card.opacity(0.8))
        .atomClip(theme, .container)
        .atomBorder(theme, .container, color: low ? theme.color.error.opacity(0.5) : (running ? theme.color.success.opacity(0.5) : theme.color.muted), width: theme.geometry.borderStandard)
        .opacity(low && blink && !reduceMotion ? 0.5 : 1)
        .onAppear {
            if low && !reduceMotion { withAnimation(.easeInOut(duration: theme.motion.durations.dramatic).repeatForever(autoreverses: true)) { blink = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Timer"))
        .accessibilityValue(Text(shown))
    }

    private func text(_ seconds: Double) -> String {
        let clamped = max(Int(seconds), 0)
        let minutes = clamped / 60
        let rest = clamped % 60
        switch props.string("format", default: "mm:ss") {
        case "ss": return "\(clamped)s"
        case "countdown": return minutes > 0 ? "\(minutes):" + String(format: "%02d", rest) : "\(rest)"
        default: return String(format: "%02d:%02d", minutes, rest)
        }
    }
}

@ViewBuilder
func TimerDisplayRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TimerDisplayAtomView(props: props, onEvent: onEvent))
}
