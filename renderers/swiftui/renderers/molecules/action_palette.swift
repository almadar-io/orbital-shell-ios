import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ActionPaletteMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func tile(_ action: AnyCodable) -> AnyCodable {
        let used = Set((props.dictValue?["usedActionIds"]?.arrayValue ?? []).compactMap { $0.stringValue })
        var values: [String: AnyCodable] = [
            "action": action,
            "size": .string(props.string("size", default: "md")),
            "disabled": .bool(!props.bool("allowDuplicates", default: true) && used.contains(action.string("id"))),
        ]
        if let colors = props.dictValue?["categoryColors"] { values["categoryColors"] = colors }
        return AtomKit.node(props, "action-tile", values)
    }

    var body: some View {
        let label = props.string("label", default: "Actions")
        let actions = props.dictValue?["actions"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            AtomKit.typo(label, "body2", color: "muted", weight: "medium", onEvent: onEvent)
            StackRenderer(
                props: AtomKit.child(props, ["direction": "horizontal", "wrap": true, "gap": "sm", "children": .array(actions.map { tile($0) })]),
                modifier: nil,
                onEvent: onEvent
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme, padding: theme.density.spacing.space3)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ActionPaletteRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ActionPaletteMoleculeView(props: props, onEvent: onEvent))
}
