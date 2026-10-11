import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ButtonAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        let variant = props.string("variant", default: "primary")
        let size = props.string("size", default: "md")
        let loading = props.bool("isLoading")
        let action = props.string("action")
        let label = AtomKit.text(props, "label").isEmpty ? props.children().compactMap { AtomKit.scalar($0) }.joined() : AtomKit.text(props, "label")
        let leading = props.string("leftIcon", default: props.string("icon"))
        let trailing = props.string("rightIcon", default: props.string("iconRight"))
        let spinnerTint = AtomKit.buttonTone(theme, variant, pressed: false).foreground
        Button(action: activate) {
            ZStack {
                HStack(spacing: theme.density.spacing.space2) {
                    if !leading.isEmpty { Image(systemName: IconMap.resolve(leading)) }
                    if !label.isEmpty { Text(label) }
                    if !trailing.isEmpty { Image(systemName: IconMap.resolve(trailing)) }
                }
                .opacity(loading ? 0 : 1)
                if loading {
                    ProgressView().tint(spinnerTint)
                }
            }
        }
        .buttonStyle(AtomButtonStyle(theme: theme, variant: variant, size: size))
        .disabled(props.bool("disabled") || loading)
        .accessibilityLabel(Text(props.string("aria-label", default: label)))
        .accessibilityAddTraits(loading ? .updatesFrequently : [])
        .atomAction(action, props)
    }

    private func activate() {
        let href = props.string("href")
        let action = props.string("action")
        if !action.isEmpty { onEvent(action, eventEnvelope(props)) }
        if href.isEmpty || href.hasPrefix("#") { return }
        if AtomKit.isAbsoluteHref(href) {
            if let url = URL(string: href) { openURL(url) }
        } else {
            onEvent(AtomKit.navigateEvent, eventEnvelope(.dict([:]), payload: .dict(["url": .string(href)])))
        }
    }
}

@ViewBuilder
func ButtonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ButtonAtomView(props: props, onEvent: onEvent))
}
