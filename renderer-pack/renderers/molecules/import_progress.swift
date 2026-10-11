import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ImportProgressMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private static let pipeline = ["fetching", "mapping", "reviewing", "committing"]
    private static let defaults = ["fetching": "Fetching", "mapping": "Mapping", "reviewing": "Reviewing", "committing": "Committing", "done": "Done", "failed": "Failed"]

    private func label(_ key: String) -> String {
        let given = props.dictValue?["labels"]?.string(key) ?? ""
        return given.isEmpty ? (Self.defaults[key] ?? key) : given
    }

    private func rule() -> some View {
        theme.color.border.frame(width: theme.density.spacing.space4, height: theme.geometry.borderHairline)
    }

    private func count(_ key: String) -> Int? {
        props.dictValue?["counts"]?.dictValue?[key]?.intValue
    }

    var body: some View {
        let step = props.string("step")
        let finished = step == "done" || step == "failed"
        let current = finished ? Self.pipeline.count : (Self.pipeline.firstIndex(of: step) ?? -1)
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.density.spacing.space2) {
                ForEach(Self.pipeline.indices, id: \.self) { index in
                    let key = Self.pipeline[index]
                    let complete = index < current
                    let active = index == current
                    if index > 0 { rule() }
                    HStack(spacing: theme.density.spacing.space1) {
                        AtomKit.icon(complete ? "check" : (active ? "loader" : "circle"), "sm", color: complete ? "success" : (active ? "primary" : "muted"), onEvent: onEvent)
                        AtomKit.typo(label(key), "caption", color: active ? "primary" : "muted", onEvent: onEvent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
                if finished {
                    rule()
                    HStack(spacing: theme.density.spacing.space1) {
                        AtomKit.icon(step == "done" ? "check" : "x", "sm", color: step == "done" ? "success" : "error", onEvent: onEvent)
                        AtomKit.typo(label(step), "caption", color: step == "done" ? "success" : "error", onEvent: onEvent)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            }
            if props.dictValue?["counts"] != nil {
                HStack(spacing: theme.density.spacing.space2) {
                    if let staged = count("staged") { AtomKit.badge("Staged \(staged)", "default", size: "sm", onEvent: onEvent) }
                    if let committed = count("committed") { AtomKit.badge("Committed \(committed)", "success", size: "sm", onEvent: onEvent) }
                    if let failed = count("failed") { AtomKit.badge("Failed \(failed)", "danger", size: "sm", onEvent: onEvent) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ImportProgressRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ImportProgressMoleculeView(props: props, onEvent: onEvent))
}
