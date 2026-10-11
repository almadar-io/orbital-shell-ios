import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct FileTreeMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open: Set<String>
    @State private var picked: String?

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        var start = Set(AtomKit.strings(props, "expandedPaths"))
        for root in props.dictValue?["tree"]?.arrayValue ?? [] where root.string("type") == "dir" { start.insert(root.string("path")) }
        let items = props.dictValue?["items"]?.arrayValue ?? []
        let known = Set(items.map { $0.string("id") })
        for item in items where item.string("parentId").isEmpty || !known.contains(item.string("parentId")) { start.insert(item.string("id")) }
        _open = State(initialValue: start)
    }

    private var indent: CGFloat { CGFloat(props.float("indent", default: 16)) }

    var body: some View {
        let tree = props.dictValue?["tree"]?.arrayValue ?? []
        let items = props.dictValue?["items"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            ForEach(tree.indices, id: \.self) { index in node(tree[index], depth: 0) }
            if tree.isEmpty { flat(items) }
        }
        .padding(.vertical, theme.density.spacing.space1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func glyph(_ name: String) -> String {
        switch (name.split(separator: ".").last.map { String($0).lowercased() } ?? "") {
        case "ts", "tsx", "js", "jsx", "py", "html": return "file-code"
        case "json", "orb": return "file-json"
        case "css", "scss", "md": return "file-text"
        default: return "file"
        }
    }

    private func size(_ bytes: Int) -> String {
        bytes < 1024 ? "\(bytes)B" : "\(Int((Double(bytes) / 1024).rounded()))KB"
    }

    private func node(_ node: AnyCodable, depth: Int) -> AnyView {
        let path = node.string("path")
        let directory = node.string("type") == "dir"
        let children = node.dictValue?["children"]?.arrayValue ?? []
        let expandable = directory || !children.isEmpty || node.bool("expandable")
        let isOpen = open.contains(path)
        let chosen = (props.string("selectedPath").isEmpty ? picked : props.string("selectedPath")) == path
        return AnyView(VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space1) {
                if expandable { AtomKit.icon(isOpen ? "chevron-down" : "chevron-right", "xs", color: "muted", onEvent: onEvent) } else { Spacer().frame(width: theme.density.spacing.space3) }
                AtomKit.icon(directory ? (isOpen ? "folder-open" : "folder") : glyph(node.string("name")), "xs", color: directory ? "warning" : "muted", onEvent: onEvent)
                AtomMonoText(node.string("name"), size: "xs").fontWeight(chosen ? .semibold : .regular).lineLimit(1)
                if !node.string("note").isEmpty { AtomKit.typo(node.string("note"), "caption", color: "muted", onEvent: onEvent) }
                if !directory, node.dictValue?["size"] != nil {
                    Spacer(minLength: theme.density.spacing.space2)
                    AtomKit.typo(size(node.int("size")), "caption", color: "muted", onEvent: onEvent)
                }
            }
            .padding(.leading, CGFloat(depth) * indent + theme.density.spacing.space2)
            .padding(.vertical, theme.density.spacing.space1 / 2)
            .padding(.trailing, theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chosen ? theme.color.primary.opacity(0.15) : AtomKit.clear(theme))
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
            .contentShape(Rectangle())
            .onTapGesture {
                if directory {
                    if isOpen { open.remove(path) } else { open.insert(path) }
                } else {
                    picked = path
                    onEvent("fileSelect", eventEnvelope(props, payload: ["path": .string(path), "name": .string(node.string("name")), "type": .string(node.string("type"))]))
                }
            }
            .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            .accessibilityValue(expandable ? (isOpen ? "expanded" : "collapsed") : "")
            .verificationContainer(VerificationIds.row(path))
            if expandable && isOpen {
                ForEach(children.indices, id: \.self) { index in self.node(children[index], depth: depth + 1) }
            }
        })
    }

    private func flat(_ items: [AnyCodable]) -> some View {
        let known = Set(items.map { $0.string("id") })
        let roots = items.filter { $0.string("parentId").isEmpty || !known.contains($0.string("parentId")) }
        return VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            ForEach(roots.indices, id: \.self) { index in item(roots[index], all: items, depth: 0) }
        }
    }

    private func item(_ item: AnyCodable, all: [AnyCodable], depth: Int) -> AnyView {
        let id = item.string("id")
        let children = all.filter { $0.string("parentId") == id }
        let isOpen = open.contains(id) || (depth > 0 && open.contains(id))
        let chosen = (props.string("selectedId").isEmpty ? picked : props.string("selectedId")) == id
        let nav = props.string("look", default: "files") == "nav"
        let glyph = item.string("icon", default: nav ? "file-text" : (children.isEmpty ? "file" : (isOpen ? "folder-open" : "folder")))
        return AnyView(VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space1) {
                if !children.isEmpty { AtomKit.icon(isOpen ? "chevron-down" : "chevron-right", "xs", color: "muted", onEvent: onEvent) } else { Spacer().frame(width: theme.density.spacing.space3) }
                AtomKit.icon(glyph, "xs", color: "muted", onEvent: onEvent)
                AtomKit.typo(item.string("label"), "caption", truncate: true, onEvent: onEvent)
            }
            .padding(.leading, CGFloat(depth) * indent + theme.density.spacing.space2)
            .padding(.vertical, nav ? theme.density.spacing.space1 : theme.density.spacing.space1 / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chosen ? theme.color.primary.opacity(0.15) : AtomKit.clear(theme))
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
            .contentShape(Rectangle())
            .onTapGesture {
                if !children.isEmpty {
                    if isOpen { open.remove(id) } else { open.insert(id) }
                }
                picked = id
                onEvent("nodeSelect", eventEnvelope(props, payload: ["id": .string(id)]))
            }
            .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            .verificationContainer(VerificationIds.row(id))
            if !children.isEmpty && isOpen {
                ForEach(children.indices, id: \.self) { index in self.item(children[index], all: all, depth: depth + 1) }
            }
        })
    }
}

@ViewBuilder
func FileTreeRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FileTreeMoleculeView(props: props, onEvent: onEvent))
}
