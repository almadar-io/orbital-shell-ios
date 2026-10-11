import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AvlGlyphShape: Shape {
    let kind: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let corner = CGSize(width: min(rect.width, rect.height) * 0.2, height: min(rect.width, rect.height) * 0.2)
        switch kind {
        case "application":
            path.addRoundedRect(in: rect, cornerSize: corner)
            path.addRoundedRect(in: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.18), cornerSize: corner)
        case "orbital":
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.addEllipse(in: rect.insetBy(dx: 0, dy: radius * 0.55))
        case "entity":
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.addEllipse(in: CGRect(x: center.x - radius * 0.45, y: center.y - radius * 0.45, width: radius * 0.9, height: radius * 0.9))
        case "trait":
            path.addEllipse(in: rect)
        case "page":
            let fold = min(rect.width, rect.height) * 0.3
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        case "state":
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.height / 2, height: rect.height / 2))
        case "transition", "binding":
            let head = min(rect.width, rect.height) * 0.3
            path.move(to: CGPoint(x: rect.minX, y: center.y))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.move(to: CGPoint(x: rect.maxX - head, y: center.y - head))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.addLine(to: CGPoint(x: rect.maxX - head, y: center.y + head))
        case "event":
            path.move(to: CGPoint(x: rect.midX + rect.width * 0.1, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY + rect.height * 0.08))
            path.addLine(to: CGPoint(x: center.x, y: rect.midY + rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.1, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY - rect.height * 0.08))
            path.addLine(to: CGPoint(x: center.x, y: rect.midY - rect.height * 0.08))
            path.closeSubpath()
        case "guard":
            path.move(to: CGPoint(x: center.x, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: center.y))
            path.closeSubpath()
        case "effect":
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case "field":
            path.move(to: CGPoint(x: rect.minX + radius * 0.3, y: center.y))
            path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
            path.addEllipse(in: CGRect(x: rect.minX, y: center.y - radius * 0.3, width: radius * 0.6, height: radius * 0.6))
        case "fieldType":
            for point in 0..<6 {
                let angle = CGFloat(point) * .pi / 3
                let vertex = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
            }
            path.closeSubpath()
        case "persistence":
            let cap = rect.height * 0.25
            path.addEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: cap))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + cap / 2))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cap / 2))
            path.addArc(center: CGPoint(x: center.x, y: rect.maxY - cap / 2), radius: rect.width / 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cap / 2))
        case "sexpr":
            path.addRoundedRect(in: rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.12), cornerSize: corner)
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.maxY), control: CGPoint(x: rect.minX - rect.width * 0.02, y: center.y))
            path.move(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY), control: CGPoint(x: rect.maxX + rect.width * 0.02, y: center.y))
        case "bindingRef", "literal":
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.height * 0.3, height: rect.height * 0.3))
        default:
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

struct AvlGlyphMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var kind: String { props.string("kind") }
    private var caption: String { props.string("label", default: kind.capitalized) }

    var body: some View {
        let height = glyphHeight
        VStack(spacing: theme.density.spacing.space1) {
            ZStack {
                AvlGlyphShape(kind: kind)
                    .stroke(tone, style: StrokeStyle(lineWidth: theme.geometry.borderHeavy, lineCap: .round, lineJoin: .round, dash: kind == "binding" ? [theme.density.spacing.space1] : []))
                    .padding(theme.density.spacing.space1)
                if ["bindingRef", "operator", "literal"].contains(kind) {
                    AtomKit.typo(props.string("label", default: kind == "operator" ? "+" : (kind == "literal" ? "42" : "entity.id")), "caption", truncate: true, onEvent: onEvent)
                }
            }
            .frame(width: height * aspect, height: height)
            if props.bool("showCaption", default: true) {
                AtomKit.typo(caption, "caption", color: "muted", onEvent: onEvent)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
    }

    private var glyphHeight: CGFloat {
        switch props.string("size", default: "md") {
        case "sm": return theme.density.spacing.space8
        case "lg": return AlmadarSizes.w20 + theme.density.spacing.space2
        default: return AlmadarSizes.w14
        }
    }

    private var aspect: CGFloat {
        switch kind {
        case "application", "sexpr": return 1.6
        case "state", "trait": return 2.4
        case "transition", "binding", "field": return 2.6
        case "bindingRef", "operator", "literal": return 1.8
        default: return 1
        }
    }

    private var tone: Color {
        switch kind {
        case "guard": return theme.color.warning
        case "event", "effect": return theme.color.accent
        case "entity", "orbital", "application": return theme.color.primary
        case "persistence", "fieldType": return theme.color.info
        default: return theme.color.foreground
        }
    }
}

@ViewBuilder
func AvlGlyphRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AvlGlyphMoleculeView(props: props, onEvent: onEvent))
}
