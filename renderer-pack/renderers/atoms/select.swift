import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct SelectAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var chosen: [String]

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _chosen = State(initialValue: SelectAtomView.values(props))
    }

    var body: some View {
        let incoming = SelectAtomView.values(props)
        let multiple = props.bool("multiple")
        let flat = flatOptions()
        let error = props.string("error")
        let disabled = props.bool("disabled")
        let summary: String = {
            let labels = chosen.compactMap { value in flat.first(where: { $0.value == value })?.label }
            return labels.isEmpty ? props.string("placeholder") : labels.joined(separator: ", ")
        }()
        AtomFieldFrame(theme: theme, label: props.string("label"), helper: props.string("helperText"), error: error, isRequired: props.bool("required")) {
            Menu {
                if props.bool("clearable") && !chosen.isEmpty {
                    Button(action: { commit([]) }) { Label("Clear", systemImage: IconMap.resolve("x")) }
                }
                menuItems(multiple: multiple)
            } label: {
                HStack(spacing: theme.density.spacing.space2) {
                    Text(summary)
                        .font(AtomKit.font(theme, "sm"))
                        .foregroundColor(chosen.isEmpty ? theme.color.placeholder : theme.color.foreground)
                        .lineLimit(1)
                    Spacer(minLength: theme.density.spacing.space2)
                    Image(systemName: IconMap.resolve("chevrons-up-down")).foregroundColor(theme.color.mutedForeground)
                }
                .atomFieldBox(theme, error: !error.isEmpty, disabled: disabled, elevated: true)
            }
            .disabled(disabled)
            .accessibilityLabel(Text(props.string("label", default: props.string("placeholder"))))
            .accessibilityValue(Text(summary))
        }
        .atomId(AtomKit.controlId(name: props.string("name"), event: props.string("action", default: props.string("onChange", default: props.string("onValueChange"))), props: props))
        .onChange(of: incoming) { value in chosen = value }
    }

    @ViewBuilder
    private func menuItems(multiple: Bool) -> some View {
        let groups = props.dictValue?["groups"]?.arrayValue ?? []
        if groups.isEmpty {
            ForEach(AtomKit.options(props.dictValue?["options"]?.arrayValue ?? []), id: \.value) { option in
                item(option, multiple: multiple)
            }
        } else {
            ForEach(groups.indices, id: \.self) { index in
                let group = groups[index].dictValue ?? [:]
                Section(AtomKit.scalar(group["label"]) ?? "") {
                    ForEach(AtomKit.options(group["options"]?.arrayValue ?? []), id: \.value) { option in
                        item(option, multiple: multiple)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func item(_ option: (value: String, label: String), multiple: Bool) -> some View {
        let isChosen = chosen.contains(option.value)
        Button(action: { toggle(option.value, multiple: multiple) }) {
            if isChosen {
                Label(option.label, systemImage: IconMap.resolve("check"))
            } else {
                Text(option.label)
            }
        }
    }

    private func flatOptions() -> [(value: String, label: String)] {
        let loose = AtomKit.options(props.dictValue?["options"]?.arrayValue ?? [])
        let grouped = (props.dictValue?["groups"]?.arrayValue ?? []).flatMap { AtomKit.options($0.dictValue?["options"]?.arrayValue ?? []) }
        return loose + grouped
    }

    private func toggle(_ value: String, multiple: Bool) {
        if multiple {
            commit(chosen.contains(value) ? chosen.filter { $0 != value } : chosen + [value])
        } else {
            commit([value])
        }
    }

    private func commit(_ next: [String]) {
        chosen = next
        let payload: AnyCodable = props.bool("multiple") ? ["value": .array(next.map { AnyCodable.string($0) })] : ["value": .string(next.first ?? "")]
        var emitted = Set<String>()
        for key in ["action", "onChange", "onValueChange"] {
            let event = props.string(key)
            if !event.isEmpty && !emitted.contains(event) {
                emitted.insert(event)
                onEvent(event, eventEnvelope(props, payload: payload))
            }
        }
    }

    private static func values(_ props: AnyCodable) -> [String] {
        guard let raw = props.dictValue?["value"] else { return [] }
        if let list = raw.arrayValue { return list.compactMap { AtomKit.scalar($0) } }
        guard let single = AtomKit.scalar(raw), !single.isEmpty else { return [] }
        return [single]
    }
}

@ViewBuilder
func SelectRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SelectAtomView(props: props, onEvent: onEvent))
}
