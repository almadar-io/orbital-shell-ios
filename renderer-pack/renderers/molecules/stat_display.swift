import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct StatDisplayMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let error = AtomKit.errorText(props)
        let clickEvent = props.string("clickEvent")
        let size = props.string("size", default: "md")
        let variant = props.string("variant", default: "default")
        let label = props.string("label")
        let icon = props.string("icon")
        let spark = (props.dictValue?["sparklineData"]?.arrayValue ?? []).compactMap { $0.doubleValue }
        let content = Group {
            if props.bool("compact") {
                HStack(spacing: theme.density.spacing.space2) {
                    if !icon.isEmpty { AtomKit.icon(icon, size == "lg" ? "md" : "sm", color: props.string("iconColor"), onEvent: onEvent) }
                    AtomKit.typo(label, "caption", color: "secondary", onEvent: onEvent)
                    value(size: size, variant: variant)
                    trendText
                    if spark.count > 1 { SparklineRenderer(props: ["data": .array(spark.map { AnyCodable.double($0) }), "color": "auto", "width": 60, "height": 20], modifier: nil, onEvent: onEvent) }
                }
            } else {
                HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo(label, "overline", color: "secondary", onEvent: onEvent)
                        HStack(alignment: .lastTextBaseline, spacing: theme.density.spacing.space2) {
                            value(size: size, variant: variant)
                            trendText
                        }
                        if let percent = targetPercent {
                            ProgressBarRenderer(props: ["value": .double(percent), "max": 100, "color": .string(variant == "default" ? "primary" : variant)], modifier: nil, onEvent: onEvent)
                                .padding(.top, theme.density.spacing.space2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: theme.density.spacing.space1) {
                        if !icon.isEmpty {
                            AtomKit.icon(icon, size == "lg" ? "lg" : "md", color: props.string("iconColor"), onEvent: onEvent)
                                .padding(theme.density.spacing.space3)
                                .background(theme.color.muted)
                                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
                        }
                        if spark.count > 1 { SparklineRenderer(props: ["data": .array(spark.map { AnyCodable.double($0) }), "color": "auto"], modifier: nil, onEvent: onEvent) }
                    }
                }
                .padding(size == "sm" ? theme.density.cardPaddingSm : (size == "lg" ? theme.density.cardPaddingLg : theme.density.cardPaddingMd))
                .background(theme.color.card)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
                .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
                .atomShadow(props.string("look", default: "elevated") == "flat" ? AtomKit.noShadow(theme) : theme.elevation.cardElevation)
            }
        }
        if !error.isEmpty {
            AtomKit.typo(error, "small", color: "error", onEvent: onEvent)
        } else if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "stats"), modifier: nil, onEvent: onEvent)
        } else if clickEvent.isEmpty {
            content.accessibilityElement(children: .combine)
        } else {
            content
                .contentShape(Rectangle())
                .onTapGesture { onEvent(clickEvent, eventEnvelope(props, payload: ["metricLabel": .string(label)])) }
                .accessibilityAddTraits(.isButton)
                .atomAction(clickEvent, props)
        }
    }

    private func value(size: String, variant: String) -> some View {
        TypographyRenderer(props: ["content": .string(composed), "variant": "h4", "size": .string(size == "sm" ? "lg" : (size == "lg" ? "3xl" : "2xl")), "color": "inherit"], modifier: nil, onEvent: onEvent)
            .foregroundColor(variant == "default" ? theme.color.foreground : AtomKit.tone(theme, variant))
    }

    private var composed: String {
        let format = props.string("format")
        let raw = AtomKit.text(props, "value")
        let shown = raw.isEmpty ? "0" : AtomKit.formatted(raw, format: format)
        let max = props.float("max")
        let withMax = max > 0 ? "\(shown) / \(AtomKit.formatted(String(Int(max)), format: "number"))" : shown
        return props.string("prefix") + withMax + props.string("suffix")
    }

    private var targetPercent: Double? {
        let target = props.float("target")
        guard target > 0, let current = Double(AtomKit.text(props, "value")) else { return nil }
        return min(max(current / target * 100, 0), 100)
    }

    @ViewBuilder
    private var trendText: some View {
        let trend = props.float("trend")
        if trend != 0 && trend.isFinite {
            let up = trend > 0
            let good = props.string("trendPolarity", default: "higher-is-better") == "lower-is-better" ? !up : up
            let magnitude = AtomKit.scalar(.double(abs(trend))) ?? ""
            AtomKit.typo("\(up ? "\u{2191}" : "\u{2193}") \(magnitude)\(props.string("trendFormat") == "percent" ? "%" : "")", "caption", color: good ? "success" : "error", weight: "semibold", onEvent: onEvent)
        }
    }
}

@ViewBuilder
func StatDisplayRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(StatDisplayMoleculeView(props: props, onEvent: onEvent))
}
