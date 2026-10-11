import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ImportPreviewTreeMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var units: [AnyCodable] { props.dictValue?["units"]?.arrayValue ?? [] }
    private var skipped: [AnyCodable] { props.dictValue?["skipped"]?.arrayValue ?? [] }

    private func formatted(_ value: AnyCodable) -> String {
        switch value {
        case .null: return "—"
        case .array(let items): return items.map { formatted($0) }.joined(separator: ", ")
        case .dict:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        default: return AtomKit.scalar(value) ?? ""
        }
    }

    private func title(_ unit: AnyCodable) -> String {
        let given = unit.string("title")
        return given.isEmpty ? unit.string("ref") : given
    }

    private func summary(_ unit: AnyCodable) -> String {
        let fields = unit.dictValue?["fields"]?.dictValue ?? [:]
        return fields.keys.sorted().map { "\($0): \(formatted(fields[$0] ?? .null))" }.joined(separator: " · ")
    }

    private func groups() -> [(entity: String, units: [AnyCodable])] {
        var order: [String] = []
        var byEntity: [String: [AnyCodable]] = [:]
        for unit in units {
            let entity = unit.string("targetEntity")
            if byEntity[entity] == nil { order.append(entity) }
            byEntity[entity, default: []].append(unit)
        }
        return order.map { (entity: $0, units: byEntity[$0] ?? []) }
    }

    private func rows(_ group: [AnyCodable]) -> [(unit: AnyCodable, depth: Int)] {
        let refs = Set(group.map { $0.string("ref") })
        var children: [String: [AnyCodable]] = [:]
        var roots: [AnyCodable] = []
        for unit in group {
            let parent = unit.string("parentRef")
            if !parent.isEmpty && refs.contains(parent) { children[parent, default: []].append(unit) } else { roots.append(unit) }
        }
        var out: [(unit: AnyCodable, depth: Int)] = []
        func walk(_ unit: AnyCodable, _ depth: Int) {
            out.append((unit: unit, depth: depth))
            for child in children[unit.string("ref")] ?? [] { walk(child, depth + 1) }
        }
        roots.forEach { walk($0, 0) }
        return out
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) { content() }
            .padding(theme.density.spacing.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(props.string("surface", default: "auto") == "none" ? AtomKit.clear(theme) : theme.color.card)
            .atomClip(theme, .container)
            .atomBorder(theme, .container, color: theme.color.border, width: theme.geometry.borderStandard)
    }

    private func heading(_ label: String, _ count: Int) -> some View {
        HStack(spacing: theme.density.spacing.space2) {
            AtomKit.typo(label, "label", onEvent: onEvent)
            AtomKit.badge("\(count)", "default", size: "sm", onEvent: onEvent)
        }
        .padding(.bottom, theme.density.spacing.space2)
    }

    var body: some View {
        let indent = CGFloat(props.dictValue?["indent"]?.doubleValue ?? 16)
        let confirm = props.string("onConfirm")
        let cancel = props.string("onCancel")
        let display = props.dictValue?["entityDisplay"]
        VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
            if units.isEmpty {
                AtomKit.typo("No units staged.", "body2", color: "muted", onEvent: onEvent)
            }
            ForEach(groups().indices, id: \.self) { groupIndex in
                let group = groups()[groupIndex]
                let label = display?.dictValue?[group.entity]?.string("plural") ?? ""
                let flat = rows(group.units)
                tile {
                    heading(label.isEmpty ? group.entity : label, group.units.count)
                    ForEach(flat.indices, id: \.self) { rowIndex in
                        let row = flat[rowIndex]
                        let line = summary(row.unit)
                        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                            HStack(spacing: theme.density.spacing.space2) {
                                AtomKit.icon("file-text", "xs", color: "muted", onEvent: onEvent)
                                AtomKit.typo(title(row.unit), "body2", onEvent: onEvent)
                            }
                            if !line.isEmpty { AtomKit.typo(line, "caption", color: "muted", onEvent: onEvent) }
                        }
                        .padding(.vertical, theme.density.spacing.space1)
                        .padding(.leading, CGFloat(row.depth) * indent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if !skipped.isEmpty {
                tile {
                    heading("Skipped", skipped.count)
                    ForEach(skipped.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: theme.density.spacing.space2) {
                            AtomKit.typo(skipped[index].string("ref"), "body2", onEvent: onEvent)
                            AtomKit.typo(skipped[index].string("reason"), "caption", color: "muted", onEvent: onEvent)
                        }
                        .padding(.vertical, theme.density.spacing.space1)
                    }
                }
            }
            if !confirm.isEmpty || !cancel.isEmpty {
                HStack(spacing: theme.density.spacing.space2) {
                    Spacer(minLength: theme.density.spacing.space0)
                    if !cancel.isEmpty {
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "default", "label": .string(props.string("cancelLabel", default: "Cancel")), "action": .string(cancel)]),
                            modifier: nil,
                            onEvent: onEvent
                        )
                    }
                    if !confirm.isEmpty {
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "primary", "label": .string(props.string("confirmLabel", default: "Confirm import")), "action": .string(confirm)]),
                            modifier: nil,
                            onEvent: onEvent
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ImportPreviewTreeRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ImportPreviewTreeMoleculeView(props: props, onEvent: onEvent))
}
