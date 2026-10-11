import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocSearchMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @State private var query = ""

    var body: some View {
        InputRenderer(
            props: [
                "inputType": "search",
                "name": "docSearchQuery",
                "placeholder": .string(props.string("placeholder", default: "Search documentation...")),
                "value": .string(query),
                "leftIcon": "search",
                "clearable": .bool(!query.isEmpty),
                "onChange": .string(AtomKit.localEvent),
            ],
            modifier: nil,
            onEvent: { _, envelope in query = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "" }
        )
        .frame(maxWidth: .infinity)
        .task(id: query) {
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let event = props.string("onSearch")
            if term.isEmpty || event.isEmpty { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            onEvent(event, eventEnvelope(props, payload: ["query": .string(term)]))
        }
    }
}

@ViewBuilder
func DocSearchRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocSearchMoleculeView(props: props, onEvent: onEvent))
}
