import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct ChatBarOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var text = ""
    @State private var requestedPlaceholder: String?

    private static let elementSelectedEvent = "ELEMENT_SELECTED"

    /// The host's focus request (`focusRequest`): its id is the field focus token, its prompt shows until the next send.
    private var requestToken: String? {
        guard let id = props.dictValue?["focusRequest"]?.dictValue?["id"] else { return nil }
        return id.stringValue ?? id.doubleValue.map { String($0) }
    }

    private static let retryEvent = "RETRY_GENERATION"
    private static let pauseEvent = "PAUSE"
    private static let stopEvent = "STOP"
    private static let resumeEvent = "RESUME"

    private var sendEvent: String { props.string("sendEvent", default: "CHAT_SEND") }
    private var status: String { props.string("status", default: "idle") }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func send() {
        guard !trimmed.isEmpty else { return }
        onEvent(sendEvent, eventEnvelope(props, payload: ["message": .string(trimmed)]))
        text = ""
        requestedPlaceholder = nil
    }

    private func jepaVariant(_ probability: Double) -> String {
        if probability >= 0.9 { return "success" }
        return probability >= 0.5 ? "warning" : "danger"
    }

    private func action(_ values: [String: AnyCodable]) -> some View {
        ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: onEvent)
    }

    @ViewBuilder
    private var trailing: some View {
        if status == "error" {
            action(["variant": "secondary", "size": "sm", "icon": "refresh-cw", "label": "Retry", "action": .string(Self.retryEvent)])
        } else if status == "running" {
            action(["variant": "ghost", "size": "sm", "icon": "pause", "aria-label": "Pause the agent — you can edit the canvas while it waits", "action": .string(Self.pauseEvent)])
            action(["variant": "ghost", "size": "sm", "icon": "square", "aria-label": "Cancel generation", "action": .string(Self.stopEvent)])
        } else if status == "paused" {
            action(["variant": "primary", "size": "sm", "icon": "play", "label": "Resume", "aria-label": "Resume the agent — your canvas edits are kept", "action": .string(Self.resumeEvent)])
        } else {
            ButtonRenderer(
                props: AtomKit.child(props, ["variant": "primary", "size": "sm", "icon": "send", "aria-label": "Send message", "action": .string(sendEvent), "disabled": .bool(trimmed.isEmpty)]),
                modifier: nil,
                onEvent: { _, _ in send() }
            )
        }
    }

    @State private var width: CGFloat = 0

    private func contextBadge() -> some View {
        let context = props.string("context")
        return Group {
            if !context.isEmpty { AtomKit.badge(context, "primary", size: "sm", onEvent: onEvent).fixedSize() }
        }
    }

    /// Return sends and Shift+Return keeps the newline, as the web textarea does; the soft keyboard Return is not a key press and still inserts one.
    @ViewBuilder
    private func keyed<Content: View>(_ content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) { return .ignored }
                send()
                return .handled
            }
        } else {
            content
        }
    }

    private func field() -> some View {
        keyed(TextareaRenderer(
            props: AtomKit.child(props, [
                "value": .string(text),
                "placeholder": .string(requestedPlaceholder ?? props.string("placeholder", default: "Ask the agent anything…")),
                "rows": .int(1),
                "onChange": .string(AtomKit.localEvent),
                "local": true,
            ]),
            modifier: nil,
            onEvent: { _, envelope in
                text = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? text
            }
        )
        .frame(maxWidth: .infinity))
        .environment(\.almadarFieldFocusToken, requestToken)
        .onChange(of: requestToken) { _ in
            let prompt = props.dictValue?["focusRequest"]?.dictValue?["placeholder"]?.stringValue ?? ""
            if !prompt.isEmpty { requestedPlaceholder = prompt }
        }
        .onAppear {
            let prompt = props.dictValue?["focusRequest"]?.dictValue?["placeholder"]?.stringValue ?? ""
            if !prompt.isEmpty { requestedPlaceholder = prompt }
        }
    }

    /// The picked canvas element a sent message edits (`editFocus`); the ✕ asks the owner to clear it.
    @ViewBuilder
    private func focusChip() -> some View {
        if let focus = props.dictValue?["editFocus"]?.dictValue, let label = focus["label"]?.stringValue {
            HStack(spacing: theme.density.spacing.space1) {
                AtomKit.icon("mouse-pointer-2", "xs", onEvent: onEvent)
                AtomKit.typo("Editing: " + label, "caption", truncate: true, onEvent: onEvent)
                ButtonRenderer(
                    props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "x", "aria-label": "Clear selection", "action": .string(Self.elementSelectedEvent)]),
                    modifier: nil,
                    onEvent: { _, _ in onEvent(Self.elementSelectedEvent, eventEnvelope(props, payload: ["focus": .null])) }
                )
            }
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.top, theme.density.spacing.space2)
        }
    }

    @ViewBuilder
    private func cluster() -> some View {
        let gate = props.string("activeGate")
        let jepa = props.dictValue?["jepaValidity"]?.doubleValue
        let running = status == "running"
        if !gate.isEmpty || jepa != nil {
            HStack(spacing: theme.density.spacing.space1) {
                if running {
                    if props.dictValue?["runningIndicator"] != nil {
                        AtomSlot(props.dictValue?["runningIndicator"], onEvent: onEvent)
                    } else {
                        SpinnerRenderer(props: AtomKit.child(props, ["size": "sm"]), modifier: nil, onEvent: onEvent)
                    }
                }
                if !gate.isEmpty {
                    AtomKit.typo(gate, running ? "body1" : "caption", color: running ? "primary" : "muted", weight: running ? "medium" : "", truncate: true, onEvent: onEvent)
                }
                if let jepa = jepa {
                    AtomKit.badge(String(format: "%.1f%%", jepa * 100), jepaVariant(jepa), size: "sm", onEvent: onEvent)
                        .fixedSize()
                }
            }
        }
    }

    var body: some View {
        let compact = width < AlmadarBreakpoints.md
        VStack(spacing: theme.density.spacing.space0) {
            theme.color.border.frame(height: theme.geometry.borderStandard)
            focusChip()
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        HStack(spacing: theme.density.spacing.space2) {
                            contextBadge()
                            HStack(spacing: theme.density.spacing.space0) {
                                field()
                                trailing
                            }
                        }
                        cluster()
                    }
                } else {
                    HStack(spacing: theme.density.spacing.space2) {
                        contextBadge()
                        HStack(spacing: theme.density.spacing.space0) {
                            field()
                            trailing
                        }
                        cluster()
                    }
                }
            }
            .padding(.horizontal, theme.density.spacing.space4)
            .padding(.vertical, theme.density.spacing.space2)
        }
        .background(theme.color.card)
        .background(GeometryReader { proxy in
            AtomKit.clear(theme).onAppear { width = proxy.size.width }.onChange(of: proxy.size.width) { next in width = next }
        })
        .accessibilityElement(children: .contain)
    }
}

@ViewBuilder
func ChatBarRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ChatBarOrganismView(props: props, onEvent: onEvent))
}
