import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TrendIndicatorAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let value = props.dictValue?["value"]?.doubleValue
        let declared = props.string("direction")
        if value != nil || !declared.isEmpty {
            let direction = declared.isEmpty ? ((value ?? 0) > 0 ? "up" : ((value ?? 0) < 0 ? "down" : "flat")) : declared
            let good = props.bool("invert") ? direction == "down" : direction == "up"
            let tint = direction == "flat" ? theme.color.mutedForeground : (good ? theme.color.success : theme.color.error)
            let icon = direction == "up" ? "trending-up" : (direction == "down" ? "trending-down" : "arrow-right")
            let shown = value.map { percent($0) }
            let size = props.string("size", default: "md")
            HStack(spacing: theme.density.spacing.space1) {
                Image(systemName: IconMap.resolve(icon))
                if props.bool("showValue", default: true), let shown = shown { Text(shown) }
            }
            .font(AtomKit.font(theme, size == "lg" ? "base" : (size == "sm" ? "xs" : "sm"), .medium))
            .foregroundColor(tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(props.string("label", default: shown.map { "\(direction) \($0)" } ?? direction)))
        }
    }

    private func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.positivePrefix = formatter.plusSign
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value / 100)) ?? String(value)
    }
}

@ViewBuilder
func TrendIndicatorRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TrendIndicatorAtomView(props: props, onEvent: onEvent))
}
