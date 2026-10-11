import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FormSectionHeaderMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let hasErrors = props.bool("hasErrors")
        let complete = props.bool("isComplete")
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        BoxRenderer(
            props: AtomKit.child(props, [
                "paddingX": "lg",
                "paddingY": "md",
                "bg": "muted",
                "border": true,
                "rounded": "xl",
                "fullWidth": true,
                "action": .string(props.string("onToggle")),
                "children": .array([row(hasErrors: hasErrors, complete: complete)]),
            ]),
            modifier: nil,
            onEvent: onEvent
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.color.primary).frame(width: theme.geometry.borderHeavy)
        }
        .clipShape(shape)
        .accessibilityElement(children: .contain)
    }

    private func row(hasErrors: Bool, complete: Bool) -> AnyCodable {
        let icon = props.string("icon")
        let badge = props.string("badge")
        var lead: [AnyCodable] = []
        if !icon.isEmpty { lead.append(AtomKit.node("icon", ["icon": .string(icon), "size": "md", "color": "primary"])) }
        if hasErrors {
            lead.append(AtomKit.node("icon", ["icon": "alert-circle", "size": "md", "color": "error"]))
        } else if complete {
            lead.append(AtomKit.node("icon", ["icon": "check-circle", "size": "md", "color": "success"]))
        }
        var titles: [AnyCodable] = [AtomKit.node("typography", ["variant": "subheading", "weight": "semibold", "content": .string(props.string("title"))])]
        if !props.string("subtitle").isEmpty {
            titles.append(AtomKit.node("typography", ["variant": "caption", "color": "muted", "content": .string(props.string("subtitle"))]))
        }
        lead.append(AtomKit.node("stack", ["direction": "vertical", "gap": "none", "align": "start", "children": .array(titles)]))
        var trail: [AnyCodable] = []
        if !badge.isEmpty {
            let variant = hasErrors ? "danger" : (complete ? "success" : props.string("badgeVariant", default: "default"))
            trail.append(AtomKit.node("badge", ["label": .string(badge), "variant": .string(variant), "size": "sm"]))
        }
        if !props.string("onToggle").isEmpty {
            trail.append(AtomKit.node("icon", ["icon": .string(props.bool("isCollapsed") ? "chevron-right" : "chevron-down"), "size": "sm", "color": "muted"]))
        }
        return AtomKit.node("stack", [
            "direction": "horizontal",
            "justify": "between",
            "align": "center",
            "children": .array([
                AtomKit.node("stack", ["direction": "horizontal", "gap": "sm", "align": "center", "children": .array(lead)]),
                AtomKit.node("stack", ["direction": "horizontal", "gap": "sm", "align": "center", "children": .array(trail)]),
            ]),
        ])
    }
}

@ViewBuilder
func FormSectionHeaderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormSectionHeaderMoleculeView(props: props, onEvent: onEvent))
}
