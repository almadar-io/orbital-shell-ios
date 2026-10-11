import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct CalendarGridMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var offset = 0
    @State private var width: CGFloat = 0

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    private static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var events: [AnyCodable] { AtomKit.rows(props, "events") }
    private var startField: String { props.string("startField", default: "startTime") }
    private var endField: String { props.string("endField", default: "endTime") }
    private var titleField: String { props.string("titleField", default: "title") }

    private var weekDays: [Date] {
        let calendar = CalendarGridMoleculeView.calendar
        let anchor = AtomKit.parseDate(props.string("weekStart")) ?? Date()
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var visible: Int {
        if let fixed = Int(AtomKit.scalar(props.dictValue?["dayWindow"]) ?? ""), [1, 3, 7].contains(fixed) { return fixed }
        if width <= AlmadarBreakpoints.sm { return 1 }
        return width <= AlmadarBreakpoints.lg ? 3 : 7
    }

    private func start(_ event: AnyCodable) -> Date? { AtomKit.parseDate(AtomKit.scalar(AtomKit.cell(event, startField)) ?? "") }
    private func end(_ event: AnyCodable) -> Date? { AtomKit.parseDate(AtomKit.scalar(AtomKit.cell(event, endField)) ?? "") }

    private func hour(_ slot: String) -> Int { Int(slot.split(separator: ":").first ?? "") ?? 0 }

    private var slots: [String] {
        let given = AtomKit.strings(props, "timeSlots")
        if !given.isEmpty { return given }
        let calendar = CalendarGridMoleculeView.calendar
        var first = 9
        var last = 17
        for event in events {
            guard let begin = start(event) else { continue }
            first = min(first, calendar.component(.hour, from: begin))
            last = max(last, calendar.component(.hour, from: begin))
            if let finish = end(event), calendar.isDate(finish, inSameDayAs: begin) {
                let minutes = calendar.component(.minute, from: finish) + calendar.component(.second, from: finish)
                last = max(last, calendar.component(.hour, from: finish) - (minutes == 0 ? 1 : 0))
            }
        }
        return (first...max(first, last)).map { String(format: "%02d:00", $0) }
    }

    private func starting(_ day: Date, _ slot: String) -> [AnyCodable] {
        let calendar = CalendarGridMoleculeView.calendar
        return events.filter { event in
            guard let begin = start(event) else { return false }
            return calendar.isDate(begin, inSameDayAs: day) && calendar.component(.hour, from: begin) == hour(slot)
        }
    }

    private func continuing(_ day: Date, _ slot: String) -> Bool {
        let calendar = CalendarGridMoleculeView.calendar
        guard let slotStart = calendar.date(bySettingHour: hour(slot), minute: 0, second: 0, of: day) else { return false }
        return events.contains { event in
            guard let begin = start(event), let finish = end(event) else { return false }
            return slotStart > begin && slotStart < finish
        }
    }

    private func chip(_ event: AnyCodable) -> AnyCodable {
        if let template = props.dictValue?["renderItem"] ?? props.dictValue?["children"], template.dictValue != nil {
            return AtomRowTemplate.bind(template, event)
        }
        let badge: AnyCodable = .dict(["type": "badge", "label": .string(AtomKit.scalar(AtomKit.cell(event, titleField)) ?? ""), "variant": "default", "size": "sm"])
        let open = props.string("onEventClick")
        if open.isEmpty { return badge }
        return AtomKit.child(props, ["type": "box", "action": .string(open), "actionPayload": .dict(["event": event]), "children": .array([badge])])
    }

    private func step(_ delta: Int) {
        offset = min(max(offset + delta * visible, 0), max(7 - visible, 0))
    }

    private func nav(_ icon: String, _ label: String, event: String, delta: Int, disabled: Bool) -> some View {
        ButtonRenderer(
            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": .string(icon), "aria-label": .string(label), "disabled": .bool(disabled && event.isEmpty), "action": .string(AtomKit.eventOrLocal(event)), "local": .bool(event.isEmpty)]),
            modifier: nil,
            onEvent: { _, _ in
                step(delta)
                if !event.isEmpty { onEvent(event, eventEnvelope(props)) }
            }
        )
    }

    private func emitSlot(_ day: Date, _ slot: String) {
        let event = props.string("longPressEvent")
        guard !event.isEmpty else { return }
        var values: [String: AnyCodable] = props.dictValue?["longPressPayload"]?.dictValue ?? [:]
        values["date"] = .string(ISO8601DateFormatter().string(from: day))
        values["time"] = .string(slot)
        onEvent(event, eventEnvelope(props, payload: .dict(values)))
    }

    var body: some View {
        let days = weekDays
        let count = visible
        let from = min(offset, max(7 - count, 0))
        let shown = Array(days.dropFirst(from).prefix(count))
        let leftEvent = props.string("swipeRightEvent")
        let rightEvent = props.string("swipeLeftEvent")
        let rows = slots
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            HStack(spacing: theme.density.spacing.space2) {
                nav("chevron-left", "Previous days", event: leftEvent, delta: -1, disabled: from == 0)
                AtomKit.typo(range(shown), "small", color: "muted", align: "center", onEvent: onEvent)
                    .frame(maxWidth: .infinity)
                nav("chevron-right", "Next days", event: rightEvent, delta: 1, disabled: from + count >= 7)
            }
            Grid(horizontalSpacing: theme.density.spacing.space0, verticalSpacing: theme.density.spacing.space0) {
                GridRow {
                    AtomKit.typo("", "caption", onEvent: onEvent)
                    ForEach(shown.indices, id: \.self) { index in
                        DayCellRenderer(
                            props: AtomKit.child(props, ["date": .string(CalendarGridMoleculeView.dayKey.string(from: shown[index])), "isToday": .bool(CalendarGridMoleculeView.calendar.isDateInToday(shown[index])), "onClick": .string(props.string("onDayClick")), "actionPayload": .dict(["day": .string(ISO8601DateFormatter().string(from: shown[index]))])]),
                            modifier: nil,
                            onEvent: onEvent
                        )
                    }
                }
                ForEach(rows.indices, id: \.self) { rowIndex in
                    let slot = rows[rowIndex]
                    GridRow {
                        AtomKit.typo(slot, "caption", color: "muted", onEvent: onEvent)
                            .gridColumnAlignment(.trailing)
                        ForEach(shown.indices, id: \.self) { index in
                            let day = shown[index]
                            let here = starting(day, slot)
                            TimeSlotCellRenderer(
                                props: AtomKit.child(props, [
                                    "time": .string(slot),
                                    "isOccupied": .bool(!here.isEmpty || continuing(day, slot)),
                                    "onClick": .string(props.string("onSlotClick")),
                                    "actionPayload": .dict(["day": .string(ISO8601DateFormatter().string(from: day)), "time": .string(slot)]),
                                    "children": .array(here.map { chip($0) }),
                                ]),
                                modifier: nil,
                                onEvent: onEvent
                            )
                            .onLongPressGesture(minimumDuration: 0.5) { emitSlot(day, slot) }
                            .gestureContainer(AtomKit.gestureId(props.string("longPressEvent"), props, VerificationIds.longPress))
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: theme.density.spacing.space8)
                    .onEnded { value in
                        if value.translation.width < 0 { step(1); if !rightEvent.isEmpty { onEvent(rightEvent, eventEnvelope(props)) } }
                        if value.translation.width > 0 { step(-1); if !leftEvent.isEmpty { onEvent(leftEvent, eventEnvelope(props)) } }
                    }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in
            AtomKit.clear(theme)
                .onAppear { width = proxy.size.width }
                .onChange(of: proxy.size.width) { next in width = next }
        })
        .accessibilityElement(children: .contain)
    }

    private func range(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let a = formatter.string(from: first)
        let b = formatter.string(from: last)
        return a == b ? a : a + " \u{2013} " + b
    }
}

@ViewBuilder
func CalendarGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CalendarGridMoleculeView(props: props, onEvent: onEvent))
}
