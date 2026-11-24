import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DataListMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var visible: Int

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        let size = props.int("pageSize", default: 5)
        _visible = State(initialValue: size > 0 ? size : Int.max)
    }

    private var fields: [AnyCodable] { AtomKit.fieldDefs(props, ["fields", "columns"]) }
    private var relations: AnyCodable? { props.dictValue?["relationsData"] }
    private var variant: String { props.string("variant", default: "default") }

    var body: some View {
        let error = AtomKit.errorText(props)
        let all = AtomKit.sortedRows(AtomKit.rows(props, "entity"), by: props.string("sortBy"), descending: props.string("sortDirection") == "desc")
        let size = props.int("pageSize", default: 5)
        let shown = size > 0 ? Array(all.prefix(visible)) : all
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AtomKit.typo(error, "body1", color: "error", align: "center", onEvent: onEvent)
                .padding(.vertical, theme.density.spacing.space8)
        } else if shown.isEmpty {
            EmptyStateRenderer(props: AtomKit.emptyProps(props, fallback: "No items"), modifier: nil, onEvent: onEvent)
        } else {
            content(shown, remaining: all.count - shown.count)
        }
    }

    @ViewBuilder
    private func content(_ rows: [AnyCodable], remaining: Int) -> some View {
        let reorder = props.bool("reorderable") && !props.string("reorderEvent").isEmpty
        VStack(alignment: .leading, spacing: variant == "card" || variant == "compact" ? theme.density.spacing.space0 : AtomKit.space(theme, props.string("gap", default: "none"))) {
            if reorder {
                List {
                    ForEach(rows.indices, id: \.self) { index in
                        row(rows[index], offset: index, last: index == rows.count - 1)
                            .listRowInsets(EdgeInsets())
                    }
                    .onMove { indices, destination in
                        guard let from = indices.first else { return }
                        onEvent(props.string("reorderEvent"), eventEnvelope(props, payload: ["fromIndex": .int(from), "toIndex": .int(destination)]))
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .frame(minHeight: theme.density.rowHeightNormal * CGFloat(rows.count))
            } else {
                let groups = grouped(rows)
                ForEach(groups.indices, id: \.self) { g in
                    if !groups[g].label.isEmpty {
                        DividerRenderer(props: ["label": .string(groups[g].label)], modifier: nil, onEvent: onEvent)
                    }
                    ForEach(groups[g].items.indices, id: \.self) { i in
                        let item = groups[g].items[i]
                        if variant == "feed" {
                            feedRow(item.row, offset: item.offset, previous: i > 0 ? groups[g].items[i - 1].row : nil)
                        } else if variant == "message" {
                            bubble(item.row, offset: item.offset)
                        } else {
                            row(item.row, offset: item.offset, last: g == groups.count - 1 && i == groups[g].items.count - 1)
                        }
                    }
                }
            }
            if remaining > 0 {
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "leftIcon": "chevron-down", "label": .string("Show more (\(remaining) remaining)"), "action": "show-more", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in visible += max(props.int("pageSize", default: 5), 1) }
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.density.spacing.space3)
            }
            if props.bool("infiniteScroll") && !props.string("loadMoreEvent").isEmpty {
                InfiniteScrollSentinelRenderer(
                    props: AtomKit.child(props, ["loadMoreEvent": .string(props.string("loadMoreEvent")), "isLoading": .bool(props.bool("isLoading")), "hasMore": .bool(props.bool("hasMore"))]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        }
    }

    private func grouped(_ rows: [AnyCodable]) -> [(label: String, items: [(offset: Int, row: AnyCodable)])] {
        let field = props.string("groupBy")
        var order: [String] = []
        var buckets: [String: [(offset: Int, row: AnyCodable)]] = [:]
        for (offset, row) in rows.enumerated() {
            let key = field.isEmpty ? "" : AtomKit.display(AtomKit.cell(row, field), format: props.string("groupFormat"))
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append((offset: offset, row: row))
        }
        return order.map { (label: $0, items: buckets[$0] ?? []) }
    }

    private func actions(for row: AnyCodable) -> [AnyCodable] {
        var list = props.dictValue?["itemActions"]?.arrayValue ?? []
        for (side, key) in [("swipeLeft", "swipeLeftActions"), ("swipeRight", "swipeRightActions")] {
            let event = props.string(side + "Event")
            guard !event.isEmpty else { continue }
            for action in props.dictValue?[key]?.arrayValue ?? [] {
                var dict = action.dictValue ?? [:]
                dict["event"] = .string(event)
                list.append(.dict(dict))
            }
        }
        return list
    }

    private func clustered(_ row: AnyCodable) -> some View {
        let split = AtomRowActions.split(actions(for: row), inlineLimit: props.dictValue?["maxInlineActions"]?.intValue)
        return AtomRowActions(owner: props, row: row, inline: split.inline, menu: split.menu, onEvent: onEvent)
    }

    @ViewBuilder
    private func row(_ row: AnyCodable, offset: Int, last: Bool) -> some View {
        let id = AtomKit.rowKey(row, offset)
        let compact = variant == "compact"
        let card = variant == "card"
        let look = props.string("look", default: "dense")
        let open = props.string("itemClickEvent")
        let hasActions = !actions(for: row).filter { AtomKit.actionable($0) }.isEmpty
        let title = fields.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" })
        let avatar = fields.first(where: { $0.string("variant") == "avatar" })
        let overlines = fields.filter { $0.string("variant") == "overline" }
        let badges = fields.filter { $0.string("variant") == "badge" && $0 != title }
        let progress = fields.filter { $0.string("variant") == "progress" }
        let prose = fields.filter { $0.string("variant") == "caption" && $0.string("format") != "boolean" }
        let body = fields.filter { field in
            field != title && field.string("variant") != "avatar" && !overlines.contains(field) && !badges.contains(field) && !progress.contains(field) && !prose.contains(field)
        }
        let horizontal = look == "dense" ? theme.density.spacing.space3 : (look == "spacious" ? theme.density.spacing.space8 : (compact ? theme.density.spacing.space4 : theme.density.spacing.space6))
        let vertical = look == "dense" ? theme.density.spacing.space1 : (look == "spacious" ? theme.density.spacing.space5 : (compact ? theme.density.spacing.space2 : theme.density.spacing.space4))
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        let plain = !card && !compact
        VStack(spacing: theme.density.spacing.space0) {
            HStack(alignment: .top, spacing: theme.density.spacing.space4) {
                HStack(alignment: .top, spacing: theme.density.spacing.space4) {
                    if let avatar = avatar, !AtomKit.blank(AtomKit.cell(row, avatar.string("name"))) {
                        AvatarRenderer(props: ["name": .string(AtomKit.fieldText(row, avatar)), "size": compact ? "sm" : "md"], modifier: nil, onEvent: onEvent)
                    }
                    if let title = title, !title.string("icon").isEmpty, !compact {
                        AtomKit.icon(title.string("icon"), "md", color: "primary", onEvent: onEvent)
                            .padding(theme.density.spacing.space2)
                            .background(theme.color.primary.opacity(0.1))
                            .clipShape(shape)
                    }
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        ForEach(overlines.indices, id: \.self) { index in
                            let text = AtomKit.fieldText(row, overlines[index], relations: relations)
                            if !text.isEmpty { AtomKit.typo(text, "overline", color: "primary", onEvent: onEvent) }
                        }
                        HStack(spacing: theme.density.spacing.space2) {
                            if let title = title, compact, !title.string("icon").isEmpty { AtomKit.icon(title.string("icon"), "xs", color: "primary", onEvent: onEvent) }
                            if let title = title {
                                let text = AtomKit.fieldText(row, title, relations: relations)
                                if !text.isEmpty {
                                    AtomKit.typo(text, compact ? "small" : (title.string("variant") == "h3" ? "h3" : "h4"), weight: "semibold", truncate: compact, onEvent: onEvent)
                                }
                            }
                            AtomFieldBadges(row: row, fields: badges, relations: relations, onEvent: onEvent)
                        }
                        ForEach(prose.indices, id: \.self) { index in
                            let text = AtomKit.fieldText(row, prose[index], relations: relations)
                            if !text.isEmpty { AtomKit.typo(text, compact ? "small" : "body1", color: "secondary", truncate: compact, onEvent: onEvent) }
                        }
                        AtomFieldMeta(row: row, fields: body, relations: relations, onEvent: onEvent)
                        AtomFieldProgress(row: row, fields: progress, onEvent: onEvent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !open.isEmpty { onEvent(open, eventEnvelope(props, payload: AtomKit.rowPayload(row))) }
                }
                .onLongPressGesture {
                    let event = props.string("longPressEvent")
                    if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["row": row])) }
                }
                .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    let event = props.string(drag.translation.width < 0 ? "swipeLeftEvent" : "swipeRightEvent")
                    if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["row": row])) }
                })
                .accessibilityAddTraits(open.isEmpty ? [] : .isButton)
                if hasActions { clustered(row) }
            }
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(look == "striped" && offset % 2 == 1 ? theme.color.muted.opacity(0.3) : (look == "card-rows" ? theme.color.card : AtomKit.clear(theme)))
            .clipShape(look == "card-rows" || plain ? shape : RoundedRectangle(cornerRadius: theme.density.spacing.space0))
            .overlay(shape.stroke(look == "card-rows" ? theme.color.border : AtomKit.clear(theme), lineWidth: theme.geometry.borderStandard))
            if (card || compact) && !last {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    .padding(.horizontal, compact ? theme.density.spacing.space4 : theme.density.spacing.space6)
            }
        }
        .padding(.bottom, look == "card-rows" ? theme.density.spacing.space2 : theme.density.spacing.space0)
        .verificationContainer(VerificationIds.ids(
            VerificationIds.row(id),
            AtomKit.gestureId(props.string("swipeLeftEvent"), props, VerificationIds.swipeLeft),
            AtomKit.gestureId(props.string("swipeRightEvent"), props, VerificationIds.swipeRight),
            AtomKit.gestureId(props.string("longPressEvent"), props, VerificationIds.longPress)
        ))
    }

    @ViewBuilder
    private func bubble(_ row: AnyCodable, offset: Int) -> some View {
        let id = AtomKit.rowKey(row, offset)
        let titleField = fields.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" })
        let contentField = (fields.first(where: { $0.string("variant") == "body" }) ?? titleField)?.string("name") ?? ""
        let senderName = props.string("senderField")
        let sender = senderName.isEmpty ? "" : AtomKit.display(AtomKit.cell(row, senderName), format: "")
        let labelField = props.string("senderLabelField")
        let senderLabel = labelField.isEmpty ? sender : (AtomKit.display(AtomKit.cell(row, labelField), format: "").isEmpty ? sender : AtomKit.display(AtomKit.cell(row, labelField), format: ""))
        let sent = !props.string("currentUser").isEmpty && sender == props.string("currentUser")
        let stamp = fields.first(where: { $0.string("format") == "date" })
        let meta = fields.filter { $0.string("name") != contentField && $0.string("name") != stamp?.string("name") }
        let open = props.string("itemClickEvent")
        let bubbleShape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        let split = AtomRowActions.split(actions(for: row), inlineLimit: props.dictValue?["maxInlineActions"]?.intValue)
        HStack {
            if sent { Spacer(minLength: theme.density.spacing.space8) }
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !sent && !senderName.isEmpty {
                    AtomKit.typo(senderLabel, "caption", weight: "semibold", onEvent: onEvent)
                }
                AtomKit.typo(AtomKit.display(AtomKit.cell(row, contentField), format: ""), "body1", color: "inherit", onEvent: onEvent)
                    .contentShape(Rectangle())
                    .onTapGesture { if !open.isEmpty { onEvent(open, eventEnvelope(props, payload: AtomKit.rowPayload(row))) } }
                    .accessibilityAddTraits(open.isEmpty ? [] : .isButton)
                AtomFieldMeta(row: row, fields: meta, relations: relations, onEvent: onEvent)
                HStack(spacing: theme.density.spacing.space2) {
                    if let stamp = stamp, !AtomKit.blank(AtomKit.cell(row, stamp.string("name"))) {
                        AtomKit.typo(AtomKit.display(AtomKit.cell(row, stamp.string("name")), format: "datetime"), "caption", color: "inherit", onEvent: onEvent)
                            .opacity(0.7)
                    }
                    Spacer(minLength: theme.density.spacing.space0)
                    AtomRowActions(owner: props, row: row, inline: split.inline, menu: split.menu, onEvent: onEvent)
                }
            }
            .foregroundColor(sent ? theme.color.primaryForeground : theme.color.foreground)
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.vertical, theme.density.spacing.space2)
            .background(sent ? theme.color.primary : theme.color.muted)
            .clipShape(bubbleShape)
            if !sent { Spacer(minLength: theme.density.spacing.space8) }
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .verificationContainer(VerificationIds.row(id))
    }

    private func feedTime(_ row: AnyCodable, _ stamp: AnyCodable?) -> Double? {
        guard let stamp = stamp, let raw = AtomKit.scalar(AtomKit.cell(row, stamp.string("name"))), !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        guard let date = fractional.date(from: raw) ?? plain.date(from: raw) ?? day.date(from: raw) else { return nil }
        return date.timeIntervalSince1970
    }

    private func feedName(_ row: AnyCodable) -> String {
        let sender = AtomKit.display(AtomKit.cell(row, props.string("senderField")), format: "")
        let labelField = props.string("senderLabelField")
        if labelField.isEmpty { return sender }
        let label = AtomKit.display(AtomKit.cell(row, labelField), format: "")
        return label.isEmpty ? sender : label
    }

    @ViewBuilder
    private func feedRow(_ row: AnyCodable, offset: Int, previous: AnyCodable?) -> some View {
        let id = AtomKit.rowKey(row, offset)
        let senderField = props.string("senderField")
        let contentField = (fields.first(where: { $0.string("variant") == "body" }) ?? fields.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" }))?.string("name") ?? ""
        let stamp = fields.first(where: { ["date", "datetime", "time"].contains($0.string("format")) })
        let meta = fields.filter { $0.string("name") != contentField && $0.string("name") != stamp?.string("name") }
        let open = props.string("itemClickEvent")
        let replyEvent = props.string("replyEvent")
        let windowSeconds = Double(props.int("feedGroupMinutes", default: 5)) * 60
        let continuation: Bool = {
            guard let previous = previous, !senderField.isEmpty else { return false }
            guard AtomKit.display(AtomKit.cell(row, senderField), format: "") == AtomKit.display(AtomKit.cell(previous, senderField), format: "") else { return false }
            guard let now = feedTime(row, stamp), let before = feedTime(previous, stamp) else { return false }
            return now - before >= 0 && now - before <= windowSeconds
        }()
        let stampText = stamp.flatMap { AtomKit.blank(AtomKit.cell(row, $0.string("name"))) ? nil : AtomKit.display(AtomKit.cell(row, $0.string("name")), format: $0.string("format")) }
        let avatarField = props.string("senderAvatarField")
        let photo = avatarField.isEmpty ? "" : AtomKit.display(AtomKit.cell(row, avatarField), format: "")
        let replyField = props.string("replyCountField")
        let replyCount = replyField.isEmpty ? 0 : Int(Double(AtomKit.scalar(AtomKit.cell(row, replyField)) ?? "") ?? 0)
        let repliersField = props.string("repliersField")
        let repliers = repliersField.isEmpty ? [] : (AtomKit.cell(row, repliersField)?.arrayValue ?? []).compactMap { AtomKit.scalar($0) }
        let split = AtomRowActions.split(actions(for: row), inlineLimit: props.dictValue?["maxInlineActions"]?.intValue)
        let shownActions = split.inline + split.menu
        HStack(alignment: .top, spacing: theme.density.spacing.space3) {
            VStack {
                if !continuation {
                    AvatarRenderer(props: ["name": .string(feedName(row)), "src": .string(photo), "size": "md"], modifier: nil, onEvent: onEvent)
                }
            }
            .frame(width: theme.density.spacing.space10, alignment: .center)
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !continuation {
                    HStack(alignment: .firstTextBaseline, spacing: theme.density.spacing.space2) {
                        AtomKit.typo(feedName(row), "small", weight: "semibold", onEvent: onEvent)
                        if let stampText = stampText {
                            AtomKit.typo(stampText, "caption", color: "secondary", onEvent: onEvent)
                        }
                    }
                }
                AtomKit.typo(AtomKit.display(AtomKit.cell(row, contentField), format: ""), "body1", onEvent: onEvent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if !open.isEmpty { onEvent(open, eventEnvelope(props, payload: AtomKit.rowPayload(row))) } }
                    .accessibilityAddTraits(open.isEmpty ? [] : .isButton)
                feedMeta(row, meta)
                if replyCount > 0 {
                    Button {
                        if !replyEvent.isEmpty { onEvent(replyEvent, eventEnvelope(props, payload: AtomKit.rowPayload(row))) }
                    } label: {
                        HStack(spacing: theme.density.spacing.space2) {
                            ForEach(repliers.indices, id: \.self) { index in
                                AvatarRenderer(props: ["name": .string(repliers[index]), "size": "xs"], modifier: nil, onEvent: onEvent)
                            }
                            AtomKit.typo(replyCount == 1 ? "1 reply" : "\(replyCount) replies", "caption", color: "primary", weight: "semibold", onEvent: onEvent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.top, continuation ? theme.density.spacing.space1 : theme.density.spacing.space2)
        .padding(.bottom, theme.density.spacing.space1)
        .overlay(alignment: .topTrailing) {
            if !shownActions.isEmpty {
                AtomRowActions(owner: props, row: row, inline: [], menu: shownActions, onEvent: onEvent)
                    .padding(.horizontal, theme.density.spacing.space4)
            }
        }
        .verificationContainer(VerificationIds.row(id))
    }

    @ViewBuilder
    private func feedMeta(_ row: AnyCodable, _ meta: [AnyCodable]) -> some View {
        let badges = meta.filter { $0.string("variant") == "badge" }
        let captions = meta.filter { $0.string("variant") != "badge" }
        if !badges.isEmpty || !captions.isEmpty {
            HStack(spacing: theme.density.spacing.space2) {
                AtomFieldBadges(row: row, fields: badges, relations: relations, onEvent: onEvent)
                ForEach(captions.indices, id: \.self) { index in
                    let text = AtomKit.fieldText(row, captions[index], relations: relations)
                    if !text.isEmpty { AtomKit.typo(text, "caption", color: "secondary", onEvent: onEvent) }
                }
            }
        }
    }
}

@ViewBuilder
func DataListRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DataListMoleculeView(props: props, onEvent: onEvent))
}
