import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct DocumentPanelMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var titleDraft: String?

    private var identity: AnyCodable { ["id": .string(props.string("id"))] }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.geometry.radiusContainer)
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            if !props.string("coverImage").isEmpty {
                ImageRenderer(props: ["src": .string(props.string("coverImage")), "alt": "", "aspect": "21/9", "rounded": "none"], modifier: nil, onEvent: onEvent)
            }
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                AtomFlowLayout(spacing: theme.density.spacing.space3) {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        if !props.string("icon").isEmpty { AtomKit.icon(props.string("icon"), "lg", color: "muted", onEvent: onEvent) }
                        titleView
                        if !props.string("subtitle").isEmpty { AtomKit.typo(props.string("subtitle"), "small", color: "secondary", onEvent: onEvent) }
                    }
                    header
                }
                bodyView
            }
            .padding(theme.density.spacing.space6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.card)
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .atomShadow(theme.elevation.cardElevation)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var titleView: some View {
        let title = props.string("title")
        if !props.string("titleCommitEvent").isEmpty, let draft = titleDraft {
            HStack(spacing: theme.density.spacing.space1) {
                InputRenderer(
                    props: ["inputType": "text", "name": "document-title", "value": .string(draft), "onChange": "document-title-draft", "action": "document-title-commit"],
                    modifier: nil,
                    onEvent: { event, envelope in
                        let typed = envelope?.dictValue?["actionPayload"]?.dictValue?["value"]?.stringValue ?? ""
                        if event == "document-title-commit" { commitTitle(typed) } else { titleDraft = typed }
                    }
                )
                ButtonRenderer(
                    props: ["variant": "ghost", "size": "sm", "icon": "check", "aria-label": "Save title", "action": "document-title-save", "local": true],
                    modifier: nil,
                    onEvent: { _, _ in commitTitle(draft) }
                )
            }
        } else if !props.string("titleCommitEvent").isEmpty {
            AtomKit.typo(title.isEmpty ? "Untitled" : title, "h2", color: title.isEmpty ? "muted" : "primary", onEvent: onEvent)
                .contentShape(Rectangle())
                .onTapGesture { titleDraft = title }
                .accessibilityAddTraits(.isButton)
                .verificationId(VerificationIds.field("document-title"))
        } else {
            AtomKit.typo(title.isEmpty ? "Untitled" : title, "h2", onEvent: onEvent)
        }
    }

    private var header: some View {
        let editing = props.bool("editing")
        let actions = (props.dictValue?["actions"]?.arrayValue ?? []).filter { !$0.string("event").isEmpty }
        let cap = min(props.dictValue?["maxInlineActions"]?.intValue ?? 1, 1)
        let inline = Array(actions.filter { $0.string("variant") == "primary" }.prefix(cap))
        let menu = actions.filter { action in !inline.contains(action) }
        let editEvent = props.string("editEvent")
        let doneEvent = props.string("doneEvent")
        return HStack(spacing: theme.density.spacing.space1) {
            if editing {
                AtomKit.typo(props.string("autosaveHint", default: "Saves as you type"), "caption", color: "muted", onEvent: onEvent)
                if !doneEvent.isEmpty {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "primary", "size": "sm", "label": .string(props.string("doneLabel", default: "Done")), "action": .string(doneEvent), "actionPayload": identity]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            } else {
                if !editEvent.isEmpty {
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "leftIcon": "edit", "label": .string(props.string("editLabel", default: "Edit")), "action": .string(editEvent), "actionPayload": identity]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
                ForEach(inline.indices, id: \.self) { index in
                    ButtonRenderer(props: actionButton(inline[index], fallback: "primary"), modifier: nil, onEvent: onEvent)
                }
                if !menu.isEmpty {
                    Menu {
                        ForEach(menu.indices, id: \.self) { index in
                            ButtonRenderer(props: actionButton(menu[index], fallback: "ghost"), modifier: nil, onEvent: onEvent)
                        }
                    } label: {
                        AtomKit.icon("more-horizontal", "sm", label: "Actions", onEvent: onEvent)
                            .frame(minWidth: theme.density.buttonHeightSm, minHeight: theme.density.buttonHeightSm)
                    }
                    .verificationId(VerificationIds.actionOverflow)
                }
            }
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        let value = props.string("value")
        if props.bool("editing") {
            InputRenderer(
                props: AtomKit.child(props, [
                    "inputType": "textarea",
                    "name": "document-body",
                    "value": .string(value),
                    "placeholder": .string(props.string("placeholder", default: "Start writing\u{2026}")),
                    "onChange": .string(props.string("contentChangeEvent", default: "document-content-change")),
                ]),
                modifier: nil,
                onEvent: onEvent
            )
        } else {
            let editEvent = props.string("editEvent")
            Group {
                if value.isEmpty {
                    AtomKit.typo(props.string("placeholder", default: "Start writing\u{2026}"), "body1", color: "muted", onEvent: onEvent)
                } else {
                    MarkdownContentRenderer(props: ["content": .string(value)], modifier: nil, onEvent: onEvent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: theme.density.rowHeightSpacious * 3, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { if !editEvent.isEmpty { onEvent(editEvent, eventEnvelope(props, payload: identity)) } }
            .accessibilityAddTraits(editEvent.isEmpty ? [] : .isButton)
        }
    }

    private func actionButton(_ action: AnyCodable, fallback: String) -> AnyCodable {
        AtomKit.child(props, [
            "variant": .string(action.string("variant", default: fallback)),
            "size": "sm",
            "label": .string(action.string("label")),
            "leftIcon": .string(action.string("icon")),
            "action": .string(action.string("event")),
            "actionPayload": ["id": .string(props.string("id")), "title": .string(props.string("title"))],
        ])
    }

    private func commitTitle(_ draft: String) {
        titleDraft = nil
        let next = draft.trimmingCharacters(in: .whitespaces)
        let event = props.string("titleCommitEvent")
        guard !event.isEmpty, !next.isEmpty, next != props.string("title") else { return }
        onEvent(event, eventEnvelope(props, payload: ["title": .string(next), "id": .string(props.string("id"))]))
    }
}

@ViewBuilder
func DocumentPanelRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocumentPanelMoleculeView(props: props, onEvent: onEvent))
}
