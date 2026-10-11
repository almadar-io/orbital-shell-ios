import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GeometricPatternMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    private let tileBase: CGFloat = 60
    private let stripBase: CGFloat = 40

    private var scale: CGFloat { CGFloat(props.float("scale", default: 1)) }
    private var tile: CGFloat { scale * tileBase }

    var body: some View {
        let mode = props.string("mode", default: "background")
        if mode == "frame" {
            VStack(spacing: theme.density.spacing.space0) {
                strip
                AtomChildren(props: props, key: "children", onEvent: onEvent)
                strip
            }
        } else {
            tiles(mode: mode)
        }
    }

    private var strip: some View {
        tiles(mode: "background").frame(height: scale * stripBase)
    }

    private var tileProps: AnyCodable {
        .dict([
            "variant": .string(props.string("variant", default: "star8")),
            "size": .double(Double(tile)),
            "color": .string(props.string("color", default: "primary")),
            "strokeWidth": .double(props.float("strokeWidth", default: 0.5)),
        ])
    }

    private func tiles(mode: String) -> some View {
        GeometryReader { proxy in
            let columns = tile > 0 ? Int((proxy.size.width / tile).rounded(.up)) : 0
            let rows = tile > 0 ? Int((proxy.size.height / tile).rounded(.up)) : 0
            ZStack(alignment: .topLeading) {
                ForEach(0..<max(rows, 0), id: \.self) { row in
                    ForEach(0..<max(columns, 0), id: \.self) { column in
                        PatternTileRenderer(props: tileProps, modifier: nil, onEvent: onEvent)
                            .offset(x: CGFloat(column) * tile, y: CGFloat(row) * tile)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .mask(fade(mode, proxy.size))
            .opacity(props.float("opacity", default: 0.06))
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func fade(_ mode: String, _ size: CGSize) -> some View {
        let solid = theme.color.foreground
        let none = AtomKit.clear(theme)
        switch mode {
        case "left":
            LinearGradient(colors: [solid, none], startPoint: .leading, endPoint: UnitPoint(x: 0.6, y: 0.5))
        case "right":
            LinearGradient(colors: [solid, none], startPoint: .trailing, endPoint: UnitPoint(x: 0.4, y: 0.5))
        case "dual":
            LinearGradient(stops: [.init(color: solid, location: 0), .init(color: none, location: 0.35), .init(color: none, location: 0.65), .init(color: solid, location: 1)], startPoint: .leading, endPoint: .trailing)
        case "around":
            RadialGradient(stops: [.init(color: none, location: 0), .init(color: none, location: 0.55), .init(color: solid, location: 0.85), .init(color: solid, location: 1)], center: .center, startRadius: theme.density.spacing.space0, endRadius: max(size.width, size.height) / 2)
        default:
            solid
        }
    }
}

@ViewBuilder
func GeometricPatternRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GeometricPatternMoleculeView(props: props, onEvent: onEvent))
}
