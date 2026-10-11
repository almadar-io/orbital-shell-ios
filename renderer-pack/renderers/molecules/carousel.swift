import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct CarouselMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var requestedAt = -1
    @GestureState private var drag: CGFloat = 0
    private let ticker: Timer.TimerPublisher

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        ticker = Timer.publish(every: max(props.float("autoPlayInterval", default: 5000) / 1000, 1), on: .main, in: .common)
    }

    private var items: [AnyCodable] { props.dictValue?["items"]?.arrayValue ?? [] }
    private var event: String { props.string("slideChangeEvent") }
    private var loop: Bool { props.bool("loop") }
    private var vertical: Bool { props.string("orientation") == "vertical" }
    private var loadMoreEvent: String { props.string("loadMoreEvent") }

    var body: some View {
        if !items.isEmpty {
            let multiple = items.count > 1
            track
            .overlay(alignment: .center) {
                if props.bool("showArrows", default: true) && multiple { arrows }
            }
            .overlay(alignment: .bottom) {
                if props.bool("showDots", default: true) && multiple {
                    dots.padding(.bottom, theme.density.spacing.space3)
                }
            }
            .onReceive(ticker.autoconnect()) { _ in
                if props.bool("autoPlay") && multiple { go(index + 1) }
            }
        }
    }

    @ViewBuilder
    private var track: some View {
        if vertical { verticalTrack } else { horizontalTrack }
    }

    private var verticalTrack: some View {
        GeometryReader { proxy in
            VStack(spacing: theme.density.spacing.space0) {
                ForEach(items.indices, id: \.self) { position in
                    slide(position).frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .offset(y: -CGFloat(index) * proxy.size.height + drag)
            .animation(reduceMotion ? nil : theme.motion.animation(for: theme.motion.expand), value: index)
            .onAppear { height = proxy.size.height }
            .onChange(of: proxy.size.height) { next in height = next }
        }
        .frame(maxHeight: props.bool("fullHeight") ? .infinity : nil)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: theme.density.spacing.space4)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    if value.translation.height < -theme.density.spacing.space10 { go(index + 1) }
                    else if value.translation.height > theme.density.spacing.space10 { go(index - 1) }
                }
        )
    }

    private var horizontalTrack: some View {
        VStack(spacing: theme.density.spacing.space0) {
            AtomKit.clear(theme)
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .background(GeometryReader { proxy in
                    AtomKit.clear(theme)
                        .onAppear { width = proxy.size.width }
                        .onChange(of: proxy.size.width) { next in width = next }
                })
            HStack(spacing: theme.density.spacing.space0) {
                ForEach(items.indices, id: \.self) { position in
                    slide(position).frame(width: width)
                }
            }
            .offset(x: -CGFloat(index) * width + drag)
            .animation(reduceMotion ? nil : theme.motion.animation(for: theme.motion.expand), value: index)
            .frame(width: width, alignment: .leading)
            .clipped()
        }
        .gesture(
            DragGesture(minimumDistance: theme.density.spacing.space4)
                .updating($drag) { value, state, _ in state = value.translation.width }
                .onEnded { value in
                    if value.translation.width < -theme.density.spacing.space10 { go(index + 1) }
                    else if value.translation.width > theme.density.spacing.space10 { go(index - 1) }
                }
        )
    }

    private var template: AnyCodable? { props.dictValue?["renderItem"] ?? props.dictValue?["children"] }

    @ViewBuilder
    private func slide(_ position: Int) -> some View {
        if let nodes = template?.arrayValue {
            if position < nodes.count { RenderChild(nodes[position], onEvent: onEvent) }
        } else if let node = template, node.dictValue != nil {
            RenderChild(node, onEvent: onEvent)
        }
    }

    @ViewBuilder
    private var arrows: some View {
        if vertical {
            VStack {
                if loop || index > 0 { arrow(-1, "chevron-up", "Previous slide") }
                Spacer(minLength: theme.density.spacing.space0)
                if loop || index < items.count - 1 { arrow(1, "chevron-down", "Next slide") }
            }
            .padding(.vertical, theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, theme.density.spacing.space2)
        } else {
            HStack {
                if loop || index > 0 { arrow(-1, "chevron-left", "Previous slide") }
                Spacer(minLength: theme.density.spacing.space0)
                if loop || index < items.count - 1 { arrow(1, "chevron-right", "Next slide") }
            }
            .padding(.horizontal, theme.density.spacing.space2)
        }
    }

    private func arrow(_ step: Int, _ icon: String, _ label: String) -> some View {
        ButtonRenderer(
            props: AtomKit.child(props, [
                "variant": "ghost",
                "size": "sm",
                "icon": .string(icon),
                "aria-label": .string(label),
                "action": .string(AtomKit.eventOrLocal(event)),
                "local": .bool(event.isEmpty),
                "actionPayload": payload(target(index + step)),
            ]),
            modifier: nil,
            onEvent: { _, _ in go(index + step) }
        )
    }

    private var dots: some View {
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(items.indices, id: \.self) { position in
                let active = position == index
                let side = active ? theme.density.spacing.space2 + theme.density.spacing.space1 / 2 : theme.density.spacing.space2
                Circle()
                    .fill(active ? theme.color.primary : theme.color.muted)
                    .opacity(active ? 1 : 0.6)
                    .frame(width: side, height: side)
                    .padding(theme.density.spacing.space1)
                    .contentShape(Rectangle())
                    .onTapGesture { go(position) }
                    .accessibilityLabel("Go to slide \(position + 1)")
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                    .atomAction(event, props)
            }
        }
    }

    private func target(_ proposed: Int) -> Int {
        let last = items.count - 1
        if loop { return proposed < 0 ? last : (proposed > last ? 0 : proposed) }
        return max(0, min(last, proposed))
    }

    private func payload(_ position: Int) -> AnyCodable {
        var merged: [String: AnyCodable] = ["index": .int(position)]
        for (key, value) in props.dictValue?["slideChangePayload"]?.dictValue ?? [:] { merged[key] = value }
        return .dict(merged)
    }

    private func go(_ proposed: Int) {
        let next = target(proposed)
        index = next
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: payload(next))) }
        requestMoreIfNear(next)
    }

    /// Asks once per page for more slides when the viewer is `loadMoreAhead` from the end.
    private func requestMoreIfNear(_ position: Int) {
        guard !loadMoreEvent.isEmpty, props.bool("hasMore"), !props.bool("isLoadingMore") else { return }
        let ahead = Int(props.float("loadMoreAhead", default: 2))
        guard position >= items.count - 1 - ahead, requestedAt != items.count else { return }
        requestedAt = items.count
        onEvent(loadMoreEvent, eventEnvelope(props, payload: .dict(["index": .int(position)])))
    }
}

@ViewBuilder
func CarouselRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CarouselMoleculeView(props: props, onEvent: onEvent))
}
