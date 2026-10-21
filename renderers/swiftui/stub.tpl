import Foundation
import SwiftUI

{{family}}

@ViewBuilder
func {{Pascal}}Renderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    // 🔧 {{name}} — placeholder
    AnyView(Text("🔧 {{name}}"))
}
