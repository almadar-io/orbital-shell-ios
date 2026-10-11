import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct HealthBarAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let current = props.float("current", default: 3)
        let maximum = props.float("max", default: 5)
        let fraction = maximum > 0 ? min(max(current / maximum, 0), 1) : 0
        let format = props.string("format", default: "hearts")
        let size = props.string("size", default: "md")
        let animated = props.bool("animated", default: true)
        let summary = "\(Int(current)) / \(Int(maximum))"
        Group {
            switch format {
            case "bar": bar(fraction: fraction, tint: barTint(fraction), thickness: thickness(size), width: theme.density.spacing.space12 * 2)
            case "progress": progress(current: current, maximum: maximum, fraction: fraction, size: size)
            case "numeric": Text(summary).font(AtomKit.font(theme, size == "lg" ? "lg" : (size == "sm" ? "sm" : "base"), .bold, mono: true)).foregroundColor(theme.color.foreground)
            default: hearts(current: Int(current), maximum: Int(maximum), size: size)
            }
        }
        .animation(animated ? theme.motion.animation(for: theme.motion.transition) : nil, value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Health"))
        .accessibilityValue(Text(summary))
    }

    @ViewBuilder
    private func hearts(current: Int, maximum: Int, size: String) -> some View {
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(0..<max(maximum, 0), id: \.self) { index in
                Image(systemName: index < current ? "heart.fill" : "heart")
                    .font(AtomKit.font(theme, size == "lg" ? "2xl" : (size == "sm" ? "base" : "xl")))
                    .foregroundColor(index < current ? theme.color.error : theme.color.mutedForeground)
            }
        }
    }

    @ViewBuilder
    private func bar(fraction: Double, tint: Color, thickness: CGFloat, width: CGFloat?) -> some View {
        let fillURL = AtomKit.assetURL(props, "fillAsset")
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                AtomKit.shape(theme, .pill, radius: thickness / 2).fill(theme.color.muted)
                if fillURL.isEmpty {
                    AtomKit.shape(theme, .pill, radius: thickness / 2).fill(tint).frame(width: proxy.size.width * fraction)
                } else {
                    AsyncImage(url: URL(string: fillURL)) { image in image.resizable() } placeholder: { tint }
                        .frame(width: proxy.size.width * fraction)
                        .atomClip(theme, .pill, radius: thickness / 2)
                }
            }
        }
        .frame(width: width, height: thickness)
    }

    @ViewBuilder
    private func progress(current: Double, maximum: Double, fraction: Double, size: String) -> some View {
        let level = props.dictValue?["level"]?.intValue
        let suffix = props.string("labelSuffix")
        HStack(spacing: theme.density.spacing.space2) {
            if let level = level {
                Text("Lv.\(level)")
                    .font(AtomKit.font(theme, "xs", .bold))
                    .foregroundColor(theme.color.accentForeground)
                    .padding(.horizontal, theme.density.spacing.space2)
                    .padding(.vertical, theme.density.spacing.space1 / 2)
                    .background(theme.color.accent)
                    .atomClip(theme, .container, radius: theme.geometry.radiusInteractive)
            }
            VStack(alignment: .leading, spacing: theme.density.spacing.space1 / 2) {
                bar(fraction: fraction, tint: theme.color.accent, thickness: thickness(size), width: nil)
                if props.bool("showLabel", default: true) {
                    Text("\(Int(current)) / \(Int(maximum))" + (suffix.isEmpty ? "" : " \(suffix)"))
                        .font(AtomKit.font(theme, "xs", .regular, mono: true))
                        .foregroundColor(theme.color.mutedForeground)
                }
            }
        }
    }

    private func thickness(_ size: String) -> CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space2
        case "lg": return theme.density.spacing.space4
        default: return theme.density.spacing.space3
        }
    }

    private func barTint(_ fraction: Double) -> Color {
        fraction > 0.66 ? theme.color.success : (fraction > 0.33 ? theme.color.warning : theme.color.error)
    }
}

@ViewBuilder
func HealthBarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(HealthBarAtomView(props: props, onEvent: onEvent))
}
