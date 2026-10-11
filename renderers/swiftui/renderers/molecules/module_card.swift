import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ModuleCardMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var data: AnyCodable { props.dictValue?["data"] ?? .dict([:]) }

    private func list(_ node: AnyCodable?, _ key: String) -> [AnyCodable] { node?.dictValue?[key]?.arrayValue ?? [] }

    private func persistenceIcon(_ kind: String) -> String {
        switch kind {
        case "persistent": return "database"
        case "runtime": return "refresh-cw"
        case "singleton": return "circle-dot"
        default: return "square"
        }
    }

    var body: some View {
        let fields = list(data, "fields")
        let traits = list(data, "traits")
        let pages = list(data, "pages")
        let links = list(data, "externalLinks")
        let persistence = data.string("persistence")
        let columns = min(3, max(2, Int((Double(fields.count) / 3).rounded(.up))))
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomKit.typo(data.string("orbitalName"), "body1", weight: "bold", onEvent: onEvent)
                .padding(.horizontal, theme.density.spacing.space3)
                .padding(.vertical, theme.density.spacing.space2)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                HStack(spacing: theme.density.spacing.space2) {
                    AtomKit.icon(persistenceIcon(persistence), "sm", color: "primary", label: persistence, onEvent: onEvent)
                    AtomKit.typo(data.string("entityName"), "small", weight: "semibold", onEvent: onEvent)
                    Spacer(minLength: theme.density.spacing.space0)
                    AtomKit.badge(persistence, "default", onEvent: onEvent)
                }
                if !fields.isEmpty {
                    AtomGridLayout(minWidth: theme.density.spacing.space12, maxColumns: 0, fixedColumns: columns, spacing: theme.density.spacing.space2) {
                        ForEach(fields.indices, id: \.self) { index in
                            HStack(spacing: theme.density.spacing.space1) {
                                AtomKit.badge(fields[index].string("type"), "default", onEvent: onEvent)
                                AtomKit.typo(fields[index].string("name"), "caption", color: "muted", truncate: true, onEvent: onEvent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(fields[index].string("name") + ": " + fields[index].string("type"))
                        }
                    }
                }
            }
            .padding(theme.density.spacing.space3)
            ForEach(traits.indices, id: \.self) { index in
                let trait = traits[index]
                let name = trait.string("name")
                let detail = data.dictValue?["traitDetails"]?.dictValue?[name]
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    AtomKit.typo(name, "caption", weight: "semibold", onEvent: onEvent)
                    ForEach(list(detail, "transitions").indices, id: \.self) { position in
                        let step = list(detail, "transitions")[position]
                        AtomKit.typo(step.string("from") + " \u{2192} " + step.string("to") + "  (" + step.string("event") + ")", "caption", color: "muted", onEvent: onEvent)
                    }
                    ForEach(links.filter { $0.string("traitName") == name }.indices, id: \.self) { position in
                        let link = links.filter { $0.string("traitName") == name }[position]
                        AtomKit.typo((link.string("direction") == "in" ? "\u{25C0} " : "\u{25B6} ") + link.string("eventName"), "caption", color: "primary", onEvent: onEvent)
                    }
                }
                .padding(theme.density.spacing.space3)
            }
            if !pages.isEmpty {
                DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                AtomFlowLayout(spacing: theme.density.spacing.space2) {
                    ForEach(pages.indices, id: \.self) { index in
                        AtomKit.typo(pages[index].string("route"), "caption", color: "muted", onEvent: onEvent)
                    }
                }
                .padding(theme.density.spacing.space3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.card)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ModuleCardRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ModuleCardMoleculeView(props: props, onEvent: onEvent))
}
