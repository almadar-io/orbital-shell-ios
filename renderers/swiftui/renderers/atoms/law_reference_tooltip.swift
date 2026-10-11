import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct LawReferenceTooltipAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open = false

    var body: some View {
        let reference = props.dictValue?["reference"]?.dictValue ?? [:]
        let heading = [AtomKit.scalar(reference["law"]), AtomKit.scalar(reference["article"])].compactMap { $0 }.joined(separator: " ")
        let name = AtomKit.scalar(reference["lawName"]) ?? ""
        let clause = AtomKit.scalar(reference["clause"]) ?? ""
        let link = AtomKit.scalar(reference["link"]) ?? ""
        let above = props.string("position", default: "top") == "top"
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            if open && above { callout(heading: heading, name: name, clause: clause, link: link) }
            Button(action: { open.toggle() }) {
                HStack(spacing: theme.density.spacing.space1) {
                    AtomChildren(props: props, key: "children", onEvent: onEvent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(heading))
            if open && !above { callout(heading: heading, name: name, clause: clause, link: link) }
        }
        .animation(theme.motion.animation(for: theme.motion.hover), value: open)
    }

    @ViewBuilder
    private func callout(heading: String, name: String, clause: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            Text(heading).font(AtomKit.font(theme, "sm", .bold)).foregroundColor(theme.color.warning)
            if !name.isEmpty { Text(name).font(AtomKit.font(theme, "sm", .medium)) }
            if !clause.isEmpty { Text(clause).font(AtomKit.font(theme, "xs")) }
            if let url = URL(string: link), !link.isEmpty {
                Link(link, destination: url).font(AtomKit.font(theme, "xs"))
            }
        }
        .foregroundColor(theme.color.background)
        .padding(theme.density.spacing.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.foreground)
        .atomClip(theme, .container)
        .atomElevation(theme, .container, theme.elevation.popoverElevation)
        .accessibilityElement(children: .combine)
    }
}

@ViewBuilder
func LawReferenceTooltipRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(LawReferenceTooltipAtomView(props: props, onEvent: onEvent))
}
