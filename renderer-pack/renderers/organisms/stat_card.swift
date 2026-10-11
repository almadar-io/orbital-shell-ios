import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct StatCardOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var metrics: [(label: String, text: String)] {
        let rows = AtomKit.rows(props, "entity")
        return (props.dictValue?["metrics"]?.arrayValue ?? []).map { metric in
            let format = metric.string("format", default: "number")
            if let fixed = AtomKit.scalar(metric.dictValue?["value"]) { return (metric.string("label"), AtomKit.formatted(fixed, format: format)) }
            let filter = metric.dictValue?["filter"]
            let scoped = rows.filter { row in
                guard let filter = filter, filter.dictValue != nil else { return true }
                return AtomKit.scalar(AtomKit.cell(row, filter.string("field"))) == AtomKit.scalar(filter.dictValue?["equals"])
            }
            let total: Double = metric.string("aggregate") == "count"
                ? Double(scoped.count)
                : scoped.reduce(0) { $0 + (AtomKit.cell($1, metric.string("field"))?.doubleValue ?? 0) }
            return (metric.string("label"), AtomKit.formatted(AtomKit.scalar(.double(total)) ?? "0", format: format))
        }
    }

    private var trend: Double? {
        if let manual = props.dictValue?["trend"]?.doubleValue { return manual }
        guard let previous = props.dictValue?["previousValue"]?.doubleValue, let current = props.dictValue?["currentValue"]?.doubleValue else { return nil }
        if previous == 0 { return current > 0 ? 100 : 0 }
        return (current - previous) / previous * 100
    }

    private var tile: some ViewModifier { AtomTileStyle(theme: theme) }

    var body: some View {
        let error = AtomKit.errorText(props)
        let stats = metrics
        let label = stats.first?.label ?? props.string("label", default: props.string("title", default: "Stat"))
        if !error.isEmpty {
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                AtomKit.typo(label, "overline", color: "secondary", onEvent: onEvent)
                AtomKit.typo("Error: " + error, "small", color: "error", onEvent: onEvent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(tile)
        } else if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "stats"), modifier: nil, onEvent: onEvent)
        } else if stats.count > 1 {
            AtomGridLayout(minWidth: theme.density.spacing.space12 * 3, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                ForEach(stats.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo(stats[index].label, "overline", color: "secondary", onEvent: onEvent)
                        AtomKit.typo(stats[index].text, "h4", onEvent: onEvent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(tile)
                }
            }
        } else {
            single(label: label, stats: stats)
        }
    }

    @ViewBuilder
    private func single(label: String, stats: [(label: String, text: String)]) -> some View {
        let raw = stats.first?.text ?? valueText
        let icon = props.string("icon")
        let spark = (props.dictValue?["sparklineData"]?.arrayValue ?? []).compactMap { $0.doubleValue }
        let action = props.dictValue?["action"]
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomKit.typo(label, "overline", color: "secondary", onEvent: onEvent)
                    AtomKit.typo(raw, "h4", onEvent: onEvent)
                    if let change = trend {
                        let direction = props.string("trendDirection", default: change == 0 ? "neutral" : (change > 0 ? "up" : "down"))
                        TrendIndicatorRenderer(
                            props: AtomKit.child(props, ["value": .double(abs(change)), "direction": .string(direction), "invert": .bool(props.bool("invertTrend")), "showValue": true, "size": "sm"]),
                            modifier: nil,
                            onEvent: onEvent
                        )
                    } else if !props.string("subtitle").isEmpty {
                        AtomKit.typo(props.string("subtitle"), "small", color: "secondary", onEvent: onEvent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: theme.density.spacing.space1) {
                    if !icon.isEmpty {
                        AtomKit.icon(icon, "lg", color: props.string("iconColor"), onEvent: onEvent)
                            .padding(theme.density.spacing.space3)
                            .background(theme.color.muted)
                    }
                    if spark.count > 1 {
                        SparklineRenderer(props: ["data": .array(spark.map { AnyCodable.double($0) }), "color": "auto"], modifier: nil, onEvent: onEvent)
                    }
                }
            }
            if let action = action, action.dictValue != nil {
                ButtonRenderer(props: AtomKit.actionProps(props, action, row: nil, size: "md", fallback: "ghost"), modifier: nil, onEvent: onEvent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(tile)
    }

    private var valueText: String {
        guard let raw = props.dictValue?["value"] else { return "0" }
        if let list = raw.arrayValue { return AtomKit.scalar(list.first) ?? String(list.count) }
        return AtomKit.scalar(raw) ?? "0"
    }
}

struct AtomTileStyle: ViewModifier {
    let theme: AlmadarTheme

    func body(content: Content) -> some View {
        content
            .padding(theme.density.cardPaddingMd)
            .background(theme.color.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }
}

@ViewBuilder
func StatCardRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StatCardOrganismView(props: props, onEvent: onEvent))
}
