import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct TabsMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var current: String

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        let list = TabsMoleculeView.items(props)
        let flagged = list.first(where: { $0.bool("active") }).map { TabsMoleculeView.tabId($0) } ?? ""
        let fallback = props.string("defaultActiveTab", default: flagged.isEmpty ? (list.first.map { TabsMoleculeView.tabId($0) } ?? "") : flagged)
        _current = State(initialValue: fallback)
    }

    static func items(_ props: AnyCodable) -> [AnyCodable] {
        props.dictValue?["items"]?.arrayValue ?? props.dictValue?["tabs"]?.arrayValue ?? []
    }

    static func tabId(_ item: AnyCodable) -> String {
        let id = item.string("id")
        return id.isEmpty ? item.string("value") : id
    }

    var body: some View {
        let list = TabsMoleculeView.items(props)
        let active = props.dictValue?["activeTab"] != nil ? props.string("activeTab") : current
        let vertical = props.string("orientation", default: "horizontal") == "vertical"
        let panel = list.first(where: { TabsMoleculeView.tabId($0) == active })?.dictValue?["content"]
        if list.isEmpty {
            AtomKit.typo("No items", "small", color: "muted", onEvent: onEvent)
                .padding(.vertical, theme.density.spacing.space4)
        } else if vertical {
            HStack(alignment: .top, spacing: theme.density.spacing.space0) {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) { lane(list, active: active) }
                    .padding(.trailing, theme.density.spacing.space2)
                panelView(panel)
            }
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: props.string("variant") == "pills" ? theme.density.spacing.space1 : theme.density.spacing.space0) { lane(list, active: active) }
                }
                .padding(props.string("variant") == "pills" ? theme.density.spacing.space1 : theme.density.spacing.space0)
                .background(props.string("variant") == "pills" ? theme.color.muted : AtomKit.clear(theme))
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
                if props.string("variant") != "pills" { DividerRenderer(props: [:], modifier: nil, onEvent: onEvent) }
                panelView(panel)
            }
        }
    }

    @ViewBuilder
    private func panelView(_ panel: AnyCodable?) -> some View {
        if panel != nil {
            AtomSlot(panel, variant: "body2", onEvent: onEvent)
                .padding(theme.density.spacing.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func lane(_ list: [AnyCodable], active: String) -> some View {
        ForEach(list.indices, id: \.self) { index in
            let item = list[index]
            let id = TabsMoleculeView.tabId(item)
            let isActive = id == active
            let pills = props.string("variant") == "pills"
            let busEvent = props.string("tabChangeEvent")
            HStack(spacing: theme.density.spacing.space2) {
                if !item.string("icon").isEmpty { AtomKit.icon(item.string("icon"), "sm", color: isActive ? "" : "muted", onEvent: onEvent) }
                AtomKit.typo(item.string("label"), "label", color: isActive ? "primary" : "muted", weight: "medium", onEvent: onEvent)
                if let badge = AtomKit.scalar(item.dictValue?["badge"]) { AtomKit.badge(badge, "default", onEvent: onEvent) }
            }
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.vertical, theme.density.spacing.space2)
            .background(pills && isActive ? theme.color.primary : AtomKit.clear(theme))
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
            .overlay(alignment: .bottom) {
                if !pills && isActive { Rectangle().fill(theme.color.primary).frame(height: theme.geometry.borderHeavy * 2) }
            }
            .opacity(item.bool("disabled") ? 0.5 : 1)
            .contentShape(Rectangle())
            .onTapGesture { if !item.bool("disabled") { select(id, item) } }
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .atomAction(item.string("event", default: busEvent), props)
        }
    }

    private func select(_ id: String, _ item: AnyCodable) {
        if props.dictValue?["activeTab"] == nil { current = id }
        let busEvent = props.string("tabChangeEvent")
        let itemEvent = item.string("event")
        if !busEvent.isEmpty { onEvent(busEvent, eventEnvelope(props, payload: ["tabId": .string(id)])) }
        if !itemEvent.isEmpty && itemEvent != busEvent { onEvent(itemEvent, eventEnvelope(props, payload: ["tabId": .string(id)])) }
    }
}

@ViewBuilder
func TabsRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TabsMoleculeView(props: props, onEvent: onEvent))
}
