import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct AtomCheckboxStyle: ToggleStyle {
    let theme: AlmadarTheme
    let invalid: Bool

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.shape(theme, .container, radius: theme.geometry.radiusInteractive / 2)
                    .fill(configuration.isOn ? theme.color.primary : theme.color.card)
                    .frame(width: theme.density.spacing.space5, height: theme.density.spacing.space5)
                    .atomBorder(theme, .container, radius: theme.geometry.radiusInteractive / 2, color: invalid ? theme.color.error : theme.color.border, width: theme.geometry.borderStandard)
                    .overlay(
                        Image(systemName: IconMap.resolve("check"))
                            .font(AtomKit.font(theme, "xs", .bold))
                            .foregroundColor(theme.color.primaryForeground)
                            .opacity(configuration.isOn ? 1 : 0)
                    )
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(configuration.isOn ? "Checked" : "Unchecked"))
    }
}

struct CheckboxAtomView: View {
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
        let error = props.string("error")
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
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            Toggle(isOn: binding) {
                HStack(spacing: theme.density.spacing.space1) {
                    Text(label).font(AtomKit.font(theme, "sm", .medium)).foregroundColor(theme.color.foreground)
                    if props.bool("required") { Text("*").foregroundColor(theme.color.error).accessibilityHidden(true) }
                }
            }
            .toggleStyle(AtomCheckboxStyle(theme: theme, invalid: !error.isEmpty))
            .disabled(props.bool("disabled"))
            .accessibilityLabel(Text(label))
            if !error.isEmpty {
                Text(error).font(AtomKit.font(theme, "xs")).foregroundColor(theme.color.error)
            }
        }
        .opacity(props.bool("disabled") ? 0.5 : 1)
        .atomId(AtomKit.controlId(name: props.string("name"), event: changeEvent, props: props))
        .onChange(of: incoming) { value in isOn = value }
    }
}

@ViewBuilder
func CheckboxRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CheckboxAtomView(props: props, onEvent: onEvent))
}
