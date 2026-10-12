import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

/// A captured key (or chord) is kept out of the text and emitted as UI:{onKey} — CodeBlock.tsx `handleEditableKeyDown`.
struct CodeBlockKeyCapture: ViewModifier {
    let props: AnyCodable
    let capturedKeys: Set<String>
    let onEvent: (String, AnyCodable?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onKeyPress(phases: [.down, .repeat]) { press in
                let keyEvent = props.string("onKey")
                let editorId = props.string("editorId")
                guard !keyEvent.isEmpty, !editorId.isEmpty else { return .ignored }
                let key = AtomKit.domKey(press)
                let ctrl = press.modifiers.contains(.control), alt = press.modifiers.contains(.option)
                let shift = press.modifiers.contains(.shift), meta = press.modifiers.contains(.command)
                guard capturedKeys.contains(key) || capturedKeys.contains(AtomKit.keyChord(key, ctrl: ctrl, alt: alt, shift: shift, meta: meta)) else { return .ignored }
                onEvent(keyEvent, eventEnvelope(props, payload: ["editorId": .string(editorId), "key": .string(key), "code": .string(AtomKit.domCode(key)), "ctrl": .bool(ctrl), "alt": .bool(alt), "shift": .bool(shift), "meta": .bool(meta), "repeat": .bool(press.phase == .repeat)]))
                return .handled
            }
        } else {
            content
        }
    }
}

