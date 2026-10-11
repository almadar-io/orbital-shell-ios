import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct WizardProgressMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var titles: [String] {
        (props.dictValue?["steps"]?.arrayValue ?? []).map { $0.stringValue ?? $0.string("title") }
    }

    var body: some View {
        let compact = props.bool("compact")
        VStack(spacing: theme.density.spacing.space0) {
            ViewThatFits(in: .horizontal) {
                row(showAll: true, compact: compact)
                row(showAll: false, compact: compact)
            }
            .padding(.horizontal, compact ? theme.density.spacing.space4 : theme.density.spacing.space6)
            .padding(.vertical, compact ? theme.density.spacing.space2 : theme.density.spacing.space4)
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        }
        .accessibilityElement(children: .contain)
    }

    private func row(showAll: Bool, compact: Bool) -> some View {
        let current = props.int("currentStep")
        let list = titles
        return HStack(spacing: theme.density.spacing.space2) {
            ForEach(list.indices, id: \.self) { index in
                marker(index, current: current, total: list.count, title: list[index], compact: compact)
                if !compact && (showAll || index == current) {
                    AtomKit.typo(list[index], "small", color: index == current ? "primary" : "muted", weight: "medium", truncate: true, onEvent: onEvent)
                }
                if index < list.count - 1 {
                    Rectangle()
                        .fill(index < current ? theme.color.primary : theme.color.border)
                        .frame(minWidth: theme.density.spacing.space4, maxWidth: .infinity, minHeight: theme.geometry.borderHeavy * 2, maxHeight: theme.geometry.borderHeavy * 2)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func marker(_ index: Int, current: Int, total: Int, title: String, compact: Bool) -> some View {
        let completed = index < current
        let navigable = completed && props.bool("allowNavigation", default: true)
        var values: [String: AnyCodable] = [
            "variant": completed || index == current ? "primary" : "secondary",
            "size": "sm",
            "disabled": .bool(!navigable),
            "aria-label": .string("Step \(index + 1) of \(total): \(title)"),
        ]
        if completed { values["icon"] = "check" } else { values["label"] = .string("\(index + 1)") }
        if navigable {
            values["action"] = .string(props.string("stepClickEvent"))
            values["actionPayload"] = ["stepIndex": .int(index)]
        }
        return ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: onEvent)
            .clipShape(Circle())
            .accessibilityAddTraits(index == current ? .isSelected : [])
    }
}

@ViewBuilder
func WizardProgressRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(WizardProgressMoleculeView(props: props, onEvent: onEvent))
}
