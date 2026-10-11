import Foundation
import SwiftUI

// tier: templates — CONTENT ONLY

struct GameShellTemplateView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let background = AtomKit.assetURL(props, "backgroundAsset")
        let hud = props.dictValue?["hud"]
        ZStack(alignment: .topLeading) {
            theme.color.background
            if !background.isEmpty {
                ImageRenderer(props: ["src": .string(background), "fit": "cover"], modifier: nil, onEvent: onEvent)
                    .opacity(0.18)
                    .accessibilityHidden(true)
            }
            VStack(spacing: theme.density.spacing.space0) {
                AtomChildren(props: props, key: "children", onEvent: onEvent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if props.bool("showTopBar", default: true) || hud != nil {
                HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                    if props.bool("showTopBar", default: true) {
                        AtomKit.typo(props.string("appName", default: "Game"), "label", weight: "bold", onEvent: onEvent)
                            .padding(.horizontal, theme.density.spacing.space4)
                            .padding(.vertical, theme.density.spacing.space2)
                            .background(theme.color.card)
                            .overlay(Rectangle().stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
                            .fixedSize()
                    }
                    AtomSlot(hud, onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(theme.density.spacing.space3)
            }
            VStack {
                Spacer(minLength: theme.density.spacing.space0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        AtomSlot(props.dictValue?["controls"], onEvent: onEvent)
                    }
                    Spacer(minLength: theme.density.spacing.space0)
                    VStack(alignment: .trailing, spacing: theme.density.spacing.space2) {
                        AtomSlot(props.dictValue?["addons"], onEvent: onEvent)
                    }
                }
                .padding(theme.density.spacing.space4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if props.dictValue?["overlay"] != nil {
                AtomSlot(props.dictValue?["overlay"], onEvent: onEvent)
                    .environment(\.almadarGameOverlay, true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func GameShellRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GameShellTemplateView(props: props, onEvent: onEvent))
}
