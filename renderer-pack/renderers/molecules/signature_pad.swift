import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SignatureStrokes: View {
    let strokes: [[CGPoint]]
    let color: Color
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes where !stroke.isEmpty {
                var path = Path()
                path.move(to: stroke[0])
                if stroke.count == 1 { path.addLine(to: stroke[0]) }
                for point in stroke.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct SignaturePadMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var strokes: [[CGPoint]] = []
    @State private var drawing = false
    @State private var padSize: CGSize = .zero

    private var signed: Bool { !strokes.isEmpty || !props.string("value").isEmpty }
    private var ink: Color {
        let given = props.string("strokeColor")
        return given.isEmpty ? theme.color.foreground : AtomKit.cssColor(theme, given)
    }
    private var inkWidth: CGFloat { CGFloat(props.dictValue?["strokeWidth"]?.doubleValue ?? 2) }

    private func dataURL() -> String? {
        let layer = SignatureStrokes(strokes: strokes, color: ink, width: inkWidth)
            .frame(width: padSize.width, height: padSize.height)
        let renderer = SwiftUI.ImageRenderer(content: layer)
        renderer.scale = 2
        guard let png = renderer.uiImage?.pngData() else { return nil }
        return "data:image/png;base64," + png.base64EncodedString()
    }

    private func announce() {
        let event = props.string("onChange")
        if event.isEmpty { return }
        let value: AnyCodable = dataURL().map { .string($0) } ?? .null
        onEvent(event, eventEnvelope(props, payload: ["value": value]))
    }

    private func clear() {
        strokes = []
        let event = props.string("onChange")
        if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["value": .null])) }
        let clearEvent = props.string("clearEvent")
        if !clearEvent.isEmpty { onEvent(clearEvent, eventEnvelope(props, payload: [:])) }
    }

    private func confirm() {
        let event = props.string("signEvent")
        if event.isEmpty { return }
        onEvent(event, eventEnvelope(props, payload: ["signature": dataURL().map { .string($0) } ?? .null]))
    }

    private func drag() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !props.bool("readOnly") else { return }
                if drawing {
                    strokes[strokes.count - 1].append(value.location)
                } else {
                    drawing = true
                    strokes.append([value.location])
                }
            }
            .onEnded { _ in
                guard drawing else { return }
                drawing = false
                announce()
            }
    }

    private var pad: some View {
        let shape = AtomKit.shape(theme, .container)
        let readOnly = props.bool("readOnly")
        return ZStack {
            if !props.string("value").isEmpty && strokes.isEmpty {
                ImageRenderer(props: AtomKit.child(props, ["src": .string(props.string("value")), "alt": .string(props.string("label", default: "Signature")), "fit": "contain"]), modifier: nil, onEvent: onEvent)
            }
            SignatureStrokes(strokes: strokes, color: ink, width: inkWidth)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(props.dictValue?["height"]?.doubleValue ?? 200))
        .background(GeometryReader { proxy in
            theme.color.background.onAppear { padSize = proxy.size }.onChange(of: proxy.size) { next in padSize = next }
        })
        .clipShape(shape)
        .overlay(shape.stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        .opacity(readOnly ? 0.6 : 1)
        .contentShape(Rectangle())
        .gesture(drag())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(props.string("label", default: "Signature"))
        .accessibilityAddTraits(.isImage)
    }

    var body: some View {
        if props.bool("isLoading") {
            LoadingStateRenderer(props: AtomKit.child(props, ["message": "Loading..."]), modifier: nil, onEvent: onEvent)
        } else if !AtomKit.errorText(props).isEmpty {
            ErrorStateRenderer(props: AtomKit.child(props, ["title": "Signature pad error", "message": .string(AtomKit.errorText(props))]), modifier: nil, onEvent: onEvent)
        } else {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                let label = props.string("label", default: "Signature")
                let helper = props.string("helperText", default: "Draw your signature above")
                if !label.isEmpty { AtomKit.typo(label, "label", weight: "medium", onEvent: onEvent) }
                pad
                if !helper.isEmpty { AtomKit.typo(helper, "caption", color: "secondary", onEvent: onEvent) }
                if !props.bool("readOnly") {
                    HStack(spacing: theme.density.spacing.space2) {
                        Spacer(minLength: theme.density.spacing.space0)
                        ButtonRenderer(
                            props: AtomKit.child(props, ["variant": "ghost", "size": "sm", "icon": "eraser", "label": "Clear", "disabled": .bool(!signed), "action": .string(AtomKit.localEvent), "local": true]),
                            modifier: nil,
                            onEvent: { _, _ in clear() }
                        )
                        if !props.string("signEvent").isEmpty {
                            ButtonRenderer(
                                props: AtomKit.child(props, ["variant": "primary", "size": "sm", "icon": "check", "label": "Confirm", "disabled": .bool(!signed), "action": .string(props.string("signEvent"))]),
                                modifier: nil,
                                onEvent: { _, _ in confirm() }
                            )
                        }
                    }
                }
            }
            .atomSurface(theme, padding: theme.density.spacing.space4)
            .accessibilityElement(children: .contain)
        }
    }
}

@ViewBuilder
func SignaturePadRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SignaturePadMoleculeView(props: props, onEvent: onEvent))
}
