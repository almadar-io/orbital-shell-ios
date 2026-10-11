import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

struct MediaGalleryOrganismView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var viewing: Int? = nil

    static let uploadEvent = "MEDIA_UPLOAD"
    static let selectEvent = "MEDIA_SELECT"
    static let closeEvent = "LIGHTBOX_CLOSE"

    private var items: [AnyCodable] {
        let given = props.dictValue?["items"]?.arrayValue ?? []
        if !given.isEmpty { return given }
        let source = props.string("srcField", default: "src")
        let caption = props.string("captionField", default: "caption")
        return AtomKit.rows(props, "entity").enumerated().map { entry in
            .dict([
                "id": .string(AtomKit.rowKey(entry.element, entry.offset)),
                "src": .string(AtomKit.assetURL(entry.element, source)),
                "alt": .string(entry.element.string("alt")),
                "thumbnail": .string(AtomKit.assetURL(entry.element, "thumbnail")),
                "caption": .string(AtomKit.scalar(AtomKit.cell(entry.element, caption)) ?? ""),
            ])
        }
    }

    private var selected: [String] {
        AtomKit.strings(props, "selectedItems")
    }

    var body: some View {
        let error = AtomKit.errorText(props)
        let list = items
        if props.bool("isLoading") {
            LoadingStateRenderer(props: AtomKit.child(props, [:]), modifier: nil, onEvent: onEvent)
        } else if !error.isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Gallery error", "message": .string(error)]), modifier: nil, onEvent: onEvent)
        } else if list.isEmpty && !props.bool("showUpload") {
            EmptyStateRenderer(props: AtomKit.emptyProps(props, fallback: "No media"), modifier: nil, onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space4) {
                header
                if props.bool("selectable") && !selected.isEmpty { AtomKit.badge("\(selected.count) selected", "info", size: "md", onEvent: onEvent) }
                if let index = viewing {
                    LightboxRenderer(
                        props: AtomKit.child(props, [
                            "images": .array(list.map { .dict(["src": .string($0.string("src")), "alt": .string($0.string("alt")), "caption": .string($0.string("caption"))]) }),
                            "currentIndex": .int(index),
                            "isOpen": true,
                            "closeAction": .string(MediaGalleryOrganismView.closeEvent),
                        ]),
                        modifier: nil,
                        onEvent: { name, _ in if name == MediaGalleryOrganismView.closeEvent { viewing = nil } }
                    )
                    .frame(minHeight: theme.density.spacing.space12 * 8)
                } else {
                    AtomGridLayout(minWidth: theme.density.spacing.space12 * 2, maxColumns: 0, fixedColumns: min(max(props.int("columns", default: 3), 2), 6), spacing: theme.density.spacing.space3) {
                        ForEach(list.indices, id: \.self) { index in
                            tile(list[index], index: index)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .atomSurface(theme, padding: theme.density.spacing.space6)
            .accessibilityElement(children: .contain)
        }
    }

    private var header: some View {
        let actions = (props.dictValue?["actions"]?.arrayValue ?? []).filter { AtomKit.actionable($0) }
        return HStack(spacing: theme.density.spacing.space2) {
            if !props.string("title").isEmpty { AtomKit.typo(props.string("title"), "h5", onEvent: onEvent) }
            Spacer(minLength: theme.density.spacing.space2)
            if props.bool("showUpload") {
                ButtonRenderer(props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "leftIcon": "upload", "label": "Upload", "action": .string(MediaGalleryOrganismView.uploadEvent)]), modifier: nil, onEvent: onEvent)
            }
            ForEach(actions.indices, id: \.self) { index in
                ButtonRenderer(props: AtomKit.actionProps(props, actions[index], row: nil, size: "sm", fallback: "ghost"), modifier: nil, onEvent: onEvent)
            }
        }
    }

    private func tile(_ item: AnyCodable, index: Int) -> some View {
        let id = item.string("id")
        let chosen = selected.contains(id)
        let ratio: CGFloat = props.string("aspectRatio", default: "square") == "landscape" ? 16.0 / 9.0 : (props.string("aspectRatio", default: "square") == "portrait" ? 3.0 / 4.0 : 1)
        let thumbnail = item.string("thumbnail").isEmpty ? item.string("src") : item.string("thumbnail")
        return ImageRenderer(props: ["src": .string(thumbnail), "alt": .string(item.string("alt", default: item.string("caption"))), "fit": "cover"], modifier: nil, onEvent: onEvent)
            .aspectRatio(ratio, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(chosen ? theme.color.primary : AtomKit.clear(theme), lineWidth: theme.geometry.borderHeavy * 2))
            .contentShape(Rectangle())
            .onTapGesture { tap(item, index: index, chosen: chosen) }
            .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel(item.string("alt", default: item.string("caption", default: id)))
            .atomAction(props.bool("selectable") ? props.string("selectionEvent", default: "SELECTION_CHANGE") : MediaGalleryOrganismView.selectEvent, props)
            .verificationContainer(VerificationIds.row(id))
    }

    private func tap(_ item: AnyCodable, index: Int, chosen: Bool) {
        if props.bool("selectable") {
            let id = item.string("id")
            let next = chosen ? selected.filter { $0 != id } : selected + [id]
            onEvent(props.string("selectionEvent", default: "SELECTION_CHANGE"), eventEnvelope(props, payload: ["selection": .array(next.map { AnyCodable.string($0) })]))
        } else {
            viewing = index
        }
        onEvent(MediaGalleryOrganismView.selectEvent, eventEnvelope(props, payload: ["row": item]))
    }
}

@ViewBuilder
func MediaGalleryRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MediaGalleryOrganismView(props: props, onEvent: onEvent))
}
