import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

/// `ScaledDiagram.tsx`: the children lay out at their natural size and scale down to the column (never up)
/// once that width reaches `MIN_DIAGRAM_WIDTH`, anchored at the leading top; the box is as tall as the scaled content.
struct ScaledDiagramView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.layoutDirection) private var direction
    @Environment(\.almadarTheme) private var theme
    @State private var natural: CGSize = .zero
    @State private var available: CGFloat = 0

    static let minDiagramWidth: CGFloat = 200

    var body: some View {
        let scale = natural.width >= Self.minDiagramWidth && available > 0 ? min(1, available / natural.width) : 1
        let anchor: UnitPoint = direction == .rightToLeft ? .topTrailing : .topLeading
        // The box is the column width and the scaled height; the content rides an overlay, so it never widens the box.
        AtomKit.clear(theme)
            .frame(maxWidth: .infinity)
            .frame(height: natural.height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { available = $0 }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
                .environment(\.almadarCanvasNaturalSize, true)
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { natural = $0 }
                .scaleEffect(scale, anchor: anchor)
            }
            .clipped()
    }
}

@ViewBuilder
func ScaledDiagramRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ScaledDiagramView(props: props, onEvent: onEvent))
}
