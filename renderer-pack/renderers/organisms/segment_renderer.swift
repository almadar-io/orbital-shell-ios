import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct SegmentRendererOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var width: CGFloat = 0

    private static let stops = "<(?:activate|connect|reflect|bloom|prq|question|answer|visualize)|\\n\\n#|\\z"
    private static let levels = "remember|understand|apply|analyze|evaluate|create"

    private static func match(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func piece(_ text: String, _ range: NSRange) -> String {
        range.location == NSNotFound ? "" : (text as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extract(_ content: String, _ name: String) -> (text: String, full: String)? {
        for pattern in ["<\(name)>([\\s\\S]*?)</\(name)>", "<\(name)>([\\s\\S]*?)(?=\(stops))"] {
            if let found = match(pattern, in: content).first {
                return (piece(content, found.range(at: 1)), (content as NSString).substring(with: found.range))
            }
        }
        return nil
    }

    private static func removeFirst(_ full: String, from content: String) -> String {
        guard let range = content.range(of: full) else { return content }
        return content.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markdownPieces(_ text: String) -> [AnyCodable] {
        let whole = text as NSString
        var out: [AnyCodable] = []
        var last = 0
        for fence in match("```([^\\n\\r]*)\\r?\\n([\\s\\S]*?)```", in: text) {
            let before = whole.substring(with: NSRange(location: last, length: fence.range.location - last))
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append(.dict(["type": "markdown", "content": .string(before)]))
            }
            let tokens = whole.substring(with: fence.range(at: 1)).split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var language = tokens.first ?? "text"
            let suffix = language.hasSuffix("-runnable")
            if suffix { language = String(language.dropLast("-runnable".count)) }
            out.append(.dict(["type": "code", "language": .string(language.isEmpty ? "text" : language), "content": .string(piece(text, fence.range(at: 2))), "runnable": .bool(suffix || tokens.contains("run"))]))
            last = fence.range.location + fence.range.length
        }
        let rest = whole.substring(from: last)
        if !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(.dict(["type": "markdown", "content": .string(rest)])) }
        return out
    }

    private static func parse(_ lesson: String) -> [AnyCodable] {
        var content = lesson.replacingOccurrences(of: "<prq>[\\s\\S]*?</prq>", with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespacesAndNewlines)
        var out: [AnyCodable] = []
        if let activate = extract(content, "activate") {
            out.append(.dict(["type": "activate", "question": .string(activate.text)]))
            content = removeFirst(activate.full, from: content)
        }
        if let connect = extract(content, "connect") {
            out.append(.dict(["type": "connect", "content": .string(connect.text)]))
            content = removeFirst(connect.full, from: content)
        }
        let tags = [
            "(<reflect>([\\s\\S]*?)</reflect>)",
            "(<reflect>([\\s\\S]*?)(?=\(stops)))",
            "(<bloom\\s+level=\"(\(levels))\">([\\s\\S]*?)</bloom>)",
            "(<bloom\\s+level=\"(\(levels))\">([\\s\\S]*?)(?=\(stops)))",
            "(<question>([\\s\\S]*?)</question>\\s*<answer>([\\s\\S]*?)</answer>)",
            "(<visualize\\s+type=\"(?:algorithms|math|physics|biology|chemistry|probability)\"\\s+description=\"[^\"]*?\"\\s*/?>)",
        ].joined(separator: "|")
        let whole = content as NSString
        var last = 0
        for found in match(tags, in: content) {
            let before = whole.substring(with: NSRange(location: last, length: found.range.location - last))
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(contentsOf: markdownPieces(before)) }
            if found.range(at: 1).location != NSNotFound || found.range(at: 3).location != NSNotFound {
                let prompt = piece(content, found.range(at: 2).location != NSNotFound ? found.range(at: 2) : found.range(at: 4))
                if !prompt.isEmpty { out.append(.dict(["type": "reflect", "prompt": .string(prompt)])) }
            } else if found.range(at: 5).location != NSNotFound || found.range(at: 8).location != NSNotFound {
                let closed = found.range(at: 5).location != NSNotFound
                let level = piece(content, found.range(at: closed ? 6 : 9)).lowercased()
                let body = piece(content, found.range(at: closed ? 7 : 10))
                if !body.isEmpty { out.append(bloom(level, body)) }
            } else if found.range(at: 11).location != NSNotFound {
                out.append(.dict(["type": "quiz", "question": .string(piece(content, found.range(at: 12))), "answer": .string(piece(content, found.range(at: 13)))]))
            }
            last = found.range.location + found.range.length
        }
        let rest = whole.substring(from: last)
        if !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(contentsOf: markdownPieces(rest)) }
        return out
    }

    private static func bloom(_ level: String, _ body: String) -> AnyCodable {
        let question = match("<question>([\\s\\S]*?)</question>", in: body).first.map { piece(body, $0.range(at: 1)) }
        let answer = match("<answer>([\\s\\S]*?)</answer>", in: body).first.map { piece(body, $0.range(at: 1)) }
        if let question = question {
            return .dict(["type": "bloom", "level": .string(level), "question": .string(question), "answer": .string(answer ?? "(Answer not provided)")])
        }
        let cleaned = body
            .replacingOccurrences(of: "^\\*\\*Question\\s*\\d*:?\\*\\*\\s*", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "^\\*\\*Q\\d*:?\\*\\*\\s*", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .dict(["type": "bloom", "level": .string(level), "question": .string(cleaned), "answer": "(See answers section below)"])
    }

    private var segments: [AnyCodable] {
        if let lesson = props.dictValue?["lesson"]?.stringValue { return Self.parse(lesson) }
        return props.dictValue?["segments"]?.arrayValue ?? []
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
