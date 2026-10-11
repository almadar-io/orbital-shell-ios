import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct TabbedContainerOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        var values: [String: AnyCodable] = [
            "items": props.dictValue?["tabs"] ?? .array([]),
            "orientation": .string(props.string("position", default: "top") == "left" ? "vertical" : "horizontal"),
        ]
        if !props.string("defaultTab").isEmpty { values["defaultActiveTab"] = .string(props.string("defaultTab")) }
        if !props.string("activeTab").isEmpty { values["activeTab"] = .string(props.string("activeTab")) }
        return TabsRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: onEvent)
    }
}

@ViewBuilder
func TabbedContainerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TabbedContainerOrganismView(props: props, onEvent: onEvent))
}
