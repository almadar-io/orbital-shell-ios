import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct PatternTileShape: Shape {
    let variant: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side / 2
        switch variant {
        case "star6": star(&path, center, radius, points: 6)
        case "star10": star(&path, center, radius, points: 10)
        case "star12": star(&path, center, radius, points: 12)
        case "rosette-double", "rosette-filled": rosette(&path, center, radius, petals: 8)
        case "seigaiha":
            for ring in 1...4 {
                let r = radius * CGFloat(ring) / 4
                path.addArc(center: CGPoint(x: center.x, y: rect.maxY), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            }
        case "greek-key": meander(&path, rect)
        case "arch":
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: center.y))
            path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        default: star(&path, center, radius, points: 8)
        }
        return path
    }

    private func star(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat, points: Int) {
        var vertices: [CGPoint] = []
        for index in 0..<points {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(points) - .pi / 2
            vertices.append(CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
        let skip = max(points / 2 - 1, 2)
        for index in 0..<points {
            path.move(to: vertices[index])
            path.addLine(to: vertices[(index + skip) % points])
        }
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func rosette(_ path: inout Path, _ center: CGPoint, _ radius: CGFloat, petals: Int) {
        let petal = radius / 2
        for index in 0..<petals {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(petals)
            let origin = CGPoint(x: center.x + petal * cos(angle), y: center.y + petal * sin(angle))
            path.addEllipse(in: CGRect(x: origin.x - petal, y: origin.y - petal, width: petal * 2, height: petal * 2))
        }
    }

    private func meander(_ path: inout Path, _ rect: CGRect) {
        let step = rect.width / 6
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + step * 5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + step * 5, y: rect.minY + step * 4))
        path.addLine(to: CGPoint(x: rect.minX + step * 2, y: rect.minY + step * 4))
        path.addLine(to: CGPoint(x: rect.minX + step * 2, y: rect.minY + step * 2))
        path.addLine(to: CGPoint(x: rect.minX + step * 3, y: rect.minY + step * 2))
    }
}

struct PatternTileAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let side = CGFloat(props.float("size", default: 60))
        PatternTileShape(variant: props.string("variant", default: "star8"))
            .stroke(AtomKit.cssColor(theme, props.string("color", default: "primary")), style: StrokeStyle(lineWidth: CGFloat(props.float("strokeWidth", default: 0.5)), lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

@ViewBuilder
func PatternTileRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PatternTileAtomView(props: props, onEvent: onEvent))
}
