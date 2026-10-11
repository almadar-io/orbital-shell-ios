import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ProgressBarAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let maximum = props.float("max", default: 100)
        let value = props.float("value")
        let fraction = maximum > 0 ? min(max(value / maximum, 0), 1) : 0
        let percent = AtomKit.formatted(String(Int((fraction * 100).rounded())), format: "percent")
        let label = props.string("label")
        let tint = fill(props.string("color", default: props.string("variant", default: "primary")))
        let showPercent = props.bool("showPercentage") || props.bool("showLabel")
        let kind = props.string("progressType", default: "linear")
        Group {
            if kind == "circular" {
                ring(fraction: fraction, tint: tint, percent: percent, showPercent: showPercent)
            } else if kind == "stepped" {
                steps(fraction: fraction, tint: tint)
            } else {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    if !label.isEmpty || showPercent {
                        HStack {
                            if !label.isEmpty { Text(label).font(AtomKit.font(theme, "sm", .bold)) }
                            Spacer()
                            if showPercent { Text(percent).font(AtomKit.font(theme, "sm", .medium)) }
                        }
                        .foregroundColor(theme.color.foreground)
                    }
                    track(fraction: fraction, tint: tint)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label.isEmpty ? "Progress" : label))
        .accessibilityValue(Text(percent))
    }

    @ViewBuilder
    private func ring(fraction: Double, tint: Color, percent: String, showPercent: Bool) -> some View {
        let side = ringSide(props.string("size", default: "md"))
        ZStack {
            Circle().stroke(theme.color.muted, lineWidth: theme.geometry.borderHeavy * 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: theme.geometry.borderHeavy * 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showPercent { Text(percent).font(AtomKit.font(theme, "sm", .bold)).foregroundColor(theme.color.foreground) }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private func track(fraction: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                theme.color.muted
                tint.frame(width: proxy.size.width * fraction)
            }
            .atomClip(theme, .container, radius: theme.density.spacing.space0)
            .atomBorder(theme, .container, radius: theme.density.spacing.space0, color: theme.color.border, width: theme.geometry.borderHairline)
        }
        .frame(height: theme.density.spacing.space2)
    }

    @ViewBuilder
    private func steps(fraction: Double, tint: Color) -> some View {
        let total = max(props.int("steps", default: 5), 1)
        let filled = Int((fraction * Double(total)).rounded())
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(0..<total, id: \.self) { index in
                (index < filled ? tint : theme.color.muted)
                    .frame(height: theme.density.spacing.space2)
                    .atomClip(theme, .container, radius: theme.density.spacing.space0)
                    .atomBorder(theme, .container, radius: theme.density.spacing.space0, color: theme.color.border, width: theme.geometry.borderHairline)
            }
        }
    }

    private func ringSide(_ size: String) -> CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space12 + theme.density.spacing.space4
        case "lg": return theme.density.spacing.space12 * 2 + theme.density.spacing.space4
        default: return theme.density.spacing.space12 * 2
        }
    }

    private func fill(_ token: String) -> Color {
        switch token {
        case "success": return theme.color.success
        case "warning": return theme.color.warning
        case "error", "danger": return theme.color.error
        default: return theme.color.primary
        }
    }
}

@ViewBuilder
func ProgressBarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ProgressBarAtomView(props: props, onEvent: onEvent))
}
