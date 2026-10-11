import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct EdgeDecorationShape: Shape {
    let variant: String
    let facingRight: Bool
    private let w: CGFloat = 200
    private let h: CGFloat = 600

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch variant {
        case "vine": vine(&path)
        case "lattice": lattice(&path)
        default: arch(&path)
        }
        return path
            .applying(CGAffineTransform(scaleX: rect.width / w, y: rect.height / h))
            .offsetBy(dx: rect.minX, dy: rect.minY)
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private func arc(_ path: inout Path, from a: CGPoint, to b: CGPoint, radius: CGFloat, large: Bool, sweep: Bool) {
        let chord = hypot(b.x - a.x, b.y - a.y)
        guard chord > 0 else { return }
        let r = max(radius, chord / 2)
        let mid = point((a.x + b.x) / 2, (a.y + b.y) / 2)
        let offset = (r * r - chord * chord / 4).squareRoot()
        let normal = point(-(b.y - a.y) / chord, (b.x - a.x) / chord)
        let signs: [CGFloat] = [1, -1]
        for sign in signs {
            let center = point(mid.x + sign * offset * normal.x, mid.y + sign * offset * normal.y)
            let start = atan2(a.y - center.y, a.x - center.x)
            var minor = atan2(b.y - center.y, b.x - center.x) - start
            while minor > .pi { minor -= 2 * .pi }
            while minor < -.pi { minor += 2 * .pi }
            let actual = large ? (minor > 0 ? minor - 2 * .pi : minor + 2 * .pi) : minor
            if (actual > 0) == sweep {
                let steps = 24
                for step in 1...steps {
                    let angle = start + actual * CGFloat(step) / CGFloat(steps)
                    path.addLine(to: point(center.x + r * cos(angle), center.y + r * sin(angle)))
                }
                return
            }
        }
    }

    private func arch(_ path: inout Path) {
        let groups = 3
        let rings = 5
        let groupH = h / CGFloat(groups)
        let edgeX = facingRight ? w : 0
        for group in 0..<groups {
            let baseY = CGFloat(group) * groupH + groupH
            let topY = CGFloat(group) * groupH + groupH * 0.05
            for ring in 0..<rings {
                let scale = 1 - CGFloat(ring) * 0.17
                let archW = w * 0.95 * scale
                let top = topY + (1 - scale) * (baseY - topY) * 0.5
                let base = baseY - (1 - scale) * groupH * 0.05
                let innerX = facingRight ? w - archW : archW
                let midY = (top + base) / 2
                let radius = (archW * archW + (base - midY) * (base - midY)).squareRoot()
                let start = point(edgeX, base)
                let through = point(innerX, top + (base - top) * 0.5)
                path.move(to: start)
                arc(&path, from: start, to: through, radius: radius, large: false, sweep: !facingRight)
                arc(&path, from: through, to: point(edgeX, top), radius: radius, large: false, sweep: !facingRight)
            }
            path.move(to: point(edgeX, baseY))
            path.addLine(to: point(facingRight ? w * 0.05 : w * 0.95, baseY))
        }
    }

    private func vine(_ path: inout Path) {
        let dir: CGFloat = facingRight ? -1 : 1
        let edgeX = facingRight ? w * 0.85 : w * 0.15
        let segments = 5
        let segH = h / CGFloat(segments)
        for index in 0..<segments {
            let y0 = CGFloat(index) * segH
            let y1 = y0 + segH
            let sway = w * 0.12 * (index % 2 == 0 ? 1 : -1)
            path.move(to: point(edgeX + sway, y0))
            path.addCurve(to: point(edgeX - sway, y1), control1: point(edgeX - sway, y0 + segH * 0.33), control2: point(edgeX + sway, y0 + segH * 0.66))
            let branchY = y0 + segH * 0.35
            let leafW = w * 0.55
            let leafH = segH * 0.35
            let tip = point(edgeX + dir * leafW, branchY - leafH * 0.2)
            path.move(to: point(edgeX, branchY))
            path.addCurve(to: tip, control1: point(edgeX + dir * leafW * 0.3, branchY - leafH), control2: point(tip.x - dir * leafW * 0.1, tip.y - leafH * 0.3))
            path.move(to: tip)
            path.addCurve(to: point(edgeX, branchY + leafH * 0.1), control1: point(tip.x - dir * leafW * 0.2, tip.y + leafH * 0.6), control2: point(edgeX + dir * leafW * 0.15, branchY + leafH * 0.4))
            let tendrilY = y0 + segH * 0.7
            let tendrilW = w * 0.35
            path.move(to: point(edgeX, tendrilY))
            path.addQuadCurve(to: point(edgeX + dir * tendrilW, tendrilY + segH * 0.05), control: point(edgeX + dir * tendrilW * 0.6, tendrilY - segH * 0.12))
            let spiral = leafW * 0.08
            path.move(to: tip)
            arc(&path, from: tip, to: point(tip.x + dir * spiral * 0.5, tip.y + spiral), radius: spiral, large: true, sweep: !facingRight)
        }
    }

    private func lattice(_ path: inout Path) {
        let columns = 5
        let cell = w / CGFloat(columns)
        let rows = Int((h / cell).rounded(.up))
        let bulge = cell * 0.3
        for row in 0..<rows {
            for column in 0..<columns {
                let cx = CGFloat(column) * cell + cell / 2
                let cy = CGFloat(row) * cell + cell / 2
                let half = cell * 0.5
                path.move(to: point(cx, cy - half))
                path.addQuadCurve(to: point(cx, cy + half), control: point(cx + bulge, cy))
                path.move(to: point(cx, cy - half))
                path.addQuadCurve(to: point(cx, cy + half), control: point(cx - bulge, cy))
                path.move(to: point(cx - half, cy))
                path.addQuadCurve(to: point(cx + half, cy), control: point(cx, cy - bulge * 0.5))
                path.move(to: point(cx - half, cy))
                path.addQuadCurve(to: point(cx + half, cy), control: point(cx, cy + bulge * 0.5))
            }
        }
    }
}

struct EdgeDecorationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let side = props.string("side", default: "both")
        let sides = side == "both" ? ["left", "right"] : [side]
        let percent = props.float("width", default: 15)
        GeometryReader { proxy in
            ZStack {
                ForEach(sides, id: \.self) { edge in
                    EdgeDecorationShape(variant: props.string("variant", default: "arch"), facingRight: edge == "right")
                        .stroke(AtomKit.cssColor(theme, props.string("color", default: "primary")), lineWidth: max(CGFloat(props.float("strokeWidth", default: 0.5)), theme.geometry.borderHairline))
                        .frame(width: proxy.size.width * CGFloat(percent) / 100, height: proxy.size.height)
                        .opacity(props.float("opacity", default: 0.15))
                        .frame(maxWidth: .infinity, alignment: edge == "right" ? .trailing : .leading)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@ViewBuilder
func EdgeDecorationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(EdgeDecorationMoleculeView(props: props, onEvent: onEvent))
}
