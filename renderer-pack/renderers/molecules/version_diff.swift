import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct VersionDiffMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var before: String
    @State private var after: String
    @State private var inline: Bool
    @State private var revealed: Set<Int> = []

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        let list = VersionDiffMoleculeView.revisions(props)
        _before = State(initialValue: props.string("beforeId", default: list.first?.string("id") ?? ""))
        _after = State(initialValue: props.string("afterId", default: list.dropFirst().first?.string("id") ?? list.first?.string("id") ?? ""))
        _inline = State(initialValue: props.string("view", default: "side-by-side") == "inline")
    }

    private static func revisions(_ props: AnyCodable) -> [AnyCodable] {
        (props.dictValue?["revisions"]?.arrayValue ?? []).filter { !$0.string("id").isEmpty && $0.dictValue?["label"] != nil && $0.dictValue?["content"] != nil }
    }

    private enum Row {
        case header(String)
        case line(AtomDiffLine)
        case gap(Int, Int)
    }

    private var revisions: [AnyCodable] { VersionDiffMoleculeView.revisions(props) }
    private var hunks: [AnyCodable]? { props.dictValue?["hunks"]?.arrayValue }
    private var activeBefore: String { props.string("beforeId", default: before) }
    private var activeAfter: String { props.string("afterId", default: after) }
    private var beforeRevision: AnyCodable? { revisions.first(where: { $0.string("id") == activeBefore }) ?? revisions.first }
    private var afterRevision: AnyCodable? { revisions.first(where: { $0.string("id") == activeAfter }) ?? (revisions.count > 1 ? revisions[1] : revisions.first) }

    private var rows: [Row] {
        if let hunks = hunks {
            return hunks.flatMap { hunk -> [Row] in
                [Row.header(hunk.string("header"))] + (hunk.dictValue?["lines"]?.arrayValue ?? []).map {
                    Row.line(AtomDiffLine(type: $0.string("type"), before: $0.dictValue?["beforeLineNumber"]?.intValue, after: $0.dictValue?["afterLineNumber"]?.intValue, content: $0.string("content")))
                }
            }
        }
        return AtomKit.lineDiff(beforeRevision?.string("content") ?? "", afterRevision?.string("content") ?? "").map { Row.line($0) }
    }

    private func collapsed(_ list: [Row]) -> [Row] {
        func unchanged(_ row: Row?) -> Bool {
            if case .some(.line(let line)) = row { return line.type == "unchanged" }
            return false
        }
        func isLine(_ row: Row?) -> Bool {
            if case .some(.line) = row { return true }
            return false
        }
        var out: [Row] = []
        var i = 0
        while i < list.count {
            if !unchanged(list[i]) {
                out.append(list[i])
                i += 1
                continue
            }
            var j = i
            while j < list.count && unchanged(list[j]) { j += 1 }
            let head = isLine(i > 0 ? list[i - 1] : nil) ? 3 : 0
            let tail = isLine(j < list.count ? list[j] : nil) ? 3 : 0
            let hidden = j - i - head - tail
            let id = i + head
            if hidden < 4 || revealed.contains(id) {
                out.append(contentsOf: list[i..<j])
            } else {
                out.append(contentsOf: list[i..<(i + head)])
                out.append(.gap(id, hidden))
                out.append(contentsOf: list[(j - tail)..<j])
            }
            i = j
        }
        return out
    }

    var body: some View {
        let all = rows
        let shown = collapsed(all)
        let added = all.filter { if case .line(let line) = $0 { return line.type == "added" } else { return false } }.count
        let removed = all.filter { if case .line(let line) = $0 { return line.type == "removed" } else { return false } }.count
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            toolbar(added: added, removed: removed)
            meta
            Group {
                if let hunks = hunks, hunks.isEmpty {
                    AtomKit.typo("No changes in this version.", "body2", color: "muted", align: "center", onEvent: onEvent)
                        .padding(.vertical, theme.density.spacing.space8)
                } else if !inline && sizeClass != .compact {
                    HStack(alignment: .top, spacing: theme.density.spacing.space0) {
                        column("before", shown)
                        Rectangle().fill(theme.color.border).frame(width: theme.geometry.borderHairline)
                        column("after", shown)
                    }
                } else if !inline {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                        column("before", shown)
                        Rectangle().fill(theme.color.border).frame(height: theme.geometry.borderHairline)
                        column("after", shown)
                    }
                } else {
                    column("inline", shown)
                }
            }
            .background(theme.color.muted.opacity(0.2))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Changes")
        }
        .background(theme.color.card)
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    private func toolbar(added: Int, removed: Int) -> some View {
        let options = revisions.map { AnyCodable.dict(["value": .string($0.string("id")), "label": .string($0.string("label"))]) }
        return AtomFlowLayout(spacing: theme.density.spacing.space2) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("git-commit", "sm", color: "muted", onEvent: onEvent)
                if hunks == nil {
                    AtomKit.typo("Compare", "small", weight: "medium", onEvent: onEvent)
                    picker(options, selected: activeBefore, name: "version-diff-before", label: "Before revision", event: props.string("selectBeforeEvent")) { before = $0 }
                    AtomKit.typo("to", "caption", color: "secondary", onEvent: onEvent)
                    picker(options, selected: activeAfter, name: "version-diff-after", label: "After revision", event: props.string("selectAfterEvent")) { after = $0 }
                }
                if !props.string("language").isEmpty { AtomKit.badge(props.string("language"), "default", onEvent: onEvent) }
                AtomKit.badge("+\(added)", "success", onEvent: onEvent)
                AtomKit.badge("-\(removed)", "error", onEvent: onEvent)
            }
            HStack(spacing: theme.density.spacing.space1) {
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "icon": .string(inline ? "columns" : "align-left"), "aria-label": .string(inline ? "Switch to side-by-side view" : "Switch to inline view"), "action": "version-diff-view", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in inline.toggle() }
                )
                if hunks == nil && !props.string("revertEvent").isEmpty, let revision = beforeRevision {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "leftIcon": "rotate-ccw", "label": "Revert", "action": .string(props.string("revertEvent")), "actionPayload": ["id": .string(revision.string("id"))]]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.vertical, theme.density.spacing.space2)
        .background(theme.color.muted.opacity(0.3))
    }

    private func picker(_ options: [AnyCodable], selected: String, name: String, label: String, event: String, set: @escaping (String) -> Void) -> some View {
        SelectRenderer(
            props: ["name": .string(name), "options": .array(options), "value": .string(selected), "aria-label": .string(label), "onChange": "version-diff-select"],
            modifier: nil,
            onEvent: { _, envelope in
                let id = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? ""
                set(id)
                if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["id": .string(id)])) }
            }
        )
        .frame(minWidth: sizeClass == .compact ? nil : AlmadarSizes.w40)
    }

    @ViewBuilder
    private var meta: some View {
        if hunks == nil, let first = beforeRevision, let second = afterRevision, [first, second].contains(where: { !$0.string("author").isEmpty || !$0.string("timestamp").isEmpty }) {
            HStack {
                AtomKit.typo(describe(first), "caption", color: "secondary", truncate: true, onEvent: onEvent)
                Spacer(minLength: theme.density.spacing.space2)
                AtomKit.typo(describe(second), "caption", color: "secondary", truncate: true, onEvent: onEvent)
            }
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.vertical, theme.density.spacing.space1)
        }
    }

    private func describe(_ revision: AnyCodable) -> String {
        revision.string("label") + (revision.string("author").isEmpty ? "" : " by \(revision.string("author"))") + (revision.string("timestamp").isEmpty ? "" : " (\(revision.string("timestamp")))")
    }

    private func column(_ side: String, _ list: [Row]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                ForEach(list.indices, id: \.self) { index in
                    switch list[index] {
                    case .header(let text):
                        AtomMonoText(text, size: "xs", color: theme.color.info)
                            .padding(.horizontal, theme.density.spacing.space3)
                            .padding(.vertical, theme.density.spacing.space1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.color.info.opacity(0.1))
                    case .gap(let id, let count):
                        ButtonRenderer(
                            props: ["variant": "ghost", "size": "sm", "icon": "chevrons-up-down", "label": .string("\(count) unchanged lines"), "action": .string("version-diff-gap-\(id)"), "local": true],
                            modifier: nil,
                            onEvent: { _, _ in revealed.insert(id) }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.color.muted.opacity(0.4))
                    case .line(let line):
                        if !(side == "before" && line.type == "added") && !(side == "after" && line.type == "removed") {
                            lineView(line, side: side)
                        }
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: theme.density.rowHeightSpacious * 12)
    }

    private func lineView(_ line: AtomDiffLine, side: String) -> some View {
        let changed = side == "inline" ? line.type == "added" || line.type == "removed" : (side == "before" ? line.type == "removed" : line.type == "added")
        let additive = line.type == "added"
        let number = side == "before" ? line.before : (side == "after" ? line.after : (line.after ?? line.before))
        let prefix = side == "inline" ? (additive ? "+" : (line.type == "removed" ? "-" : " ")) : ""
        let tint = changed ? (additive ? theme.color.success : theme.color.error) : theme.color.foreground
        return HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            AtomMonoText(number.map { String($0) } ?? "", size: "xs", color: theme.color.mutedForeground).frame(minWidth: theme.density.spacing.space8, alignment: .trailing)
            if !prefix.isEmpty { AtomMonoText(prefix, size: "xs", color: tint) }
            AtomMonoText(line.content.isEmpty ? " " : line.content, size: "xs", color: tint).fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, theme.density.spacing.space3)
        .padding(.vertical, theme.density.spacing.space1 / 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(changed ? tint.opacity(0.1) : AtomKit.clear(theme))
    }
}

@ViewBuilder
func VersionDiffRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(VersionDiffMoleculeView(props: props, onEvent: onEvent))
}
