import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct GameMenuMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.almadarGameOverlay) private var inOverlay

    private var options: [AnyCodable] {
        if let given = props.dictValue?["options"]?.arrayValue, !given.isEmpty { return given }
        if let given = props.dictValue?["menuItems"]?.arrayValue, !given.isEmpty { return given }
        return [
            .dict(["label": "New Game", "event": "NEW_GAME", "variant": "primary"]),
            .dict(["label": "Continue", "event": "CONTINUE", "variant": "secondary"]),
            .dict(["label": "Settings", "event": "SETTINGS", "variant": "ghost"]),
        ]
    }

    var body: some View {
        let list = options
        let logo = AtomKit.assetURL(props, "logo")
        VStack(spacing: theme.density.spacing.space8) {
            VStack(spacing: theme.density.spacing.space2) {
                if !logo.isEmpty {
                    ImageRenderer(props: ["src": .string(logo), "alt": .string(props.string("title")), "fit": "contain"], modifier: nil, onEvent: onEvent)
                        .frame(height: theme.density.spacing.space12 * 2)
                }
                AtomKit.typo(props.string("title", default: "Menu"), "h1", align: "center", onEvent: onEvent)
                if !props.string("subtitle").isEmpty { AtomKit.typo(props.string("subtitle"), "body1", color: "muted", align: "center", onEvent: onEvent) }
            }
            VStack(spacing: theme.density.spacing.space4) {
                ForEach(list.indices, id: \.self) { index in
                    let option = list[index]
                    let routed = AtomKit.route(option, row: nil)
                    ChoiceButtonRenderer(
                        props: AtomKit.child(props, [
                            "text": .string(option.string("label")),
                            "index": .int(index + 1),
                            "disabled": .bool(option.bool("disabled")),
                            "action": .string(routed.event),
                            "payload": .dict((routed.payload?.dictValue ?? [:]).merging(["option": option]) { current, _ in current }),
                        ]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
        }
        .frame(maxWidth: theme.density.spacing.space12 * 9)
        .atomSurface(theme, padding: theme.density.cardPaddingLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(inOverlay ? AtomKit.clear(theme) : theme.color.background)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func GameMenuRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GameMenuMoleculeView(props: props, onEvent: onEvent))
}
