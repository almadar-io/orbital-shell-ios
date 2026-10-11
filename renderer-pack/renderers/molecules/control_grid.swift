import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ControlGridMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var held: Set<String> = []

    // U+FE0E keeps the arrows in text presentation; iOS draws ◀ ▶ as emoji otherwise.
    private static let glyphs: [String: String] = ["up": "▲\u{FE0E}", "down": "▼\u{FE0E}", "left": "◀\u{FE0E}", "right": "▶\u{FE0E}"]
    private static let names: [String: String] = ["up": "Up", "down": "Down", "left": "Left", "right": "Right"]

    private var size: String { props.string("size", default: "md") }

    var body: some View {
        content.accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var content: some View {
        if props.string("kind") == "dpad" {
            dpad()
        } else {
            actions()
        }
    }

    private func dpad() -> some View {
        let gap = padGap()
        let width = padWidth()
        let cell = (width - gap * 2) / 3
        return Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            GridRow { blank(cell); direction("up", cell); blank(cell) }
            GridRow { direction("left", cell); hub(cell); direction("right", cell) }
            GridRow { blank(cell); direction("down", cell); blank(cell) }
        }
        .frame(width: width, alignment: .leading)
    }

    private func padWidth() -> CGFloat {
        switch size {
        case "sm": return AlmadarSizes.w28
        case "lg": return AlmadarSizes.w52
        default: return AlmadarSizes.w40
        }
    }

    private func padGap() -> CGFloat {
        switch size {
        case "sm": return AlmadarSizes.w0_5
        case "lg": return AlmadarSizes.w1_5
        default: return theme.density.spacing.space1
        }
    }

    private func blank(_ cell: CGFloat) -> some View {
        AtomKit.clear(theme).frame(width: cell, height: 0)
    }

    private func hub(_ cell: CGFloat) -> some View {
        let side = theme.density.spacing.space6
        let radius = theme.geometry.radiusInteractive
        return AtomKit.shape(theme, .container, radius: radius)
            .fill(theme.color.muted)
            .frame(width: side, height: side)
            .atomBorder(theme, .container, radius: radius, color: theme.color.mutedForeground, width: theme.geometry.borderHeavy)
            .frame(width: cell)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func direction(_ d: String, _ cell: CGFloat) -> some View {
        let events = props.dictValue?["directionEvents"]
        if events == nil || !(events?.string(d) ?? "").isEmpty {
            pressable(d, values: padValues(d), press: events?.string(d) ?? "", release: props.dictValue?["directionReleaseEvents"]?.string(d) ?? "")
                .frame(width: cell, alignment: .leading)
        } else {
            blank(cell)
        }
    }

    private func padValues(_ d: String) -> [String: AnyCodable] {
        var values: [String: AnyCodable] = [
            "variant": "secondary",
            "label": .string(Self.glyphs[d] ?? ""),
            "aria-label": .string(Self.names[d] ?? d),
        ]
        if let asset = props.dictValue?["directionAssets"]?.dictValue?[d] { values["assetUrl"] = asset }
        return values
    }

    @ViewBuilder
    private func actions() -> some View {
        let list = buttons()
        let layout = props.string("layout", default: "horizontal")
        if layout == "diamond" && list.count == 4 {
            Grid(horizontalSpacing: theme.density.spacing.space1, verticalSpacing: theme.density.spacing.space1) {
                GridRow { void(); action(list[0]); void() }
                GridRow { action(list[3]); void(); action(list[1]) }
                GridRow { void(); action(list[2]); void() }
            }
        } else if layout == "diamond" {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.density.spacing.space1), count: 3), spacing: theme.density.spacing.space1) {
                ForEach(list.indices, id: \.self) { action(list[$0]) }
            }
        } else if layout == "vertical" {
            VStack(spacing: theme.density.spacing.space2) {
                ForEach(list.indices, id: \.self) { action(list[$0]) }
            }
        } else {
            HStack(spacing: theme.density.spacing.space2) {
                ForEach(list.indices, id: \.self) { action(list[$0]) }
            }
        }
    }

    private func void() -> some View {
        AtomKit.clear(theme).frame(width: 0, height: 0)
    }

    private func buttons() -> [AnyCodable] {
        if let given = props.dictValue?["buttons"]?.arrayValue { return given }
        return [
            .dict(["id": "jump", "label": "Jump", "icon": "chevron-up", "variant": "primary"]),
            .dict(["id": "attack", "label": "Attack", "icon": "sword", "variant": "secondary"]),
            .dict(["id": "dodge", "label": "Dodge", "icon": "wind", "variant": "ghost"]),
        ]
    }

    private func action(_ button: AnyCodable) -> some View {
        pressable(button.string("id"), values: actionValues(button), press: "", release: "")
    }

    private func actionValues(_ button: AnyCodable) -> [String: AnyCodable] {
        var values: [String: AnyCodable] = [
            "variant": .string(button.string("variant", default: "secondary")),
            "aria-label": .string(button.string("label", default: button.string("id"))),
        ]
        for key in ["label", "icon", "assetUrl"] {
            if let value = button.dictValue?[key] { values[key] = value }
        }
        return values
    }

    private func pressable(_ id: String, values: [String: AnyCodable], press: String, release: String) -> some View {
        ControlButtonRenderer(
            props: AtomKit.child(props, values.merging([
                "pressEvent": .string(press),
                "releaseEvent": .string(release),
                "size": .string(size),
                "disabled": .bool(props.bool("disabled")),
            ]) { current, _ in current }),
            modifier: nil,
            onEvent: onEvent
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in begin(id) }
                .onEnded { _ in end(id) }
        )
    }

    private func begin(_ id: String) {
        guard !props.bool("disabled"), !held.contains(id) else { return }
        held.insert(id)
        announce(id, pressed: true)
    }

    private func end(_ id: String) {
        guard held.remove(id) != nil else { return }
        announce(id, pressed: false)
    }

    private func announce(_ id: String, pressed: Bool) {
        let flag: AnyCodable = .bool(pressed)
        let actionEvent = props.string("actionEvent")
        if !actionEvent.isEmpty {
            onEvent(actionEvent, eventEnvelope(props, payload: ["id": .string(id), "pressed": flag]))
        }
        guard props.string("kind") == "dpad" else { return }
        let directionEvent = props.string("directionEvent")
        if !directionEvent.isEmpty {
            onEvent(directionEvent, eventEnvelope(props, payload: ["direction": .string(id), "pressed": flag]))
        }
    }
}

@ViewBuilder
func ControlGridRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ControlGridMoleculeView(props: props, onEvent: onEvent))
}
