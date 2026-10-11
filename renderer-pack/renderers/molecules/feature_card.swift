import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FeatureCardMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        let href = props.string("href")
        let target = AtomKit.navigate(.dict(["href": .string(href)]))
        let interactive = props.string("variant", default: "bordered") == "interactive" && !href.isEmpty
        let external = interactive && target.event.isEmpty
        let card = CardRenderer(props: cardProps(target: target, interactive: interactive && !external), modifier: nil, onEvent: onEvent)
        if external {
            card
                .contentShape(Rectangle())
                .onTapGesture { if let url = URL(string: target.href) { openURL(url) } }
                .accessibilityAddTraits(.isButton)
        } else {
            card
        }
    }

    private func cardProps(target: (event: String, payload: AnyCodable?, href: String), interactive: Bool) -> AnyCodable {
        let size = props.string("size", default: "md")
        var values: [String: AnyCodable] = [
            "variant": .string(props.string("variant", default: "bordered")),
            "padding": .string(size),
            "children": .array([content(size: size)]),
        ]
        if interactive {
            values["action"] = .string(target.event)
            if let payload = target.payload { values["actionPayload"] = payload }
        }
        return AtomKit.child(props, values)
    }

    private func content(size: String) -> AnyCodable {
        let href = props.string("href")
        let icon = props.string("icon")
        var nodes: [AnyCodable] = []
        if !icon.isEmpty {
            nodes.append(.dict(["type": "icon", "icon": .string(icon), "size": .string(size == "sm" ? "lg" : "xl"), "color": "accent"]))
        }
        nodes.append(.dict(["type": "typography", "variant": "h4", "content": .string(props.string("title"))]))
        nodes.append(.dict(["type": "typography", "variant": "body2", "color": "muted", "content": .string(props.string("description"))]))
        if !href.isEmpty && props.string("variant", default: "bordered") != "interactive" {
            let link = AtomKit.linkProps(props, .dict(["href": .string(href)]), ["type": "button", "variant": "ghost", "size": "sm", "label": .string(props.string("linkLabel", default: "Learn more"))])
            nodes.append(link)
        }
        return .dict(["type": "stack", "direction": "vertical", "gap": .string(size), "align": "start", "children": .array(nodes)])
    }
}

@ViewBuilder
func FeatureCardRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FeatureCardMoleculeView(props: props, onEvent: onEvent))
}
