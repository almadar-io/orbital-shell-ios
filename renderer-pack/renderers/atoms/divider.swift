import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct DividerLine: Shape {
    let vertical: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if vertical {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return path
    }
}

struct DividerAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let vertical = props.string("orientation", default: "horizontal") == "vertical"
        let label = props.string("label")
        if vertical {
            line(vertical: true)
                .frame(width: theme.geometry.borderHairline)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
        } else if label.isEmpty {
            line(vertical: false)
                .frame(height: theme.geometry.borderHairline)
                .padding(.vertical, theme.density.spacing.space2)
                .accessibilityHidden(true)
        } else {
            HStack(spacing: theme.density.spacing.space3) {
                line(vertical: false).frame(height: theme.geometry.borderHairline)
                Text(label)
                    .font(AtomKit.font(theme, "sm", .bold))
                    .foregroundColor(theme.color.foreground)
                    .textCase(.uppercase)
                line(vertical: false).frame(height: theme.geometry.borderHairline)
            }
            .padding(.vertical, theme.density.spacing.space3)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func line(vertical: Bool) -> some View {
        let variant = props.string("variant", default: "solid")
        if variant == "solid" && !vertical {
            Divider().overlay(theme.color.border)
        } else {
            DividerLine(vertical: vertical)
                .stroke(theme.color.border, style: StrokeStyle(lineWidth: theme.geometry.borderHairline, lineCap: .round, dash: dash(variant)))
        }
    }

    private func dash(_ variant: String) -> [CGFloat] {
        switch variant {
        case "dashed": return [theme.density.spacing.space2, theme.density.spacing.space1]
        case "dotted": return [theme.geometry.borderHairline, theme.density.spacing.space1]
        default: return []
        }
    }
}

@ViewBuilder
func DividerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DividerAtomView(props: props, onEvent: onEvent))
}
