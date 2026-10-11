import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FxOverlayNodeView: View {
    let item: AnyCodable
    let tickMs: Double
    /// Native-only test seam: an `at` prop (ms into the effect) pins one frame; absent, the live clock runs.
    let pinnedMs: Double?
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var born = Date()

    private var id: String { item.string("id") }
    private var scale: Double { item.dictValue?["size"]?.doubleValue ?? 1 }
    private var anchor: CGPoint {
        CGPoint(x: item.dictValue?["x"]?.doubleValue ?? 0.5, y: item.dictValue?["z"]?.doubleValue ?? item.dictValue?["y"]?.doubleValue ?? 0.4)
    }
    private var lifeMs: Double {
        let ttl = item.dictValue?["ttl"]?.doubleValue ?? 0
        let maxTtl = item.dictValue?["maxTtl"]?.doubleValue ?? ttl
        return max(maxTtl, ttl, 1) * tickMs
    }

    private func tint(_ fallback: String) -> Color {
        AtomKit.cssColor(theme, item.string("color", default: fallback))
    }

    private func lerp(_ from: Double, _ to: Double, _ amount: Double) -> Double { from + (to - from) * amount }

    var body: some View {
        Group {
            if let at = pinnedMs {
                effect(elapsed: at, progress: min(max(at / lifeMs, 0), 1))
            } else {
                TimelineView(.animation) { context in
                    let elapsed = max(context.date, Date()).timeIntervalSince(born) * 1000
                    let progress = min(max(elapsed / lifeMs, 0), 1)
                    effect(elapsed: elapsed, progress: progress)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func effect(elapsed: Double, progress: Double) -> some View {
        switch item.string("effect", default: "sparkle") {
        case "confetti":
            AtomConfettiBurst(
                particles: AtomFx.confetti(Int(item.dictValue?["particleCount"]?.doubleValue ?? 30), seed: id),
                elapsedMs: elapsed,
                lifeMs: lifeMs,
                reach: scale,
                tint: item.dictValue?["color"] == nil ? nil : tint(""),
                anchor: anchor,
                minDurationMs: 200
            )
        case "flash":
            tint("#ffffff").opacity(0.75 * (1 - AtomFx.easeOut(progress)))
        case "streak-glow":
            let amount = progress < 0.6 ? lerp(0.9, 0.6, AtomFx.easeInOut(progress / 0.6)) : lerp(0.6, 0, AtomFx.easeInOut((progress - 0.6) / 0.4))
            let blur = 60 * scale
            Rectangle()
                .strokeBorder(tint("var(--color-warning)"), lineWidth: blur / 2)
                .blur(radius: blur / 2)
                .clipped()
                .opacity(amount)
        case "float-text":
            floating(elapsed: elapsed, progress: progress)
        case "shake":
            EmptyView()
        default:
            sparkle(elapsed: elapsed)
        }
    }

    @ViewBuilder
    private func floating(elapsed: Double, progress: Double) -> some View {
        let message = item.string("message")
        if !message.isEmpty {
            let rise = progress < 0.15 ? AtomFx.easeOut(progress / 0.15) : 1 - AtomFx.easeOut((progress - 0.15) / 0.85)
            GeometryReader { proxy in
                AtomKit.ink(theme, message, "base", weight: .bold, color: tint("var(--color-success)"))
                    .shadow(color: theme.color.foreground.opacity(0.4), radius: theme.geometry.borderStandard, y: theme.geometry.borderHairline)
                    .scaleEffect(scale)
                    .fixedSize()
                    .opacity(rise)
                    .position(x: anchor.x * proxy.size.width, y: anchor.y * proxy.size.height + 8 - 48 * AtomFx.easeOut(progress))
            }
        }
    }

    @ViewBuilder
    private func sparkle(elapsed: Double) -> some View {
        let count = Int(item.dictValue?["particleCount"]?.doubleValue ?? 8)
        GeometryReader { proxy in
            ForEach(0..<max(count, 0), id: \.self) { index in
                let dx = (AtomFx.hash01(id, index * 4) - 0.5) * 160 * scale
                let dy = (AtomFx.hash01(id, index * 4 + 1) - 0.5) * 120 * scale
                let dot = (4 + AtomFx.hash01(id, index * 4 + 2) * 5) * scale
                let delay = AtomFx.hash01(id, index * 4 + 3) * lifeMs * 0.4
                let t = min(max((elapsed - delay) / max(lifeMs - delay, 200), 0), 1)
                let grow = t < 0.3 ? AtomFx.easeInOut(t / 0.3) : 1 - AtomFx.easeInOut((t - 0.3) / 0.7)
                let size = t < 0.3 ? grow : lerp(0.3, 1, grow)
                if elapsed >= delay {
                    Circle()
                        .fill(item.dictValue?["color"] == nil ? AlmadarThemeParse.color("#FFD700", fallback: theme.color.warning) : tint(""))
                        .frame(width: dot, height: dot)
                        .scaleEffect(size)
                        .opacity(grow)
                        .position(x: anchor.x * proxy.size.width + dx + dot / 2, y: anchor.y * proxy.size.height + dy + dot / 2)
                }
            }
        }
    }
}

struct FxOverlayShake: ViewModifier {
    let token: String
    let lifeMs: Double
    let pinnedMs: Double?
    @State private var born = Date()
    private static let steps: [Double] = [0, -6, 5, -4, 3, -2, 0]

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: token.isEmpty || pinnedMs != nil)) { context in
            let elapsed = pinnedMs ?? max(context.date, Date()).timeIntervalSince(born) * 1000
            content.offset(x: token.isEmpty ? 0 : shift(min(max(elapsed / min(lifeMs, 600), 0), 1)))
        }
        .id(token)
    }

    private func shift(_ t: Double) -> CGFloat {
        let slot = min(Int(t * 6), 5)
        let local = AtomFx.easeInOut(t * 6 - Double(slot))
        return CGFloat(Self.steps[slot] + (Self.steps[slot + 1] - Self.steps[slot]) * local)
    }
}

struct FxOverlayMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var items: [AnyCodable] {
        (props.dictValue?["items"]?.arrayValue ?? []).filter { $0.dictValue?["id"]?.stringValue != nil && $0.string("space") != "world" }
    }

    private func life(_ item: AnyCodable, _ tick: Double) -> Double {
        let ttl = item.dictValue?["ttl"]?.doubleValue ?? 0
        return max(item.dictValue?["maxTtl"]?.doubleValue ?? ttl, ttl, 1) * tick
    }

    private func layer(_ tick: Double) -> some View {
        ZStack {
            ForEach(items.indices, id: \.self) { index in
                FxOverlayNodeView(item: items[index], tickMs: tick, pinnedMs: props.dictValue?["at"]?.doubleValue, onEvent: onEvent)
                    .id(items[index].string("id"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    var body: some View {
        let tick = props.dictValue?["tickMs"]?.doubleValue ?? 500
        let shake = items.last(where: { $0.string("effect") == "shake" })
        if props.dictValue?["children"] != nil {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
                .modifier(FxOverlayShake(token: shake?.string("id") ?? "", lifeMs: shake.map { life($0, tick) } ?? 0, pinnedMs: props.dictValue?["at"]?.doubleValue))
                .overlay(layer(tick))
        } else {
            AtomKit.clear(theme)
                .frame(maxWidth: .infinity, minHeight: AlmadarSizes.w64)
                .overlay(layer(tick))
        }
    }
}

@ViewBuilder
func FxOverlayRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FxOverlayMoleculeView(props: props, onEvent: onEvent))
}
