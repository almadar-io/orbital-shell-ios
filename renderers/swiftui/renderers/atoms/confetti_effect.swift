import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ConfettiEffectAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var burst = 0
    @State private var started = Date()
    @State private var live = false
    @State private var armed = false

    private func sync(_ trigger: Bool) {
        let rising = trigger && !armed
        armed = trigger
        if rising && !reducedMotion {
            burst += 1
            started = Date()
            live = true
        }
    }

    private func drawn(elapsedMs: Double, duration: Double, seed: String) -> some View {
        AtomConfettiBurst(
            particles: AtomFx.confetti(props.int("particleCount", default: 30), seed: seed),
            elapsedMs: elapsedMs,
            lifeMs: duration,
            reach: 1,
            tint: nil,
            anchor: nil,
            minDurationMs: 1
        )
    }

    var body: some View {
        let duration = props.float("duration", default: 2000)
        Group {
            // Native-only test seam: an `at` prop (ms into the burst) pins one frame; absent, the live clock runs.
            if let at = props.dictValue?["at"]?.doubleValue {
                if props.bool("trigger") { drawn(elapsedMs: at, duration: duration, seed: "confetti-pinned") }
            } else {
                TimelineView(.animation(paused: !live)) { context in
                    if live { drawn(elapsedMs: max(context.date, Date()).timeIntervalSince(started) * 1000, duration: duration, seed: "confetti-\(burst)") }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: AlmadarSizes.w64)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { sync(props.bool("trigger")) }
        .onChange(of: props.bool("trigger")) { next in sync(next) }
        .task(id: burst) {
            guard live else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(max(duration, 0) * 1_000_000))
            } catch {
                return
            }
            live = false
        }
    }
}

@ViewBuilder
func ConfettiEffectRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ConfettiEffectAtomView(props: props, onEvent: onEvent))
}
