import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ReplyTreeNodeView: View {
    let owner: AnyCodable
    let node: AnyCodable
    let depth: Int
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var collapsed: Bool
    @State private var composing = false
    @State private var draft = ""

    init(owner: AnyCodable, node: AnyCodable, depth: Int, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.owner = owner
        self.node = node
        self.depth = depth
        self.onEvent = onEvent
        _collapsed = State(initialValue: node.bool("collapsed"))
    }

    private var nodeId: String { AtomKit.scalar(node.dictValue?["id"]) ?? "" }

    var body: some View {
        let replies = node.dictValue?["replies"]?.arrayValue ?? []
        let author = node.string("authorName")
        HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            VStack(spacing: theme.density.spacing.space1) {
                if !replies.isEmpty {
                    ButtonRenderer(
                        props: ["variant": "ghost", "size": "sm", "icon": .string(collapsed ? "chevron-right" : "chevron-down"), "aria-label": .string(collapsed ? "Expand replies" : "Collapse replies"), "action": "reply-toggle", "local": true],
                        modifier: nil,
                        onEvent: { _, _ in collapsed.toggle() }
                    )
                } else {
                    Spacer().frame(width: theme.density.spacing.space6, height: theme.density.spacing.space6)
                }
                if !replies.isEmpty && !collapsed {
                    Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderHairline).frame(maxHeight: .infinity)
                }
            }
            .frame(width: theme.density.spacing.space6)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space2) {
                    AvatarRenderer(props: ["src": .string(node.string("authorAvatarUrl")), "name": .string(author), "size": "sm"], modifier: nil, onEvent: onEvent)
                    AtomKit.typo(author, "body1", weight: "semibold", onEvent: onEvent)
                    AtomKit.typo(node.string("postedAt"), "caption", color: "secondary", onEvent: onEvent)
                }
                AtomKit.typo(node.string("content"), "body1", onEvent: onEvent)
                if owner.bool("showActions", default: true) { actions(author: author) }
                if composing { composer(author: author) }
                if !replies.isEmpty && !collapsed { children(replies) }
            }
            .padding(.bottom, theme.density.spacing.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .verificationContainer(VerificationIds.row(nodeId))
    }

    private func actions(author: String) -> some View {
        HStack(spacing: theme.density.spacing.space2) {
            VoteStackRenderer(
                props: AtomKit.child(owner, [
                    "count": .int(node.int("voteCount")),
                    "userVote": .string(node.string("userVote")),
                    "size": "sm",
                    "variant": "horizontal",
                    "label": .string("Vote on reply by " + author),
                    "voteEvent": .string(owner.string("voteEvent")),
                ]),
                modifier: nil,
                onEvent: { name, payload in
                    let next = payload?.dictValue?["actionPayload"]?.dictValue?["next"] ?? .null
                    onEvent(name, eventEnvelope(owner, payload: ["nodeId": .string(nodeId), "vote": next]))
                }
            )
            ButtonRenderer(
                props: ["variant": "ghost", "size": "sm", "leftIcon": "message-square", "label": "Reply", "aria-label": .string("Reply to " + author), "action": "reply-compose", "local": true],
                modifier: nil,
                onEvent: { _, _ in composing.toggle() }
            )
            ButtonRenderer(
                props: AtomKit.child(owner, ["variant": "ghost", "size": "sm", "leftIcon": "flag", "label": "Flag", "aria-label": .string("Flag reply by " + author), "action": .string(owner.string("flagEvent")), "actionPayload": ["nodeId": .string(nodeId)]]),
                modifier: nil,
                onEvent: onEvent
            )
        }
    }

    private func composer(author: String) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            InputRenderer(
                props: ["inputType": "textarea", "value": .string(draft), "placeholder": .string("Reply to " + author), "aria-label": .string("Reply to " + author), "onChange": "reply-draft", "local": true],
                modifier: nil,
                onEvent: { _, payload in draft = AtomKit.scalar(payload?.dictValue?["actionPayload"]?.dictValue?["value"]) ?? "" }
            )
            HStack(spacing: theme.density.spacing.space2) {
                ButtonRenderer(
                    props: AtomKit.child(owner, ["variant": "primary", "size": "sm", "leftIcon": "send", "label": "Send", "disabled": .bool(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty), "action": .string(owner.string("replyEvent"))]),
                    modifier: nil,
                    onEvent: { name, _ in
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onEvent(name, eventEnvelope(owner, payload: ["parentNodeId": .string(nodeId), "content": .string(text)]))
                        draft = ""
                        composing = false
                    }
                )
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "label": "Cancel", "action": "reply-cancel", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in
                        draft = ""
                        composing = false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func children(_ replies: [AnyCodable]) -> some View {
        if depth >= max(owner.int("maxDepth", default: 6), 1) {
            ButtonRenderer(
                props: AtomKit.child(owner, ["variant": "ghost", "size": "sm", "rightIcon": "chevron-right", "label": "Continue thread", "action": .string(owner.string("continueThreadEvent")), "actionPayload": ["nodeId": .string(nodeId)]]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                ForEach(replies.indices, id: \.self) { index in
                    ReplyTreeNodeView(owner: owner, node: replies[index], depth: depth + 1, onEvent: onEvent)
                }
            }
            .padding(.top, theme.density.spacing.space1)
        }
    }
}

@ViewBuilder
func ReplyTreeRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let roots = AtomKit.rows(props, "nodes")
    AnyView(VStack(alignment: .leading, spacing: 0) {
        ForEach(roots.indices, id: \.self) { index in
            ReplyTreeNodeView(owner: props, node: roots[index], depth: 0, onEvent: onEvent)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain))
}
