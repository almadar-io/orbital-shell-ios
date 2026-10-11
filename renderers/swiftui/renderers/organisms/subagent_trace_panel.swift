import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

enum AtomTrace {
    static let activityLabels: [String: String] = [
        "tool_call": "tool call", "tool_result": "tool result", "message": "message", "error": "error",
        "file_operation": "file operation", "schema_diff": "schema diff", "milestone": "milestone", "analysis": "analysis",
        "cancelled": "cancelled", "clarification_question": "clarification question", "coordinator_decision": "coordinator decision",
        "done": "done", "llm_response": "model response", "orbital_done": "orbital done", "orbital_started": "orbital started",
        "pending_question": "pending question", "plan_committed": "plan committed", "schema_change": "schema change",
    ]

    static let fileOperations: [String: String] = ["ls": "list", "read_file": "read", "write_file": "write", "edit_file": "edit"]

    static func time(_ timestamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp / 1000))
    }

    static func quote(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return (try? encoder.encode(text)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }

    static func json(_ value: AnyCodable, pretty: Bool, depth: Int = 0) -> String {
        let inner = pretty ? "\n" + String(repeating: "  ", count: depth + 1) : ""
        let outer = pretty ? "\n" + String(repeating: "  ", count: depth) : ""
        let colon = pretty ? ": " : ":"
        switch value {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .int(let number): return String(number)
        case .double(let number): return number.isFinite && number == number.rounded() && abs(number) < 1e15 ? String(Int(number)) : String(number)
        case .string(let text): return quote(text)
        case .array(let list):
            if list.isEmpty { return "[]" }
            return "[" + inner + list.map { json($0, pretty: pretty, depth: depth + 1) }.joined(separator: "," + inner) + outer + "]"
        case .dict(let map):
            if map.isEmpty { return "{}" }
            let entries = map.sorted { $0.key < $1.key }.map { quote($0.key) + colon + json($0.value, pretty: pretty, depth: depth + 1) }
            return "{" + inner + entries.joined(separator: "," + inner) + outer + "}"
        }
    }

    static func prettyJSON(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else { return nil }
        let chars = Array(raw)
        var out = ""
        var depth = 0
        var inString = false
        var escaped = false
        var index = 0
        func newline() { out += "\n" + String(repeating: "  ", count: depth) }
        while index < chars.count {
            let char = chars[index]
            if inString {
                out.append(char)
                if escaped { escaped = false } else if char == "\\" { escaped = true } else if char == "\"" { inString = false }
                index += 1
                continue
            }
            switch char {
            case "\"":
                inString = true
                out.append(char)
            case " ", "\n", "\r", "\t":
                break
            case "{", "[":
                var next = index + 1
                while next < chars.count, chars[next].isWhitespace { next += 1 }
                if next < chars.count, chars[next] == (char == "{" ? "}" : "]") {
                    out.append(char)
                    out.append(chars[next])
                    index = next
                } else {
                    out.append(char)
                    depth += 1
                    newline()
                }
            case "}", "]":
                depth -= 1
                newline()
                out.append(char)
            case ",":
                out.append(char)
                newline()
            case ":":
                out += ": "
            default:
                out.append(char)
            }
            index += 1
        }
        return out
    }

    static func preview(_ text: String, _ limit: Int = 120) -> String {
        text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }

    static func summarize(_ args: AnyCodable?) -> String {
        let keys = (args?.dictValue ?? [:]).keys.sorted()
        if keys.isEmpty { return "" }
        return keys.prefix(3).joined(separator: ", ") + (keys.count > 3 ? ", …" : "")
    }

    static func compact(_ value: AnyCodable) -> String {
        let text = json(value, pretty: false)
        return text.count <= 240 ? text : String(text.prefix(239)) + "…"
    }

    static func statusIcon(_ status: String) -> String {
        switch status {
        case "running": return "loader"
        case "complete": return "check"
        case "error": return "x"
        default: return "circle"
        }
    }

    static func lastMessage(_ subagent: AnyCodable) -> String? {
        subagent.dictValue?["messages"]?.arrayValue?.last?.string("message")
    }

    static func groups(_ subagents: [AnyCodable], unattached: String) -> [(name: String, subagents: [AnyCodable])] {
        var order: [String] = []
        var map: [String: [AnyCodable]] = [:]
        for subagent in subagents {
            let key = subagent.dictValue?["orbitalName"]?.stringValue ?? unattached
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(subagent)
        }
        return order.map { (name: $0, subagents: map[$0] ?? []) }
    }

    static func subagentActivities(_ subagent: AnyCodable) -> [AnyCodable] {
        (subagent.dictValue?["messages"]?.arrayValue ?? []).map { entry in
            let timestamp = AnyCodable.double(entry.float("timestamp"))
            if !entry.string("tool").isEmpty {
                return AtomKit.node("tool_call", ["tool": .string(entry.string("tool")), "argsText": .string(entry.string("message")), "timestamp": timestamp])
            }
            return AtomKit.node("message", ["role": "system", "content": .string(entry.string("message")), "timestamp": timestamp])
        }
    }

    static func coordinatorItems(_ activities: [AnyCodable]) -> [AnyCodable] {
        activities.flatMap { activity -> [AnyCodable] in
            let timestamp = AnyCodable.double(activity.float("timestamp"))
            switch activity.string("type") {
            case "tool_call":
                return [AtomKit.node("tool_call", ["tool": .string(activity.string("tool")), "argsText": .string(activity.string("argsText")), "timestamp": timestamp])]
            case "tool_result":
                return [AtomKit.node("tool_result", ["tool": .string(activity.string("tool")), "resultText": .string(activity.string("resultText")), "success": .bool(activity.bool("success", default: true)), "timestamp": timestamp])]
            case "message":
                return [AtomKit.node("message", ["role": .string(activity.string("role")), "content": .string(activity.string("content")), "timestamp": timestamp])]
            case "error":
                return [AtomKit.node("message", ["role": "system", "content": .string("Error: \(activity.string("message"))"), "timestamp": timestamp])]
            case "llm_response":
                return [AtomKit.node("message", ["role": "assistant", "content": .string(activity.string("content")), "timestamp": timestamp])]
            case "file_operation":
                return [AtomKit.node("file_operation", ["operation": .string(activity.string("operation")), "path": .string(activity.string("path")), "success": .bool(activity.bool("success", default: true)), "timestamp": timestamp])]
            case "schema_diff":
                return [AtomKit.node("schema_diff", ["filePath": .string(activity.string("filePath")), "hunks": activity.dictValue?["hunks"] ?? .array([]), "timestamp": timestamp])]
            default:
                return []
            }
        }
    }

    static func activityLabel(_ type: String) -> String { activityLabels[type] ?? type }

    static func roleVariant(_ role: String) -> String {
        switch role {
        case "user": return "info"
        case "tool": return "warning"
        case "assistant": return "default"
        default: return "neutral"
        }
    }

    static func timelineIcon(_ source: String, _ data: AnyCodable) -> (name: String, tone: String) {
        switch source {
        case "message":
            if data.string("role") == "tool" { return ("terminal", "primary") }
            if !data.string("reasoningContent").isEmpty { return ("sparkles", "primary") }
            if data.string("role") == "user" { return ("user", "primary") }
            return ("message-square", "muted")
        case "activity":
            switch data.string("type") {
            case "tool_call": return ("terminal", "primary")
            case "tool_result": return data.bool("success", default: true) ? ("check", "success") : ("x", "error")
            case "error": return ("alert-triangle", "error")
            case "file_operation": return ("file", "muted")
            case "schema_diff": return ("git-commit", "muted")
            default: return ("info", "muted")
            }
        default:
            return ("bot", "primary")
        }
    }

    static func timelineLabel(_ source: String, _ data: AnyCodable) -> String {
        switch source {
        case "message":
            if data.string("role") == "tool" { return "tool" }
            if !data.string("reasoningContent").isEmpty { return "thinking" }
            return data.string("role")
        case "activity": return activityLabel(data.string("type"))
        default: return "subagent"
        }
    }

    static func timelinePreview(_ source: String, _ data: AnyCodable) -> String {
        switch source {
        case "message":
            if data.string("role") == "tool" {
                let id = data.string("toolCallId")
                return "\(data.string("toolName").isEmpty ? "tool" : data.string("toolName")) → \(String(id.prefix(8)))"
            }
            if !data.string("reasoningContent").isEmpty { return preview(data.string("reasoningContent")) }
            return preview(data.string("content"))
        case "activity":
            switch data.string("type") {
            case "tool_call": return "\(data.string("tool"))(\(preview(data.string("argsText"))))"
            case "tool_result": return "\(data.string("tool")): \(preview(data.string("resultText")))"
            case "message": return preview(data.string("content"))
            case "error": return preview(data.string("message"))
            case "file_operation": return "\(fileOperations[data.string("operation")] ?? data.string("operation")) \(data.string("path"))"
            case "schema_diff": return "diff \(data.string("filePath"))"
            default: return data.string("type")
            }
        default:
            return "\(data.string("name")) · \(data.string("task"))"
        }
    }

    static func timelineTime(_ source: String, _ data: AnyCodable) -> String? {
        if source == "activity" { return time(data.float("timestamp")) }
        if source == "subagent", let first = data.dictValue?["messages"]?.arrayValue?.first, first.dictValue?["timestamp"] != nil {
            return time(first.float("timestamp"))
        }
        return nil
    }
}

