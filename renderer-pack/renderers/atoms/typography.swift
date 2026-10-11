import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct TypographyAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let variant = props.string("variant", default: props.int("level") > 0 ? "h\(props.int("level"))" : "body1")
        let spec = style(variant)
        let sizeToken = props.string("size", default: "none")
        let sizeKey = sizeToken == "none" ? spec.size : sizeToken
        let weight: Font.Weight? = AtomKit.weight(props.string("weight")) ?? spec.weight
        let alignToken = props.string("align")
        let overflow = props.string("overflow")
        let lines: Int? = props.bool("truncate") || overflow == "hidden" ? 1 : (overflow == "clamp-2" ? 2 : (overflow == "clamp-3" ? 3 : nil))
        let nested = props.children().filter { $0.dictValue != nil }
        Group {
            if nested.isEmpty {
                let raw = AtomKit.text(props, "content").isEmpty ? childText() : AtomKit.text(props, "content")
                let shown = AtomKit.formatted(raw, format: props.string("format"))
                if spec.heading {
                    AtomKit.headingText(theme, shown, sizeKey, weight: weight)
                        .lineLimit(lines)
                        .atomTextShadow(theme.typeScale.heading.shadow)
                } else {
                    Text(spec.upper ? shown.uppercased() : shown)
                        .font(AtomKit.font(theme, sizeKey, weight ?? .regular, mono: false))
                        .lineLimit(lines)
                }
            } else {
                HStack(spacing: theme.density.spacing.space1) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
            }
        }
        .foregroundColor(AtomKit.typographyColor(theme, props.string("color", default: "primary")))
        .multilineTextAlignment(alignToken == "center" ? .center : (alignToken == "right" ? .trailing : .leading))
        .frame(maxWidth: alignToken.isEmpty ? nil : .infinity, alignment: alignToken == "center" ? .center : (alignToken == "right" ? .trailing : .leading))
        .accessibilityAddTraits(spec.heading ? .isHeader : [])
    }

    private func childText() -> String {
        props.children().compactMap { AtomKit.scalar($0) }.joined()
    }

    private func style(_ variant: String) -> (size: String, weight: Font.Weight?, upper: Bool, heading: Bool) {
        switch variant {
        case "h1": return ("4xl", nil, false, true)
        case "h2": return ("3xl", nil, false, true)
        case "heading": return ("2xl", nil, false, true)
        case "h3": return ("2xl", nil, false, true)
        case "h4": return ("xl", nil, false, true)
        case "h5", "subheading": return ("lg", nil, false, true)
        case "h6": return ("base", nil, false, true)
        case "caption": return ("xs", .regular, false, false)
        case "overline": return ("xs", .bold, true, false)
        case "body2", "small": return ("sm", .regular, false, false)
        case "large": return ("lg", .medium, false, false)
        case "label": return ("sm", .medium, false, false)
        default: return ("base", .regular, false, false)
        }
    }
}

@ViewBuilder
func TypographyRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(TypographyAtomView(props: props, onEvent: onEvent))
}
