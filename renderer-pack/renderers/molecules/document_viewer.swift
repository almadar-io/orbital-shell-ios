import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import PDFKit

struct AtomPDFSurface: UIViewRepresentable {
    let source: String

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard let url = URL(string: source) else { return }
        if url.isFileURL {
            view.document = PDFDocument(url: url)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let document = PDFDocument(data: data) else { return }
            DispatchQueue.main.async { view.document = document }
        }.resume()
    }
}

struct DocumentViewerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.openURL) private var openURL
    @State private var zoom = 100
    @State private var page: Int
    @State private var active = 0
    private let pageKey = "DOCUMENT_PAGE_CHANGE"
    private let downloadKey = "DOCUMENT_DOWNLOAD"
    private let printKey = "DOCUMENT_PRINT"

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _page = State(initialValue: props.dictValue?["currentPage"] != nil ? props.int("currentPage", default: 1) : 1)
    }

    private var documents: [AnyCodable] { props.dictValue?["documents"]?.arrayValue ?? [] }
    private var current: AnyCodable? { documents.indices.contains(active) ? documents[active] : nil }
    private var source: String { current.map { AtomKit.assetURL($0, "src") }.flatMap { $0.isEmpty ? nil : $0 } ?? AtomKit.assetURL(props, "src") }
    private var text: String { current.map { $0.string("content") }.flatMap { $0.isEmpty ? nil : $0 } ?? props.string("content") }
    private var kind: String { current.map { $0.string("documentType") }.flatMap { $0.isEmpty ? nil : $0 } ?? props.string("documentType", default: "pdf") }
    private var total: Int { props.int("totalPages") }

    var body: some View {
        let error = AtomKit.errorText(props)
        if props.bool("isLoading") {
            LoadingStateRenderer(props: AtomKit.child(props, ["message": "Loading..."]), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Document error", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else if source.isEmpty && text.isEmpty {
            EmptyStateRenderer(props: AtomKit.child(props, ["icon": "file-text", "title": "No document", "description": "No document to display."]), modifier: nil, onEvent: onEvent)
        } else {
            VStack(spacing: theme.density.spacing.space0) {
                if documents.count > 1 { switcher }
                if props.bool("showToolbar", default: true) {
                    toolbar
                    DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
                }
                content
                    .frame(maxWidth: .infinity)
                    .background(theme.color.muted.opacity(0.2))
            }
            .padding(theme.density.cardPaddingMd)
            .background(theme.color.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .accessibilityElement(children: .contain)
        }
    }

    private var switcher: some View {
        AtomFlowLayout(spacing: theme.density.spacing.space1) {
            ForEach(documents.indices, id: \.self) { index in
                ButtonRenderer(
                    props: ["variant": .string(index == active ? "primary" : "ghost"), "size": "sm", "label": .string(documents[index].string("label")), "action": .string(AtomKit.localEvent), "local": true],
                    modifier: nil,
                    onEvent: { _, _ in active = index }
                )
            }
        }
        .padding(.bottom, theme.density.spacing.space1)
    }

    private func tool(_ icon: String, _ label: String, event: String = "", payload: AnyCodable? = nil, disabled: Bool = false, _ run: @escaping () -> Void) -> some View {
        var values: [String: AnyCodable] = [
            "variant": "ghost",
            "size": "sm",
            "icon": .string(icon),
            "aria-label": .string(label),
            "disabled": .bool(disabled),
            "action": .string(AtomKit.eventOrLocal(event)),
            "local": .bool(event.isEmpty),
        ]
        if let payload = payload { values["actionPayload"] = payload }
        return ButtonRenderer(props: AtomKit.child(props, values), modifier: nil, onEvent: { _, _ in run() })
    }

    private var toolbar: some View {
        let actions = props.dictValue?["actions"]?.arrayValue ?? []
        return HStack(spacing: theme.density.spacing.space2) {
            AtomKit.icon("file-text", "sm", color: "muted", onEvent: onEvent)
            if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "small", weight: "medium", truncate: true, onEvent: onEvent) }
            Spacer(minLength: theme.density.spacing.space0)
            AtomFlowLayout(spacing: theme.density.spacing.space1) {
                tool("zoom-out", "Zoom out") { zoom = max(zoom - 25, 50) }
                AtomKit.typo("\(zoom)%", "caption", color: "secondary", align: "center", onEvent: onEvent)
                tool("zoom-in", "Zoom in") { zoom = min(zoom + 25, 200) }
                if total > 1 {
                    tool("chevron-left", "Previous page", event: pageKey, payload: ["page": .int(page - 1)], disabled: page <= 1) {
                        page = max(page - 1, 1)
                        onEvent(pageKey, eventEnvelope(props, payload: ["page": .int(page)]))
                    }
                    AtomKit.typo("\(page) / \(total)", "caption", color: "secondary", onEvent: onEvent)
                    tool("chevron-right", "Next page", event: pageKey, payload: ["page": .int(page + 1)], disabled: page >= total) {
                        page = min(page + 1, total)
                        onEvent(pageKey, eventEnvelope(props, payload: ["page": .int(page)]))
                    }
                }
                if props.bool("showDownload") {
                    tool("download", "Download document", event: downloadKey, payload: ["src": .string(source)]) {
                        onEvent(downloadKey, eventEnvelope(props, payload: ["src": .string(source)]))
                        if let url = URL(string: source), url.scheme != nil { openURL(url) }
                    }
                }
                if props.bool("showPrint") {
                    tool("printer", "Print document", event: printKey, payload: [:]) { onEvent(printKey, eventEnvelope(props)) }
                }
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    ButtonRenderer(
                        props: AtomKit.child(props, ["variant": .string(action.string("variant", default: "secondary")), "size": "sm", "label": .string(action.string("label")), "action": .string(action.string("event")), "actionPayload": ["page": .int(page)]]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let tall = props.dictValue?["height"]?.stringValue.flatMap { AtomKit.length($0) } ?? CGFloat(props.float("height", default: 600))
        if kind == "pdf" && !source.isEmpty {
            AtomPDFSurface(source: source)
                .scaleEffect(CGFloat(zoom) / 100, anchor: .topLeading)
                .frame(height: tall)
                .clipped()
        } else {
            ScrollView {
                if kind == "html" {
                    AtomKit.typo(AtomKit.plainHTML(text), "body1", onEvent: onEvent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    AtomMonoText(text, size: "sm")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(theme.density.spacing.space4)
            .scaleEffect(CGFloat(zoom) / 100, anchor: .topLeading)
            .frame(height: tall)
            .clipped()
        }
    }
}

@ViewBuilder
func DocumentViewerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(DocumentViewerMoleculeView(props: props, onEvent: onEvent))
}