struct AtomTraceEntry {
    let source: String
    let data: AnyCodable
    let index: Int
}

struct AtomTraceScroll<Content: View>: View {
    let cap: CGFloat
    let count: Int
    let autoScroll: Bool
    let content: Content

    init(cap: CGFloat, count: Int, autoScroll: Bool = true, @ViewBuilder content: () -> Content) {
        self.cap = cap
        self.count = count
        self.autoScroll = autoScroll
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        content
                        Spacer(minLength: 0).frame(height: 0).id("trace-end")
                    }
                }
                .onAppear { if autoScroll { proxy.scrollTo("trace-end", anchor: .bottom) } }
                .onChange(of: count) { _ in
                    if autoScroll { withAnimation { proxy.scrollTo("trace-end", anchor: .bottom) } }
                }
            }
        }
        .frame(maxHeight: cap)
    }
}

struct AtomTraceDot: View {
    let color: Color
    let pulse: Bool
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: theme.density.spacing.space2, height: theme.density.spacing.space2)
            .opacity(pulse && dim ? 0.4 : 1)
            .onAppear {
                if pulse && !reduceMotion {
                    withAnimation(.easeInOut(duration: theme.motion.durations.dramatic * 2).repeatForever(autoreverses: true)) { dim = true }
                }
            }
            .accessibilityHidden(true)
    }
}

