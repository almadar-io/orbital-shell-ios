import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct RadioAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var selected: String

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _selected = State(initialValue: AtomKit.text(props, "value"))
    }

    var body: some View {
        let incoming = AtomKit.text(props, "value")
        let choices = AtomKit.strings(props, "options")
        let action = props.string("action")
        let error = props.string("error")
        let helper = props.string("helperText")
        let label = props.string("label")
        let rows: [String] = choices.isEmpty ? [props.string("value", default: label)] : choices
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if !choices.isEmpty && !label.isEmpty {
                Text(label).font(AtomKit.font(theme, "sm", .medium)).foregroundColor(theme.color.foreground)
            }
            ForEach(rows.indices, id: \.self) { index in
                let option = rows[index]
                let isSelected = choices.isEmpty ? props.bool("checked") || selected == option : selected == option
                Button(action: { choose(option, action: action) }) {
                    HStack(spacing: theme.density.spacing.space3) {
                        Circle()
                            .stroke(!error.isEmpty ? theme.color.error : (isSelected ? theme.color.primary : theme.color.border), lineWidth: theme.geometry.borderStandard)
                            .frame(width: side, height: side)
                            .overlay(
                                Circle()
                                    .fill(!error.isEmpty ? theme.color.error : theme.color.primary)
                                    .frame(width: side / 2, height: side / 2)
                                    .opacity(isSelected ? 1 : 0)
                            )
                        Text(choices.isEmpty ? label : option)
                            .font(AtomKit.font(theme, "sm", .medium))
                            .foregroundColor(!error.isEmpty ? theme.color.error : theme.color.foreground)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
            if !error.isEmpty {
                Text(error).font(AtomKit.font(theme, "xs", .medium)).foregroundColor(theme.color.error)
            } else if !helper.isEmpty {
                Text(helper).font(AtomKit.font(theme, "xs")).foregroundColor(theme.color.mutedForeground)
            }
        }
        .disabled(props.bool("disabled"))
        .opacity(props.bool("disabled") ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .atomId(AtomKit.controlId(name: props.string("name"), event: action, props: props))
        .onChange(of: incoming) { value in selected = value }
    }

    private var side: CGFloat {
        switch props.string("size", default: "md") {
        case "sm": return theme.density.spacing.space4
        case "lg": return theme.density.spacing.space6
        default: return theme.density.spacing.space5
        }
    }

    private func choose(_ option: String, action: String) {
        selected = option
        if !action.isEmpty {
            onEvent(action, eventEnvelope(props, payload: ["value": .string(option)]))
        }
    }
}

@ViewBuilder
func RadioRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RadioAtomView(props: props, onEvent: onEvent))
}
