import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func ErrorBoundaryRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(Group { AtomChildren(props: props, key: "children", onEvent: onEvent) })
}
