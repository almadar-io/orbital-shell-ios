import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct ToastSlotOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func dismiss() {
        let dismissKey = "DISMISS"
        let closeKey = "CLOSE"
        onEvent(dismissKey, eventEnvelope(props))
        onEvent(closeKey, eventEnvelope(props))
    }

    var body: some View {
        let dismissKey = "DISMISS"
        if let first = props.children().first {
            let message = first.stringValue ?? first.string("message")
            if message.isEmpty && first.dictValue != nil {
                RenderChild(first, onEvent: onEvent)
            } else {
                NotificationRenderer(
                    props: AtomKit.child(props, [
                        "message": .string(message),
                        "variant": .string(props.string("variant", default: first.string("variant", default: "info"))),
                        "title": .string(props.string("title", default: first.string("title"))),
                        "duration": .double(props.float("duration", default: 5000)),
                        "dismissEvent": .string(dismissKey),
                    ]),
                    modifier: nil,
                    onEvent: { _, _ in dismiss() }
                )
            }
        }
    }
}

@ViewBuilder
func ToastSlotRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ToastSlotOrganismView(props: props, onEvent: onEvent))
}
