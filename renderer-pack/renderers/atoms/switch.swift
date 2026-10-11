import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AtomSwitchStyle: ToggleStyle {
    let theme: AlmadarTheme

    func makeBody(configuration: Configuration) -> some View {
        let track = theme.density.spacing.space6
        let thumb = theme.density.spacing.space5
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: theme.density.spacing.space2) {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    AtomKit.shape(theme, .pill, radius: track / 2)
                        .fill(configuration.isOn ? theme.color.primary : theme.color.muted)
                    AtomKit.shape(theme, .pill, radius: thumb / 2)
                        .fill(theme.color.background)
                        .frame(width: thumb, height: thumb)
                        .atomElevation(theme, .pill, radius: thumb / 2, theme.elevation.interactiveElevation)
                        .padding(theme.geometry.borderHeavy)
                }
                .frame(width: theme.density.spacing.space11, height: track)
                .animation(theme.motion.animation(for: theme.motion.transition), value: configuration.isOn)
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
    }
}

struct SwitchAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var isOn: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _isOn = State(initialValue: props.bool("checked", default: props.bool("defaultChecked")))
    }

    var body: some View {
        let incoming = props.bool("checked", default: props.bool("defaultChecked"))
        let changeEvent = props.string("onChange")
        let label = props.string("label")
        let binding = Binding<Bool>(
            get: { isOn },
            set: { newValue in
                isOn = newValue
                if !changeEvent.isEmpty {
                    onEvent(changeEvent, eventEnvelope(props, payload: ["checked": .bool(newValue)]))
                }
            }
        )
        Toggle(isOn: binding) {
            Text(label).font(AtomKit.font(theme, "sm", .medium)).foregroundColor(theme.color.foreground)
        }
        .toggleStyle(AtomSwitchStyle(theme: theme))
        .disabled(props.bool("disabled"))
        .opacity(props.bool("disabled") ? 0.5 : 1)
        .accessibilityLabel(Text(label))
        .atomId(AtomKit.controlId(name: props.string("name"), event: changeEvent, props: props))
        .onChange(of: incoming) { value in isOn = value }
    }
}

@ViewBuilder
func SwitchRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SwitchAtomView(props: props, onEvent: onEvent))
}