struct AtomTraceRow: View {
    let activity: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var spec: (icon: String, tone: String, text: AnyView) {
        let type = activity.string("type")
        switch type {
        case "tool_call":
            let args = activity.string("argsText")
            var runs = [AtomMonoRun(text: activity.string("tool"), color: nil, bold: true)]
            if args != "" && args != "{}" { runs.append(AtomMonoRun(text: " " + args, color: theme.color.mutedForeground, bold: false)) }
            return ("terminal", "primary", AnyView(AtomMonoRuns(runs)))
        case "tool_result":
            let ok = activity.bool("success", default: true)
            let runs = [
                AtomMonoRun(text: activity.string("tool") + ": ", color: theme.color.mutedForeground, bold: false),
                AtomMonoRun(text: activity.string("resultText"), color: nil, bold: false),
            ]
            return (ok ? "check" : "x", ok ? "success" : "error", AnyView(AtomMonoRuns(runs)))
        case "message":
            let role = activity.string("role")
            let icon = role == "user" ? "user" : (role == "system" ? "info" : "sparkles")
            let tone = role == "user" ? "primary" : (role == "system" ? "muted" : "")
            return (icon, tone, AtomKit.typo(activity.string("content"), "caption", onEvent: onEvent))
        case "error":
            return ("alert-triangle", "error", AtomKit.typo(activity.string("message"), "caption", color: "error", onEvent: onEvent))
        default:
            return ("file", "muted", AnyView(AtomMonoRuns([AtomMonoRun(text: "[\(type)] \(AtomTrace.compact(activity))", color: theme.color.mutedForeground, bold: false)])))
        }
    }

