import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct DetailPanelOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var fields: [AnyCodable] {
        let declared = AtomKit.fieldDefs(props, ["fields"])
        if !declared.isEmpty { return declared }
        return AtomKit.strings(props, "fieldNames").map { AnyCodable.dict(["name": .string($0)]) }
    }

    private var record: AnyCodable? {
        guard let raw = props.dictValue?["entity"] ?? props.dictValue?["initialData"] else { return nil }
        if let list = raw.arrayValue { return list.first }
        if case .null = raw { return props.dictValue?["initialData"] }
        return raw
    }

    private var relations: AnyCodable? { props.dictValue?["relationsData"] }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "detail"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Error loading data", "message": .string(error), "retryEvent": "RETRY"]), modifier: nil, onEvent: onEvent)
        } else if record == nil && !fields.isEmpty {
            EmptyStateRenderer(props: AtomKit.child(props, ["title": "Not found", "description": "The item could not be found."]), modifier: nil, onEvent: onEvent)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                    header
                    figures
                    sections
                    prose
                    totals
                    if let footer = props.dictValue?["footer"] {
                        DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                        RenderChild(footer, onEvent: onEvent)
                    }
                }
                .padding(theme.density.spacing.space6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .atomSurfaceImage(theme, .container, radius: theme.density.spacing.space0)
            .background(theme.color.card)
            .atomBackdrop(theme, .container, radius: theme.density.spacing.space0)
            .accessibilityElement(children: .contain)
        }
    }

    private func slot(_ field: AnyCodable) -> String {
        let variant = field.string("variant")
        let format = field.string("format")
        if variant == "badge" { return "badge" }
        if variant == "progress" { return "progress" }
        if variant == "body" { return "body" }
        if format == "date" || format == "datetime" { return "date" }
        if format == "currency" || format == "number" || format == "percent" { return "metric" }
        return "other"
    }

    private var titleField: AnyCodable? {
        fields.first(where: { $0.string("variant") == "h3" || $0.string("variant") == "h4" })
    }

    private var title: String {
        let declared = props.string("title")
        if !declared.isEmpty { return declared }
        guard let record = record, let field = titleField else { return "" }
        return AtomKit.fieldText(record, field, relations: relations)
    }

    private func label(_ field: AnyCodable) -> String { field.string("label", default: field.string("name")) }

    private func present(_ field: AnyCodable) -> Bool {
        guard let record = record else { return false }
        return !AtomKit.blank(AtomKit.cell(record, field.string("name")))
    }

    private var shownActions: [AnyCodable] {
        (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
    }

    private var closeAction: AnyCodable? {
        let event = props.string("closeEvent")
        return event.isEmpty ? nil : shownActions.first(where: { $0.string("event") == event })
    }

    @ViewBuilder
    private var header: some View {
        let others = shownActions.filter { $0 != closeAction }
        let limit = props.int("maxInlineActions", default: 2)
        let avatarField = props.string("avatarField")
        let status = props.dictValue?["status"]
        AtomFlowLayout(spacing: theme.density.spacing.space4) {
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                if let back = props.dictValue?["backAction"], AtomKit.actionable(back) {
                    ButtonRenderer(props: actionButton(back, fallback: "ghost", icon: back.string("icon", default: "arrow-left")), modifier: nil, onEvent: onEvent)
                }
                if !avatarField.isEmpty || props.string("look") == "profile" {
                    AvatarRenderer(props: ["src": .string(record.flatMap { AtomKit.scalar(AtomKit.cell($0, avatarField)) } ?? ""), "name": .string(title), "size": "xl"], modifier: nil, onEvent: onEvent)
                }
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomFlowLayout(spacing: theme.density.spacing.space2) {
                        AtomKit.typo(title.isEmpty ? "Details" : title, "h2", onEvent: onEvent)
                        if let record = record {
                            AtomFieldBadges(row: record, fields: fields.filter { slot($0) == "badge" }, relations: relations, onEvent: onEvent)
                        }
                        if let status = status, !status.string("label").isEmpty {
                            AtomKit.badge(status.string("label"), status.string("variant", default: "default"), size: "md", onEvent: onEvent)
                        }
                    }
                    if !props.string("subtitle").isEmpty { AtomKit.typo(props.string("subtitle"), "body1", color: "secondary", onEvent: onEvent) }
                }
            }
            if props.bool("showActions", default: true) {
                HStack(spacing: theme.density.spacing.space1) {
                    ForEach(Array(others.prefix(limit).enumerated()), id: \.offset) { pair in
                        ButtonRenderer(props: actionButton(pair.element, fallback: "secondary", icon: pair.element.string("icon")), modifier: nil, onEvent: onEvent)
                    }
                    if others.count > limit {
                        Menu {
                            ForEach(Array(others.dropFirst(limit).enumerated()), id: \.offset) { pair in
                                ButtonRenderer(props: actionButton(pair.element, fallback: "ghost", icon: pair.element.string("icon")), modifier: nil, onEvent: onEvent)
                            }
                        } label: {
                            AtomKit.icon("more-horizontal", "sm", label: "Actions", onEvent: onEvent)
                                .frame(minWidth: theme.density.buttonHeightSm, minHeight: theme.density.buttonHeightSm)
                        }
                        .verificationId(VerificationIds.actionOverflow)
                    }
                    if let close = closeAction {
                        ButtonRenderer(props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close panel", "action": .string(close.string("event")), "actionPayload": record.map { AtomKit.rowPayload($0) } ?? .null]), modifier: nil, onEvent: onEvent)
                    }
                }
            }
        }
    }

    private func actionButton(_ action: AnyCodable, fallback: String, icon: String) -> AnyCodable {
        let routed = AtomKit.route(action, row: record)
        return AtomKit.child(props, [
            "variant": .string(action.string("variant", default: fallback)),
            "size": "sm",
            "label": .string(action.string("label")),
            "leftIcon": .string(icon),
            "action": .string(routed.event),
            "actionPayload": routed.payload ?? .null,
        ])
    }

    @ViewBuilder
    private var figures: some View {
        if let record = record {
            let keyFigures = fields.filter { (slot($0) == "progress" || slot($0) == "metric") && present($0) }
            if !keyFigures.isEmpty {
                AtomFlowLayout(spacing: theme.density.spacing.space4) {
                    ForEach(keyFigures.indices, id: \.self) { index in
                        let field = keyFigures[index]
                        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                            AtomKit.typo(label(field), "caption", color: "muted", weight: "medium", onEvent: onEvent)
                            AtomKit.typo(AtomKit.fieldText(record, field, relations: relations), "h4", onEvent: onEvent)
                            if slot(field) == "progress", let value = AtomKit.cell(record, field.string("name")), value.stringValue == nil, let number = value.doubleValue {
                                ProgressBarRenderer(props: ["value": .double(number)], modifier: nil, onEvent: onEvent)
                            }
                        }
                        .padding(theme.density.spacing.space3)
                        .frame(minWidth: AlmadarSizes.w40, maxWidth: AlmadarSizes.maxW72, alignment: .leading)
                        .background(theme.color.muted.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
                        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
                    }
                }
            }
        }
    }

    private struct Entry {
        let label: String
        let icon: String
        let value: AnyView
    }

    private func entries(for names: [AnyCodable]) -> [Entry] {
        guard let record = record else { return [] }
        return names.filter { present($0) }.map { Entry(label: label($0), icon: $0.string("icon"), value: valueView(record, $0)) }
    }

    private var groups: [(title: String, entries: [Entry])] {
        guard let record = record else { return [] }
        if let declared = props.dictValue?["sections"]?.arrayValue, !declared.isEmpty {
            return declared.map { section in
                let items: [Entry] = (section.dictValue?["fields"]?.arrayValue ?? []).compactMap { item in
                    if let name = item.stringValue {
                        let field = fields.first(where: { $0.string("name") == name }) ?? .dict(["name": .string(name)])
                        return Entry(label: label(field), icon: "", value: valueView(record, field))
                    }
                    return Entry(label: item.string("label"), icon: item.string("icon"), value: AtomKit.typo(AtomKit.scalar(item.dictValue?["value"]) ?? "\u{2014}", "body1", onEvent: onEvent))
                }
                return (title: section.string("title"), entries: items)
            }.filter { !$0.entries.isEmpty }
        }
        let overview = entries(for: fields.filter { slot($0) == "other" })
        let timeline = entries(for: fields.filter { slot($0) == "date" })
        return [("Overview", overview), ("Timeline", timeline)].filter { !$0.1.isEmpty }.map { (title: $0.0, entries: $0.1) }
    }

    @ViewBuilder
    private var sections: some View {
        let shown = groups
        VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
            ForEach(shown.indices, id: \.self) { sectionIndex in
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    if shown.count > 1 { AtomKit.typo(shown[sectionIndex].title, "h5", color: "secondary", onEvent: onEvent) }
                    AtomGridLayout(minWidth: AlmadarSizes.w48, maxColumns: 3, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                        ForEach(shown[sectionIndex].entries.indices, id: \.self) { index in
                            let entry = shown[sectionIndex].entries[index]
                            HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                                if !entry.icon.isEmpty { AtomKit.icon(entry.icon, "md", color: "muted", onEvent: onEvent) }
                                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                                    AtomKit.typo(entry.label, "caption", color: "muted", weight: "medium", onEvent: onEvent)
                                    entry.value
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var prose: some View {
        if let record = record {
            let body = fields.filter { slot($0) == "body" && present($0) }
            if !body.isEmpty {
                VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
                    ForEach(body.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                            AtomKit.typo(label(body[index]), "caption", color: "muted", weight: "medium", onEvent: onEvent)
                            AtomKit.typo(AtomKit.fieldText(record, body[index], relations: relations), "body1", onEvent: onEvent)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var totals: some View {
        if let record = record, let list = props.dictValue?["totals"]?.arrayValue, !list.isEmpty {
            let rows = list.compactMap { AtomKit.normalizedField($0) }
            VStack(spacing: theme.density.spacing.space1) {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                ForEach(rows.indices, id: \.self) { index in
                    let last = index == rows.count - 1
                    let raw = AtomKit.cell(record, rows[index].string("name"))
                    HStack {
                        AtomKit.typo(label(rows[index]), last ? "body1" : "small", color: last ? "primary" : "secondary", weight: last ? "semibold" : "", onEvent: onEvent)
                        Spacer(minLength: theme.density.spacing.space6)
                        AtomKit.typo(AtomKit.blank(raw) ? "\u{2014}" : AtomKit.fieldText(record, rows[index], relations: relations), last ? "h4" : "body1", onEvent: onEvent)
                    }
                }
            }
            .frame(minWidth: AlmadarSizes.w64, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func valueView(_ record: AnyCodable, _ field: AnyCodable) -> AnyView {
        guard let raw = AtomKit.cell(record, field.string("name")) else { return AtomKit.typo("\u{2014}", "body1", onEvent: onEvent) }
        let text = AtomKit.scalar(raw) ?? ""
        let type = field.string("type")
        let options = relations?.dictValue?[field.string("name")]?.arrayValue ?? []
        if !field.string("format").isEmpty {
            return AtomKit.typo(AtomKit.fieldText(record, field, relations: relations), "body1", onEvent: onEvent)
        }
        switch type {
        case "image":
            return ImageRenderer(props: ["src": .string(AtomKit.assetURL(.dict(["u": raw]), "u")), "alt": .string(label(field)), "fit": "contain", "rounded": "md"], modifier: nil, onEvent: onEvent)
        case "url" where text.lowercased().hasPrefix("http"):
            return ButtonRenderer(props: ["variant": "link", "label": .string(text), "href": .string(text)], modifier: nil, onEvent: onEvent)
        case "email":
            return ButtonRenderer(props: ["variant": "link", "label": .string(text), "href": .string("mailto:" + text)], modifier: nil, onEvent: onEvent)
        case "phone":
            return ButtonRenderer(props: ["variant": "link", "label": .string(text), "href": .string("tel:" + text)], modifier: nil, onEvent: onEvent)
        case "date", "datetime", "timestamp":
            return AtomKit.typo(AtomKit.formatted(text, format: type == "date" ? "date" : "datetime"), "body1", onEvent: onEvent)
        case "money":
            return AtomKit.typo(AtomKit.formatted(text, format: "currency"), "body1", onEvent: onEvent)
        case "boolean":
            return AtomKit.typo(AtomKit.display(raw, format: "boolean"), "body1", onEvent: onEvent)
        case "file":
            let name = raw.string("name", default: "file")
            return ButtonRenderer(props: ["variant": "secondary", "size": "sm", "leftIcon": "file-text", "label": .string(name), "href": .string(raw.string("url"))], modifier: nil, onEvent: onEvent)
        case "array", "relation":
            let items = (raw.arrayValue ?? [raw]).compactMap { AtomKit.relationLabel($0, options) ?? AtomKit.scalar($0) }
            if items.isEmpty { return AtomKit.typo("\u{2014}", "body1", onEvent: onEvent) }
            if items.count == 1 && type == "relation" { return AtomKit.typo(items[0], "body1", onEvent: onEvent) }
            return AnyView(AtomFlowLayout(spacing: theme.density.spacing.space1) {
                ForEach(items.indices, id: \.self) { index in AtomKit.badge(items[index], "default", onEvent: onEvent) }
            })
        default:
            if AtomKit.strings(field, "values").contains(text) {
                return AtomKit.badge(AtomKit.labelled(text, field), AtomKit.badgeVariant(field, text), size: "md", onEvent: onEvent)
            }
            return AtomKit.typo(AtomKit.fieldText(record, field, relations: relations), "body1", onEvent: onEvent)
        }
    }
}

@ViewBuilder
func DetailPanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DetailPanelOrganismView(props: props, onEvent: onEvent))
}
