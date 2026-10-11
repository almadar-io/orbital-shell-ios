import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AgentChatFeedMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @AppStorage private var showRaw: Bool
    @State private var openTurns: Set<Int> = []
    @State private var copied: String = ""

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _showRaw = AppStorage(wrappedValue: false, props.string("rawLlmPreferenceKey"))
    }

    private struct Turn {
        var request: Int?
        var steps: [Int]
        var replies: [Int]
        var started: Double
    }

    private func isUser(_ activity: AnyCodable) -> Bool {
        activity.string("type") == "message" && activity.string("role") == "user"
    }

    private func isReply(_ activity: AnyCodable) -> Bool {
        (activity.string("type") == "message" && activity.string("role") != "user") || activity.string("type") == "error"
    }

    private func turns(_ activities: [AnyCodable]) -> [Turn] {
        var list: [Turn] = []
        for (index, activity) in activities.enumerated() {
            let stamp = activity.float("timestamp")
            if isUser(activity) || list.isEmpty {
                list.append(Turn(request: isUser(activity) ? index : nil, steps: isUser(activity) || isReply(activity) ? [] : [index], replies: isReply(activity) ? [index] : [], started: stamp))
            } else if isReply(activity) {
                list[list.count - 1].replies.append(index)
            } else {
                list[list.count - 1].steps.append(index)
            }
        }
        return list
    }

    var body: some View {
        let activities = props.dictValue?["activities"]?.arrayValue ?? []
        let working = props.bool("working")
        if activities.isEmpty && !working {
            EmptyStateRenderer(
                props: AtomKit.child(props, ["icon": "sparkles", "title": .string(props.string("emptyTitle")), "description": "Ask in your own words \u{2014} the assistant can look things up and make changes for you."]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            let grouped = turns(activities)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        ForEach(grouped.indices, id: \.self) { index in
                            turn(grouped[index], index: index, previous: index > 0 ? grouped[index - 1] : nil, last: index == grouped.count - 1, working: working, activities: activities)
                        }
                        if working {
                            HStack(spacing: theme.density.spacing.space2) {
                                AtomKit.icon("loader", "sm", color: "primary", animation: "spin", onEvent: onEvent)
                                AtomKit.typo("Thinking\u{2026}", "body2", color: "muted", onEvent: onEvent)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.updatesFrequently)
                        }
                        theme.color.background.opacity(0).frame(height: theme.geometry.borderHairline).id("chat-end")
                    }
                    .padding(theme.density.spacing.space3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: activities.count) { _ in withAnimation { proxy.scrollTo("chat-end", anchor: .bottom) } }
                .onChange(of: working) { _ in withAnimation { proxy.scrollTo("chat-end", anchor: .bottom) } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Conversation")
            .verificationId("\(props.string("idPrefix"))-scroller")
        }
    }

    private func day(_ stamp: Double) -> String {
        let date = Date(timeIntervalSince1970: stamp / 1000)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func clock(_ stamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: stamp / 1000))
    }

    @ViewBuilder
    private func turn(_ turn: Turn, index: Int, previous: Turn?, last: Bool, working: Bool, activities: [AnyCodable]) -> some View {
        let newDay = previous == nil || day(previous?.started ?? 0) != day(turn.started)
        let steps = turn.steps.map { activities[$0] }
        let visible = steps.filter { showRaw || $0.string("type") != "llm_response" }
        let toolSteps = steps.filter { $0.string("type") != "llm_response" }.count
        let hasRaw = steps.contains(where: { $0.string("type") == "llm_response" })
        let live = last && working && turn.replies.isEmpty
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            if newDay { DividerRenderer(props: ["label": .string(day(turn.started))], modifier: nil, onEvent: onEvent) }
            if let request = turn.request {
                VStack(alignment: .trailing, spacing: theme.density.spacing.space0) {
                    AtomAgentRow(activity: activities[request], settled: false, ready: 0, onEvent: onEvent)
                    AtomKit.typo(clock(activities[request].float("timestamp")), "caption", color: "muted", onEvent: onEvent)
                }
            }
            if live {
                stepRows(visible)
            } else if toolSteps > 0 || hasRaw {
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "leftIcon": .string(openTurns.contains(index) ? "chevron-down" : "chevron-right"), "label": .string("Worked through \(toolSteps) steps"), "action": .string("\(props.string("idPrefix"))-steps-\(index)"), "local": true],
                    modifier: nil,
                    onEvent: { _, _ in if openTurns.contains(index) { openTurns.remove(index) } else { openTurns.insert(index) } }
                )
                .accessibilityValue(openTurns.contains(index) ? "expanded" : "collapsed")
                if openTurns.contains(index) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        if hasRaw {
                            SwitchRenderer(
                                props: ["label": "Raw LLM", "checked": .bool(showRaw), "name": .string("\(props.string("idPrefix"))-show-raw-llm-\(index)"), "onChange": "raw-llm-toggle", "local": true],
                                modifier: nil,
                                onEvent: { _, envelope in showRaw = envelope?.dictValue?["actionPayload"]?.dictValue?["checked"]?.boolValue ?? !showRaw }
                            )
                        }
                        stepRows(visible)
                    }
                    .padding(.leading, theme.density.spacing.space3)
                    .overlay(alignment: .leading) { Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderStandard) }
                }
            }
            ForEach(turn.replies.indices, id: \.self) { r in
                let reply = activities[turn.replies[r]]
                let key = "\(index)-\(r)"
                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    AtomAgentRow(activity: reply, settled: false, ready: 0, onEvent: onEvent)
                    HStack(spacing: theme.density.spacing.space1) {
                        AtomKit.typo(clock(reply.float("timestamp")), "caption", color: "muted", onEvent: onEvent)
                        if reply.string("type") == "message" {
                            ButtonRenderer(
                                props: ["variant": "ghost", "size": "sm", "icon": .string(copied == key ? "check" : "copy"), "aria-label": .string(copied == key ? "Copied" : "Copy reply"), "action": .string("\(props.string("idPrefix"))-copy-\(key)"), "local": true],
                                modifier: nil,
                                onEvent: { _, _ in
                                    UIPasteboard.general.string = reply.string("content")
                                    copied = key
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func stepRows(_ steps: [AnyCodable]) -> some View {
        let facts = AtomKit.agentFacts(steps)
        return VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            ForEach(steps.indices, id: \.self) { index in
                AtomAgentRow(activity: steps[index], settled: facts[index].settled, ready: facts[index].ready, onEvent: onEvent)
            }
        }
    }
}

@ViewBuilder
func AgentChatFeedRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AgentChatFeedMoleculeView(props: props, onEvent: onEvent))
}
