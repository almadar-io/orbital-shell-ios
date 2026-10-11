import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct MeterMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var minimum: Double { props.float("min", default: 0) }
    private var maximum: Double { props.float("max", default: 100) }
    private var value: Double { props.float("value", default: 0) }
    private var percentage: Double {
        let range = maximum - minimum
        return range > 0 ? min(max((value - minimum) / range, 0), 1) : 0
    }

    private var shown: String {
        let number = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return number + props.string("unit")
    }

    private func color(at amount: Double) -> Color {
        let list = props.dictValue?["thresholds"]?.arrayValue ?? []
        if list.isEmpty {
            if amount <= 30 { return theme.color.error }
            return amount <= 70 ? theme.color.warning : theme.color.success
        }
        for item in list where amount <= item.float("value") { return AtomKit.cssColor(theme, item.string("color")) }
        return AtomKit.cssColor(theme, list.last?.string("color") ?? "")
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            LoadingStateRenderer(props: AtomKit.child(props, [:]), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Meter error", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                switch props.string("variant", default: "linear") {
                case "radial": radial
                case "segmented": segmented
                default: linear
                }
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .atomSurface(theme)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(props.string("label", default: props.string("aria-label")))
            .accessibilityValue(shown)
        }
    }

    private var header: some View {
        HStack {
            if !props.string("label").isEmpty { AtomKit.typo(props.string("label"), "small", color: "secondary", weight: "medium", onEvent: onEvent) }
            Spacer()
            if props.bool("showValue", default: true) { AtomKit.typo(shown, "small", weight: "bold", onEvent: onEvent) }
        }
    }

    private var linear: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if !props.string("label").isEmpty || props.bool("showValue", default: true) { header }
            GeometryReader { box in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.color.muted)
                    Capsule().fill(color(at: percentage * 100)).frame(width: box.size.width * percentage)
                }
            }
            .frame(height: theme.density.spacing.space3)
            HStack {
                AtomKit.typo("\(Int(minimum))" + props.string("unit"), "caption", color: "secondary", onEvent: onEvent)
                Spacer()
                AtomKit.typo("\(Int(maximum))" + props.string("unit"), "caption", color: "secondary", onEvent: onEvent)
            }
        }
    }

    private var segmented: some View {
        let count = max(props.int("segments", default: 5), 1)
        let active = Int((percentage * Double(count)).rounded())
        return VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if !props.string("label").isEmpty || props.bool("showValue", default: true) { header }
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(0..<count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive / 2)
                        .fill(index < active ? color(at: Double(index + 1) / Double(count) * 100) : theme.color.muted)
                        .frame(height: theme.density.spacing.space2)
                }
            }
        }
    }

    private var radial: some View {
        let side: CGFloat = props.string("size", default: "md") == "sm" ? theme.density.spacing.space12 + theme.density.spacing.space4 * 2 : (props.string("size", default: "md") == "lg" ? theme.density.spacing.space12 * 3 + theme.density.spacing.space2 : theme.density.spacing.space12 * 2 + theme.density.spacing.space6)
        let stroke = theme.geometry.borderHeavy * (props.string("size", default: "md") == "lg" ? 10 : (props.string("size", default: "md") == "sm" ? 6 : 8))
        return VStack(spacing: theme.density.spacing.space2) {
            if !props.string("label").isEmpty { AtomKit.typo(props.string("label"), "small", color: "secondary", weight: "medium", align: "center", onEvent: onEvent) }
            ZStack {
                Circle().stroke(theme.color.muted, lineWidth: stroke)
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(color(at: percentage * 100), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if props.bool("showValue", default: true) { AtomKit.typo(shown, "h5", align: "center", onEvent: onEvent) }
            }
            .frame(width: side, height: side)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var actions: some View {
        let list = (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        if !list.isEmpty {
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(list.indices, id: \.self) { index in
                    let base = AtomKit.actionProps(props, list[index], row: nil, size: "sm", fallback: "ghost")
                    let routed = AtomKit.route(list[index], row: nil)
                    ButtonRenderer(props: routed.payload == nil ? base.merging(["actionPayload": ["value": .double(value)]]) : base, modifier: nil, onEvent: onEvent)
                }
            }
        }
    }
}

@ViewBuilder
func MeterRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MeterMoleculeView(props: props, onEvent: onEvent))
}
