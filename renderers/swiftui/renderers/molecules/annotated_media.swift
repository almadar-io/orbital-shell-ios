import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct AnnotatedMediaMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private struct Pin {
        let id: String
        let number: Int
        let x: Double
        let y: Double
        let label: String
        let resolved: Bool
    }

    private var pins: [Pin] {
        (props.dictValue?["pins"]?.arrayValue ?? []).enumerated().compactMap { index, pin in
            guard let x = pin.dictValue?["x"]?.doubleValue, let y = pin.dictValue?["y"]?.doubleValue else { return nil }
            return Pin(id: pin.string("id"), number: index + 1, x: x, y: y, label: pin.string("label"), resolved: pin.bool("resolved"))
        }
    }

    var body: some View {
        let title = props.string("title")
        if props.string("mediaType", default: "image") == "video" {
            FallbackRendererView(patternName: "annotated-media", props: props, modifier: nil, onEvent: onEvent)
        } else {
            ImageRenderer(
                props: ["src": .string(AtomKit.assetURL(props, "src")), "alt": .string(title), "fit": "contain"],
                modifier: nil,
                onEvent: onEvent
            )
            .overlay(GeometryReader { proxy in overlay(proxy.size) })
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }

    private func overlay(_ size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(AtomKit.clear(theme))
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { place($0.location, in: size) })
                .atomAction(props.string("placeEvent"), props)
            ForEach(pins, id: \.id) { pin in
                badge(pin)
                    .position(x: size.width * pin.x / 100, y: size.height * pin.y / 100)
            }
        }
    }

    private func badge(_ pin: Pin) -> some View {
        let active = pin.id == props.string("activePinId")
        let diameter = theme.density.buttonHeightSm
        return ZStack {
            Circle().fill(pin.resolved ? theme.color.muted : theme.color.primary)
            Circle().strokeBorder(active ? theme.color.ring : theme.color.background, lineWidth: active ? theme.geometry.borderHeavy : theme.geometry.borderStandard)
            AtomKit.typo(String(pin.number), "caption", color: "inherit", weight: "bold", onEvent: onEvent)
                .foregroundColor(pin.resolved ? theme.color.mutedForeground : theme.color.primaryForeground)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onTapGesture { select(pin) }
        .atomAction(props.string("pinSelectEvent"), props)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.label.isEmpty ? String(pin.number) : pin.label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private func percent(_ value: CGFloat, of extent: CGFloat) -> Double {
        let raw = Double(value / extent) * 100
        return (min(100, max(0, raw)) * 10).rounded() / 10
    }

    private func place(_ location: CGPoint, in size: CGSize) {
        let event = props.string("placeEvent")
        guard props.bool("placing", default: true), !event.isEmpty, size.width > 0, size.height > 0 else { return }
        onEvent(event, eventEnvelope(props, payload: ["x": .double(percent(location.x, of: size.width)), "y": .double(percent(location.y, of: size.height)), "time": .int(0)]))
    }

    private func select(_ pin: Pin) {
        let event = props.string("pinSelectEvent")
        guard !event.isEmpty else { return }
        onEvent(event, eventEnvelope(props, payload: ["id": .string(pin.id)]))
    }
}

@ViewBuilder
func AnnotatedMediaRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(AnnotatedMediaMoleculeView(props: props, onEvent: onEvent))
}
