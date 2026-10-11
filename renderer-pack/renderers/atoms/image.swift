import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ImageAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        if AtomKit.assetURL(props, "src").isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let src = AtomKit.assetURL(props, "src")
        let alt = props.string("alt")
        let fit = props.string("fit", default: "cover")
        let roundedToken = props.string("rounded", default: "md")
        let role: AtomRole = roundedToken == "full" ? .pill : .container
        let radius = AtomKit.radius(theme, roundedToken)
        let shape = AtomKit.shape(theme, role, radius: radius)
        AsyncImage(url: URL(string: src)) { phase in
            if let image = phase.image {
                switch fit {
                case "contain", "scale-down": image.resizable().aspectRatio(contentMode: .fit)
                case "fill": image.resizable()
                case "none": image
                default: image.resizable().aspectRatio(contentMode: .fill)
                }
            } else if phase.error != nil {
                theme.color.muted.overlay(Image(systemName: IconMap.resolve("image")).foregroundColor(theme.color.mutedForeground))
            } else {
                theme.color.muted.overlay(ProgressView().tint(theme.color.mutedForeground))
            }
        }
        .aspectRatio(ratio(props.string("aspect", default: "auto")), contentMode: .fit)
        .clipShape(shape)
        .atomBorder(theme, role, radius: radius, color: props.bool("bordered") ? theme.color.border : AtomKit.clear(theme), width: theme.geometry.borderStandard)
        .accessibilityLabel(Text(alt))
        .accessibilityHidden(alt.isEmpty)
    }

    private func ratio(_ token: String) -> CGFloat? {
        switch token {
        case "1/1": return 1
        case "4/3": return 4.0 / 3.0
        case "3/2": return 3.0 / 2.0
        case "16/9": return 16.0 / 9.0
        case "21/9": return 21.0 / 9.0
        default: return nil
        }
    }
}

@ViewBuilder
func ImageRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ImageAtomView(props: props, onEvent: onEvent))
}
