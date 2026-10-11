import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct VoteStackMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let vote = props.string("userVote")
        let vertical = props.string("variant", default: "vertical") == "vertical"
        let layout = vertical ? AnyLayout(VStackLayout(spacing: theme.density.spacing.space0)) : AnyLayout(HStackLayout(spacing: theme.density.spacing.space0))
        layout {
            arrow("up", icon: "chevron-up", selected: vote == "up")
            AtomKit.typo(AtomKit.text(props, "count"), props.string("size", default: "md") == "lg" ? "large" : "body1", weight: "bold", align: "center", onEvent: onEvent)
                .frame(minWidth: theme.density.spacing.space10)
                .padding(vertical ? .vertical : .horizontal, theme.density.spacing.space1)
            arrow("down", icon: "chevron-down", selected: vote == "down")
        }
        .fixedSize()
        .background(theme.color.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .opacity(props.bool("disabled") ? 0.5 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(props.string("aria-label", default: props.string("label", default: "Vote")))
    }

    private func arrow(_ direction: String, icon: String, selected: Bool) -> some View {
        let next: AnyCodable = selected ? .null : .string(direction)
        return ButtonRenderer(
            props: AtomKit.child(props, [
                "variant": selected ? "primary" : "ghost",
                "size": .string(props.string("size", default: "md") == "lg" ? "lg" : "md"),
                "icon": .string(icon),
                "aria-label": .string(direction == "up" ? "Upvote" : "Downvote"),
                "disabled": .bool(props.bool("disabled")),
                "action": .string(props.string("voteEvent")),
                "actionPayload": ["next": next],
            ]),
            modifier: nil,
            onEvent: onEvent
        )
    }
}

@ViewBuilder
func VoteStackRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(VoteStackMoleculeView(props: props, onEvent: onEvent))
}
