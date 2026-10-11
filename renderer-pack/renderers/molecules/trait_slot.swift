import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct TraitSlotMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var dragOver = false
    @State private var tipOpen = false

    private var item: AnyCodable? {
        guard let raw = props.dictValue?["equippedItem"], raw.dictValue != nil else { return nil }
        return raw
    }

    private var slotNumber: Int { props.int("slotNumber") }
    private var locked: Bool { props.bool("locked") }

    private func named(_ event: String, _ callback: String) -> String {
        let declared = props.string(event)
        return declared.isEmpty ? props.string(callback) : declared
    }

    private func category(_ key: String) -> Color? {
        guard let item = item else { return nil }
        let given = props.dictValue?["categoryColors"]?.dictValue?[item.string("category")]?.string(key) ?? ""
        return given.isEmpty ? nil : AtomKit.cssColor(theme, given)
    }

    private func side(_ size: String) -> CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space10
        case "lg": return theme.density.spacing.space12 + theme.density.spacing.space6
        default: return AlmadarSizes.w14
        }
    }

    private func iconSide(_ size: String) -> CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space5
        case "lg": return theme.density.spacing.space10
        default: return theme.density.spacing.space7
        }
    }

    private func iconVariant(_ size: String) -> String {
        switch size {
        case "sm": return "large"
        case "lg": return "h1"
        default: return "h2"
        }
    }

    private func click() {
        guard !locked else { return }
        let event = named("clickEvent", "onClick")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["slotNumber": .int(slotNumber)])) }
    }

    private func remove() {
        let event = named("removeEvent", "onRemove")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["slotNumber": .int(slotNumber)])) }
    }

    private var droppable: Bool { !locked && !named("dropEvent", "onItemDrop").isEmpty }

    private func accept(_ raw: String) -> Bool {
        guard droppable, let data = raw.data(using: .utf8), let dropped = try? JSONDecoder().decode(AnyCodable.self, from: data) else { return false }
        onEvent(named("dropEvent", "onItemDrop"), eventEnvelope(props, payload: ["slotNumber": .int(slotNumber), "itemId": .string(dropped.string("id"))]))
        return true
    }

    private var payload: String {
        guard let item = item else { return "" }
        return (try? JSONEncoder().encode(item)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func ring(_ feedback: String) -> Color? {
        if dragOver { return theme.color.accent }
        if feedback == "correct" { return theme.color.success }
        if feedback == "wrong" { return theme.color.error }
        return props.bool("selected") ? theme.color.primary : nil
    }

    @ViewBuilder
    private func content(_ size: String) -> some View {
        if locked {
            VStack(spacing: theme.density.spacing.space0) {
                AtomKit.typo("\u{1F512}", "caption", color: "muted", onEvent: onEvent)
                if !props.string("lockLabel").isEmpty { AtomKit.typo(props.string("lockLabel"), "caption", color: "muted", onEvent: onEvent) }
            }
        } else if let item = item {
            let iconUrl = AtomKit.assetURL(item, "iconUrl")
            if !iconUrl.isEmpty {
                ImageRenderer(props: AtomKit.child(props, ["src": .string(iconUrl), "alt": .string(item.string("name")), "fit": "contain"]), modifier: nil, onEvent: onEvent)
                    .frame(width: iconSide(size), height: iconSide(size))
            } else {
                AtomKit.typo(item.string("iconEmoji", default: "\u{2726}"), iconVariant(size), onEvent: onEvent)
            }
        } else {
            AtomKit.typo("+", "large", color: "muted", onEvent: onEvent)
        }
    }

    private var machine: AnyCodable? {
        guard let item = item else { return nil }
        if let given = item.dictValue?["stateMachine"], given.dictValue != nil { return given }
        return .dict([
            "name": .string(item.string("name")),
            "states": ["idle", "active", "done"],
            "currentState": "idle",
            "transitions": [
                ["from": "idle", "to": "active", "event": "ACTIVATE"],
                ["from": "active", "to": "done", "event": "COMPLETE"],
            ],
            "description": .string(item.string("description")),
        ])
    }

    private var tooltip: some View {
        VStack(spacing: theme.density.spacing.space2) {
            AtomKit.typo(item?.string("name") ?? "", "h6", align: "center", onEvent: onEvent)
            if let description = item?.string("description"), !description.isEmpty {
                AtomKit.typo(description, "caption", color: "muted", align: "center", onEvent: onEvent)
            }
            if let machine = machine {
                TraitStateViewerView(props: AtomKit.child(props, ["trait": machine, "variant": "compact", "size": "sm"]), onEvent: onEvent)
            }
        }
        .padding(theme.density.spacing.space3)
        .frame(minWidth: AlmadarSizes.w52)
        .background(theme.color.background)
        .clipShape(AtomKit.shape(theme, .container))
        .overlay(AtomKit.shape(theme, .container).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .atomShadow(theme.elevation.popoverElevation)
        .fixedSize()
    }

    private func slot(_ size: String) -> some View {
        let shape = AtomKit.shape(theme, .container)
        let feedback = props.string("feedback")
        let empty = item == nil
        let edge: Color = dragOver ? theme.color.accent : (feedback == "correct" ? theme.color.success : (feedback == "wrong" ? theme.color.error : (category("border") ?? theme.color.border)))
        let dash: [CGFloat] = empty ? [theme.density.spacing.space1] : []
        return content(size)
            .frame(width: side(size), height: side(size))
            .background(category("bg") ?? theme.color.card.opacity(0.5))
            .clipShape(shape)
            .overlay(shape.stroke(edge, style: StrokeStyle(lineWidth: theme.geometry.borderHeavy, dash: dash)))
            .overlay {
                if let color = ring(feedback) {
                    shape.stroke(color, lineWidth: theme.geometry.borderHeavy)
                        .padding(-(AlmadarSizes.w0_5 + theme.geometry.borderHeavy / 2))
                }
            }
            .opacity(locked ? 0.5 : 1)
            .scaleEffect(dragOver ? 1.1 : 1)
    }

    var body: some View {
        let size = props.string("size", default: "md")
        let tap = named("clickEvent", "onClick")
        let removable = item != nil && !named("removeEvent", "onRemove").isEmpty
        let base = slot(size)
            .overlay(alignment: .bottomLeading) {
                AtomKit.typo("\(slotNumber)", "caption", color: "muted", onEvent: onEvent)
                    .frame(width: theme.density.spacing.space4, height: theme.density.spacing.space4)
                    .background(theme.color.card)
                    .atomClip(theme, .pill)
                    .atomBorder(theme, .pill, color: theme.color.border, width: theme.geometry.borderStandard)
                    .offset(x: -theme.density.spacing.space1, y: theme.density.spacing.space1)
            }
            .overlay(alignment: .topTrailing) {
                if removable {
                    AtomKit.typo("\u{00D7}", "caption", onEvent: onEvent)
                        .frame(width: theme.density.spacing.space4, height: theme.density.spacing.space4)
                        .background(theme.color.error)
                        .atomClip(theme, .pill)
                        .offset(x: AlmadarSizes.w1_5, y: -AlmadarSizes.w1_5)
                        .onTapGesture { remove() }
                        .accessibilityLabel("Remove")
                        .accessibilityAddTraits(.isButton)
                        .atomAction(named("removeEvent", "onRemove"), props)
                }
            }
            .overlay(alignment: .top) {
                if tipOpen && item != nil && props.bool("showTooltip", default: true) {
                    tooltip.alignmentGuide(.top) { $0[.bottom] + theme.density.spacing.space2 }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { click() }
            .atomId(tap.isEmpty ? "" : AtomKit.busId(tap, props))
            .onLongPressGesture { tipOpen.toggle() }
            .dropDestination(for: String.self) { items, _ in
                items.first.map { accept($0) } ?? false
            } isTargeted: { targeted in
                dragOver = targeted && droppable
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(item?.string("name") ?? "")
        if props.bool("draggable") && item != nil {
            base.draggable(payload)
        } else {
            base
        }
    }
}

@ViewBuilder
func TraitSlotRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TraitSlotMoleculeView(props: props, onEvent: onEvent))
}
