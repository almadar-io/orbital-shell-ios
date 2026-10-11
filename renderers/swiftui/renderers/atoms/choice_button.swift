import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ChoiceButtonAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let selected = props.bool("selected")
        let action = props.string("action")
        let icon = props.string("icon")
        let asset = AtomKit.assetURL(props, "assetUrl")
        let index = AtomKit.scalar(props.dictValue?["index"])
        let shape = AtomKit.shape(theme, .container, radius: theme.geometry.radiusInteractive)
        Button(action: { if !action.isEmpty { onEvent(action, eventEnvelope(props, payload: props.dictValue?["payload"])) } }) {
            HStack(spacing: theme.density.spacing.space2) {
                if let index = index {
                    Text("\(index).").font(AtomKit.font(theme, "sm", .bold, mono: true)).foregroundColor(selected ? theme.color.accent : theme.color.mutedForeground)
                }
                if !asset.isEmpty {
                    AsyncImage(url: URL(string: asset)) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                        .frame(width: theme.density.spacing.space4, height: theme.density.spacing.space4)
                } else if !icon.isEmpty {
                    Image(systemName: IconMap.resolve(icon))
                }
                Text(props.string("text")).font(AtomKit.font(theme, "sm")).multilineTextAlignment(.leading)
                Spacer(minLength: theme.density.spacing.space0)
            }
            .foregroundColor(theme.color.foreground)
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.vertical, theme.density.spacing.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? theme.color.accent.opacity(0.15) : theme.color.muted.opacity(0.4))
            .clipShape(shape)
            .atomBorder(theme, .container, radius: theme.geometry.radiusInteractive, color: selected ? theme.color.accent : theme.color.border, width: theme.geometry.borderStandard)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(props.bool("disabled"))
        .opacity(props.bool("disabled") ? 0.4 : 1)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .atomAction(action, props)
    }
}

@ViewBuilder
func ChoiceButtonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ChoiceButtonAtomView(props: props, onEvent: onEvent))
}
