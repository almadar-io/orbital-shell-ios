import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct InputAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        let inputType = props.string("inputType", default: "text")
        switch inputType {
        case "select":
            SelectRenderer(props: props, modifier: nil, onEvent: onEvent)
        case "checkbox":
            CheckboxRenderer(props: props, modifier: nil, onEvent: onEvent)
        case "textarea":
            TextareaRenderer(props: props, modifier: nil, onEvent: onEvent)
        case "date", "datetime-local", "time":
            DateEntry(props: props, onEvent: onEvent, inputType: inputType)
        default:
            AtomTextEntry(props: props, onEvent: onEvent, multiline: false, changeEvent: props.string("onChange"), submitEvent: props.string("action"))
        }
    }
}

struct DateEntry: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    let inputType: String
    @Environment(\.almadarTheme) private var theme
    @State private var date: Date

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void, inputType: String) {
        self.props = props
        self.onEvent = onEvent
        self.inputType = inputType
        _date = State(initialValue: DateEntry.parse(AtomKit.text(props, "value"), inputType: inputType) ?? Date())
    }

    var body: some View {
        let changeEvent = props.string("onChange")
        let binding = Binding<Date>(
            get: { date },
            set: { newValue in
                date = newValue
                if !changeEvent.isEmpty {
                    onEvent(changeEvent, eventEnvelope(props, payload: ["value": .string(DateEntry.formatter(inputType).string(from: newValue))]))
                }
            }
        )
        AtomFieldFrame(theme: theme, label: props.string("label"), helper: props.string("helperText"), error: props.string("error"), isRequired: props.bool("required")) {
            DatePicker(props.string("label", default: props.string("placeholder")), selection: binding, displayedComponents: components)
                .labelsHidden()
                .tint(theme.color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .atomFieldBox(theme, error: !props.string("error").isEmpty, disabled: props.bool("disabled"))
                .disabled(props.bool("disabled"))
        }
        .atomId(AtomKit.controlId(name: props.string("name"), event: changeEvent, props: props))
    }

    private var components: DatePickerComponents {
        switch inputType {
        case "time": return .hourAndMinute
        case "datetime-local": return [.date, .hourAndMinute]
        default: return .date
        }
    }

    private static func formatter(_ inputType: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        switch inputType {
        case "time": formatter.dateFormat = "HH:mm"
        case "datetime-local": formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        default: formatter.dateFormat = "yyyy-MM-dd"
        }
        return formatter
    }

    private static func parse(_ raw: String, inputType: String) -> Date? {
        formatter(inputType).date(from: raw)
    }
}

@ViewBuilder
func InputRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(InputAtomView(props: props, onEvent: onEvent))
}
