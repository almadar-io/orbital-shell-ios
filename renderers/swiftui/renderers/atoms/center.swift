import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct CenterAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        let horizontal = props.bool("horizontal", default: true)
        let vertical = props.bool("vertical", default: true)
        let alignment: Alignment = horizontal ? (vertical ? .center : .top) : (vertical ? .leading : .topLeading)
        let minHeight = props.dictValue?["minHeight"]?.doubleValue
        let content = ZStack(alignment: alignment) {
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(minHeight: minHeight.map { CGFloat($0) }, alignment: alignment)
        if props.bool("inline") {
            content
        } else {
            content.frame(maxWidth: .infinity, maxHeight: props.bool("fullHeight") ? .infinity : nil, alignment: alignment)
        }
    }
}

@ViewBuilder
func CenterRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CenterAtomView(props: props, onEvent: onEvent))
}
