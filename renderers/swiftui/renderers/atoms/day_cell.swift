import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct DayCellAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let today = props.bool("isToday")
        let date = parsed()
        let action = props.string("onClick")
        let cell = VStack(spacing: theme.density.spacing.space1) {
            Text(weekdayText(date))
                .font(AtomKit.font(theme, "sm", .medium))
                .foregroundColor(today ? theme.color.primary : theme.color.mutedForeground)
            Text("\(Calendar.current.component(.day, from: date))")
                .font(AtomKit.font(theme, "base", .bold))
                .foregroundColor(today ? theme.color.primaryForeground : theme.color.foreground)
                .frame(width: theme.density.spacing.space8, height: theme.density.spacing.space8)
                .background(today ? theme.color.primary : AtomKit.clear(theme))
                .atomClip(theme, .pill, radius: theme.density.spacing.space8 / 2)
        }
        .padding(theme.density.spacing.space2)
        .frame(maxWidth: .infinity)
        .background(today ? theme.color.primary.opacity(0.1) : AtomKit.clear(theme))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(props.string("aria-label", default: fullText(date))))
        .accessibilityAddTraits(today ? [.isSelected] : [])
        if action.isEmpty {
            cell
        } else {
            Button(action: { onEvent(action, eventEnvelope(props, payload: ["date": .string(AtomKit.text(props, "date"))])) }) { cell }
                .buttonStyle(.plain)
                .atomAction(action, props)
        }
    }

    private func weekdayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func fullText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func parsed() -> Date {
        let raw = AtomKit.text(props, "date")
        let iso = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        return iso.date(from: raw) ?? day.date(from: String(raw.prefix(10))) ?? Date()
    }
}

@ViewBuilder
func DayCellRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DayCellAtomView(props: props, onEvent: onEvent))
}
