import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import MapKit

enum AtomMapPointKind { case marker, pin, route }

final class AtomMapPoint: MKPointAnnotation {
    let kind: AtomMapPointKind
    let payload: AnyCodable?

    init(kind: AtomMapPointKind, payload: AnyCodable? = nil, at coordinate: CLLocationCoordinate2D, title: String?, subtitle: String? = nil) {
        self.kind = kind
        self.payload = payload
        super.init()
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

struct AtomMapRouteStyle {
    let color: UIColor
    let weight: CGFloat
    let dash: [NSNumber]?
    let label: String
}

final class AtomMapRoute: MKPolyline {
    var style = AtomMapRouteStyle(color: UIColor.label, weight: 0, dash: nil, label: "")
}

enum AtomMapGeometry {
    static func distance(_ point: CGPoint, _ from: CGPoint, _ to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : max(0, min(1, ((point.x - from.x) * dx + (point.y - from.y) * dy) / lengthSquared))
        return hypot(point.x - (from.x + t * dx), point.y - (from.y + t * dy))
    }

    static func region(center: CLLocationCoordinate2D, zoom: Double, size: CGSize) -> MKCoordinateRegion {
        let degreesPerPoint = 360 / (256 * pow(2, zoom))
        let lonDelta = min(360, Double(size.width) * degreesPerPoint)
        let latDelta = min(180, Double(size.height) * degreesPerPoint * cos(center.latitude * .pi / 180))
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.000001), longitudeDelta: max(lonDelta, 0.000001)))
    }

    static func dash(_ raw: String) -> [NSNumber]? {
        let values = raw.components(separatedBy: CharacterSet(charactersIn: ", ")).compactMap { Double($0) }
        return values.isEmpty ? nil : values.map { NSNumber(value: $0) }
    }

    static func signature(_ markers: [AnyCodable], _ routes: [AnyCodable]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let encode: ([AnyCodable]) -> String = { list in
            (try? encoder.encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
        return encode(markers) + "|" + encode(routes)
    }
}

struct AtomMapView: UIViewRepresentable {
    let markers: [AnyCodable]
    let routes: [AnyCodable]
    let center: CLLocationCoordinate2D
    let zoom: Double
    let size: CGSize
    let showPin: Bool
    let tint: UIColor
    let hitSlop: CGFloat
    let routeColor: (String) -> UIColor
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onMarkerClick: ((AnyCodable) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let regionKey = "\(center.latitude)|\(center.longitude)|\(zoom)|\(Int(size.width))|\(Int(size.height))"
        if size.width > 0, coordinator.regionKey != regionKey {
            coordinator.regionKey = regionKey
            map.setRegion(map.regionThatFits(AtomMapGeometry.region(center: center, zoom: zoom, size: size)), animated: false)
        }
        let contentKey = AtomMapGeometry.signature(markers, routes)
        if coordinator.contentKey != contentKey {
            coordinator.contentKey = contentKey
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.filter { ($0 as? AtomMapPoint)?.kind != .pin })
            map.addAnnotations(markers.compactMap(coordinator.marker))
            for route in routes.compactMap(coordinator.route) { map.addOverlay(route) }
        }
        if !showPin, let pin = coordinator.pin {
            map.removeAnnotation(pin)
            coordinator.pin = nil
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: AtomMapView
        var regionKey = ""
        var contentKey = ""
        var pin: AtomMapPoint?
        var popup: AtomMapPoint?

        init(_ parent: AtomMapView) { self.parent = parent }

        func marker(_ raw: AnyCodable) -> AtomMapPoint? {
            guard let lat = raw.dictValue?["lat"]?.doubleValue, let lng = raw.dictValue?["lng"]?.doubleValue else { return nil }
            let label = raw.string("label")
            let category = raw.string("category")
            return AtomMapPoint(kind: .marker, payload: raw, at: CLLocationCoordinate2D(latitude: lat, longitude: lng), title: label.isEmpty ? nil : label, subtitle: category.isEmpty ? nil : category)
        }

        func route(_ raw: AnyCodable) -> AtomMapRoute? {
            let coordinates: [CLLocationCoordinate2D] = (raw.dictValue?["waypoints"]?.arrayValue ?? []).compactMap { point in
                guard let lat = point.dictValue?["lat"]?.doubleValue, let lng = point.dictValue?["lng"]?.doubleValue else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            if coordinates.count < 2 { return nil }
            let line = AtomMapRoute(coordinates: coordinates, count: coordinates.count)
            let opacity = raw.dictValue?["opacity"]?.doubleValue ?? 0.8
            line.style = AtomMapRouteStyle(
                color: parent.routeColor(raw.string("color")).withAlphaComponent(CGFloat(opacity)),
                weight: CGFloat(raw.dictValue?["weight"]?.doubleValue ?? 4),
                dash: AtomMapGeometry.dash(raw.string("dashArray")),
                label: raw.string("label")
            )
            return line
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? AtomMapPoint else { return nil }
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "atom-map") as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: point, reuseIdentifier: "atom-map")
            view.annotation = point
            view.markerTintColor = parent.tint
            view.canShowCallout = point.title?.isEmpty == false
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            view.animatesWhenAdded = false
            view.alpha = point.kind == .route ? 0 : 1
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let route = overlay as? AtomMapRoute else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: route)
            renderer.strokeColor = route.style.color
            renderer.lineWidth = route.style.weight
            renderer.lineDashPattern = route.style.dash
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? AtomMapPoint, point.kind == .marker, let payload = point.payload else { return }
            parent.onMarkerClick?(payload)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var current = touch.view
            while let view = current {
                if view is MKAnnotationView { return false }
                current = view.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func hitRoute(_ map: MKMapView, _ point: CGPoint) -> AtomMapRoute? {
            for case let route as AtomMapRoute in map.overlays.reversed() where !route.style.label.isEmpty {
                let vertices = route.points()
                let screen = (0..<route.pointCount).map { map.convert(vertices[$0].coordinate, toPointTo: map) }
                for index in 1..<max(screen.count, 1) where AtomMapGeometry.distance(point, screen[index - 1], screen[index]) <= route.style.weight / 2 + parent.hitSlop {
                    return route
                }
            }
            return nil
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            parent.onMapClick(coordinate)
            if let stale = popup {
                map.removeAnnotation(stale)
                popup = nil
            }
            if parent.showPin {
                if let previous = pin { map.removeAnnotation(previous) }
                let next = AtomMapPoint(kind: .pin, at: coordinate, title: String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                pin = next
                map.addAnnotation(next)
            }
            if let route = hitRoute(map, point) {
                let next = AtomMapPoint(kind: .route, at: coordinate, title: route.style.label)
                popup = next
                map.addAnnotation(next)
                map.selectAnnotation(next, animated: false)
            }
        }
    }
}

struct MapViewMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private func clicked(_ coordinate: CLLocationCoordinate2D) {
        let event = props.string("mapClickEvent")
        if event.isEmpty { return }
        onEvent(event, eventEnvelope(props, payload: .dict(["latitude": .double(coordinate.latitude), "longitude": .double(coordinate.longitude)])))
    }

    private func markerClicked(_ marker: AnyCodable) {
        let markerEvent = props.string("markerClickEvent")
        if !markerEvent.isEmpty { onEvent(markerEvent, eventEnvelope(props, payload: marker)) }
    }

    var body: some View {
        let center = CLLocationCoordinate2D(latitude: props.float("centerLat", default: 51.505), longitude: props.float("centerLng", default: -0.09))
        let hasMarkerEvent = !props.string("markerClickEvent").isEmpty
        GeometryReader { proxy in
            AtomMapView(
                markers: props.dictValue?["markers"]?.arrayValue ?? [],
                routes: props.dictValue?["routes"]?.arrayValue ?? [],
                center: center,
                zoom: props.float("zoom", default: 13),
                size: proxy.size,
                showPin: props.bool("showClickedPin"),
                tint: UIColor(theme.color.primary),
                hitSlop: theme.density.spacing.space2,
                routeColor: { raw in UIColor(raw.isEmpty ? theme.color.primary : AtomKit.cssColor(theme, raw)) },
                onMapClick: clicked,
                onMarkerClick: hasMarkerEvent ? markerClicked : nil
            )
        }
        .frame(height: AtomKit.length(props.string("height", default: "400px")))
        .atomClip(theme, .container)
        .atomAction(props.string("mapClickEvent"), props)
    }
}

@ViewBuilder
func MapViewRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(MapViewMoleculeView(props: props, onEvent: onEvent))
}
