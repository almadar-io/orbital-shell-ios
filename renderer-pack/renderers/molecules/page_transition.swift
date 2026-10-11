import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct PageTransitionMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let key = props.string("locationKey")
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AlmadarSurfaceEnter(shape: "pageEnter", timing: .page, replayKey: key))
    }
}

@ViewBuilder
func PageTransitionRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PageTransitionMoleculeView(props: props, onEvent: onEvent))
}
