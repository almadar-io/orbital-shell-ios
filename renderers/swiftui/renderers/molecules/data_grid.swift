import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DataGridMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var visible: Int
    @State private var selected: Set<String> = []

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        let size = props.int("pageSize")
        _visible = State(initialValue: size > 0 ? size : Int.max)
    }

    private var fields: [AnyCodable] { AtomKit.fieldDefs(props, ["fields", "columns"]) }
    private var relations: AnyCodable? { props.dictValue?["relationsData"] }
    private var asRows: Bool { props.int("cols") == 1 && !props.bool("scrollX") }

    var body: some View {
        let error = AtomKit.errorText(props)
        let all = AtomKit.rows(props, "entity")
        let size = props.int("pageSize")
        let shown = size > 0 ? Array(all.prefix(visible)) : all
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "grid"), modifier: nil, onEvent: onEvent)
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
        let ids = rows.indices.map { AtomKit.rowKey(rows[$0], $0) }
        let gap = AtomKit.space(theme, props.string("gap", default: "md"))
        let minimum = CGFloat(props.float("minCardWidth", default: 280))
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if props.bool("selectable") && !selected.isEmpty {
                HStack(spacing: theme.density.spacing.space2) {
                    CheckboxRenderer(
                        props: AtomKit.child(props, ["checked": .bool(ids.allSatisfy { selected.contains($0) }), "onChange": .string(AtomKit.eventOrLocal(props.string("selectionEvent"))), "local": .bool(props.string("selectionEvent").isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in toggleAll(ids) }
                    )
                    AtomKit.typo("\(selected.count) selected", "caption", weight: "semibold", onEvent: onEvent)
                }
                .padding(theme.density.spacing.space2)
                .background(theme.color.muted)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            }
            if asRows {
                VStack(spacing: theme.density.spacing.space0) {
                    ForEach(rows.indices, id: \.self) { index in
                        card(rows[index], id: ids[index])
                        if index < rows.count - 1 { DividerRenderer(props: [:], modifier: nil, onEvent: onEvent) }
                    }
                }
            } else if props.bool("scrollX") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: gap) {
                        ForEach(rows.indices, id: \.self) { index in
                            card(rows[index], id: ids[index]).frame(width: minimum)
                        }
                    }
                }
            } else {
                AtomGridLayout(minWidth: props.int("cols") > 0 ? 140 : minimum, maxColumns: 0, fixedColumns: props.int("cols"), spacing: gap, breakpointColumns: true) {
                    ForEach(rows.indices, id: \.self) { index in
                        card(rows[index], id: ids[index])
                    }
                }
            }
            if remaining > 0 {
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "leftIcon": "chevron-down", "label": .string("Show more (\(remaining) remaining)"), "action": "show-more", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in visible += max(props.int("pageSize"), 5) }
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

    @ViewBuilder
    private func card(_ row: AnyCodable, id: String) -> some View {
        let title = fields.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" })
        let badges = fields.filter { $0.string("variant") == "badge" && $0 != title }
        let rest = fields.filter { $0 != title && !badges.contains($0) }
        let prose = rest.filter { $0.string("variant") == "caption" && $0.string("format") != "boolean" }
        let progress = rest.filter { $0.string("variant") == "progress" }
        let meta = rest.filter { ($0.string("variant") != "caption" || $0.string("format") == "boolean") && $0.string("variant") != "progress" }
        let titleText = title.map { AtomKit.fieldText(row, $0, relations: relations) } ?? ""
        let open = props.string("itemClickEvent")
        let chosen = selected.contains(id)
        let image = props.string("imageField")
        let split = actionSplit(row)
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        let body = VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            ForEach(prose.indices, id: \.self) { index in
                let text = AtomKit.fieldText(row, prose[index], relations: relations)
                if !text.isEmpty { AtomKit.typo(text, "small", color: "secondary", onEvent: onEvent) }
            }
            AtomFieldMeta(row: row, fields: meta, relations: relations, onEvent: onEvent)
            AtomFieldProgress(row: row, fields: progress, onEvent: onEvent)
        }
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            if !image.isEmpty && !asRows {
                media(AtomKit.assetURL(["u": AtomKit.cell(row, image) ?? .null], "u"), alt: titleText)
            }
            HStack(alignment: asRows ? .center : .top, spacing: theme.density.spacing.space3) {
                if !image.isEmpty && asRows {
                    media(AtomKit.assetURL(["u": AtomKit.cell(row, image) ?? .null], "u"), alt: titleText)
                        .frame(width: theme.density.spacing.space12, height: theme.density.spacing.space12)
                }
                if props.bool("selectable") {
                    CheckboxRenderer(
                        props: AtomKit.child(props, ["checked": .bool(chosen), "onChange": .string(AtomKit.eventOrLocal(props.string("selectionEvent"))), "local": .bool(props.string("selectionEvent").isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in toggle(id) }
                    )
                }
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    if let title = title, !titleText.isEmpty {
                        HStack(spacing: theme.density.spacing.space1) {
                            if !title.string("icon").isEmpty { AtomKit.icon(title.string("icon"), "sm", color: "primary", onEvent: onEvent) }
                            AtomKit.typo(titleText, title.string("variant") == "h3" && !asRows ? "h3" : "h4", weight: "semibold", truncate: asRows, onEvent: onEvent)
                        }
                    }
                    AtomFieldBadges(row: row, fields: badges, relations: relations, onEvent: onEvent)
                    if asRows { body }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if !open.isEmpty { onEvent(open, eventEnvelope(props, payload: AtomKit.rowPayload(row))) } }
                .accessibilityAddTraits(open.isEmpty ? [] : .isButton)
                if !split.inline.isEmpty || !split.menu.isEmpty {
                    AtomRowActions(owner: props, row: row, inline: split.inline, menu: split.menu, iconOnlyInline: true, onEvent: onEvent)
                }
            }
            .padding(asRows ? theme.density.spacing.space3 : theme.density.spacing.space4)
            if !asRows {
                body
                    .padding(.horizontal, theme.density.spacing.space4)
                    .padding(.bottom, theme.density.spacing.space4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(asRows ? (chosen ? theme.color.primary.opacity(0.05) : AtomKit.clear(theme)) : theme.color.card)
        .clipShape(asRows ? RoundedRectangle(cornerRadius: theme.density.spacing.space0) : shape)
        .overlay(shape.stroke(asRows ? AtomKit.clear(theme) : (chosen ? theme.color.primary : theme.color.border), lineWidth: chosen ? theme.geometry.borderHeavy : theme.geometry.borderStandard))
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .verificationContainer(VerificationIds.row(id))
    }

    private func media(_ url: String, alt: String) -> some View {
        ImageRenderer(props: ["src": .string(url), "alt": .string(alt), "aspect": "16/9", "rounded": "none"], modifier: nil, onEvent: onEvent)
    }

    private func actionSplit(_ row: AnyCodable) -> (inline: [AnyCodable], menu: [AnyCodable]) {
        let usable = (props.dictValue?["itemActions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        let cap = min(props.dictValue?["maxInlineActions"]?.intValue ?? 1, 1)
        let primary = Array(usable.filter { $0.string("variant") == "primary" }.prefix(cap))
        return (primary, usable.filter { action in !primary.contains(action) })
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        announce()
    }

    private func toggleAll(_ ids: [String]) {
        selected = ids.allSatisfy { selected.contains($0) } ? [] : Set(ids)
        announce()
    }

    private func announce() {
        let event = props.string("selectionEvent")
        if !event.isEmpty {
            onEvent(event, eventEnvelope(props, payload: ["selectedIds": .array(selected.sorted().map { AnyCodable.string($0) })]))
        }
    }
}

@ViewBuilder
func DataGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DataGridMoleculeView(props: props, onEvent: onEvent))
}
