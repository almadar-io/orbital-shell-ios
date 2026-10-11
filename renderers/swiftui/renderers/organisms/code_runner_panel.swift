import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct CodeRunnerPanelOrganismView: View {
    let props: AnyCodable
    let modifier: AnyView?
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var code: String
    @State private var copied = false

    init(props: AnyCodable, modifier: AnyView?, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.modifier = modifier
        self.onEvent = onEvent
        _code = State(initialValue: props.string("code"))
    }

    private static let copyEvent = "COPY_CODE"

    private var language: String { props.string("language", default: "text") }
    private var runEvent: String { props.string("runEvent", default: "RUN_CODE") }
    private var resetEvent: String { props.string("resetEvent") }
    private var runId: String { props.string("runId") }
    private var running: Bool { props.bool("running") }
    private var failure: String { props.string("error") }
    private var output: [String: AnyCodable]? { props.dictValue?["output"]?.dictValue }

    private func button(_ values: [String: AnyCodable], _ handler: @escaping (String, AnyCodable?) -> Void) -> some View {
        ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: handler)
    }

    private var toolbar: some View {
        let resettable = !resetEvent.isEmpty
        let shape = AtomKit.shape(theme, .container)
        return HStack(spacing: theme.density.spacing.space1) {
            button(
                ["variant": "ghost", "size": "sm", "icon": .string(copied ? "check" : "copy"), "aria-label": "Copy", "action": .string(Self.copyEvent)],
                { _, _ in
                    UIPasteboard.general.string = code
                    copied = true
                    onEvent(Self.copyEvent, eventEnvelope(props, payload: ["language": .string(language), "success": .bool(true)]))
                }
            )
            .environment(\.atomButtonTint, copied ? theme.color.success : nil)
            button(
                [
                    "variant": "ghost", "size": "sm", "icon": "rotate-ccw", "aria-label": "Reset", "disabled": .bool(running),
                    "action": .string(resettable ? resetEvent : "code-reset"), "local": .bool(!resettable),
                ],
                { _, _ in
                    code = props.string("code")
                    if resettable { onEvent(resetEvent, eventEnvelope(props, payload: ["runId": .string(runId)])) }
                }
            )
            button(
                [
                    "variant": "primary", "size": "sm", "icon": .string(running ? "rotate-cw" : "play"),
                    "label": .string(running ? "Loading..." : "Run"), "isLoading": .bool(running),
                    "action": .string(runEvent),
                ],
                { _, _ in onEvent(runEvent, eventEnvelope(props, payload: ["code": .string(code), "language": .string(language), "runId": .string(runId)])) }
            )
        }
        .padding(theme.density.spacing.space1)
        .background(theme.color.card.opacity(0.9))
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .padding(theme.density.spacing.space2)
    }

    private var editor: some View {
        ZStack(alignment: .topTrailing) {
            CodeBlockMoleculeView(
                props: AtomKit.child(props, ["code": .string(code), "language": .string(language), "editable": true, "showLanguageBadge": true, "showCopyButton": false, "maxHeight": "22.5rem"]),
                onEvent: onEvent,
                text: $code
            )
            toolbar
        }
        .frame(height: AtomKit.length("22.5rem"))
    }

    private func line(_ text: String, color: Color, italic: Bool = false) -> some View {
        AtomMonoText(text, size: "sm", color: color)
            .italic(italic)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func testRow(_ index: Int, _ test: AnyCodable) -> some View {
        let passed = test.bool("passed")
        return HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            AtomKit.icon(passed ? "check-circle" : "x-circle", "sm", color: passed ? "success" : "error", onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                line(passed ? "Test \(index + 1): passed" : "Test \(index + 1): failed", color: passed ? theme.color.success : theme.color.error)
                line("Input: \(test.string("input"))", color: theme.color.background)
                line("Expected: \(test.string("expectedOutput"))", color: theme.color.background)
                line("Actual: \(test.string("actualOutput"))", color: theme.color.background)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let stdout = output?["stdout"]?.stringValue ?? ""
        let stderr = output?["stderr"]?.stringValue ?? ""
        let tests = output?["testResults"]?.arrayValue ?? []
        if !failure.isEmpty {
            line(failure, color: theme.color.error)
        } else {
            if !stdout.isEmpty { line(stdout, color: theme.color.background) }
            if !stderr.isEmpty { line(stderr, color: theme.color.error) }
            if stdout.isEmpty && stderr.isEmpty { line("No output", color: theme.color.background, italic: true) }
            if !tests.isEmpty {
                theme.color.border.frame(height: theme.geometry.borderStandard).padding(.top, theme.density.spacing.space3)
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    ForEach(tests.indices, id: \.self) { index in testRow(index, tests[index]) }
                }
                .padding(.top, theme.density.spacing.space3)
            }
        }
    }

    private var pane: some View {
        let shape = AtomKit.shape(theme, .container)
        let exit = output?["exitCode"]?.intValue ?? 0
        return VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("terminal", "sm", color: "muted", onEvent: onEvent)
                AtomKit.typo("Output", "small", weight: "medium", onEvent: onEvent)
                if output != nil { AtomKit.badge("Exit \(exit)", exit == 0 ? "success" : "danger", onEvent: onEvent).fixedSize() }
            }
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.card)
            theme.color.border.frame(height: theme.geometry.borderStandard)
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) { results }
                .padding(theme.density.spacing.space3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.color.foreground)
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    @ViewBuilder
    var body: some View {
        if props.bool("runnable") {
            VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
                editor
                if output != nil || !failure.isEmpty { pane }
            }
            .accessibilityElement(children: .contain)
        } else {
            CodeBlockRenderer(props: props.merging(["code": .string(props.string("code")), "language": .string(language)]), modifier: modifier, onEvent: onEvent)
        }
    }
}

@ViewBuilder
func CodeRunnerPanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(CodeRunnerPanelOrganismView(props: props, modifier: modifier, onEvent: onEvent))
}
