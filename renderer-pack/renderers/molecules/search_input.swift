import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SearchInputMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var pending: DispatchWorkItem?

    var body: some View {
        let event = props.string("event")
        let entity = props.string("entity")
        let query = props.string("query")
        let wired = !event.isEmpty || !entity.isEmpty || !query.isEmpty
        let loading = props.bool("isLoading")
        let clearEvent = !event.isEmpty || !query.isEmpty ? "CLEAR_SEARCH" : ""
        InputRenderer(
            props: AtomKit.child(props, [
                "inputType": "search",
                "placeholder": .string(props.string("placeholder", default: "Search")),
                "value": .string(props.string("value")),
                "leftIcon": "search",
                "clearable": .bool(props.bool("clearable", default: true) && !loading),
                "onChange": .string(event.isEmpty ? (wired ? "SEARCH" : "") : event),
                "onClear": .string(clearEvent),
                "name": .string(props.string("name")),
            ]),
            modifier: nil,
            onEvent: { name, envelope in
                if name == "CLEAR_SEARCH" {
                    pending?.cancel()
                    onEvent(name, eventEnvelope(props, payload: ["searchTerm": "", "entity": .string(entity), "query": .string(query)]))
                    return
                }
                schedule(envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? "")
            }
        )
        .overlay(alignment: .trailing) {
            if loading {
                SpinnerRenderer(props: ["size": "sm"], modifier: nil, onEvent: onEvent)
                    .padding(.trailing, theme.density.spacing.space3)
            }
        }
        .accessibilityAddTraits(loading ? .updatesFrequently : [])
    }

    private func schedule(_ term: String) {
        pending?.cancel()
        let work = DispatchWorkItem { emit(term) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(props.int("debounceMs", default: 300)), execute: work)
    }

    private func emit(_ term: String) {
        let event = props.string("event")
        let entity = props.string("entity")
        let query = props.string("query")
        if !event.isEmpty && event != "SEARCH" {
            onEvent(event, eventEnvelope(props, payload: ["searchTerm": .string(term), "entity": .string(entity)]))
        }
        if !event.isEmpty || !entity.isEmpty || !query.isEmpty {
            onEvent("SEARCH", eventEnvelope(props, payload: ["searchTerm": .string(term), "entity": .string(entity), "query": .string(query)]))
        }
    }
}

@ViewBuilder
func SearchInputRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SearchInputMoleculeView(props: props, onEvent: onEvent))
}
