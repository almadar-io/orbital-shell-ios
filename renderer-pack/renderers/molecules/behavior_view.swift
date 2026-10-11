import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct BehaviorViewMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var details: [AnyCodable] {
        let data = props.dictValue?["data"]
        let traits = data?.dictValue?["traits"]?.arrayValue ?? []
        let byName = data?.dictValue?["traitDetails"]?.dictValue ?? [:]
        return traits.compactMap { byName[$0.string("name")] }
    }

    var body: some View {
        if details.isEmpty {
            EmptyStateRenderer(
                props: AtomKit.child(props, ["icon": "workflow", "title": "No trait data"]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            VStack(spacing: theme.density.spacing.space4) {
                ForEach(details.indices, id: \.self) { index in
                    BoxRenderer(
                        props: AtomKit.child(props, [
                            "padding": "md",
                            "bg": "surface",
                            "border": true,
                            "rounded": "lg",
                            "shadow": "sm",
                            "fullWidth": true,
                            "children": .array([AtomKit.child(props, ["type": "avl-state-machine", "trait": details[index]])]),
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

@ViewBuilder
func BehaviorViewRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(BehaviorViewMoleculeView(props: props, onEvent: onEvent))
}
