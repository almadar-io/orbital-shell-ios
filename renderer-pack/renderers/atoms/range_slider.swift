import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct RangeSliderAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var current: Double
    @State private var dragging = false

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _current = State(initialValue: props.float("value"))
    }

    private var lower: Double { props.float("min", default: 0) }
    private var upper: Double { max(props.float("max", default: 100), lower + 1) }
    private var step: Double { props.float("step", default: 1) }
    private var disabled: Bool { props.bool("disabled") }
    private var shown: Double { min(max(current, lower), upper) }

    private var trackHeight: CGFloat {
        switch props.string("size", default: "md") {
        case "sm": return theme.density.spacing.space1
        case "lg": return theme.density.spacing.space2
        default: return AlmadarSizes.maxW1_5
        }
    }

    private var thumbSide: CGFloat {
        switch props.string("size", default: "md") {
        case "sm": return theme.density.spacing.space3
        case "lg": return theme.density.spacing.space5
        default: return theme.density.spacing.space4
        }
    }

    private func commit(_ raw: Double) {
        let stepped = step > 0 ? lower + ((raw - lower) / step).rounded() * step : raw
        let next = min(max(stepped, lower), upper)
        guard next != current else { return }
        current = next
        let action = props.string("action")
        guard !action.isEmpty else { return }
        var merged = props.dictValue?["actionPayload"]?.dictValue ?? [:]
        merged["value"] = .double(next)
        onEvent(action, eventEnvelope(props.merging(["actionPayload": .dict(merged)])))
    }

    private func track(_ width: CGFloat) -> some View {
        let reach = max(width - thumbSide, 1)
        let offset = CGFloat((shown - lower) / (upper - lower)) * reach
        let thumb = AtomKit.shape(theme, .pill, radius: thumbSide / 2)
        return ZStack(alignment: .leading) {
            AtomKit.shape(theme, .pill, radius: trackHeight / 2)
                .fill(theme.color.muted)
                .frame(height: trackHeight)
            AtomKit.shape(theme, .pill, radius: trackHeight / 2)
                .fill(theme.color.primary)
                .frame(width: offset + thumbSide / 2, height: trackHeight)
            thumb
                .fill(theme.color.primaryForeground)
                .overlay(thumb.stroke(theme.color.primary, lineWidth: theme.geometry.borderHeavy))
                .frame(width: thumbSide, height: thumbSide)
                .atomElevation(theme, .pill, radius: thumbSide / 2, theme.elevation.interactiveElevation)
                .offset(x: offset)
            if props.bool("showTooltip") && dragging {
                AtomKit.ink(theme, display(shown), "xs", weight: .medium, color: theme.color.background)
                    .padding(.horizontal, theme.density.spacing.space2)
                    .padding(.vertical, theme.density.spacing.space1 / 2)
                    .background(theme.color.foreground)
                    .atomClip(theme, .container)
                    .fixedSize()
                    .alignmentGuide(.leading) { $0.width / 2 - thumbSide / 2 }
                    .offset(x: offset, y: -(thumbSide / 2 + theme.density.spacing.space4))
            }
        }
        .frame(width: width, height: thumbSide + theme.density.spacing.space4, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    dragging = true
                    let fraction = min(max(Double((drag.location.x - thumbSide / 2) / reach), 0), 1)
                    commit(lower + fraction * (upper - lower))
                }
                .onEnded { _ in dragging = false }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            GeometryReader { proxy in track(proxy.size.width) }
                .frame(height: thumbSide + theme.density.spacing.space4)
            if props.bool("showTicks") {
                HStack {
                    AtomKit.ink(theme, display(lower), "xs", color: theme.color.mutedForeground)
                    Spacer()
                    AtomKit.ink(theme, display(upper), "xs", color: theme.color.mutedForeground)
                }
            }
        }
        .opacity(disabled ? 0.5 : 1)
        .allowsHitTesting(!disabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(props.string("aria-label", default: "Slider")))
        .accessibilityValue(Text(display(shown)))
        .accessibilityAdjustableAction { direction in
            let delta = step > 0 ? step : 1
            commit(direction == .increment ? shown + delta : shown - delta)
        }
        .atomAction(props.string("action"), props)
        .onChange(of: props.float("value")) { value in current = value }
    }

    private func display(_ value: Double) -> String {
        AtomKit.scalar(.double(value)) ?? ""
    }
}

@ViewBuilder
func RangeSliderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RangeSliderAtomView(props: props, onEvent: onEvent))
}
