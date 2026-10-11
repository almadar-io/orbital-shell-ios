import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct SectionHeaderAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let align = props.string("align", default: "center")
        let level = props.int("level", default: 2)
        let subtitle = props.string("subtitle")
        let key = level == 1 ? "4xl" : (level == 3 ? "2xl" : "3xl")
        VStack(alignment: align == "center" ? .center : (align == "right" ? .trailing : .leading), spacing: theme.density.spacing.space2) {
            Text(props.string("title"))
                .font(AtomKit.font(theme, key, .bold))
                .foregroundColor(theme.color.foreground)
                .accessibilityAddTraits(.isHeader)
            if !subtitle.isEmpty {
                Text(subtitle).font(AtomKit.font(theme, "base")).foregroundColor(theme.color.mutedForeground)
            }
        }
        .multilineTextAlignment(align == "center" ? .center : (align == "right" ? .trailing : .leading))
        .frame(maxWidth: .infinity, alignment: align == "center" ? .center : (align == "right" ? .trailing : .leading))
    }
}

@ViewBuilder
func SectionHeaderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SectionHeaderAtomView(props: props, onEvent: onEvent))
}
