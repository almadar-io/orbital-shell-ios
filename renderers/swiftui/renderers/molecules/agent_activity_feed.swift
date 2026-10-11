import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AgentActivityFeedMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let activities = props.dictValue?["activities"]?.arrayValue ?? []
        let working = props.bool("working")
        if activities.isEmpty && !working {
            EmptyStateRenderer(
                props: AtomKit.child(props, [
                    "icon": "sparkles",
                    "title": .string(props.string("emptyTitle", default: "No activity yet")),
                    "description": .string(props.string("emptyDescription", default: "Send a message and the agent's work shows up here.")),
                ]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            let groups = conversations(activities)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                if groups.count > 1 {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        AtomKit.typo("Earlier conversations (\(groups.count - 1))", "caption", color: "muted", weight: "semibold", onEvent: onEvent)
                        ForEach(0..<(groups.count - 1), id: \.self) { index in
                            earlier(groups[index], activities: activities)
                        }
                    }
                }
                if let current = groups.last { rows(current.indices, activities: activities) }
                if working { thinking }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }

    private func conversations(_ activities: [AnyCodable]) -> [(prompt: String?, indices: [Int])] {
        var groups: [(prompt: String?, indices: [Int])] = []
        for (index, activity) in activities.enumerated() {
            let prompt = activity.string("type") == "message" && activity.string("role") == "user"
            if prompt || groups.isEmpty {
                groups.append((prompt: prompt ? activity.string("content") : nil, indices: [index]))
            } else {
                groups[groups.count - 1].indices.append(index)
            }
        }
        return groups
    }

    private func rows(_ indices: [Int], activities: [AnyCodable]) -> some View {
        let facts = AtomKit.agentFacts(indices.map { activities[$0] })
        return VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            ForEach(indices.indices, id: \.self) { position in
                AtomAgentRow(activity: activities[indices[position]], settled: facts[position].settled, ready: facts[position].ready, onEvent: onEvent)
            }
        }
    }

    private func earlier(_ group: (prompt: String?, indices: [Int]), activities: [AnyCodable]) -> some View {
        DisclosureGroup {
            rows(group.prompt == nil ? group.indices : Array(group.indices.dropFirst()), activities: activities)
        } label: {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("message-square", "sm", color: "muted", onEvent: onEvent)
                AtomKit.typo(group.prompt ?? "Earlier activity", "body2", truncate: true, onEvent: onEvent)
            }
        }
    }

    private var thinking: some View {
        HStack(spacing: theme.density.spacing.space2) {
            AtomKit.icon("loader", "sm", color: "primary", animation: "spin", onEvent: onEvent)
            AtomKit.typo("Thinking\u{2026}", "body2", color: "muted", onEvent: onEvent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

@ViewBuilder
func AgentActivityFeedRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AgentActivityFeedMoleculeView(props: props, onEvent: onEvent))
}