    var body: some View {
        let shown = spec
        HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            AtomKit.icon(shown.icon, "xs", color: shown.tone, onEvent: onEvent)
            shown.text.frame(maxWidth: .infinity, alignment: .leading)
            AtomKit.typo(AtomTrace.time(activity.float("timestamp")), "caption", color: "muted", onEvent: onEvent)
        }
        .padding(.horizontal, theme.density.spacing.space3)
        .padding(.vertical, theme.density.spacing.space1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AtomTraceStream: View {
    let activities: [AnyCodable]
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(activities.indices, id: \.self) { index in
                AtomTraceRow(activity: activities[index], onEvent: onEvent)
            }
        }
    }
}

struct AtomTraceCoordinatorCard: View {
    let activities: [AnyCodable]
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let decision = activities.last { $0.string("type") == "coordinator_decision" }
        let plan = activities.last { $0.string("type") == "plan_committed" }
        let orbitals = AtomKit.strings(plan ?? .null, "orbitals")
        let questions = activities.filter { $0.string("type") == "pending_question" }
        if decision != nil || plan != nil || !questions.isEmpty {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space1) {
                    AtomKit.icon("compass", "xs", onEvent: onEvent)
                    AtomKit.typo("Coordinator", "caption", weight: "semibold", onEvent: onEvent)
                }
                if let decision = decision {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                        HStack(spacing: theme.density.spacing.space1) {
                            AtomKit.typo("ORGANISM", "caption", color: "muted", onEvent: onEvent)
                            AtomKit.badge(decision.string("organism"), "default", onEvent: onEvent)
                            if !decision.string("priorOrganism").isEmpty && decision.string("priorOrganism") != decision.string("organism") {
                                AtomKit.typo("was \(decision.string("priorOrganism"))", "caption", color: "muted", onEvent: onEvent)
                            }
                        }
                        if !decision.string("reason").isEmpty {
                            AtomKit.typo(decision.string("reason"), "caption", color: "muted", onEvent: onEvent)
                        }
                    }
                }
                if !orbitals.isEmpty {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("PLAN · \(orbitals.count) \(orbitals.count == 1 ? "ORBITAL" : "ORBITALS")", "caption", color: "muted", onEvent: onEvent)
                        AtomFlowLayout(spacing: theme.density.spacing.space1) {
                            ForEach(orbitals.indices, id: \.self) { index in
                                AtomKit.badge(orbitals[index], "neutral", onEvent: onEvent)
                            }
                        }
                    }
                }
                if !questions.isEmpty {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("\(questions.count) PENDING \(questions.count == 1 ? "QUESTION" : "QUESTIONS")", "caption", color: "muted", onEvent: onEvent)
                        ForEach(questions.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: theme.density.spacing.space1) {
                                AtomKit.icon("help-circle", "xs", color: "warning", onEvent: onEvent)
                                AtomKit.typo(questions[index].string("question") + (questions[index].string("orbitalName").isEmpty ? "" : " (\(questions[index].string("orbitalName")))"), "caption", onEvent: onEvent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.muted.opacity(0.3))
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }
}

struct AtomTraceSubagentRow: View {
    let subagent: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                AtomKit.icon(AtomTrace.statusIcon(subagent.string("status")), "xs", onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    HStack(spacing: theme.density.spacing.space2) {
                        AtomKit.typo(subagent.string("name"), "caption", weight: "medium", truncate: true, onEvent: onEvent)
                        AtomKit.badge(subagent.string("role"), "default", onEvent: onEvent)
                    }
                    AtomKit.typo(AtomTrace.lastMessage(subagent) ?? subagent.string("task"), "caption", color: "muted", truncate: true, onEvent: onEvent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }
}

struct AtomTraceOrbitalGroup: View {
    let name: String
    let subagents: [AnyCodable]
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let running = subagents.filter { $0.string("status") == "running" }.count
        let complete = subagents.filter { $0.string("status") == "complete" }.count
        VStack(spacing: 0) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("circle", "xs", onEvent: onEvent)
                AtomKit.typo(name, "caption", weight: "semibold", truncate: true, onEvent: onEvent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                AtomKit.badge(running > 0 ? "\(running) running" : "\(complete) done", "default", onEvent: onEvent)
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .background(theme.color.surface)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            ForEach(subagents.indices, id: \.self) { index in
                AtomTraceSubagentRow(subagent: subagents[index], onEvent: onEvent)
            }
        }
    }
}

