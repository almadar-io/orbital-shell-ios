import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import UniformTypeIdentifiers

struct UploadDropZoneMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var importing = false
    @State private var failure = ""

    private var types: [UTType] {
        let parts = props.string("accept").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let resolved: [UTType] = parts.compactMap { part in
            if part.hasSuffix("/*") {
                switch part {
                case "image/*": return .image
                case "video/*": return .movie
                case "audio/*": return .audio
                case "text/*": return .text
                default: return nil
                }
            }
            if part.hasPrefix(".") { return UTType(filenameExtension: String(part.dropFirst())) }
            return UTType(mimeType: part)
        }
        return resolved.isEmpty ? [.item] : resolved
    }

    var body: some View {
        let disabled = props.bool("disabled")
        let label = props.string("label", default: "Drop files here or tap to upload")
        VStack(spacing: theme.density.spacing.space2) {
            AtomKit.icon(failure.isEmpty ? (props.string("icon").isEmpty ? "upload" : props.string("icon")) : "alert-circle", "lg", color: failure.isEmpty ? "muted" : "error", onEvent: onEvent)
            AtomKit.typo(label, "body2", align: "center", onEvent: onEvent)
            if !summary.isEmpty { AtomKit.typo(summary, "caption", color: "muted", align: "center", onEvent: onEvent) }
            if !failure.isEmpty { AtomKit.typo(failure, "caption", color: "error", align: "center", onEvent: onEvent) }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.density.spacing.space8)
        .background(theme.color.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive))
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusInteractive).stroke(failure.isEmpty ? theme.color.border : theme.color.error, style: StrokeStyle(lineWidth: theme.geometry.borderHeavy * 2, dash: [theme.density.spacing.space2, theme.density.spacing.space1])))
        .opacity(disabled ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if !disabled { importing = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(props.string("aria-label", default: label))
        .accessibilityAddTraits(.isButton)
        .atomAction(props.string("action"), props)
        .fileImporter(isPresented: $importing, allowedContentTypes: types, allowsMultipleSelection: props.int("maxFiles", default: 1) > 1) { result in
            switch result {
            case .success(let urls): receive(urls)
            case .failure: failure = "Could not read the selected file"
            }
        }
    }

    private var summary: String {
        let described = props.string("description")
        if !described.isEmpty { return described }
        var parts: [String] = []
        if !props.string("accept").isEmpty { parts.append("Accepted: " + props.string("accept")) }
        if props.int("maxSize") > 0 { parts.append("Max size: " + ByteCountFormatter.string(fromByteCount: Int64(props.int("maxSize")), countStyle: .file)) }
        if props.int("maxFiles", default: 1) > 1 { parts.append("Max files: \(props.int("maxFiles", default: 1))") }
        return parts.joined(separator: ". ")
    }

    private func receive(_ urls: [URL]) {
        let limit = props.int("maxFiles", default: 1)
        if urls.count > limit {
            failure = "You can upload at most \(limit) file(s)"
            return
        }
        var files: [AnyCodable] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                failure = "Could not read " + url.lastPathComponent
                return
            }
            if props.int("maxSize") > 0 && data.count > props.int("maxSize") {
                failure = url.lastPathComponent + " is too large"
                return
            }
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let content = props.string("readAs", default: "dataUrl") == "text"
                ? String(data: data, encoding: .utf8) ?? ""
                : "data:" + mime + ";base64," + data.base64EncodedString()
            files.append(.dict(["name": .string(url.lastPathComponent), "size": .int(data.count), "type": .string(mime), "content": .string(content)]))
        }
        failure = ""
        let event = props.string("action")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["files": .array(files)])) }
    }
}

@ViewBuilder
func UploadDropZoneRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(UploadDropZoneMoleculeView(props: props, onEvent: onEvent))
}
