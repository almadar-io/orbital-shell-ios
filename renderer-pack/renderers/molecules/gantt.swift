import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GanttMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private struct Placed {
        let id: String
        let label: String
        let status: String
        let group: String
        let start: Date
        let end: Date
        let reversed: Bool
    }

    private enum Item {
        case group(String)
        case task(Placed)
    }

    private static let day: TimeInterval = 86_400

    private func midnight(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    private func parseDay(_ raw: AnyCodable?) -> Date? {
        guard let raw = raw else { return nil }
        if raw.stringValue == nil, let epoch = raw.doubleValue { return midnight(Date(timeIntervalSince1970: epoch / 1000)) }
        guard let text = raw.stringValue, !text.isEmpty else { return nil }
        return AtomKit.parseDate(text).map { midnight($0) }
    }

    private var placed: [Placed] {
        let titleField = props.string("titleField", default: "title")
        let startField = props.string("startField", default: "start")
        let endField = props.string("endField", default: "end")
        let statusField = props.string("statusField", default: "status")
        let durationField = props.string("durationField")
        let groupField = props.string("groupField")
        var out: [Placed] = []
        for (index, row) in AtomKit.rows(props, "tasks").enumerated() {
            let declaredEnd = parseDay(AtomKit.cell(row, endField))
            guard let declaredStart = parseDay(AtomKit.cell(row, startField)) ?? declaredEnd else { continue }
            var start = declaredStart
            var end = declaredStart
            var reversed = false
            if let finish = declaredEnd {
                reversed = finish < declaredStart
                if reversed { start = finish }
                end = (reversed ? declaredStart : finish).addingTimeInterval(Self.day)
            } else {
                let days = durationField.isEmpty ? Double.nan : (AtomKit.cell(row, durationField)?.doubleValue ?? Double.nan)
                end = start.addingTimeInterval((days.isFinite && days > 0 ? days : 1) * Self.day)
            }
            out.append(Placed(
                id: AtomKit.scalar(row.dictValue?["id"]) ?? String(index),
                label: AtomKit.scalar(AtomKit.cell(row, titleField)) ?? "",
                status: AtomKit.scalar(AtomKit.cell(row, statusField)) ?? "",
                group: groupField.isEmpty ? "" : (AtomKit.scalar(AtomKit.cell(row, groupField)) ?? ""),
                start: start,
                end: end,
                reversed: reversed
            ))
        }
        return out
    }

    private func items(_ tasks: [Placed]) -> [Item] {
        if props.string("groupField").isEmpty { return tasks.map { Item.task($0) } }
        var out: [Item] = []
        var seen = Set<String>()
        for task in tasks {
            if !seen.contains(task.group) {
                seen.insert(task.group)
                out.append(.group(task.group.isEmpty ? "—" : task.group))
            }
            out.append(.task(task))
        }
        return out
    }

    private func barFill(_ status: String) -> Color {
        switch props.dictValue?["statusColorMap"]?.dictValue?[status]?.stringValue ?? "" {
        case "secondary": return theme.color.secondary.opacity(0.8)
        case "success": return theme.color.success.opacity(0.8)
        case "warning": return theme.color.warning.opacity(0.8)
        case "danger", "error", "destructive": return theme.color.error.opacity(0.8)
        case "info": return theme.color.info.opacity(0.8)
        case "neutral": return theme.color.mutedForeground.opacity(0.5)
        default: return theme.color.primary.opacity(0.8)
        }
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let tasks = placed
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "grid"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body1", color: "error", onEvent: onEvent)
                .padding(theme.density.spacing.space4)
        } else if tasks.isEmpty {
            EmptyStateRenderer(props: AtomKit.child(props, ["title": "No data available"]), modifier: nil, onEvent: onEvent)
        } else {
            board(tasks)
        }
    }

    private func board(_ tasks: [Placed]) -> some View {
        let dayWidth = CGFloat(props.dictValue?["dayWidth"]?.doubleValue ?? 28)
        // Native-only test seam: an `at` prop (epoch ms) stands in for now; absent, the live clock runs.
        let now = props.dictValue?["at"]?.doubleValue.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let lo = parseDay(props.dictValue?["rangeStart"]) ?? (tasks.map { $0.start }.min().map { $0.addingTimeInterval(-2 * Self.day) } ?? midnight(now))
        let rawHi = parseDay(props.dictValue?["rangeEnd"]) ?? (tasks.map { $0.end }.max().map { $0.addingTimeInterval(2 * Self.day) } ?? lo.addingTimeInterval(30 * Self.day))
        let hi = rawHi > lo ? rawHi : lo.addingTimeInterval(Self.day)
        let totalDays = max(Int((hi.timeIntervalSince(lo) / Self.day).rounded()), 1)
        let chartWidth = CGFloat(totalDays) * dayWidth
        let rows = items(tasks)
        let rowHeight = theme.density.spacing.space9
        let headerHeight = theme.density.spacing.space11
        let labelWidth = AlmadarSizes.w48
        let offset: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(lo) / Self.day) * dayWidth }
        let today = parseDay(.double(now.timeIntervalSince1970 * 1000))
        let surface = props.string("surface", default: "auto") == "none" ? AtomKit.clear(theme) : theme.color.card
        return HStack(alignment: .top, spacing: theme.density.spacing.space0) {
            VStack(spacing: theme.density.spacing.space0) {
                AtomKit.clear(theme).frame(width: labelWidth, height: headerHeight)
                    .overlay(alignment: .bottom) { theme.color.border.frame(height: theme.geometry.borderStandard) }
                ForEach(rows.indices, id: \.self) { index in
                    labelCell(rows[index], width: labelWidth, height: rowHeight)
                }
            }
            .overlay(alignment: .trailing) { theme.color.border.frame(width: theme.geometry.borderStandard) }
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: theme.density.spacing.space0) {
                        HStack(spacing: theme.density.spacing.space0) {
                            ForEach(0..<totalDays, id: \.self) { index in
                                let date = lo.addingTimeInterval(Double(index) * Self.day)
                                ZStack(alignment: .bottom) {
                                    (isWeekend(date) ? theme.color.muted.opacity(0.4) : AtomKit.clear(theme))
                                    if dayWidth >= 20 {
                                        AtomKit.typo("\(Calendar.current.component(.day, from: date))", "caption", color: "secondary", onEvent: onEvent)
                                            .padding(.bottom, theme.density.spacing.space1)
                                    }
                                }
                                .frame(width: dayWidth, height: headerHeight)
                                .overlay(alignment: .leading) { theme.color.border.opacity(0.5).frame(width: theme.geometry.borderHairline) }
                            }
                        }
                        .overlay(alignment: .bottom) { theme.color.border.frame(height: theme.geometry.borderStandard) }
                        ForEach(rows.indices, id: \.self) { index in
                            chartRow(rows[index], width: chartWidth, height: rowHeight, offset: offset)
                        }
                    }
                    arrows(rows, offset: offset, header: headerHeight, row: rowHeight, dayWidth: dayWidth)
                    if props.bool("showToday", default: true), let marker = today, marker >= lo, marker <= hi {
                        theme.color.error.opacity(0.7)
                            .frame(width: AlmadarSizes.w0_5, height: headerHeight + CGFloat(rows.count) * rowHeight)
                            .offset(x: offset(marker))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: chartWidth, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func labelCell(_ item: Item, width: CGFloat, height: CGFloat) -> some View {
        switch item {
        case .group(let label):
            AtomKit.typo(label, "caption", weight: "semibold", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .frame(width: width, height: height, alignment: .leading)
                .background(theme.color.muted.opacity(0.3))
                .overlay(alignment: .bottom) { theme.color.border.frame(height: theme.geometry.borderStandard) }
        case .task(let task):
            AtomKit.typo(task.label, "small", truncate: true, onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .frame(width: width, height: height, alignment: .leading)
                .overlay(alignment: .bottom) { theme.color.border.opacity(0.5).frame(height: theme.geometry.borderStandard) }
        }
    }

    @ViewBuilder
    private func chartRow(_ item: Item, width: CGFloat, height: CGFloat, offset: (Date) -> CGFloat) -> some View {
        switch item {
        case .group:
            theme.color.muted.opacity(0.3)
                .frame(width: width, height: height)
                .overlay(alignment: .bottom) { theme.color.border.frame(height: theme.geometry.borderStandard) }
        case .task(let task):
            let event = props.string("barClickEvent")
            let shape = RoundedRectangle(cornerRadius: AtomKit.radius(theme, "sm"))
            ZStack(alignment: .leading) {
                AtomKit.clear(theme).frame(width: width, height: height)
                if task.reversed {
                    shape.fill(theme.color.error.opacity(0.3))
                        .overlay(shape.strokeBorder(theme.color.error, style: StrokeStyle(lineWidth: theme.geometry.borderStandard, dash: [theme.density.spacing.space1])))
                        .frame(width: offset(task.end) - offset(task.start), height: theme.density.spacing.space4)
                        .offset(x: offset(task.start))
                        .accessibilityLabel(task.label)
                        .accessibilityHint("Ends before it starts — check its dates")
                } else {
                    shape.fill(barFill(task.status))
                        .frame(width: offset(task.end) - offset(task.start), height: theme.density.spacing.space4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["id": .string(task.id)])) }
                        }
                        .offset(x: offset(task.start))
                        .accessibilityLabel(task.label)
                        .atomId(event.isEmpty ? "" : VerificationIds.action(event))
                }
            }
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) { theme.color.border.opacity(0.5).frame(height: theme.geometry.borderStandard) }
        }
    }

    private func arrows(_ rows: [Item], offset: (Date) -> CGFloat, header: CGFloat, row: CGFloat, dayWidth: CGFloat) -> some View {
        var geometry: [String: (x0: CGFloat, x1: CGFloat, y: CGFloat)] = [:]
        for (index, item) in rows.enumerated() {
            if case .task(let task) = item {
                let x0 = offset(task.start)
                geometry[task.id] = (x0: x0, x1: max(offset(task.end), x0 + dayWidth / 2), y: header + CGFloat(index) * row + row / 2)
            }
        }
        let links = props.dictValue?["links"]?.arrayValue ?? []
        let reach = theme.density.spacing.space2
        let half = theme.density.spacing.space1
        return ZStack(alignment: .topLeading) {
            Path { path in
                for link in links {
                    guard let from = geometry[link.string("from")], let to = geometry[link.string("to")] else { continue }
                    let midX = from.x1 + max(reach, (to.x0 - from.x1) / 2)
                    path.move(to: CGPoint(x: from.x1, y: from.y))
                    path.addLine(to: CGPoint(x: midX, y: from.y))
                    path.addLine(to: CGPoint(x: midX, y: to.y))
                    path.addLine(to: CGPoint(x: to.x0, y: to.y))
                }
            }
            .stroke(theme.color.mutedForeground, lineWidth: theme.geometry.borderStandard)
            Path { path in
                for link in links {
                    guard geometry[link.string("from")] != nil, let to = geometry[link.string("to")] else { continue }
                    path.move(to: CGPoint(x: to.x0, y: to.y))
                    path.addLine(to: CGPoint(x: to.x0 - reach, y: to.y - half))
                    path.addLine(to: CGPoint(x: to.x0 - reach, y: to.y + half))
                    path.closeSubpath()
                }
            }
            .fill(theme.color.mutedForeground)
        }
        .allowsHitTesting(false)
    }
}

@ViewBuilder
func GanttRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GanttMoleculeView(props: props, onEvent: onEvent))
}
