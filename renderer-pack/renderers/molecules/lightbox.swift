import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct LightboxMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var index: Int

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _index = State(initialValue: props.int("currentIndex"))
    }

    var body: some View {
        let images = props.dictValue?["images"]?.arrayValue ?? []
        if props.bool("isOpen") && !images.isEmpty {
            let current = min(max(index, 0), images.count - 1)
            let image = images[current]
            ZStack {
                theme.color.scrim
                ImageRenderer(
                    props: ["src": .string(image.stringValue ?? AtomKit.assetURL(image, "src")), "alt": .string(image.string("alt")), "fit": "contain"],
                    modifier: nil,
                    onEvent: onEvent
                )
                .padding(theme.density.spacing.space12)
                HStack {
                    if current > 0 { step(current - 1, icon: "chevron-left", label: "Previous image") }
                    Spacer(minLength: theme.density.spacing.space0)
                    if current < images.count - 1 { step(current + 1, icon: "chevron-right", label: "Next image") }
                }
                .padding(theme.density.spacing.space4)
                VStack {
                    HStack {
                        Spacer(minLength: theme.density.spacing.space0)
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "icon": "x", "aria-label": "Close", "action": .string(props.string("closeAction"))]),
                            modifier: nil,
                            onEvent: onEvent
                        )
                    }
                    Spacer(minLength: theme.density.spacing.space0)
                    VStack(spacing: theme.density.spacing.space1) {
                        if !image.string("caption").isEmpty { AtomKit.typo(image.string("caption"), "small", align: "center", onEvent: onEvent) }
                        if props.bool("showCounter", default: true) { AtomKit.typo("\(current + 1) / \(images.count)", "caption", color: "muted", align: "center", onEvent: onEvent) }
                    }
                }
                .padding(theme.density.spacing.space4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func step(_ target: Int, icon: String, label: String) -> some View {
        ButtonRenderer(
            props: ["variant": "secondary", "size": "sm", "icon": .string(icon), "aria-label": .string(label), "action": "lightbox-step", "local": true],
            modifier: nil,
            onEvent: { _, _ in index = target }
        )
    }
}

@ViewBuilder
func LightboxRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LightboxMoleculeView(props: props, onEvent: onEvent))
}
