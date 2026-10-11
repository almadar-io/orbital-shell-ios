import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct SparklineShape: Shape {
    let values: [Double]
    let closed: Bool
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let low = values.min(), let high = values.max() else { return path }
        let span = high - low == 0 ? 1 : high - low
        let width = rect.width - inset * 2
        let height = rect.height - inset * 2
        var points: [CGPoint] = []
        for (index, value) in values.enumerated() {
            let x = rect.minX + inset + CGFloat(index) / CGFloat(values.count - 1) * width
            let y = rect.minY + inset + CGFloat(1 - (value - low) / span) * height
            points.append(CGPoint(x: x, y: y))
        }
        if closed { path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset)) }
        for (index, point) in points.enumerated() {
            if index == 0 && !closed { path.move(to: point) } else { path.addLine(to: point) }
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset))
            path.closeSubpath()
        }
        return path
    }
}

struct SparklineAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let values = (props.dictValue?["data"]?.arrayValue ?? []).compactMap { $0.doubleValue }
        let width = CGFloat(props.float("width", default: 80))
        let height = CGFloat(props.float("height", default: 32))
        let tone = props.string("color", default: "auto")
        let tint: Color = tone == "auto" ? ((values.last ?? 0) >= (values.first ?? 0) ? theme.color.success : theme.color.error) : AtomKit.tone(theme, tone)
        let stroke = CGFloat(props.float("strokeWidth", default: 2))
        if values.count > 1 {
            ZStack {
                if props.bool("fill") {
                    SparklineShape(values: values, closed: true, inset: stroke).fill(tint.opacity(0.15))
                }
                SparklineShape(values: values, closed: false, inset: stroke)
                    .stroke(tint, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
            }
            .frame(width: width, height: height)
            .accessibilityHidden(props.bool("aria-hidden", default: true))
        }
    }
}

@ViewBuilder
func SparklineRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SparklineAtomView(props: props, onEvent: onEvent))
}
