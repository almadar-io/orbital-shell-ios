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
        if CodeBufferModel.isActive(props) {
            CodeBufferView(props: props, onEvent: onEvent)
        } else if props.bool("editable") && files.isEmpty {
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

struct CodeBufferCell: Equatable {
    let row: Int
    let col: Int
}

struct CodeBufferSelection {
    let fromRow: Int, fromCol: Int, toRow: Int, toCol: Int
    let linewise: Bool
}

struct CodeBufferDecoration {
    let id: String
    let fromRow: Int, fromCol: Int, toRow: Int, toCol: Int
    let tone: String
    let label: String
}

struct CodeBufferPopover {
    struct Section { let heading: String; let lines: [String] }
    let fromRow: Int, fromCol: Int
    let title: String
    let sections: [Section]
    let busy: Bool
}

struct CodeBufferCellStyle: Equatable {
    var foreground: String?
    var background: String?
}

struct CodeBufferRun: Equatable {
    let text: String
    let foreground: String?
}

/// Buffer-mode contract (CodeBlock.tsx `CodeCursor` and siblings): every row and column is zero-based and a column counts Unicode scalars.
struct CodeBufferModel {
    static let syntaxTones: Set<String> = ["keyword", "string", "comment", "number", "type", "function", "operator", "punctuation", "variable"]
    static let annotationTones: Set<String> = ["search", "review", "review-recent", "error", "warning", "info"]

    let lines: [[Unicode.Scalar]]
    let cursor: CodeBufferCell
    let caret: String
    let selection: CodeBufferSelection?
    let decorations: [CodeBufferDecoration]
    let popover: CodeBufferPopover?
    let relative: Bool

    static func isActive(_ props: AnyCodable) -> Bool {
        props.dictValue?["cursor"]?.dictValue != nil
    }

    init(_ props: AnyCodable) {
        lines = props.string("code").components(separatedBy: "\n").map { Array($0.unicodeScalars) }
        let at = props.dictValue?["cursor"]
        cursor = CodeBufferCell(row: at?.dictValue?["row"]?.intValue ?? 0, col: at?.dictValue?["col"]?.intValue ?? 0)
        caret = props.string("caret", default: "block")
        relative = props.bool("relativeLineNumbers")
        if let range = props.dictValue?["selection"], range.dictValue != nil {
            selection = CodeBufferSelection(fromRow: range.int("fromRow"), fromCol: range.int("fromCol"), toRow: range.int("toRow"), toCol: range.int("toCol"), linewise: range.bool("linewise"))
        } else {
            selection = nil
        }
        decorations = (props.dictValue?["decorations"]?.arrayValue ?? []).map {
            CodeBufferDecoration(id: $0.string("id"), fromRow: $0.int("fromRow"), fromCol: $0.int("fromCol"), toRow: $0.int("toRow"), toCol: $0.int("toCol"), tone: $0.string("tone"), label: $0.string("label"))
        }
        if let note = props.dictValue?["popover"], note.dictValue != nil {
            popover = CodeBufferPopover(
                fromRow: note.int("fromRow"), fromCol: note.int("fromCol"), title: note.string("title"),
                sections: (note.dictValue?["sections"]?.arrayValue ?? []).map {
                    CodeBufferPopover.Section(heading: $0.string("heading"), lines: ($0.dictValue?["lines"]?.arrayValue ?? []).compactMap { $0.stringValue })
                },
                busy: note.bool("busy")
            )
        } else {
            popover = nil
        }
    }

    var columns: Int { max(lines.map { $0.count }.max() ?? 0, cursor.col) + 1 }

    func length(_ row: Int) -> Int { row >= 0 && row < lines.count ? lines[row].count : 0 }

    /// Gutter text per line: absolute 1-based numbers, or the distance from the cursor row with the cursor row keeping its own number.
    var gutter: [String] {
        lines.indices.map { relative && $0 != cursor.row ? String(abs($0 - cursor.row)) : String($0 + 1) }
    }

    /// The painted cell range of a row for the selection: the max end is inclusive, a row left before the max end includes its line-end cell.
    func selectionSpan(row: Int) -> Range<Int>? {
        guard let range = selection else { return nil }
        let forward = (range.fromRow, range.fromCol) <= (range.toRow, range.toCol)
        let first = forward ? (range.fromRow, range.fromCol) : (range.toRow, range.toCol)
        let last = forward ? (range.toRow, range.toCol) : (range.fromRow, range.fromCol)
        guard row >= first.0, row <= last.0 else { return nil }
        let size = length(row)
        if range.linewise { return 0..<(size + 1) }
        let start = row == first.0 ? first.1 : 0
        let end = row == last.0 ? last.1 + 1 : size + 1
        return start < end ? start..<end : nil
    }

    /// Per-character tone channels of a row: a syntax tone sets the foreground, an annotation tone the background; later decorations win per channel.
    func styles(row: Int) -> [CodeBufferCellStyle] {
        var cells = [CodeBufferCellStyle](repeating: CodeBufferCellStyle(), count: length(row))
        for decoration in decorations where row >= decoration.fromRow && row <= decoration.toRow {
            let start = row == decoration.fromRow ? decoration.fromCol : 0
            let end = row == decoration.toRow ? decoration.toCol : cells.count
            guard start < end else { continue }
            for index in max(start, 0)..<min(end, cells.count) {
                if Self.syntaxTones.contains(decoration.tone) { cells[index].foreground = decoration.tone }
                if Self.annotationTones.contains(decoration.tone) { cells[index].background = decoration.tone }
            }
        }
        return cells
    }

    func runs(row: Int) -> [CodeBufferRun] {
        guard row >= 0, row < lines.count else { return [] }
        var runs: [CodeBufferRun] = []
        var text = String.UnicodeScalarView()
        var tone: String?
        for (scalar, style) in zip(lines[row], styles(row: row)) {
            if style.foreground != tone, !text.isEmpty {
                runs.append(CodeBufferRun(text: String(text), foreground: tone))
                text = String.UnicodeScalarView()
            }
            tone = style.foreground
            text.append(scalar)
        }
        if !text.isEmpty { runs.append(CodeBufferRun(text: String(text), foreground: tone)) }
        return runs
    }

    /// Contiguous background ranges of a row, one per tone.
    func backgrounds(row: Int) -> [(range: Range<Int>, tone: String)] {
        var spans: [(range: Range<Int>, tone: String)] = []
        for (index, style) in styles(row: row).enumerated() {
            guard let tone = style.background else { continue }
            if let previous = spans.last, previous.tone == tone, previous.range.upperBound == index {
                spans[spans.count - 1] = (previous.range.lowerBound..<(index + 1), tone)
            } else {
                spans.append((index..<(index + 1), tone))
            }
        }
        return spans
    }

    /// The character under the caret, or nil for the space-width cell past the line end.
    var caretCharacter: String? {
        guard cursor.row >= 0, cursor.row < lines.count, cursor.col >= 0, cursor.col < lines[cursor.row].count else { return nil }
        return String(Character(lines[cursor.row][cursor.col]))
    }

    /// The cell a point in the text column lands on: past a line's end clamps to the line length, below the last line to the last row.
    func cell(x: Double, y: Double, cellWidth: Double, cellHeight: Double) -> CodeBufferCell {
        guard cellWidth > 0, cellHeight > 0 else { return CodeBufferCell(row: 0, col: 0) }
        let row = min(max(Int((y / cellHeight).rounded(.down)), 0), lines.count - 1)
        return CodeBufferCell(row: row, col: min(max(Int((x / cellWidth).rounded(.down)), 0), length(row)))
    }

    static func keyPayload(editorId: String, key: String, ctrl: Bool, alt: Bool, shift: Bool, meta: Bool, repeating: Bool) -> AnyCodable {
        ["editorId": .string(editorId), "key": .string(key), "code": .string(AtomKit.domCode(key)), "ctrl": .bool(ctrl), "alt": .bool(alt), "shift": .bool(shift), "meta": .bool(meta), "repeat": .bool(repeating)]
    }

    static func cellPayload(editorId: String, _ cell: CodeBufferCell) -> AnyCodable {
        ["editorId": .string(editorId), "row": .int(cell.row), "col": .int(cell.col)]
    }

    /// Hover reports once per entered cell: nil when the pointer is still on the last reported cell.
    static func hovered(last: CodeBufferCell?, now: CodeBufferCell) -> CodeBufferCell? {
        last == now ? nil : now
    }

    static func color(_ tone: String, _ theme: AlmadarTheme) -> Color? {
        switch tone {
        case "keyword": return theme.color.primary
        case "string": return theme.color.success
        case "comment": return theme.color.mutedForeground
        case "number": return theme.color.warning
        case "type": return theme.color.info
        case "function": return theme.color.accent
        case "punctuation": return theme.color.mutedForeground
        case "operator", "variable": return theme.color.foreground
        case "search": return theme.color.warning.opacity(0.35)
        case "review": return theme.color.info.opacity(0.2)
        case "review-recent": return theme.color.info.opacity(0.4)
        case "error": return theme.color.error.opacity(0.25)
        case "warning": return theme.color.warning.opacity(0.2)
        case "info": return theme.color.info.opacity(0.15)
        default: return nil
        }
    }
}

struct CodeBufferView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @FocusState private var focused: Bool
    @State private var cell = CGSize.zero
    @State private var popoverHeight: CGFloat = 0
    @State private var lastHover: CodeBufferCell?

    private var editorId: String { props.string("editorId") }

    private var limit: CGFloat {
        let raw = props.string("maxHeight", default: "60vh")
        if raw.hasSuffix("vh"), let percent = Double(raw.dropLast(2)) { return UIScreen.main.bounds.height * CGFloat(percent / 100) }
        return AtomKit.length(raw) ?? UIScreen.main.bounds.height * 0.6
    }

    private func emit(_ key: String, _ payload: AnyCodable) {
        let event = props.string(key)
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: payload)) }
    }

    var body: some View {
        let model = CodeBufferModel(props)
        let font = AtomKit.font(theme, "xs", .regular, mono: true)
        let numbered = props.bool("showLineNumbers") || props.bool("lineNumbers")
        let width = cell.width * CGFloat(model.columns)
        let height = cell.height * CGFloat(model.lines.count)
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                    if numbered {
                        VStack(alignment: .trailing, spacing: theme.density.spacing.space0) {
                            ForEach(Array(model.gutter.enumerated()), id: \.offset) { _, number in
                                Text(number).font(font).foregroundColor(theme.color.mutedForeground).frame(height: cell.height)
                            }
                        }
                    }
                    ZStack(alignment: .topLeading) {
                        Text("M").font(font).fixedSize().hidden()
                            .background(GeometryReader { geometry in
                                Color.clear
                                    .onAppear { cell = geometry.size }
                                    .onChange(of: geometry.size) { cell = $0 }
                            })
                        VStack(spacing: theme.density.spacing.space0) {
                            ForEach(model.lines.indices, id: \.self) { Color.clear.frame(width: 1, height: cell.height).id($0) }
                        }
                        paint(model)
                        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                            ForEach(model.lines.indices, id: \.self) { row in
                                Text(attributed(model.runs(row: row))).font(font).lineLimit(1).fixedSize()
                                    .frame(height: cell.height, alignment: .leading)
                            }
                        }
                        caretShape(model)
                        caretText(model, font: font)
                    }
                    .frame(width: width, height: height, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        focused = true
                        let hit = model.cell(x: tap.location.x, y: tap.location.y, cellWidth: cell.width, cellHeight: cell.height)
                        emit("onPointerDown", CodeBufferModel.cellPayload(editorId: editorId, hit))
                    })
                    .onContinuousHover { phase in
                        guard case .active(let point) = phase else { lastHover = nil; return }
                        let hit = model.cell(x: point.x, y: point.y, cellWidth: cell.width, cellHeight: cell.height)
                        guard let entered = CodeBufferModel.hovered(last: lastHover, now: hit) else { return }
                        lastHover = entered
                        emit("onHover", CodeBufferModel.cellPayload(editorId: editorId, entered))
                    }
                    .overlay(alignment: .topLeading) { popoverView(model, contentHeight: height) }
                }
                .padding(theme.density.spacing.space2)
            }
            .frame(maxHeight: limit)
            .onChange(of: model.cursor) { proxy.scrollTo($0.row) }
        }
        .modifier(CodeBufferFocusable())
        .focused($focused)
        .onChange(of: focused) { isFocused in
            let event = props.string(isFocused ? "onEditorFocus" : "onEditorBlur", default: isFocused ? "EDITOR_FOCUS" : "EDITOR_BLUR")
            if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["editorId": .string(editorId)])) }
        }
        .modifier(CodeBufferKeys(props: props, onEvent: onEvent))
    }

    private func attributed(_ runs: [CodeBufferRun]) -> AttributedString {
        var text = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            piece.foregroundColor = run.foreground.flatMap { CodeBufferModel.color($0, theme) } ?? theme.color.foreground
            text.append(piece)
        }
        return text
    }

    @ViewBuilder
    private func paint(_ model: CodeBufferModel) -> some View {
        ForEach(model.lines.indices, id: \.self) { row in
            if let span = model.selectionSpan(row: row) {
                block(row: row, span: span, color: theme.color.primary.opacity(0.3))
            }
            ForEach(Array(model.backgrounds(row: row).enumerated()), id: \.offset) { _, entry in
                block(row: row, span: entry.range, color: CodeBufferModel.color(entry.tone, theme) ?? AtomKit.clear(theme))
            }
        }
        ForEach(model.decorations.filter { !$0.label.isEmpty }, id: \.id) { decoration in
            block(row: decoration.fromRow, span: decoration.fromCol..<max(decoration.fromRow == decoration.toRow ? decoration.toCol : model.length(decoration.fromRow), decoration.fromCol), color: AtomKit.clear(theme))
                .accessibilityElement()
                .accessibilityLabel(decoration.label)
        }
    }

    private func block(row: Int, span: Range<Int>, color: Color) -> some View {
        Rectangle().fill(color)
            .frame(width: cell.width * CGFloat(span.count), height: cell.height)
            .offset(x: cell.width * CGFloat(span.lowerBound), y: cell.height * CGFloat(row))
    }

    @ViewBuilder
    private func caretShape(_ model: CodeBufferModel) -> some View {
        let origin = CGPoint(x: cell.width * CGFloat(model.cursor.col), y: cell.height * CGFloat(model.cursor.row))
        let weight = theme.geometry.borderHeavy
        switch model.caret {
        case "bar":
            Rectangle().fill(theme.color.foreground).frame(width: weight, height: cell.height).offset(x: origin.x, y: origin.y)
        case "underline":
            Rectangle().fill(theme.color.foreground).frame(width: cell.width, height: weight).offset(x: origin.x, y: origin.y + cell.height - weight)
        default:
            Rectangle().fill(theme.color.foreground).frame(width: cell.width, height: cell.height).offset(x: origin.x, y: origin.y)
        }
    }

    @ViewBuilder
    private func caretText(_ model: CodeBufferModel, font: Font) -> some View {
        if model.caret != "bar", model.caret != "underline", let character = model.caretCharacter {
            Text(character).font(font).foregroundColor(theme.color.background).fixedSize()
                .offset(x: cell.width * CGFloat(model.cursor.col), y: cell.height * CGFloat(model.cursor.row))
        }
    }

    @ViewBuilder
    private func popoverView(_ model: CodeBufferModel, contentHeight: CGFloat) -> some View {
        if let note = model.popover {
            let below = cell.height * CGFloat(note.fromRow + 1)
            let fits = contentHeight - below >= popoverHeight
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                if !note.title.isEmpty { AtomKit.typo(note.title, "small", weight: "medium", onEvent: onEvent) }
                ForEach(Array(note.sections.enumerated()), id: \.offset) { _, section in
                    if !section.heading.isEmpty { AtomKit.typo(section.heading, "small", weight: "medium", onEvent: onEvent) }
                    ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                        AtomKit.typo(line, "small", color: "muted", onEvent: onEvent)
                    }
                }
                if note.busy { ProgressView().controlSize(.small) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: cell.width * 48, alignment: .leading)
            .atomSurface(theme, padding: theme.density.spacing.space3)
            .atomShadow(theme.elevation.popoverElevation)
            .background(GeometryReader { geometry in
                Color.clear.onAppear { popoverHeight = geometry.size.height }.onChange(of: geometry.size.height) { popoverHeight = $0 }
            })
            .offset(x: cell.width * CGFloat(note.fromCol), y: fits ? below : cell.height * CGFloat(note.fromRow) - popoverHeight)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Buffer mode: every hardware key press while focused is the program's input, emitted as UI:{onKey} and kept out of the platform.
struct CodeBufferFocusable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.focusable()
        } else {
            content
        }
    }
}

struct CodeBufferKeys: ViewModifier {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onKeyPress(phases: [.down, .repeat]) { press in
                let event = props.string("onKey")
                guard !event.isEmpty else { return .ignored }
                let key = AtomKit.domKey(press)
                onEvent(event, eventEnvelope(props, payload: CodeBufferModel.keyPayload(
                    editorId: props.string("editorId"), key: key,
                    ctrl: press.modifiers.contains(.control), alt: press.modifiers.contains(.option),
                    shift: press.modifiers.contains(.shift), meta: press.modifiers.contains(.command),
                    repeating: press.phase == .repeat
                )))
                return .handled
            }
        } else {
            content
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