struct AtomTraceRichCard: View {
    let subagent: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var dotColor: Color {
        switch subagent.string("status") {
        case "complete": return theme.color.success
        case "error": return theme.color.error
        default: return theme.color.primary
        }
    }

    private var roleVariant: String {
        switch subagent.string("role") {
        case "deterministic": return "default"
        case "llm": return "info"
        default: return "warning"
        }
    }

    private var duration: String? {
        let ms = subagent.float("durationMs")
        if ms <= 0 { return nil }
        return ms < 1000 ? "\(Int(ms))ms" : String(format: "%.1fs", ms / 1000)
    }

    var body: some View {
        let activities = AtomTrace.subagentActivities(subagent)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomTraceDot(color: dotColor, pulse: subagent.string("status") == "running")
                    AtomKit.typo(subagent.string("name"), "caption", weight: "semibold", truncate: true, onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AtomKit.badge(subagent.string("role"), roleVariant, onEvent: onEvent)
                    if let duration = duration { AtomKit.typo(duration, "caption", color: "muted", onEvent: onEvent) }
                }
                AtomKit.typo(subagent.string("task"), "caption", color: "muted", onEvent: onEvent)
                if !activities.isEmpty {
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    AtomTraceScroll(cap: AlmadarSizes.w64, count: activities.count) {
                        AtomTraceStream(activities: activities, onEvent: onEvent)
                    }
                } else {
                    AtomKit.typo(subagent.string("status") == "complete" ? "No conversation log" : "Waiting for process data…", "caption", color: "muted", onEvent: onEvent).italic()
                }
            }
            .padding(theme.density.spacing.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }
}

struct AtomTraceChatRow: View {
    let message: AnyCodable
    let index: Int
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func code(_ text: String) -> AnyCodable {
        AtomKit.node("code-block", ["code": .string(text), "language": "json", "maxHeight": "24rem"])
    }

    private func toolCallItems(_ calls: [AnyCodable], prefix: String) -> [AnyCodable] {
        calls.enumerated().map { offset, call in
            .dict(["id": .string("\(prefix)-\(index)-\(offset)"), "title": .string("\(call.string("name"))(\(AtomTrace.summarize(call.dictValue?["args"])))"), "content": code(AtomTrace.json(call.dictValue?["args"] ?? .dict([:]), pretty: true))])
        }
    }

    var body: some View {
        let role = message.string("role")
        let content = message.string("content")
        let reasoning = message.string("reasoningContent")
        let calls = message.dictValue?["toolCalls"]?.arrayValue ?? []
        VStack(spacing: 0) {
            if role == "tool" {
                let pretty = AtomTrace.prettyJSON(content)
                let id = message.string("toolCallId")
                let title = "\(message.string("toolName").isEmpty ? "tool" : message.string("toolName")) →\(id.isEmpty ? "" : " " + String(id.prefix(8)))"
                let item: AnyCodable = .dict(["id": .string("tool-\(index)"), "title": .string(title), "content": pretty.map { code($0) } ?? .null])
                AccordionMoleculeView(
                    props: ["items": .array([item])],
                    onEvent: onEvent,
                    rendered: pretty == nil ? ["tool-\(index)": AnyView(AtomMonoText(content, size: "xs"))] : [:]
                )
                    .padding(.horizontal, theme.density.spacing.space3)
                    .padding(.vertical, theme.density.spacing.space2)
            } else {
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    HStack(spacing: theme.density.spacing.space1) {
                        AtomKit.badge(role.uppercased(), AtomTrace.roleVariant(role), onEvent: onEvent)
                        if !reasoning.isEmpty { AtomKit.typo("· thinking", "caption", color: "muted", onEvent: onEvent) }
                        if !calls.isEmpty { AtomKit.typo("· \(calls.count) tool call\(calls.count == 1 ? "" : "s")", "caption", color: "muted", onEvent: onEvent) }
                    }
                    if !reasoning.isEmpty {
                        AccordionRenderer(props: ["items": .array([.dict(["id": .string("reasoning-\(index)"), "title": "Reasoning", "content": AtomKit.node("markdown-content", ["content": .string(reasoning)])])])], modifier: nil, onEvent: onEvent)
                    }
                    if !content.isEmpty { MarkdownContentRenderer(props: ["content": .string(content)], modifier: nil, onEvent: onEvent) }
                    if !calls.isEmpty {
                        AccordionRenderer(props: ["multiple": true, "items": .array(toolCallItems(calls, prefix: "tc"))], modifier: nil, onEvent: onEvent)
                    }
                }
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.vertical, theme.density.spacing.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }
}

struct AtomTraceConversation: View {
    let messages: [AnyCodable]
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(messages.indices, id: \.self) { index in
                AtomTraceChatRow(message: messages[index], index: index, onEvent: onEvent)
            }
        }
    }
}

