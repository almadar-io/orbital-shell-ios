import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TraitFrameAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let fallback = props.dictValue?["fallback"] {
                RenderChild(fallback, onEvent: onEvent)
            }
        }
        .id(props.string("traitName"))
    }
}

@ViewBuilder
func TraitFrameRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TraitFrameAtomView(props: props, onEvent: onEvent))
}
