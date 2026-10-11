import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import UniformTypeIdentifiers

struct ImportSourcePickerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var picking: AnyCodable?

    private var sources: [AnyCodable] { props.dictValue?["sources"]?.arrayValue ?? [] }

    private func eventName(_ source: AnyCodable) -> String {
        props.string(source.string("kind") == "file" ? "onFilesSelected" : "onSelect")
    }

    private func select(_ source: AnyCodable) {
        if source.bool("disabled") || eventName(source).isEmpty { return }
        if source.string("kind") == "file" {
            picking = source
            return
        }
        onEvent(eventName(source), eventEnvelope(props, payload: .dict(["sourceId": .string(source.string("id"))])))
    }

    /// The web `accept` list (`.md,text/markdown`): an extension or a MIME type per entry.
    private static func contentTypes(_ accept: String) -> [UTType] {
        let types = accept.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.compactMap { entry -> UTType? in
            entry.hasPrefix(".") ? UTType(filenameExtension: String(entry.dropFirst())) : UTType(mimeType: entry)
        }
        return types.isEmpty ? [.item] : types
    }

    private func picked(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else { return }
        let files: [AnyCodable] = urls.compactMap { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return .dict([
                "name": .string(url.lastPathComponent),
                "size": .double(Double(data.count)),
                "type": .string(UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? ""),
                "text": .string(String(decoding: data, as: UTF8.self)),
            ])
        }
        if files.isEmpty { return }
        onEvent(props.string("onFilesSelected"), eventEnvelope(props, payload: .dict(["files": .array(files)])))
    }

    private func row(_ source: AnyCodable) -> some View {
        let disabled = source.bool("disabled")
        return HStack(spacing: theme.density.spacing.space3) {
            if !source.string("icon").isEmpty { AtomKit.icon(source.string("icon"), "md", onEvent: onEvent) }
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                AtomKit.typo(source.string("label"), "label", onEvent: onEvent)
                if !source.string("description").isEmpty {
                    AtomKit.typo(source.string("description"), "caption", color: "muted", onEvent: onEvent)
                }
            }
            Spacer(minLength: theme.density.spacing.space0)
        }
        .padding(.horizontal, theme.density.spacing.space4)
        .padding(.vertical, theme.density.spacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.color.card)
        .atomClip(theme, .interactive)
        .atomBorder(theme, .interactive, color: theme.color.border, width: theme.geometry.borderStandard)
        .opacity(disabled ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture { select(source) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .atomAction(eventName(source), props)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h4", onEvent: onEvent) }
            ForEach(sources.indices, id: \.self) { index in
                row(sources[index])
            }
            AtomSlot(props.dictValue?["moreSources"], onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: Self.contentTypes(picking?.string("accept") ?? ""),
            allowsMultipleSelection: picking?.bool("multiple") ?? false
        ) { result in
            picking = nil
            picked(result)
        }
    }
}

@ViewBuilder
func ImportSourcePickerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ImportSourcePickerMoleculeView(props: props, onEvent: onEvent))
}
