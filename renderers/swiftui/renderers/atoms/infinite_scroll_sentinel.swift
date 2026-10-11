import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct InfiniteScrollSentinelAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let loading = props.bool("isLoading")
        let more = props.bool("hasMore", default: true)
        let event = props.string("loadMoreEvent")
        VStack(spacing: theme.density.spacing.space0) {
            if loading {
                ProgressView().controlSize(.small).tint(theme.color.mutedForeground).accessibilityLabel(Text("Loading"))
            }
            AtomKit.clear(theme)
                .frame(height: theme.geometry.borderHairline)
                .onAppear {
                    guard more, !loading, !event.isEmpty else { return }
                    onEvent(event, eventEnvelope(props, payload: props.dictValue?["loadMorePayload"]))
                }
                .accessibilityHidden(true)
                .atomAction(event, props)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.density.spacing.space4)
    }
}

@ViewBuilder
func InfiniteScrollSentinelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(InfiniteScrollSentinelAtomView(props: props, onEvent: onEvent))
}
