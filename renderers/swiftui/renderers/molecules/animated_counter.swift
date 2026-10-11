import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct CountingText: View, Animatable {
    var number: Double
    let render: (Double) -> String
    let onEvent: (String, AnyCodable?) -> Void

    var animatableData: Double {
        get { number }
        set { number = newValue }
    }

    var body: some View {
        TypographyRenderer(props: ["content": .string(render(number)), "variant": "h2", "color": "inherit"], modifier: nil, onEvent: onEvent)
    }
}

struct AnimatedCounterMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        let parsed = parse(AtomKit.text(props, "value"))
        let label = props.string("label")
        VStack(spacing: theme.density.spacing.space1) {
            if let target = parsed.number {
                CountingText(number: shown, render: { text(parsed, $0) }, onEvent: onEvent)
                    .foregroundColor(theme.color.primary)
                    .onAppear { settle(to: target) }
                    .onChange(of: target) { settle(to: $0) }
            } else {
                AtomKit.typo(parsed.suffix, "h2", color: "inherit", onEvent: onEvent)
                    .foregroundColor(theme.color.primary)
            }
            if !label.isEmpty { AtomKit.typo(label, "body2", color: "muted", align: "center", onEvent: onEvent) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func settle(to target: Double) {
        let seconds = props.float("duration", default: 1500) / 1000
        if reduceMotion || seconds <= 0 {
            shown = target
        } else {
            withAnimation(.easeOut(duration: seconds)) { shown = target }
        }
    }

    private func text(_ parsed: (prefix: String, number: Double?, suffix: String, decimals: Int), _ value: Double) -> String {
        let format = props.string("format")
        let body: String
        switch format {
        case "currency", "percent", "number": body = AtomKit.formatted(String(Int(value.rounded())), format: format)
        default: body = String(format: "%.\(parsed.decimals)f", value)
        }
        return props.string("prefix") + parsed.prefix + body + parsed.suffix + props.string("suffix")
    }

    private func parse(_ raw: String) -> (prefix: String, number: Double?, suffix: String, decimals: Int) {
        let digits = Set("0123456789")
        guard let start = raw.firstIndex(where: { digits.contains($0) || $0 == "-" }) else { return ("", nil, raw, 0) }
        var end = start
        var seenDot = false
        var index = start
        while index < raw.endIndex {
            let character = raw[index]
            if digits.contains(character) || (index == start && character == "-") {
                end = raw.index(after: index)
            } else if character == "." && !seenDot, raw.index(after: index) < raw.endIndex, digits.contains(raw[raw.index(after: index)]) {
                seenDot = true
                end = raw.index(after: index)
            } else {
                break
            }
            index = raw.index(after: index)
        }
        let numeric = String(raw[start..<end])
        let decimals = numeric.contains(".") ? numeric.split(separator: ".").last.map { $0.count } ?? 0 : 0
        return (String(raw[raw.startIndex..<start]), Double(numeric), String(raw[end...]), decimals)
    }
}

@ViewBuilder
func AnimatedCounterRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AnimatedCounterMoleculeView(props: props, onEvent: onEvent))
}
