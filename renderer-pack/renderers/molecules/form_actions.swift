import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FormActionsMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var segmented: Bool { ["segmented", "toggle"].contains(props.string("variant", default: "default")) }
    private var look: String { props.string("look", default: "right-aligned-buttons") }

    var body: some View {
        let gap = segmented ? theme.density.spacing.space0 : theme.density.spacing.space2
        let content = Group {
            if props.string("orientation", default: "horizontal") == "vertical" {
                VStack(spacing: gap) { buttons }
            } else {
                HStack(spacing: gap) { buttons }
            }
        }
        if look == "floating-bar" {
            content
                .padding(theme.density.cardPaddingSm)
                .background(theme.color.card)
                .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
                .atomShadow(theme.elevation.toastElevation)
                .accessibilityElement(children: .contain)
        } else {
            content.accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        let children = props.children()
        let filters = props.dictValue?["filters"]?.arrayValue ?? []
        let secondary = props.dictValue?["secondary"]?.arrayValue ?? []
        let primary = props.dictValue?["primary"]
        let collapsed = look == "dropdown-menu" || look == "command-palette-trigger"
        if !children.isEmpty {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        } else if !filters.isEmpty {
            let shown = collapsed ? Array(filters.prefix(1)) : filters
            ForEach(shown.indices, id: \.self) { index in
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "label": .string(shown[index].string("label")), "action": .string(AtomKit.localEvent), "local": true]),
                    modifier: nil,
                    onEvent: { _, _ in }
                )
            }
        } else {
            let actions: [(AnyCodable, String)] = secondary.map { ($0, "ghost") } + (primary.map { [($0, "primary")] } ?? [])
            let shown = collapsed ? Array(actions.prefix(1)) : actions
            ForEach(shown.indices, id: \.self) { index in
                ButtonRenderer(
                    props: AtomKit.actionProps(props, shown[index].0, row: nil, size: "md", fallback: shown[index].1),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        }
    }
}

@ViewBuilder
func FormActionsRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormActionsMoleculeView(props: props, onEvent: onEvent))
}
