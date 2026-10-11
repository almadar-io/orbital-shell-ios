import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AtomTooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TooltipMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var shown = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        let position = props.string("position", default: "top")
        let horizontal = position == "left" || position == "right"
        let leading = position == "top" || position == "left"
        let content = props.dictValue?["content"]
        let spoken = AtomKit.scalar(content) ?? ""
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: theme.density.spacing.space1)) : AnyLayout(VStackLayout(spacing: theme.density.spacing.space1))
        layout {
            if shown && leading { bubble(content, position: position) }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
                .contentShape(Rectangle())
                .onTapGesture { toggle() }
                .onLongPressGesture(minimumDuration: max(props.float("delay", default: 200) / 1000, 0.01)) { reveal() }
            if shown && !leading { bubble(content, position: position) }
        }
        .accessibilityHint(spoken)
    }

    private func reveal() {
        shown = true
        hideTask?.cancel()
        let hide = props.float("hideDelay")
        if hide > 0 {
            hideTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(hide * 1_000_000))
                if !Task.isCancelled { shown = false }
            }
        }
    }

    private func toggle() {
        if shown { shown = false } else { reveal() }
    }

    @ViewBuilder
    private func bubble(_ content: AnyCodable?, position: String) -> some View {
        let arrow = props.bool("showArrow", default: true)
        let degrees: Double = position == "top" ? 0 : (position == "bottom" ? 180 : (position == "left" ? -90 : 90))
        let tip = AtomTooltipArrow()
            .fill(theme.color.foreground)
            .frame(width: theme.density.spacing.space2, height: theme.density.spacing.space1)
            .rotationEffect(.degrees(degrees))
        let label = AtomSlot(content, variant: "caption", color: "inherit", onEvent: onEvent)
            .foregroundColor(theme.color.background)
            .padding(.horizontal, theme.density.spacing.space2)
            .padding(.vertical, theme.density.spacing.space1)
            .background(theme.color.foreground)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        let layout = (position == "left" || position == "right") ? AnyLayout(HStackLayout(spacing: theme.density.spacing.space0)) : AnyLayout(VStackLayout(spacing: theme.density.spacing.space0))
        layout {
            if arrow && (position == "bottom" || position == "right") { tip }
            label
            if arrow && (position == "top" || position == "left") { tip }
        }
    }
}

@ViewBuilder
func TooltipRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TooltipMoleculeView(props: props, onEvent: onEvent))
}
