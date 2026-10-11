import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DateRangeSelectorMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var chosen: String

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _chosen = State(initialValue: props.string("selected", default: "month"))
    }

    private var choices: [(value: String, label: String)] {
        let given = AtomKit.options(props.dictValue?["options"]?.arrayValue ?? [])
        return given.isEmpty ? [(value: "week", label: "1W"), (value: "month", label: "1M"), (value: "3months", label: "3M"), (value: "year", label: "1Y")] : given
    }

    var body: some View {
        let list = choices
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(list.indices, id: \.self) { index in
                let option = list[index]
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": .string(chosen == option.value ? "primary" : "ghost"), "size": "sm", "label": .string(option.label), "action": .string(AtomKit.localEvent), "local": true]),
                    modifier: nil,
                    onEvent: { _, _ in chosen = option.value }
                )
                .accessibilityAddTraits(chosen == option.value ? .isSelected : [])
            }
        }
        .onChange(of: props.string("selected", default: "month")) { value in chosen = value }
    }
}

@ViewBuilder
func DateRangeSelectorRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DateRangeSelectorMoleculeView(props: props, onEvent: onEvent))
}
