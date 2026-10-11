import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import Charts

struct ChartMoleculePoint {
    let series: String
    let label: String
    let value: Double
    let color: Color
}

struct ChartMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private static let palette = ["var(--color-primary)", "var(--color-success)", "var(--color-warning)", "var(--color-error)", "var(--color-info)", "var(--color-accent)"]

    private var kind: String {
        let look = props.string("look")
        let raw = look.isEmpty ? props.string("chartType", default: "bar") : look
        switch raw {
        case "bar", "bar-vertical", "histogram": return raw == "histogram" ? "histogram" : "bar"
        default: return raw
        }
    }

    private func label(_ raw: String) -> String {
        props.bool("timeAxis") ? AtomKit.formatted(raw, format: "date") : raw
    }

    private var points: [ChartMoleculePoint] {
        let list = props.dictValue?["series"]?.arrayValue ?? []
        if list.isEmpty {
            return (props.dictValue?["data"]?.arrayValue ?? []).enumerated().map { entry in
                let tone = entry.element.string("color", default: ChartMoleculeView.palette[entry.offset % ChartMoleculeView.palette.count])
                return ChartMoleculePoint(series: "default", label: label(entry.element.string("label")), value: entry.element.float("value"), color: AtomKit.cssColor(theme, tone))
            }
        }
        var out: [ChartMoleculePoint] = []
        for (index, series) in list.enumerated() {
            let name = series.string("name")
            let tone = series.string("color", default: ChartMoleculeView.palette[index % ChartMoleculeView.palette.count])
            for point in series.dictValue?["data"]?.arrayValue ?? [] {
                let own = point.string("color")
                out.append(ChartMoleculePoint(series: name, label: label(point.string("label")), value: point.float("value"), color: AtomKit.cssColor(theme, own.isEmpty ? tone : own)))
            }
        }
        return out
    }

    private var scatter: [AnyCodable] { props.dictValue?["scatterData"]?.arrayValue ?? [] }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "chart"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Chart error", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else if points.isEmpty && scatter.isEmpty {
            EmptyStateRenderer(props: AtomKit.emptyProps(props, fallback: "No data"), modifier: nil, onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
                if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h5", onEvent: onEvent) }
                if !props.string("subtitle").isEmpty { AtomKit.typo(props.string("subtitle"), "caption", color: "muted", onEvent: onEvent) }
                plot
                    .atomAction(props.string("drillEvent"), props)
                if props.bool("showLegend", default: true) { legend }
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .atomSurface(theme)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var plot: some View {
        let height = CGFloat(props.float("height", default: 200))
        if kind == "pie" || kind == "donut" {
            pie(donut: kind == "donut")
                .frame(height: height)
        } else {
            Chart {
                if kind == "scatter" {
                    ForEach(scatter.indices, id: \.self) { index in
                        PointMark(x: .value("X", scatter[index].float("x")), y: .value("Y", scatter[index].float("y")))
                            .foregroundStyle(AtomKit.cssColor(theme, scatter[index].string("color", default: "var(--color-primary)")))
                            .symbolSize(scatter[index].float("size", default: 8) * 12)
                    }
                } else {
                    ForEach(points.indices, id: \.self) { index in
                        mark(points[index])
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: height)
            .chartOverlay { proxy in
                GeometryReader { box in
                    Rectangle()
                        .fill(AtomKit.clear(theme))
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let origin = box[proxy.plotAreaFrame].origin
                            let key: String? = kind == "bar-horizontal" ? proxy.value(atY: location.y - origin.y, as: String.self) : proxy.value(atX: location.x - origin.x, as: String.self)
                            if let key = key { drill(key) }
                        }
                }
            }
        }
    }

    private var stacking: MarkStackingMethod {
        props.string("stack", default: "none") == "normalize" ? .normalized : .standard
    }

    private var grouped: Bool {
        props.string("stack", default: "none") == "none" && Set(points.map { $0.series }).count > 1
    }

    @ChartContentBuilder
    private func mark(_ point: ChartMoleculePoint) -> some ChartContent {
        if kind == "line" {
            LineMark(x: .value("Label", point.label), y: .value("Value", point.value), series: .value("Series", point.series))
                .foregroundStyle(point.color)
                .annotation(position: .top) { valueText(point) }
        } else if kind == "area" {
            AreaMark(x: .value("Label", point.label), y: .value("Value", point.value), series: .value("Series", point.series), stacking: stacking)
                .foregroundStyle(point.color.opacity(0.4))
        } else if kind == "bar-horizontal" {
            BarMark(x: .value("Value", point.value), y: .value("Label", point.label), stacking: stacking)
                .foregroundStyle(point.color)
                .annotation(position: .trailing) { valueText(point) }
        } else if kind == "histogram" {
            BarMark(x: .value("Label", point.label), y: .value("Value", point.value), width: .ratio(1), stacking: stacking)
                .foregroundStyle(point.color)
                .annotation(position: .top) { valueText(point) }
        } else if grouped {
            BarMark(x: .value("Label", point.label), y: .value("Value", point.value))
                .foregroundStyle(point.color)
                .position(by: .value("Series", point.series))
                .annotation(position: .top) { valueText(point) }
        } else {
            BarMark(x: .value("Label", point.label), y: .value("Value", point.value), stacking: stacking)
                .foregroundStyle(point.color)
                .annotation(position: .top) { valueText(point) }
        }
    }

    @ViewBuilder
    private func valueText(_ point: ChartMoleculePoint) -> some View {
        if props.bool("showValues") {
            AtomKit.typo(point.value == point.value.rounded() ? String(Int(point.value)) : String(format: "%.1f", point.value), "caption", color: "muted", onEvent: onEvent)
        }
    }

    private func drill(_ key: String) {
        let event = props.string("drillEvent")
        guard !event.isEmpty, let hit = points.first(where: { $0.label == key }) else { return }
        onEvent(event, eventEnvelope(props, payload: ["label": .string(hit.label), "value": .double(hit.value), "series": .string(hit.series)]))
    }

    private func slices() -> [(start: Double, end: Double, point: ChartMoleculePoint)] {
        let list = points
        let total = max(list.reduce(0) { $0 + abs($1.value) }, 0.0001)
        var running = 0.0
        return list.map { point in
            let begin = running
            running += abs(point.value) / total
            return (start: begin, end: running, point: point)
        }
    }

    private func pie(donut: Bool) -> some View {
        let parts = slices()
        return ZStack {
            ForEach(parts.indices, id: \.self) { index in
                AtomPieShape(start: parts[index].start, end: parts[index].end, hole: donut ? 0.6 : 0)
                    .fill(parts[index].point.color)
                    .overlay(AtomPieShape(start: parts[index].start, end: parts[index].end, hole: donut ? 0.6 : 0).stroke(theme.color.card, lineWidth: theme.geometry.borderStandard))
                    .contentShape(AtomPieShape(start: parts[index].start, end: parts[index].end, hole: donut ? 0.6 : 0))
                    .onTapGesture { drill(parts[index].point.label) }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var legend: some View {
        let pieLike = kind == "pie" || kind == "donut"
        let entries: [(name: String, color: Color)] = pieLike
            ? points.map { (name: $0.label + ": " + String($0.value == $0.value.rounded() ? String(Int($0.value)) : String($0.value)), color: $0.color) }
            : Array(Dictionary(grouping: points, by: { $0.series }).compactMap { entry -> (name: String, color: Color)? in
                entry.key == "default" ? nil : (name: entry.key, color: entry.value[0].color)
            }).sorted { $0.name < $1.name }
        if !entries.isEmpty {
            AtomGridLayout(minWidth: theme.density.spacing.space12 * 2, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space2) {
                ForEach(entries.indices, id: \.self) { index in
                    HStack(spacing: theme.density.spacing.space1) {
                        Circle().fill(entries[index].color).frame(width: theme.density.spacing.space2, height: theme.density.spacing.space2)
                        AtomKit.typo(entries[index].name, "caption", color: "muted", onEvent: onEvent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        let list = (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        if !list.isEmpty {
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(list.indices, id: \.self) { index in
                    ButtonRenderer(props: AtomKit.actionProps(props, list[index], row: nil, size: "sm", fallback: "ghost"), modifier: nil, onEvent: onEvent)
                }
            }
        }
    }
}

@ViewBuilder
func ChartRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ChartMoleculeView(props: props, onEvent: onEvent))
}
