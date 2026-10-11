import Foundation
import SwiftUI

// tier: templates — CONTENT ONLY

struct GenericAppTemplateView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let footer = props.dictValue?["footer"]
        VStack(spacing: theme.density.spacing.space0) {
            BoxRenderer(props: AtomKit.child(props, ["padding": "md", "fullWidth": true, "children": .array([header])]), modifier: nil, onEvent: onEvent)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            ScrollView {
                BoxRenderer(
                    props: AtomKit.child(props, ["padding": "lg", "fullWidth": true, "entity": props.dictValue?["entity"] ?? .null, "children": .array(props.children())]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
            if let footer = footer {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                BoxRenderer(props: AtomKit.child(props, ["padding": "md", "bg": "muted", "fullWidth": true, "children": .array([footer])]), modifier: nil, onEvent: onEvent)
            }
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var header: AnyCodable {
        var titles: [AnyCodable] = [AtomKit.node("typography", ["variant": "h3", "content": .string(props.string("title"))])]
        if !props.string("subtitle").isEmpty {
            titles.append(AtomKit.node("typography", ["variant": "body2", "color": "secondary", "content": .string(props.string("subtitle"))]))
        }
        var row: [AnyCodable] = [AtomKit.node("stack", ["direction": "vertical", "gap": "xs", "align": "start", "children": .array(titles)])]
        let actions = AtomKit.nodes(props, "headerActions")
        if !actions.isEmpty {
            row.append(AtomKit.node("stack", ["direction": "horizontal", "gap": "sm", "align": "center", "children": .array(actions)]))
        }
        return AtomKit.node("stack", ["direction": "horizontal", "justify": "between", "align": "center", "children": .array(row)])
    }
}

@ViewBuilder
func GenericAppTemplateRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GenericAppTemplateView(props: props, onEvent: onEvent))
}
