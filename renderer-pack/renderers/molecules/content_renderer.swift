import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ContentRendererMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    private var segments: [AtomContentSegment] {
        if let declared = props.dictValue?["segments"]?.arrayValue {
            return declared.map { AtomContentSegment(kind: $0.string("type"), language: $0.string("language"), text: $0.string("content", default: $0.string("question")), answer: $0.string("answer")) }
        }
        return AtomKit.contentSegments(props.string("content"))
    }

    var body: some View {
        let list = segments
        if !list.isEmpty {
            StackRenderer(
                props: AtomKit.child(props, [
                    "direction": "vertical",
                    "gap": "md",
                    "align": "stretch",
                    "children": .array(list.map { segment -> AnyCodable in node(segment) }),
                ]),
                modifier: nil,
                onEvent: onEvent
            )
        }
    }

    private func node(_ segment: AtomContentSegment) -> AnyCodable {
        switch segment.kind {
        case "quiz":
            return AtomKit.node("quiz-block", ["question": .string(segment.text), "answer": .string(segment.answer)])
        case "markdown":
            return AtomKit.node("markdown-content", ["content": .string(segment.text), "direction": .string(props.string("direction", default: "ltr"))])
        default:
            return AtomKit.node("code-block", ["code": .string(segment.text), "language": .string(segment.language.isEmpty ? "text" : segment.language)])
        }
    }
}

@ViewBuilder
func ContentRendererRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ContentRendererMoleculeView(props: props, onEvent: onEvent))
}
