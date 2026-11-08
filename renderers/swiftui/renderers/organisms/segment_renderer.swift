import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct SegmentRendererOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var width: CGFloat = 0

    private var segments: [AnyCodable] {
        props.dictValue?["segments"]?.arrayValue ?? []
    }

    private func event(_ key: String) -> [String: AnyCodable] {
        let name = props.string(key)
        return name.isEmpty ? [:] : [fallbackKey(key): .string(name)]
    }

    private func fallbackKey(_ key: String) -> String {
        switch key {
        case "activationSaveEvent", "reflectionSaveEvent": return "saveEvent"
        case "bloomAnswerEvent": return "answerEvent"
        default: return key
        }
    }

    private func nodes(_ list: [AnyCodable]) -> [AnyCodable] {
        let progress = props.dictValue?["userProgress"]
        let annotations = props.dictValue?["annotations"]?.arrayValue ?? []
        var owners: [Int: [AnyCodable]] = [:]
        for annotation in annotations {
            let text = annotation.string("text")
            if let at = list.firstIndex(where: { $0.string("type") == "markdown" && $0.string("content").contains(text) }) {
                owners[at, default: []].append(annotation)
            }
        }
        var reflectIndex = 0
        var bloomIndex = 0
        var out: [AnyCodable] = []
        for (index, segment) in list.enumerated() {
            switch segment.string("type") {
            case "markdown":
                var values: [String: AnyCodable] = ["content": .string(segment.string("content"))]
                if let owned = owners[index] { values["annotations"] = .array(owned) }
                for key in ["annotationEvent", "askEvent", "noteEvent", "askLabel", "noteLabel"] where !props.string(key).isEmpty { values[key] = .string(props.string(key)) }
                out.append(AtomKit.node(props, "markdown-content", values))
            case "code":
                let language = segment.string("language", default: "text")
                if segment.bool("runnable") && !props.string("runCodeEvent").isEmpty {
                    let runId = String(index)
                    var values: [String: AnyCodable] = [
                        "code": .string(segment.string("content")), "language": .string(language), "runnable": true,
                        "runEvent": .string(props.string("runCodeEvent")), "runId": .string(runId), "running": .bool(props.string("runningCode") == runId),
                    ]
                    if !props.string("resetCodeEvent").isEmpty { values["resetEvent"] = .string(props.string("resetCodeEvent")) }
                    if let output = props.dictValue?["codeOutputs"]?.dictValue?[runId] { values["output"] = output }
                    out.append(AtomKit.node(props, "code-runner-panel", values))
                } else {
                    out.append(AtomKit.node(props, "code-block", ["code": .string(segment.string("content")), "language": .string(language)]))
                }
            case "quiz":
                out.append(AtomKit.node(props, "quiz-block", ["question": .string(segment.string("question")), "answer": .string(segment.string("answer"))]))
            case "activate":
                var values: [String: AnyCodable] = ["question": .string(segment.string("question"))]
                if let saved = progress?.dictValue?["activationResponse"] { values["savedResponse"] = saved }
                values.merge(event("activationSaveEvent")) { current, _ in current }
                out.append(AtomKit.node(props, "activation-block", values))
            case "connect":
                out.append(AtomKit.node(props, "connection-block", ["content": .string(segment.string("content"))]))
            case "reflect":
                var values: [String: AnyCodable] = ["prompt": .string(segment.string("prompt")), "index": .int(reflectIndex)]
                if let note = progress?.dictValue?["reflectionNotes"]?.arrayValue, reflectIndex < note.count { values["savedNote"] = note[reflectIndex] }
                values.merge(event("reflectionSaveEvent")) { current, _ in current }
                reflectIndex += 1
                out.append(AtomKit.node(props, "reflection-block", values))
            case "bloom":
                var values: [String: AnyCodable] = [
                    "level": .string(segment.string("level")),
                    "question": .string(segment.string("question")),
                    "answer": .string(segment.string("answer")),
                    "index": .int(bloomIndex),
                ]
                if let answered = progress?.dictValue?["bloomAnswered"]?.dictValue?[String(bloomIndex)] { values["isAnswered"] = answered }
                values.merge(event("bloomAnswerEvent")) { current, _ in current }
                bloomIndex += 1
                out.append(AtomKit.node(props, "bloom-quiz-block", values))
            default:
                continue
            }
        }
        return out
    }

    @ViewBuilder
    private func segment(_ node: AnyCodable) -> some View {
        if node.string("type") == "code-block", node.string("language") == "mermaid", let diagram = AtomKit.mermaid(node.string("code"), onEvent: onEvent) {
            diagram
        } else {
            RenderChild(node, onEvent: onEvent)
        }
    }

    var body: some View {
        let list = nodes(segments)
        let shape = AtomKit.shape(theme, .container)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: AtomKit.space(theme, "lg")) {
                ForEach(list.indices, id: \.self) { index in
                    segment(list[index]).frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(width >= AlmadarBreakpoints.md ? theme.density.spacing.space4 : theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            .background(GeometryReader { proxy in
                AtomKit.clear(theme).onAppear { width = proxy.size.width }.onChange(of: proxy.size.width) { next in width = next }
            })
            .accessibilityElement(children: .contain)
        }
    }
}

@ViewBuilder
func SegmentRendererRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SegmentRendererOrganismView(props: props, onEvent: onEvent))
}
