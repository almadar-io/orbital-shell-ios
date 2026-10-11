import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct PageHeaderMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let breadcrumbs = props.dictValue?["breadcrumbs"]?.arrayValue ?? []
        let status = status()
        let actions = (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        let visible = sizeClass == .compact ? 1 : 2
        let subtitle = AtomKit.scalar(props.dictValue?["subtitle"]) ?? ""
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            if !breadcrumbs.isEmpty {
                BreadcrumbRenderer(props: ["items": .array(breadcrumbs)], modifier: nil, onEvent: onEvent)
            }
            AtomFlowLayout(spacing: theme.density.spacing.space4) {
                HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                    if props.bool("showBack") {
                        ButtonRenderer(props: AtomKit.child(props, ["variant": "ghost", "icon": "arrow-left", "aria-label": "Back", "action": .string(props.string("backEvent", default: "BACK"))]), modifier: nil, onEvent: onEvent)
                    }
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        HStack(spacing: theme.density.spacing.space3) {
                            if !props.string("icon").isEmpty { AtomKit.icon(props.string("icon"), "lg", color: "muted", onEvent: onEvent) }
                            AtomKit.typo(AtomKit.scalar(props.dictValue?["title"]) ?? "", "h1", onEvent: onEvent)
                            if let status = status { AtomKit.badge(status.label, status.variant, onEvent: onEvent) }
                        }
                        if !subtitle.isEmpty { AtomKit.typo(subtitle, "small", color: "muted", onEvent: onEvent) }
                    }
                }
                if !actions.isEmpty {
                    HStack(spacing: theme.density.spacing.space2) {
                        ForEach(Array(actions.prefix(visible).enumerated()), id: \.offset) { pair in
                            ButtonRenderer(props: actionProps(pair.element, index: pair.offset), modifier: nil, onEvent: onEvent)
                        }
                        if actions.count > visible {
                            Menu {
                                ForEach(Array(actions.dropFirst(visible).enumerated()), id: \.offset) { pair in
                                    ButtonRenderer(props: actionProps(pair.element, index: pair.offset + visible), modifier: nil, onEvent: onEvent)
                                }
                            } label: {
                                AtomKit.icon("more-horizontal", "sm", label: "Actions", onEvent: onEvent)
                                    .frame(minWidth: theme.density.buttonHeightSm, minHeight: theme.density.buttonHeightSm)
                            }
                            .verificationId(VerificationIds.actionOverflow)
                        }
                    }
                }
            }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status() -> (label: String, variant: String)? {
        guard let raw = props.dictValue?["status"] else { return nil }
        if let text = raw.stringValue { return text.isEmpty ? nil : (text, "default") }
        let label = raw.string("label")
        return label.isEmpty ? nil : (label, raw.string("variant", default: "default"))
    }

    private func actionProps(_ action: AnyCodable, index: Int) -> AnyCodable {
        let routed = AtomKit.route(action, row: nil)
        return AtomKit.child(props, [
            "variant": .string(action.string("variant", default: index == 0 ? "primary" : "secondary")),
            "label": .string(action.string("label")),
            "leftIcon": .string(action.string("icon")),
            "action": .string(routed.event),
            "actionPayload": routed.payload ?? .null,
            "isLoading": .bool(action.bool("loading") || props.bool("isLoading")),
            "disabled": .bool(action.bool("disabled")),
        ])
    }
}

@ViewBuilder
func PageHeaderRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PageHeaderMoleculeView(props: props, onEvent: onEvent))
}
