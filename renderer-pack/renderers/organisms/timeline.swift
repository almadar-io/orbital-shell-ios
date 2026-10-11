import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct TimelineOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var items: [AnyCodable] {
        let given = props.dictValue?["items"]?.arrayValue ?? []
        if !given.isEmpty { return given }
        let titleField = props.string("titleField")
        let descriptionField = props.string("descriptionField")
        let dateField = props.string("dateField")
        let statusField = props.string("statusField")
        return AtomKit.rows(props, "entity").enumerated().map { entry in
            var item: [String: AnyCodable] = [
                "id": .string(AtomKit.rowKey(entry.element, entry.offset)),
                "title": .string(titleField.isEmpty ? "" : AtomKit.scalar(AtomKit.cell(entry.element, titleField)) ?? ""),
                "status": .string(statusField.isEmpty ? "pending" : (AtomKit.scalar(AtomKit.cell(entry.element, statusField)) ?? "pending")),
            ]
            if !descriptionField.isEmpty, let text = AtomKit.scalar(AtomKit.cell(entry.element, descriptionField)), !text.isEmpty { item["description"] = .string(text) }
            if !dateField.isEmpty, let text = AtomKit.scalar(AtomKit.cell(entry.element, dateField)), !text.isEmpty { item["date"] = .string(text) }
            return .dict(item)
        }
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let list = items
        if props.bool("isLoading") {
            SkeletonRenderer(props: AtomKit.skeletonProps(props, fallback: "list"), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Timeline error", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else if list.isEmpty {
            EmptyStateRenderer(props: AtomKit.emptyProps(props, fallback: "No events"), modifier: nil, onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
                if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h5", onEvent: onEvent) }
                if props.string("look", default: "vertical-spacious").hasPrefix("vertical") {
                    VStack(alignment: .leading, spacing: props.string("look") == "vertical-compact" ? theme.density.spacing.space1 : theme.density.spacing.space0) {
                        ForEach(list.indices, id: \.self) { index in
                            entry(list[index], last: index == list.count - 1, vertical: true)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: theme.density.spacing.space6) {
                            ForEach(list.indices, id: \.self) { index in
                                entry(list[index], last: index == list.count - 1, vertical: false)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .atomSurface(theme, padding: theme.density.spacing.space6)
            .accessibilityElement(children: .contain)
        }
    }

    private func status(_ item: AnyCodable) -> (icon: String, tone: String, line: Color) {
        switch item.string("status", default: "pending") {
        case "complete": return ("check-circle", "success", theme.color.success)
        case "active": return ("clock", "primary", theme.color.primary)
        case "error": return ("alert-circle", "error", theme.color.error)
        default: return ("circle", "muted", theme.color.border)
        }
    }

    private func entry(_ item: AnyCodable, last: Bool, vertical: Bool) -> some View {
        let style = status(item)
        let icon = item.string("icon").isEmpty ? style.icon : item.string("icon")
        let layout = vertical ? AnyLayout(HStackLayout(alignment: .top, spacing: theme.density.spacing.space4)) : AnyLayout(VStackLayout(alignment: .leading, spacing: theme.density.spacing.space2))
        return layout {
            VStack(spacing: theme.density.spacing.space0) {
                AtomKit.icon(icon, "sm", color: style.tone, onEvent: onEvent)
                if !last && vertical {
                    Rectangle().fill(style.line.opacity(0.4)).frame(width: theme.geometry.borderHeavy * 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: theme.density.spacing.space6)
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                HStack(alignment: .top) {
                    AtomKit.typo(item.string("title"), "body1", weight: "semibold", onEvent: onEvent)
                    Spacer(minLength: theme.density.spacing.space2)
                    if !item.string("date").isEmpty { AtomKit.typo(AtomKit.formatted(item.string("date"), format: "date"), "caption", color: "secondary", onEvent: onEvent) }
                }
                if !item.string("description").isEmpty { AtomKit.typo(item.string("description"), "small", color: "secondary", onEvent: onEvent) }
                let tags = AtomKit.strings(item, "tags")
                if !tags.isEmpty {
                    HStack(spacing: theme.density.spacing.space1) {
                        ForEach(tags.indices, id: \.self) { position in AtomKit.badge(tags[position], "default", onEvent: onEvent) }
                    }
                }
                let actions = (props.dictValue?["itemActions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
                if !actions.isEmpty {
                    HStack(spacing: theme.density.spacing.space1) {
                        ForEach(actions.indices, id: \.self) { position in
                            ButtonRenderer(props: AtomKit.actionProps(props, actions[position], row: item, size: "sm", fallback: "ghost"), modifier: nil, onEvent: onEvent)
                        }
                    }
                }
            }
            .padding(.bottom, last ? theme.density.spacing.space0 : theme.density.spacing.space6)
            .frame(maxWidth: vertical ? .infinity : nil, alignment: .leading)
        }
        .verificationContainer(VerificationIds.row(item.string("id")))
    }
}

@ViewBuilder
func TimelineRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TimelineOrganismView(props: props, onEvent: onEvent))
}