struct AtomTraceDetail: View {
    let entry: AtomTraceEntry
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func head(_ badge: String, _ variant: String, _ time: String?) -> some View {
        HStack(spacing: theme.density.spacing.space1) {
            AtomKit.badge(badge, variant, onEvent: onEvent)
            if let time = time { AtomKit.typo(time, "caption", color: "muted", onEvent: onEvent) }
        }
    }

    private func code(_ text: String, height: String) -> some View {
        CodeBlockRenderer(props: ["code": .string(text), "language": "json", "maxHeight": .string(height)], modifier: nil, onEvent: onEvent)
    }

    var body: some View {
        let data = entry.data
        let time = AtomTrace.timelineTime(entry.source, data)
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            switch entry.source {
            case "message":
                let role = data.string("role")
                let content = data.string("content")
                let calls = data.dictValue?["toolCalls"]?.arrayValue ?? []
                head(role.uppercased(), AtomTrace.roleVariant(role), nil)
                if !data.string("reasoningContent").isEmpty {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("Reasoning", "caption", color: "muted", onEvent: onEvent)
                        MarkdownContentRenderer(props: ["content": .string(data.string("reasoningContent"))], modifier: nil, onEvent: onEvent)
                    }
                }
                if !content.isEmpty {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("Content", "caption", color: "muted", onEvent: onEvent)
                        if role == "tool" {
                            if let pretty = AtomTrace.prettyJSON(content) {
                                code(pretty, height: "24rem")
                            } else {
                                AtomMonoText(content, size: "xs")
                            }
                        } else {
                            MarkdownContentRenderer(props: ["content": .string(content)], modifier: nil, onEvent: onEvent)
                        }
                    }
                }
                if !calls.isEmpty {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("Tool calls", "caption", color: "muted", onEvent: onEvent)
                        AccordionRenderer(props: ["multiple": true, "items": .array(calls.enumerated().map { offset, call in
                            .dict(["id": .string("tc-detail-\(offset)"), "title": .string("\(call.string("name"))(\(AtomTrace.summarize(call.dictValue?["args"])))"), "content": AtomKit.node("code-block", ["code": .string(AtomTrace.json(call.dictValue?["args"] ?? .dict([:]), pretty: true)), "language": "json", "maxHeight": "24rem"])])
                        })], modifier: nil, onEvent: onEvent)
                    }
                }
            case "activity":
                switch data.string("type") {
                case "tool_call":
                    head(AtomTrace.activityLabel("tool_call"), "default", time)
                    AtomKit.typo(data.string("tool"), "body2", onEvent: onEvent)
                    code(data.string("argsText"), height: "60vh")
                case "tool_result":
                    head(data.bool("success", default: true) ? "success" : "fail", data.bool("success", default: true) ? "default" : "warning", time)
                    AtomKit.typo(data.string("tool"), "body2", onEvent: onEvent)
                    code(data.string("resultText"), height: "60vh")
                case "message":
                    head(data.string("role"), "neutral", time)
                    AtomKit.typo(data.string("content"), "body2", onEvent: onEvent)
                case "error":
                    head("error", "warning", time)
                    AtomKit.typo(data.string("message"), "body2", color: "error", onEvent: onEvent)
                case "file_operation":
                    head("file", "neutral", time)
                    AtomKit.typo("\(AtomTrace.fileOperations[data.string("operation")] ?? data.string("operation")) \(data.string("path"))", "body2", onEvent: onEvent)
                case "schema_diff":
                    head("diff", "neutral", time)
                    AtomKit.typo(data.string("filePath"), "body2", onEvent: onEvent)
                default:
                    AtomKit.typo(time ?? "", "caption", color: "muted", onEvent: onEvent)
                    AtomKit.typo(data.string("type"), "body2", onEvent: onEvent)
                }
            default:
                let activities = AtomTrace.subagentActivities(data)
                head(data.string("role"), "default", time)
                AtomKit.typo(data.string("name"), "body2", weight: "semibold", onEvent: onEvent)
                AtomKit.typo(data.string("task"), "body2", color: "muted", onEvent: onEvent)
                if !activities.isEmpty {
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                    AtomTraceStream(activities: activities, onEvent: onEvent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SubagentTracePanelOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var selected: AtomTraceEntry?

    private var subagents: [AnyCodable] { props.dictValue?["subagents"]?.arrayValue ?? [] }
    private var activities: [AnyCodable] { props.dictValue?["coordinatorActivities"]?.arrayValue ?? [] }
    private var messages: [AnyCodable] { props.dictValue?["coordinatorMessages"]?.arrayValue ?? [] }
    private var tabMode: Bool { props.string("mode", default: "overlay") == "tab" }
    private var rich: Bool { tabMode || props.int("disclosureLevel", default: 1) >= 3 }

    private func header(_ title: AnyView) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("activity", "sm", onEvent: onEvent)
                title.frame(maxWidth: .infinity, alignment: .leading)
                if !props.string("onClose").isEmpty {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Close", "action": .string(props.string("onClose"))]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }

    private func centered(_ text: String) -> some View {
        AtomKit.typo(text, tabMode ? "body2" : "caption", color: "muted", align: "center", onEvent: onEvent)
            .padding(.horizontal, theme.density.spacing.space4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entries: [AtomTraceEntry] {
        messages.enumerated().map { AtomTraceEntry(source: "message", data: $1, index: $0) }
            + activities.map { AtomTraceEntry(source: "activity", data: $0, index: 0) }
            + subagents.map { AtomTraceEntry(source: "subagent", data: $0, index: 0) }
    }

    private func timelineRow(_ entry: AtomTraceEntry, last: Bool) -> some View {
        let icon = AtomTrace.timelineIcon(entry.source, entry.data)
        let time = AtomTrace.timelineTime(entry.source, entry.data)
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                VStack(spacing: theme.density.spacing.space1) {
                    Circle().fill(theme.color.primary).frame(width: theme.density.spacing.space2, height: theme.density.spacing.space2)
                    if !last {
                        theme.color.border.frame(width: AlmadarSizes.w0_5).frame(minHeight: theme.density.spacing.space6).frame(maxHeight: .infinity)
                    }
                }
                .frame(width: theme.density.spacing.space5)
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    HStack(spacing: theme.density.spacing.space1) {
                        AtomKit.icon(icon.name, "xs", color: icon.tone, onEvent: onEvent)
                        if let time = time { AtomKit.typo(time, "caption", color: "muted", onEvent: onEvent) }
                        AtomKit.badge(AtomTrace.timelineLabel(entry.source, entry.data), "neutral", onEvent: onEvent)
                    }
                    HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                        AtomKit.typo(AtomTrace.timelinePreview(entry.source, entry.data), "body2", color: "muted", onEvent: onEvent)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "maximize-2", "aria-label": "Expand", "action": .string(AtomKit.localEvent), "local": true]),
                            modifier: nil,
                            onEvent: { _, _ in selected = entry }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .contentShape(Rectangle())
            .onTapGesture { selected = entry }
            .accessibilityAddTraits(.isButton)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }

    private var detail: some View {
        ZStack {
            theme.color.scrim.onTapGesture { selected = nil }
            if let entry = selected {
                let time = AtomTrace.timelineTime(entry.source, entry.data)
                ModalMoleculeView(
                    props: ["isOpen": true, "title": .string(AtomTrace.timelineLabel(entry.source, entry.data) + (time.map { " · " + $0 } ?? "")), "size": "lg", "closeEvent": .string(AtomKit.localEvent), "local": true],
                    onEvent: { _, _ in selected = nil },
                    content: AnyView(ScrollView { AtomTraceDetail(entry: entry, onEvent: onEvent) })
                )
                .padding(theme.density.spacing.space4)
            }
        }
    }

    private func conversationHeader(_ count: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.density.spacing.space1) {
                Circle().fill(theme.color.primary).frame(width: AlmadarSizes.w1_5, height: AlmadarSizes.w1_5)
                AtomKit.typo("Coordinator", "caption", weight: "semibold", onEvent: onEvent)
                AtomKit.typo(count, "caption", color: "muted", onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space0)
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space1)
            .background(theme.color.card)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
    }

    @ViewBuilder
    private var coordinatorSection: some View {
        if !messages.isEmpty {
            VStack(spacing: 0) {
                conversationHeader("\(messages.count) messages")
                AtomTraceScroll(cap: AlmadarSizes.maxWXl, count: messages.count) {
                    AtomTraceConversation(messages: messages, onEvent: onEvent)
                }
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
        } else if !activities.isEmpty {
            VStack(spacing: 0) {
                conversationHeader("\(activities.count) events")
                AtomTraceScroll(cap: AlmadarSizes.w60, count: activities.count) {
                    AtomTraceStream(activities: AtomTrace.coordinatorItems(activities), onEvent: onEvent)
                }
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            }
        }
    }

    private func density(_ isRich: Bool) -> String { isRich ? "Detailed" : "Compact" }

    private var tabPanel: some View {
        let items = entries
        return VStack(spacing: 0) {
            header(AtomKit.typo("Trace", "caption", weight: "semibold", onEvent: onEvent))
            if items.isEmpty {
                centered("No agent activity yet")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items.indices, id: \.self) { index in
                            timelineRow(items[index], last: index == items.count - 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.color.card)
        .overlay { if selected != nil { detail } }
    }

    private var overlayBody: some View {
        let focused = props.string("focusedOrbital")
        let shown = focused.isEmpty ? subagents : subagents.filter { $0.string("orbitalName") == focused }
        let hasCoordinator = !messages.isEmpty || !activities.isEmpty
        return VStack(spacing: 0) {
            if shown.isEmpty && !hasCoordinator {
                header(AtomKit.typo("Subagents", "caption", weight: "semibold", onEvent: onEvent))
                centered(focused.isEmpty ? "No subagents active" : "No subagents for \(focused)")
            } else if !focused.isEmpty {
                header(AnyView(VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    AtomKit.typo(focused, "caption", weight: "semibold", truncate: true, onEvent: onEvent)
                    AtomKit.typo("\(shown.count) subagent\(shown.count == 1 ? "" : "s") · \(density(rich))", "caption", color: "muted", onEvent: onEvent)
                }))
                ForEach(shown.indices, id: \.self) { index in
                    if rich { AtomTraceRichCard(subagent: shown[index], onEvent: onEvent) } else { AtomTraceSubagentRow(subagent: shown[index], onEvent: onEvent) }
                }
            } else {
                header(AtomKit.typo("Subagents (\(shown.count)) · \(density(rich))", "caption", weight: "semibold", onEvent: onEvent))
                if rich { AtomTraceCoordinatorCard(activities: activities, onEvent: onEvent) }
                coordinatorSection
                if rich {
                    ForEach(shown.indices, id: \.self) { index in
                        AtomTraceRichCard(subagent: shown[index], onEvent: onEvent)
                    }
                } else {
                    let grouped = AtomTrace.groups(shown, unattached: "(unattached)")
                    ForEach(grouped.indices, id: \.self) { index in
                        AtomTraceOrbitalGroup(name: grouped[index].name, subagents: grouped[index].subagents, onEvent: onEvent)
                    }
                }
            }
        }
    }

    private var overlayPanel: some View {
        let width = rich ? AlmadarSizes.maxWMd : AlmadarSizes.w80
        return AtomTraceScroll(cap: UIScreen.main.bounds.height * 0.6, count: subagents.count, autoScroll: false) { overlayBody }
            .frame(maxWidth: width)
            .atomSurfaceImage(theme, .container)
            .background(theme.color.card)
            .atomBackdrop(theme, .container)
            .atomClip(theme, .container)
            .atomBorder(theme, .container, color: theme.color.border, width: theme.geometry.borderStandard)
            .atomShadow(theme.elevation.popoverElevation)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    var body: some View {
        if tabMode {
            tabPanel.accessibilityElement(children: .contain)
        } else if props.bool("open") {
            overlayPanel.accessibilityElement(children: .contain)
        }
    }
}

@ViewBuilder
func SubagentTracePanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SubagentTracePanelOrganismView(props: props, onEvent: onEvent))
}
