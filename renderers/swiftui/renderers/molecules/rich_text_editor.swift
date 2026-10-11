import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct RichTextEditorMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var text: String
    @State private var pending: Task<Void, Never>?

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _text = State(initialValue: props.string("value"))
    }

    private static let tools: [(icon: String, label: String, snippet: String)] = [
        ("heading-1", "Heading 1", "<h1></h1>"),
        ("heading-2", "Heading 2", "<h2></h2>"),
        ("heading-3", "Heading 3", "<h3></h3>"),
        ("bold", "Bold", "<strong></strong>"),
        ("italic", "Italic", "<em></em>"),
        ("underline", "Underline", "<u></u>"),
        ("strikethrough", "Strikethrough", "<s></s>"),
        ("code", "Code", "<code></code>"),
        ("list", "Bulleted list", "<ul><li></li></ul>"),
        ("list-ordered", "Numbered list", "<ol><li></li></ol>"),
        ("quote", "Quote", "<blockquote></blockquote>"),
        ("minus", "Divider", "<hr>"),
        ("link", "Link", "<a href=\"\"></a>"),
        ("image", "Image", "<img src=\"\" alt=\"\">"),
    ]

    private func schedule() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            let event = props.string("changeEvent")
            if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["value": .string(text)])) }
        }
    }

    var body: some View {
        let changeEvent = props.string("changeEvent")
        if props.bool("readOnly") {
            AtomKit.typo(AtomKit.plainHTML(text), "body1", onEvent: onEvent)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                if props.bool("showToolbar", default: true) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.density.spacing.space1) {
                            ForEach(RichTextEditorMoleculeView.tools.indices, id: \.self) { index in
                                let tool = RichTextEditorMoleculeView.tools[index]
                                ButtonRenderer(
                                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": .string(tool.icon), "aria-label": .string(tool.label), "action": .string(AtomKit.localEvent), "local": true]),
                                    modifier: nil,
                                    onEvent: { _, _ in
                                        text += tool.snippet
                                        schedule()
                                    }
                                )
                            }
                        }
                    }
                }
                TextareaRenderer(
                    props: AtomKit.child(props, [
                        "value": .string(text),
                        "placeholder": .string(props.string("placeholder")),
                        "onChange": .string(AtomKit.eventOrLocal(changeEvent)),
                        "local": .bool(changeEvent.isEmpty),
                    ]),
                    modifier: nil,
                    onEvent: { _, envelope in
                        if let next = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue {
                            text = next
                            schedule()
                        }
                    }
                )
            }
            .onChange(of: props.string("value")) { next in text = next }
        }
    }
}

@ViewBuilder
func RichTextEditorRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(RichTextEditorMoleculeView(props: props, onEvent: onEvent))
}