struct CodeBlockMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var draft: String
    @State private var folded = false
    @State private var wrapped: Bool
    @State private var copied = false
    @State private var active = 0
    @FocusState private var focused: Bool
    @State private var capturedKeys: Set<String> = []
    private let shared: Binding<String>?

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void, text: Binding<String>? = nil) {
        self.props = props
        self.onEvent = onEvent
        self.shared = text
        _draft = State(initialValue: props.string("code"))
        _wrapped = State(initialValue: props.bool("wordWrap"))
    }

    private var files: [AnyCodable] { props.dictValue?["files"]?.arrayValue ?? [] }
    private var code: String { files.isEmpty ? (props.bool("editable") ? (shared?.wrappedValue ?? draft) : props.string("code")) : files[min(active, files.count - 1)].string("code") }
    private var language: String { files.isEmpty ? props.string("language", default: "text") : files[min(active, files.count - 1)].string("language", default: props.string("language", default: "text")) }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            SkeletonRenderer(props: ["spec": "text"], modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            AlertRenderer(props: ["variant": "error", "message": .string(error)], modifier: nil, onEvent: onEvent)
        } else {
            let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                toolbar
                if files.count > 1 { tabs }
                if !folded { content }
            }
            .background(theme.color.muted.opacity(0.3))
            .clipShape(shape)
            .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
            .accessibilityElement(children: .contain)
        }
    }

    private var toolbar: some View {
        let title = props.string("title")
        let copyable = props.dictValue?["showCopy"]?.boolValue ?? props.bool("showCopyButton", default: true)
        let actions = (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        return AtomFlowLayout(spacing: theme.density.spacing.space2) {
            HStack(spacing: theme.density.spacing.space2) {
                if props.bool("foldable") {
                    ButtonRenderer(
                        props: ["variant": "ghost", "size": "sm", "icon": .string(folded ? "chevron-right" : "chevron-down"), "aria-label": .string(folded ? "Expand code" : "Collapse code"), "action": "code-fold", "local": true],
                        modifier: nil,
                        onEvent: { _, _ in folded.toggle() }
                    )
                }
                if !title.isEmpty { AtomKit.typo(title, "small", weight: "medium", onEvent: onEvent) }
                if props.bool("showLanguageBadge", default: true) && !language.isEmpty { AtomKit.badge(language, "default", onEvent: onEvent) }
            }
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(actions.indices, id: \.self) { index in
                    ButtonRenderer(props: AtomKit.actionProps(props, actions[index], row: nil, size: "sm", fallback: "secondary"), modifier: nil, onEvent: onEvent)
                }
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "icon": "wrap-text", "aria-label": .string(wrapped ? "Disable word wrap" : "Enable word wrap"), "action": "code-wrap", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in wrapped.toggle() }
                )
                if copyable {
                    ButtonRenderer(
                        props: ["variant": "ghost", "size": "sm", "icon": .string(copied ? "check" : "copy"), "aria-label": .string(copied ? "Copied" : "Copy code"), "action": "code-copy", "local": true],
                        modifier: nil,
                        onEvent: { _, _ in
                            UIPasteboard.general.string = code
                            copied = true
                        }
                    )
                }
            }
        }
        .padding(.horizontal, theme.density.spacing.space3)
        .padding(.vertical, theme.density.spacing.space1)
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.density.spacing.space1) {
                ForEach(files.indices, id: \.self) { index in
                    ButtonRenderer(
                        props: ["variant": .string(index == active ? "secondary" : "ghost"), "size": "sm", "label": .string(files[index].string("label")), "action": .string("code-file-\(index)"), "local": true],
                        modifier: nil,
                        onEvent: { _, _ in active = index }
                    )
                    .accessibilityAddTraits(index == active ? .isSelected : [])
                }
            }
            .padding(.horizontal, theme.density.spacing.space2)
        }
    }

    private var limit: CGFloat {
        let raw = props.string("maxHeight", default: "60vh")
        if raw.hasSuffix("vh"), let percent = Double(raw.dropLast(2)) { return UIScreen.main.bounds.height * CGFloat(percent / 100) }
        return AtomKit.length(raw) ?? UIScreen.main.bounds.height * 0.6
    }

    private var diffLines: [AtomDiffLine]? {
        let declared = props.dictValue?["diff"]?.arrayValue ?? []
        if !declared.isEmpty {
            return declared.map { AtomDiffLine(type: $0.string("type"), before: nil, after: $0.dictValue?["lineNumber"]?.intValue, content: $0.string("content")) }
        }
        if props.string("mode") == "diff" || props.dictValue?["oldValue"] != nil || props.dictValue?["newValue"] != nil {
            return AtomKit.lineDiff(props.string("oldValue"), props.string("newValue"))
        }
        return nil
    }

    @ViewBuilder
    private var content: some View {
        if props.bool("editable") && files.isEmpty {
            TextEditor(text: shared ?? $draft)
                .font(AtomKit.font(theme, "xs", .regular, mono: true))
                .scrollContentBackground(.hidden)
                .focused($focused)
                .frame(minHeight: theme.density.rowHeightSpacious * 4, maxHeight: limit)
                .padding(theme.density.spacing.space2)
                .onChange(of: focused) { isFocused in
                    let event = props.string(isFocused ? "onEditorFocus" : "onEditorBlur", default: isFocused ? "EDITOR_FOCUS" : "EDITOR_BLUR")
                    if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["editorId": .string(props.string("editorId"))])) }
                }
                .onReceive(AlmadarBus.shared.events) { bus in
                    // CodeBlock.tsx useEditorCapabilities: the latest SET_MODE for this editor names the keys it captures.
                    guard bus.event == props.string("onSetMode", default: "SET_MODE"), bus.payload?.string("editorId") == props.string("editorId") else { return }
                    capturedKeys = Set((bus.payload?.dictValue?["keys"]?.arrayValue ?? []).compactMap { $0.stringValue })
                }
                .modifier(CodeBlockKeyCapture(props: props, capturedKeys: capturedKeys, onEvent: onEvent))
        } else if code.isEmpty && diffLines == nil {
            AtomKit.typo("Nothing to show", "small", color: "muted", align: "center", onEvent: onEvent)
                .padding(theme.density.spacing.space4)
        } else {
            let marked = props.dictValue?["errorLines"]?.dictValue ?? [:]
            let numbered = props.bool("showLineNumbers") || props.bool("lineNumbers")
            let shown = diffLines.map { lines in lines.map { (text: $0.content, kind: $0.type, number: $0.after ?? $0.before) } }
                ?? code.components(separatedBy: "\n").enumerated().map { (text: $0.element, kind: "plain", number: Optional($0.offset + 1)) }
            ScrollView(wrapped ? .vertical : [.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                    ForEach(shown.indices, id: \.self) { index in
                        let line = shown[index]
                        let tone = marked[String(line.number ?? 0)]?.stringValue ?? ""
                        HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                            if numbered { AtomMonoText(line.number.map { String($0) } ?? "", size: "xs", color: theme.color.mutedForeground).frame(minWidth: theme.density.spacing.space8, alignment: .trailing) }
                            if line.kind != "plain" { AtomMonoText(prefix(line.kind), size: "xs", color: tint(line.kind)) }
                            AtomMonoText(line.text.isEmpty ? " " : line.text, size: "xs", color: line.kind == "plain" ? nil : tint(line.kind))
                                .fixedSize(horizontal: !wrapped, vertical: true)
                        }
                        .frame(maxWidth: wrapped ? .infinity : nil, alignment: .leading)
                        .padding(.horizontal, theme.density.spacing.space3)
                        .background(background(line.kind, tone: tone))
                    }
                }
                .padding(.vertical, theme.density.spacing.space2)
            }
            .frame(maxHeight: limit)
        }
    }

    private func prefix(_ kind: String) -> String {
        switch kind {
        case "add", "added": return "+"
        case "remove", "removed": return "-"
        default: return " "
        }
    }

    private func tint(_ kind: String) -> Color {
        switch kind {
        case "add", "added": return theme.color.success
        case "remove", "removed": return theme.color.error
        default: return theme.color.foreground
        }
    }

    private func background(_ kind: String, tone: String) -> Color {
        if tone == "error" { return theme.color.error.opacity(0.15) }
        if tone == "warning" { return theme.color.warning.opacity(0.15) }
        switch kind {
        case "add", "added": return theme.color.success.opacity(0.1)
        case "remove", "removed": return theme.color.error.opacity(0.1)
        default: return AtomKit.clear(theme)
        }
    }
}

@ViewBuilder
func CodeBlockRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CodeBlockMoleculeView(props: props, onEvent: onEvent))
}
