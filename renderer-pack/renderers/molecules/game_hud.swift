import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GameHudMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var stats: [AnyCodable] {
        if let given = props.dictValue?["stats"]?.arrayValue { return given }
        if let given = props.dictValue?["items"]?.arrayValue { return given }
        if let elements = props.dictValue?["elements"]?.arrayValue { return elements.map { convert($0) } }
        return [
            .dict(["label": "HP", "value": 75, "max": 100, "format": "bar", "variant": "danger"]),
            .dict(["label": "MP", "value": 40, "max": 60, "format": "bar", "variant": "primary"]),
            .dict(["label": "Score", "value": 4200, "format": "number", "variant": "warning"]),
            .dict(["label": "Level", "value": 4, "format": "number", "variant": "default"]),
        ]
    }

    private func convert(_ element: AnyCodable) -> AnyCodable {
        let type = element.string("type")
        let fallback: String
        switch type {
        case "health-bar": fallback = "Health"
        case "score-display": fallback = "Score"
        case "lives": fallback = "Lives"
        case "timer": fallback = "Time"
        default: fallback = type
        }
        var stat: [String: AnyCodable] = ["label": .string(element.string("label", default: fallback))]
        for key in ["value", "icon", "assetUrl", "format", "max"] {
            if let value = element.dictValue?[key] { stat[key] = value }
        }
        return .dict(stat)
    }

    private func badge(_ stat: AnyCodable) -> some View {
        StatBadgeRenderer(props: AtomKit.child(props, stat.merging(["size": .string(props.string("size", default: "md"))]).dictValue ?? [:]), modifier: nil, onEvent: onEvent)
    }

    var body: some View {
        let list = stats
        let mid = (list.count + 1) / 2
        let left = Array(list.prefix(mid))
        let right = Array(list.dropFirst(mid))
        let veil = props.bool("transparent", default: true) ? 0.4 : 1.0
        layout(left: left, right: right, veil: veil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func layout(left: [AnyCodable], right: [AnyCodable], veil: Double) -> some View {
        if props.string("position", default: "top") == "corners" {
            corners(left: left, right: right)
        } else if props.string("variant", default: "floating") == "bar" {
            bar(left: left, right: right, veil: veil)
        } else {
            floating(left + right, veil: veil)
        }
    }

    private func corners(left: [AnyCodable], right: [AnyCodable]) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                ForEach(left.indices, id: \.self) { index in badge(left[index]) }
            }
            Spacer(minLength: theme.density.spacing.space0)
            VStack(alignment: .trailing, spacing: theme.density.spacing.space2) {
                ForEach(right.indices, id: \.self) { index in badge(right[index]) }
            }
        }
        .padding(theme.density.spacing.space4)
    }

    private func bar(left: [AnyCodable], right: [AnyCodable], veil: Double) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.density.spacing.space4) {
                HStack(spacing: theme.density.spacing.space3) {
                    ForEach(left.indices, id: \.self) { index in badge(left[index]) }
                }
                Spacer(minLength: theme.density.spacing.space0)
                HStack(spacing: theme.density.spacing.space3) {
                    ForEach(right.indices, id: \.self) { index in badge(right[index]) }
                }
            }
            AtomFlowLayout(spacing: theme.density.spacing.space3) {
                ForEach((left + right).indices, id: \.self) { index in badge((left + right)[index]) }
            }
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.vertical, theme.density.spacing.space2)
        .background(theme.color.card.opacity(veil))
        .overlay(Rectangle().stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    private func floating(_ all: [AnyCodable], veil: Double) -> some View {
        AtomFlowLayout(spacing: theme.density.spacing.space3) {
            ForEach(all.indices, id: \.self) { index in badge(all[index]) }
        }
        .padding(theme.density.cardPaddingSm)
        .background(theme.color.card.opacity(veil * 0.75))
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }
}

@ViewBuilder
func GameHudRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GameHudMoleculeView(props: props, onEvent: onEvent))
}
