import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ProgressDotsMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let count = max(props.int("count"), 0)
        let current = props.int("currentIndex")
        let scale: CGFloat = props.string("size", default: "md") == "sm" ? 0.75 : (props.string("size", default: "md") == "lg" ? 1.25 : 1)
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(0..<count, id: \.self) { index in
                let active = index == current
                Circle()
                    .fill(active ? theme.color.primary : theme.color.muted)
                    .frame(width: theme.density.spacing.space2 * scale * (active ? 1.25 : 1), height: theme.density.spacing.space2 * scale * (active ? 1.25 : 1))
                    .frame(minWidth: theme.density.spacing.space3, minHeight: theme.density.spacing.space3)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Step \(index + 1) of \(count)")
                    .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ProgressDotsRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ProgressDotsMoleculeView(props: props, onEvent: onEvent))
}
