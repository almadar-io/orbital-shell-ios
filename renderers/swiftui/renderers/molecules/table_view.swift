import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct TableViewMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var visible: Int
    @State private var chosen: Set<String> = []

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        let size = props.int("pageSize")
        _visible = State(initialValue: size > 0 ? size : Int.max)
    }

    private var columns: [AnyCodable] { AtomKit.fieldDefs(props, ["columns", "fields"]) }
    private var relations: AnyCodable? { props.dictValue?["relationsData"] }
    private var idField: String { props.string("dndItemIdField", default: "id") }
    private var selection: Set<String> {
        props.dictValue?["selectedIds"] != nil ? Set(AtomKit.strings(props, "selectedIds")) : chosen
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let all = AtomKit.rows(props, "entity")
        let size = props.int("pageSize")
        let shown = size > 0 ? Array(all.prefix(visible)) : all
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            if !columns.isEmpty { header(shown) }
            if props.bool("isLoading") {
                SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "table"), modifier: nil, onEvent: onEvent)
            } else if !error.isEmpty {
                AtomKit.typo(error, "body1", color: "error", align: "center", onEvent: onEvent)
                    .padding(.vertical, theme.density.spacing.space8)
            } else if shown.isEmpty {
                EmptyStateRenderer(props: AtomKit.emptyProps(props, fallback: "No items"), modifier: nil, onEvent: onEvent)
            } else {
                rows(shown)
                if all.count > shown.count {
                    ButtonRenderer(
                        props: ["variant": "ghost", "size": "sm", "leftIcon": "chevron-down", "label": .string("Show more (\(all.count - shown.count) remaining)"), "action": "show-more", "local": true],
                        modifier: nil,
                        onEvent: { _, _ in visible += max(props.int("pageSize"), 5) }
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.density.spacing.space3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(props.string("surface", default: "auto") == "none" ? AtomKit.clear(theme) : theme.color.card)
    }

    private func name(_ column: AnyCodable) -> String {
        column.string("field", default: column.string("key", default: column.string("name")))
    }

    private func align(_ column: AnyCodable) -> Alignment {
        switch column.string("align") {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    @ViewBuilder
    private func header(_ rows: [AnyCodable]) -> some View {
        let sortEvent = props.string("sortEvent")
        let current = props.string("sortColumn")
        let direction = props.string("sortDirection")
        let ids = rows.indices.map { AtomKit.rowKey(rows[$0], $0) }
        HStack(spacing: theme.density.spacing.space3) {
            if props.bool("selectable") {
                CheckboxRenderer(
                    props: AtomKit.child(props, ["checked": .bool(!ids.isEmpty && ids.allSatisfy { selection.contains($0) }), "onChange": .string(AtomKit.eventOrLocal(props.string("selectEvent"))), "local": .bool(props.string("selectEvent").isEmpty)]),
                    modifier: nil,
                    onEvent: { _, _ in commit(ids.allSatisfy { selection.contains($0) } ? [] : Set(ids)) }
                )
                .frame(width: theme.density.spacing.space6)
            }
            ForEach(columns.indices, id: \.self) { index in
                let column = columns[index]
                let label = column.string("label", default: column.string("name"))
                let active = current == name(column)
                if column.bool("sortable") && !sortEvent.isEmpty {
                    ButtonRenderer(
                        props: AtomKit.child(props, [
                            "variant": "ghost",
                            "size": "sm",
                            "label": .string(label),
                            "rightIcon": .string(active ? (direction == "asc" ? "chevron-up" : "chevron-down") : "chevrons-up-down"),
                            "action": .string(sortEvent),
                            "actionPayload": ["column": .string(name(column)), "direction": .string(active && direction == "asc" ? "desc" : "asc")],
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                    .frame(maxWidth: .infinity, alignment: align(column))
                } else if sizeClass != .compact {
                    AtomKit.typo(label, "overline", color: "secondary", onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: align(column))
                }
            }
            if !(props.dictValue?["itemActions"]?.arrayValue ?? []).isEmpty && sizeClass != .compact {
                Spacer().frame(width: theme.density.spacing.space10)
            }
        }
        .padding(.horizontal, theme.density.spacing.space3)
        .padding(.vertical, theme.density.spacing.space2)
        .background(theme.color.tableHeader)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.color.tableBorder).frame(height: theme.geometry.borderHairline) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func rows(_ rows: [AnyCodable]) -> some View {
        let groups = AtomKit.grouped(rows, by: props.string("groupBy"), format: "")
        let look = props.string("look", default: "dense")
        VStack(spacing: theme.density.spacing.space0) {
            ForEach(groups.indices, id: \.self) { g in
                if !groups[g].label.isEmpty {
                    DividerRenderer(props: ["label": .string(groups[g].label)], modifier: nil, onEvent: onEvent)
                }
                ForEach(groups[g].rows.indices, id: \.self) { i in
                    let row = groups[g].rows[i]
                    let index = rows.firstIndex(of: row) ?? i
                    line(row, index: index)
                        .background(look == "striped" && index % 2 == 1 ? theme.color.tableRowHover : AtomKit.clear(theme))
                    if look == "dense" || look == "spacious" || look == "bordered" {
                        Rectangle().fill(theme.color.tableBorder).frame(height: theme.geometry.borderHairline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func line(_ row: AnyCodable, index: Int) -> some View {
        let id = String(AtomKit.scalar(row.dictValue?[idField]) ?? String(index))
        let open = props.string("itemClickEvent")
        let actions = (props.dictValue?["itemActions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        let titleColumn = columns.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" }) ?? columns.first
        let compact = sizeClass == .compact
        let vertical = props.string("look", default: "dense") == "spacious" ? theme.density.spacing.space4 : theme.density.spacing.space2
        HStack(alignment: .center, spacing: theme.density.spacing.space3) {
            if props.bool("selectable") {
                CheckboxRenderer(
                    props: AtomKit.child(props, ["checked": .bool(selection.contains(id)), "onChange": .string(AtomKit.eventOrLocal(props.string("selectEvent"))), "local": .bool(props.string("selectEvent").isEmpty)]),
                    modifier: nil,
                    onEvent: { _, _ in
                        var next = selection
                        if next.contains(id) { next.remove(id) } else { next.insert(id) }
                        commit(next)
                    }
                )
                .frame(width: theme.density.spacing.space6)
            }
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        ForEach(columns.indices, id: \.self) { index in
                            let column = columns[index]
                            let isTitle = column.dictValue?["name"] == titleColumn?.dictValue?["name"]
                            HStack(spacing: theme.density.spacing.space3) {
                                if !isTitle { AtomKit.typo(column.string("label", default: column.string("name")), "caption", color: "secondary", onEvent: onEvent) }
                                if !isTitle { Spacer(minLength: theme.density.spacing.space2) }
                                cellView(row, column, title: isTitle)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: theme.density.spacing.space3) {
                        ForEach(columns.indices, id: \.self) { index in
                            cellView(row, columns[index], title: false)
                                .frame(maxWidth: .infinity, alignment: align(columns[index]))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !open.isEmpty { onEvent(open, eventEnvelope(props, payload: AtomKit.rowPayload(row))) } }
            .accessibilityAddTraits(open.isEmpty ? [] : .isButton)
            if !actions.isEmpty {
                AtomRowActions(owner: props, row: row, inline: [], menu: actions, onEvent: onEvent)
            }
        }
        .padding(.horizontal, theme.density.spacing.space3)
        .padding(.vertical, vertical)
        .accessibilityAddTraits(selection.contains(id) ? .isSelected : [])
        .verificationContainer(VerificationIds.row(id))
    }

    @ViewBuilder
    private func cellView(_ row: AnyCodable, _ column: AnyCodable, title: Bool) -> some View {
        let raw = AtomKit.cell(row, name(column))
        let text = AtomKit.fieldText(row, ["name": .string(name(column)), "format": column.dictValue?["format"] ?? .null], relations: relations)
        if column.string("format") == "badge" && !AtomKit.blank(raw) {
            AtomKit.badge(AtomKit.labelled(text, column), AtomKit.badgeVariant(column, AtomKit.scalar(raw) ?? text), onEvent: onEvent)
        } else {
            AtomKit.typo(text, title ? "body1" : "small", weight: title ? "medium" : column.string("weight"), truncate: true, onEvent: onEvent)
        }
    }

    private func commit(_ next: Set<String>) {
        if props.dictValue?["selectedIds"] == nil { chosen = next }
        let event = props.string("selectEvent")
        if !event.isEmpty {
            onEvent(event, eventEnvelope(props, payload: ["selectedIds": .array(next.sorted().map { AnyCodable.string($0) })]))
        }
    }
}

@ViewBuilder
func TableViewRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TableViewMoleculeView(props: props, onEvent: onEvent))
}
