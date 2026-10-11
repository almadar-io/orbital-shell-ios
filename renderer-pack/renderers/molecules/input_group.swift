import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct InputGroupMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    @ViewBuilder
    private func addon(_ key: String) -> some View {
        if let node = props.dictValue?[key] {
            AtomSlot(node, variant: "small", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .frame(maxHeight: .infinity)
                .background(theme.color.muted)
                .overlay(Rectangle().stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        }
    }

    var body: some View {
        var values = props.dictValue ?? [:]
        for key in ["leftAddon", "rightAddon"] { values.removeValue(forKey: key) }
        for key in ["action", "onChange"] where !props.string(key).isEmpty { values[key] = .string(props.string(key)) }
        return HStack(alignment: .bottom, spacing: theme.density.spacing.space0) {
            addon("leftAddon")
            InputRenderer(props: .dict(values), modifier: nil, onEvent: onEvent)
            addon("rightAddon")
        }
        .frame(maxWidth: .infinity)
    }
}

@ViewBuilder
func InputGroupRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(InputGroupMoleculeView(props: props, onEvent: onEvent))
}
