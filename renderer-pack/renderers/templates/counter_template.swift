import Foundation
import SwiftUI

// tier: templates — CONTENT ONLY

struct CounterTemplateView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    private var entity: AnyCodable? {
        guard let raw = props.dictValue?["entity"], raw.dictValue != nil else { return nil }
        return raw
    }

    private var size: String { props.string("size", default: "md") }

    var body: some View {
        if let entity = entity {
            RenderChild(tree(entity), onEvent: onEvent)
        }
    }

    private func node(_ type: String, _ values: [String: AnyCodable]) -> AnyCodable {
        AtomKit.child(props, values.merging(["type": .string(type)]) { _, new in new })
    }

    private func step(_ entity: AnyCodable, minus: Bool, label: Bool, variant: String) -> AnyCodable {
        var values: [String: AnyCodable] = [
            "variant": .string(variant),
            "size": .string(size),
            "icon": .string(minus ? "minus" : "plus"),
            "action": .string(props.string(minus ? "decrementEvent" : "incrementEvent", default: props.string(minus ? "onDecrement" : "onIncrement"))),
            "disabled": .bool(entity.bool(minus ? "decrementDisabled" : "incrementDisabled")),
        ]
        if label { values["label"] = .string(entity.string(minus ? "decrementLabel" : "incrementLabel")) }
        return node("button", values)
    }

    private func reset(_ label: String) -> AnyCodable {
        node("button", ["variant": "ghost", "size": "sm", "icon": "rotate-ccw", "label": .string(label), "action": .string(props.string("resetEvent", default: props.string("onReset")))])
    }

    private func count(_ entity: AnyCodable, color: String) -> AnyCodable {
        let display = size == "lg" ? "4xl" : (size == "sm" ? "2xl" : "3xl")
        return node("typography", ["variant": "h1", "size": .string(display), "color": .string(color), "align": "center", "content": .string(AtomKit.scalar(entity.dictValue?["count"]) ?? "0")])
    }

    private func tree(_ entity: AnyCodable) -> AnyCodable {
        let variant = props.string("variant", default: "standard")
        let title = node("typography", ["variant": "h2", "color": "muted", "align": "center", "content": .string(props.string("title", default: "Counter"))])
        if variant == "minimal" {
            return node("stack", [
                "direction": "horizontal", "gap": "lg", "align": "center", "justify": "center",
                "children": .array([step(entity, minus: true, label: true, variant: "secondary"), count(entity, color: "primary"), step(entity, minus: false, label: true, variant: "secondary")]),
            ])
        }
        let full = variant == "full"
        var column: [AnyCodable] = [title]
        if full {
            var figure: [AnyCodable] = [count(entity, color: "primary")]
            if !entity.string("rangeText").isEmpty {
                figure.append(node("typography", ["variant": "small", "color": "muted", "align": "center", "content": .string(entity.string("rangeText"))]))
            }
            column.append(node("stack", ["direction": "vertical", "gap": "sm", "align": "center", "children": .array(figure)]))
        } else {
            column.append(count(entity, color: "primary"))
        }
        column.append(node("stack", [
            "direction": "horizontal", "gap": "md", "align": "center", "justify": "center",
            "children": .array([step(entity, minus: true, label: full, variant: "secondary"), step(entity, minus: false, label: full, variant: "primary")]),
        ]))
        if props.bool("showReset", default: true) { column.append(reset(full ? "Reset to 0" : "Reset")) }
        return node("container", [
            "size": "sm",
            "padding": "lg",
            "children": .array([node("stack", ["direction": "vertical", "gap": .string(full ? "xl" : "lg"), "align": "center", "children": .array(column)])]),
        ])
    }
}

@ViewBuilder
func CounterTemplateRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CounterTemplateView(props: props, onEvent: onEvent))
}
