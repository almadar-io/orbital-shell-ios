import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import Charts

struct LineChartMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private struct Sample: Identifiable {
        let id: Int
        let x: Double
        let y: Double
        let label: String?
    }

    private var samples: [Sample] {
        let raw = props.dictValue?["data"]?.arrayValue ?? []
        let dated = raw.contains { $0.dictValue?["date"] != nil }
        let numeric = !dated && raw.contains { $0.dictValue?["x"] != nil }
        let ordered: [AnyCodable]
        if dated {
            ordered = raw.sorted { (AtomKit.parseDate($0.string("date"))?.timeIntervalSince1970 ?? 0) < (AtomKit.parseDate($1.string("date"))?.timeIntervalSince1970 ?? 0) }
        } else if numeric {
            ordered = raw.sorted { $0.float("x") < $1.float("x") }
        } else {
            ordered = raw
        }
        return ordered.enumerated().map { index, point in
            Sample(id: index, x: numeric ? point.float("x") : Double(index), y: point.float("value"), label: AtomKit.scalar(point.dictValue?["label"]))
        }
    }

    var body: some View {
        let points = samples
        let line = AtomKit.cssColor(theme, props.string("lineColor", default: "var(--color-primary)"))
        let fill = AtomKit.cssColor(theme, props.string("areaColor", default: "var(--color-primary)"))
        let ratio = CGFloat(props.float("width", default: 400) / max(props.float("height", default: 200), 1))
        if points.isEmpty {
            AtomKit.typo("No data available", "body1", color: "muted", align: "center", onEvent: onEvent)
                .frame(maxWidth: .infinity)
                .padding(theme.density.spacing.space6)
        } else {
            Chart(points) { point in
                if props.bool("showArea", default: true) && points.count > 1 {
                    AreaMark(x: .value("x", point.x), y: .value("value", point.y))
                        .foregroundStyle(LinearGradient(colors: [fill.opacity(0.3), AtomKit.clear(theme)], startPoint: .top, endPoint: .bottom))
                }
                if points.count > 1 {
                    LineMark(x: .value("x", point.x), y: .value("value", point.y))
                        .foregroundStyle(line)
                        .lineStyle(StrokeStyle(lineWidth: theme.geometry.borderHeavy, lineCap: .round, lineJoin: .round))
                }
                PointMark(x: .value("x", point.x), y: .value("value", point.y))
                    .foregroundStyle(line)
                    .annotation(position: .top) {
                        if props.bool("showValues") || points.count == 1 {
                            AtomKit.typo(point.label ?? AtomKit.scalar(.double(point.y)) ?? "", "caption", onEvent: onEvent)
                        }
                    }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                if props.bool("showGrid", default: true) {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(theme.color.border)
                    }
                }
            }
            .chartLegend(.hidden)
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(props.string("aria-label", default: "Line chart"))
            .accessibilityValue(points.map { ($0.label ?? "") + " " + (AtomKit.scalar(.double($0.y)) ?? "") }.joined(separator: ", "))
        }
    }
}

@ViewBuilder
func LineChartRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LineChartMoleculeView(props: props, onEvent: onEvent))
}
