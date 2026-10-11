import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct MarkdownContentMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var selected: Int? = nil

    var body: some View {
        let blocks = AtomMarkdown.parse(AtomKit.text(props, "content"))
        let annotations = props.dictValue?["annotations"]?.arrayValue ?? []
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            ForEach(blocks.indices, id: \.self) { index in
                block(blocks[index], index: index, annotations: annotations)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, props.string("direction", default: "ltr") == "rtl" ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .contain)
    }

    private func annotate(_ id: String) {
        let event = props.string("annotationEvent")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["annotationId": .string(id)])) }
    }

    private func prose(_ text: String, size: String = "base", weight: Font.Weight = .regular, annotations: [AnyCodable]) -> some View {
        AtomInlineText(text, sizeKey: size, weight: weight, annotations: annotations, onAnnotation: { annotate($0) })
    }

    private func headingSize(_ level: Int) -> String {
        switch level {
        case 1: return "4xl"
        case 2: return "3xl"
        case 3: return "2xl"
        case 4: return "xl"
        case 5: return "lg"
        default: return "base"
        }
    }

    @ViewBuilder
    private func block(_ block: AtomMarkdownBlock, index: Int, annotations: [AnyCodable]) -> some View {
        switch block.kind {
        case .heading:
            prose(block.text, size: headingSize(block.level), weight: .bold, annotations: annotations)
                .accessibilityAddTraits(.isHeader)
        case .paragraph:
            annotatable(index: index, text: block.text) { prose(block.text, annotations: annotations) }
        case .code:
            if block.items.first == "mermaid", let diagram = AtomKit.mermaid(block.text, onEvent: onEvent) {
                diagram
            } else {
                CodeBlockRenderer(
                    props: AtomKit.child(props, ["code": .string(block.text), "language": .string(block.items.first ?? "")]),
                    modifier: nil,
                    onEvent: onEvent
                )
            }
        case .quote:
            HStack(alignment: .top, spacing: theme.density.spacing.space3) {
                Rectangle().fill(theme.color.primary).frame(width: theme.geometry.borderHeavy * 2)
                prose(block.text, annotations: annotations)
            }
        case .list:
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                ForEach(block.items.indices, id: \.self) { position in
                    HStack(alignment: .top, spacing: theme.density.spacing.space2) {
                        AtomKit.typo(block.ordered ? "\(position + 1)." : "•", "body1", color: "muted", onEvent: onEvent)
                        prose(block.items[position], annotations: annotations)
                    }
                }
            }
        case .rule:
            DividerRenderer(props: [:], modifier: nil, onEvent: onEvent)
        case .image:
            ImageRenderer(props: ["src": .string(imageSource(block.text)), "alt": .string(imageAlt(block.text)), "fit": "contain"], modifier: nil, onEvent: onEvent)
        case .table:
            table(block.rows)
        }
    }

    private func imageSource(_ raw: String) -> String {
        guard let open = raw.range(of: "](", options: .backwards) else { return "" }
        return String(raw[open.upperBound...].dropLast())
    }

    private func imageAlt(_ raw: String) -> String {
        guard let close = raw.range(of: "](", options: .backwards) else { return "" }
        return String(raw[raw.index(raw.startIndex, offsetBy: 2)..<close.lowerBound])
    }

    private func table(_ rows: [[String]]) -> some View {
        VStack(spacing: theme.density.spacing.space0) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(alignment: .top, spacing: theme.density.spacing.space0) {
                    ForEach(rows[rowIndex].indices, id: \.self) { column in
                        prose(rows[rowIndex][column], size: "sm", weight: rowIndex == 0 ? .bold : .regular, annotations: [])
                            .padding(theme.density.spacing.space2)
                            .overlay(Rectangle().stroke(theme.color.border, lineWidth: theme.geometry.borderHairline))
                    }
                }
                .background(rowIndex == 0 ? theme.color.muted : AtomKit.clear(theme))
            }
        }
    }

    @ViewBuilder
    private func annotatable<Content: View>(index: Int, text: String, @ViewBuilder content: () -> Content) -> some View {
        let ask = props.string("askEvent")
        let note = props.string("noteEvent")
        if ask.isEmpty && note.isEmpty {
            content()
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                content()
                    .padding(theme.density.spacing.space1)
                    .background(selected == index ? theme.color.primary.opacity(0.1) : AtomKit.clear(theme))
                    .contentShape(Rectangle())
                    .onTapGesture { selected = selected == index ? nil : index }
                if selected == index {
                    HStack(spacing: theme.density.spacing.space2) {
                        if !ask.isEmpty {
                            ButtonRenderer(
                                props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "label": .string(props.string("askLabel", default: "Ask")), "action": .string(ask), "actionPayload": ["selectedText": .string(text)]]),
                                modifier: nil,
                                onEvent: onEvent
                            )
                        }
                        if !note.isEmpty {
                            ButtonRenderer(
                                props: AtomKit.child(props, ["variant": "secondary", "size": "sm", "label": .string(props.string("noteLabel", default: "Note")), "action": .string(note), "actionPayload": ["selectedText": .string(text)]]),
                                modifier: nil,
                                onEvent: onEvent
                            )
                        }
                    }
                }
            }
        }
    }
}

@ViewBuilder
func MarkdownContentRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MarkdownContentMoleculeView(props: props, onEvent: onEvent))
}
