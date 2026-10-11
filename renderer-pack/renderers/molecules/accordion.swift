import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AccordionMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    /// SwiftUI bodies a host composes itself, by item id; an item without one renders its `content` node.
    let rendered: [String: AnyView]
    @Environment(\.almadarTheme) private var theme
    @State private var open: Set<String>

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void, rendered: [String: AnyView] = [:]) {
        self.props = props
        self.onEvent = onEvent
        self.rendered = rendered
        let items = props.dictValue?["items"]?.arrayValue ?? []
        var initial: [String] = []
        if let ids = props.dictValue?["defaultOpenItems"]?.arrayValue {
            initial = ids.compactMap { AtomKit.scalar($0) }
        } else if let indices = props.dictValue?["defaultOpen"]?.arrayValue {
            initial = indices.compactMap { $0.intValue }.filter { $0 >= 0 && $0 < items.count }.map { AccordionMoleculeView.itemId(items[$0], $0) }
        } else {
            initial = items.indices.filter { items[$0].bool("defaultOpen") }.map { AccordionMoleculeView.itemId(items[$0], $0) }
        }
        _open = State(initialValue: Set(initial))
    }

    static func itemId(_ item: AnyCodable, _ index: Int) -> String {
        let explicit = item.string("id")
        if !explicit.isEmpty { return explicit }
        let head = AtomKit.text(item, "header").isEmpty ? AtomKit.text(item, "title") : AtomKit.text(item, "header")
        if head.isEmpty { return "accordion-item-\(index)" }
        return "accordion-" + head.lowercased().split(separator: " ").joined(separator: "-") + "-\(index)"
    }

    private var controlled: Set<String>? {
        props.dictValue?["openItems"]?.arrayValue.map { Set($0.compactMap { AtomKit.scalar($0) }) }
    }

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let current = controlled ?? open
        let event = props.string("toggleEvent")
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                let id = AccordionMoleculeView.itemId(item, index)
                let isOpen = current.contains(id)
                let disabled = item.bool("disabled")
                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    HStack(spacing: theme.density.spacing.space2) {
                        AtomSlot(item.dictValue?["header"] ?? item.dictValue?["title"], variant: "body1", weight: "medium", onEvent: onEvent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        AtomKit.icon("chevron-down", "sm", onEvent: onEvent)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .padding(.horizontal, theme.density.spacing.space4)
                    .padding(.vertical, theme.density.spacing.space3)
                    .background(isOpen ? theme.color.muted : AtomKit.clear(theme))
                    .contentShape(Rectangle())
                    .opacity(disabled ? 0.5 : 1)
                    .onTapGesture { if !disabled { toggle(id, isOpen: isOpen, current: current) } }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityValue(isOpen ? "expanded" : "collapsed")
                    .atomAction(event, props)
                    if isOpen {
                        DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                        Group {
                            if let view = rendered[id] { view } else { AtomSlot(item.dictValue?["content"], variant: "body2", onEvent: onEvent) }
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, theme.density.spacing.space4)
                            .padding(.vertical, theme.density.spacing.space3)
                    }
                    if index < items.count - 1 {
                        DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func toggle(_ id: String, isOpen: Bool, current: Set<String>) {
        var next = current
        if isOpen {
            next.remove(id)
        } else {
            if !props.bool("multiple") { next.removeAll() }
            next.insert(id)
        }
        if controlled == nil { open = next }
        let event = props.string("toggleEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["itemId": .string(id), "isOpen": .bool(!isOpen)])) }
    }
}

@ViewBuilder
func AccordionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AccordionMoleculeView(props: props, onEvent: onEvent))
}
