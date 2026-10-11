import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct PullToRefreshMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func refresh() {
        let event = props.string("refreshEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: props.dictValue?["refreshPayload"])) }
    }

    var body: some View {
        let event = props.string("refreshEvent")
        ScrollView {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack {
                    Spacer(minLength: theme.density.spacing.space0)
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "refresh-cw", "aria-label": "Refresh", "action": .string(AtomKit.eventOrLocal(event)), "local": .bool(event.isEmpty)]),
                        modifier: nil,
                        onEvent: { _, _ in refresh() }
                    )
                }
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .refreshable { refresh() }
    }
}

@ViewBuilder
func PullToRefreshRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PullToRefreshMoleculeView(props: props, onEvent: onEvent))
}
