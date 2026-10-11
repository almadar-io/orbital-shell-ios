import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

/// `AtlasPanel`: a container skinned by an atlas slice. With children, they lay out inside the border and
/// the Rust renderer draws the nine-slice frame (or the tiled pattern) behind them at the box's size.
struct AtlasPanelAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        if props.children().isEmpty {
            LearningCanvasRenderer(pattern: "atlas-panel", props: props, modifier: nil, onEvent: onEvent, fixedSize: true)
        } else {
            let border = props.string("mode") == "repeat" ? 0 : CGFloat(props.float("borderWidth", default: 16))
            VStack(alignment: .leading, spacing: 0) {
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            }
            .padding(border)
            .frame(width: Self.stylePx(props, "width"), height: Self.stylePx(props, "height"), alignment: .topLeading)
            .background(GeometryReader { geo in
                LearningCanvasRenderer(pattern: "atlas-panel", props: Self.skin(props, geo.size), modifier: nil, onEvent: onEvent, fixedSize: true)
            })
        }
    }

    /// A `style` width/height in pixels (a number or `"<n>px"`), as the web span takes it.
    static func stylePx(_ props: AnyCodable, _ key: String) -> CGFloat? {
        guard let value = props.dictValue?["style"]?.dictValue?[key] else { return nil }
        if let n = value.doubleValue { return CGFloat(n) }
        guard let text = value.stringValue, text.hasSuffix("px"), let n = Double(text.dropLast(2).trimmingCharacters(in: .whitespaces)) else { return nil }
        return CGFloat(n)
    }

    /// The skin scene for a box of `size`: the panel's props without its children, sized in points.
    static func skin(_ props: AnyCodable, _ size: CGSize) -> AnyCodable {
        var fields = props.dictValue ?? [:]
        fields.removeValue(forKey: "children")
        var style = fields["style"]?.dictValue ?? [:]
        style["width"] = .double(Double(size.width))
        style["height"] = .double(Double(size.height))
        fields["style"] = .dict(style)
        return .dict(fields)
    }
}

@ViewBuilder
func AtlasPanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AtlasPanelAtomView(props: props, onEvent: onEvent))
}
