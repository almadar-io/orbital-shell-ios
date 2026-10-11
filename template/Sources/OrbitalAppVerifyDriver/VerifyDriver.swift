import Darwin
import Foundation
import XCTest

/// `orb verify` tap driver. ONE long-lived test: launches the app with the verify
/// bridge on, then serves HTTP+JSON on 127.0.0.1:`ORBITAL_DRIVER_PORT` (default 7358)
/// until `/stop`. Generic — it knows nothing about the app under test; elements are
/// addressed by the accessibility identifiers the renderers stamp
/// (`action-<EVENT>`, `pattern-<name>`, `row-<id>`, `field-<name>`).
///
/// Every XCUITest call runs on the test thread (single connection at a time).
final class VerifyDriverTests: XCTestCase {
    func test_serveDriver() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        let driverPort = UInt16(env["ORBITAL_DRIVER_PORT"] ?? "") ?? 7358
        let bridgePort = env["ORBITAL_VERIFY_PORT"] ?? "7357"

        let app = XCUIApplication()
        var baseEnvironment = ["ORBITAL_VERIFY_BRIDGE": "1", "ORBITAL_VERIFY_PORT": bridgePort]
        if let apiBase = env["ORBITAL_API_BASE_URL"], !apiBase.isEmpty {
            baseEnvironment["ORBITAL_API_BASE_URL"] = apiBase
        }
        if let authToken = env["ORBITAL_AUTH_TOKEN"], !authToken.isEmpty {
            baseEnvironment["ORBITAL_AUTH_TOKEN"] = authToken
        }
        app.launchEnvironment = baseEnvironment
        app.launch()

        let driver = Driver(app: app, baseEnvironment: baseEnvironment)
        try driver.serve(port: driverPort)
        app.terminate()
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data
}

private struct HTTPResponse {
    let status: Int
    let contentType: String
    let body: Data

    static func json(_ status: Int, _ object: Any) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, contentType: "application/json", body: data)
    }

    static func error(_ status: Int, _ message: String) -> HTTPResponse {
        json(status, ["error": message])
    }
}

private final class Driver {
    private let app: XCUIApplication
    private let baseEnvironment: [String: String]
    private var stopRequested = false

    init(app: XCUIApplication, baseEnvironment: [String: String]) {
        self.app = app
        self.baseEnvironment = baseEnvironment
    }

    func serve(port: UInt16) throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        guard listener >= 0 else { throw DriverError.socket("socket() failed: errno \(errno)") }
        defer { close(listener) }
        var reuse: Int32 = 1
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw DriverError.socket("bind 127.0.0.1:\(port) failed: errno \(errno)") }
        guard listen(listener, 8) == 0 else { throw DriverError.socket("listen failed: errno \(errno)") }

        while !stopRequested {
            let client = accept(listener, nil, nil)
            if client < 0 { continue }
            handle(client)
            close(client)
        }
    }

    private func handle(_ client: Int32) {
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        guard let request = readRequest(client) else { return }
        write(client, route(request))
    }

    private func readRequest(_ client: Int32) -> HTTPRequest? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        let separator = Data("\r\n\r\n".utf8)
        var headerEnd: Range<Data.Index>?
        while headerEnd == nil {
            let n = recv(client, &chunk, chunk.count, 0)
            if n <= 0 { return nil }
            buffer.append(chunk, count: n)
            headerEnd = buffer.range(of: separator)
        }
        guard let end = headerEnd,
              let head = String(data: buffer[buffer.startIndex..<end.lowerBound], encoding: .utf8)
        else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var contentLength = 0
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        var body = Data(buffer[end.upperBound...])
        while body.count < contentLength {
            let n = recv(client, &chunk, chunk.count, 0)
            if n <= 0 { return nil }
            body.append(chunk, count: n)
        }
        let target = String(requestLine[1])
        let pieces = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var query: [String: String] = [:]
        if pieces.count == 2 {
            for pair in pieces[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                query[key] = kv.count == 2 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
            }
        }
        return HTTPRequest(method: String(requestLine[0]), path: String(pieces[0]), query: query, body: body.prefix(contentLength))
    }

    private func write(_ client: Int32, _ response: HTTPResponse) {
        let head = "HTTP/1.1 \(response.status) \(reason(response.status))\r\nContent-Type: \(response.contentType)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(response.body)
        out.withUnsafeBytes { raw in
            var sent = 0
            while sent < out.count {
                let n = send(client, raw.baseAddress! + sent, out.count - sent, 0)
                if n <= 0 { return }
                sent += n
            }
        }
    }

    private func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        default: return "Error"
        }
    }

    private func route(_ request: HTTPRequest) -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/health"):
            return .json(200, ["ok": true])
        case ("GET", "/tree"):
            return tree(includeHittable: request.query["hittable"] != "0")
        case ("POST", "/tap"):
            return withBody(request) { body in tap(body) }
        case ("POST", "/longpress"):
            return withBody(request) { body in longPress(body) }
        case ("POST", "/swipe"):
            return withBody(request) { body in swipe(body) }
        case ("POST", "/type"):
            return withBody(request) { body in type(body) }
        case ("GET", "/screenshot"):
            let png = XCUIScreen.main.screenshot().pngRepresentation
            return HTTPResponse(status: 200, contentType: "image/png", body: png)
        case ("POST", "/relaunch"):
            return relaunch(request)
        case ("POST", "/stop"):
            stopRequested = true
            return .json(200, ["ok": true])
        case (_, "/health"), (_, "/tree"), (_, "/tap"), (_, "/longpress"), (_, "/swipe"), (_, "/type"), (_, "/screenshot"), (_, "/relaunch"), (_, "/stop"):
            return .error(405, "method not allowed")
        default:
            return .error(404, "not found")
        }
    }

    /// An empty body relaunches with the base launch environment; `{"env": {K: V}}` merges over it for this launch.
    private func relaunch(_ request: HTTPRequest) -> HTTPResponse {
        var environment = baseEnvironment
        if !request.body.isEmpty {
            guard let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                return .error(400, "body must be a json object")
            }
            if let extra = body["env"] {
                guard let overrides = extra as? [String: String] else { return .error(400, "env must be an object of strings") }
                environment.merge(overrides) { _, new in new }
            }
        }
        app.terminate()
        app.launchEnvironment = environment
        app.launch()
        return .json(200, ["ok": true])
    }

    private func withBody(_ request: HTTPRequest, _ run: ([String: Any]) -> HTTPResponse) -> HTTPResponse {
        guard let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            return .error(400, "body must be a json object")
        }
        return run(object)
    }

    /// `within` narrows the search to the first element carrying that identifier (a row scope such as `row-5`).
    private func resolve(_ body: [String: Any]) -> (XCUIElement?, HTTPResponse?) {
        guard let id = body["id"] as? String, !id.isEmpty else { return (nil, .error(400, "id must be a non-empty string")) }
        var root: XCUIElement = app
        if let within = body["within"] as? String, !within.isEmpty {
            let scope = app.descendants(matching: .any).matching(identifier: within).firstMatch
            guard scope.exists else { return (nil, .error(404, "within \(within) not found")) }
            root = scope
        }
        let element = root.descendants(matching: .any).matching(identifier: id).firstMatch
        guard element.exists else { return (nil, .error(404, "\(id) not found")) }
        return (element, nil)
    }

    /// Taps the centre of the element's on-screen frame, the same rule the Android driver applies to
    /// `uiautomator` bounds; XCUIElement.isHittable/tap() raise a test failure (ending the driver) on
    /// elements without an activation point.
    private func tapCentre(_ target: XCUIElement) -> HTTPResponse? {
        guard let (_, centre) = onScreen(target) else {
            return .error(409, "element exists but has no on-screen area")
        }
        centre.tap()
        return nil
    }

    /// The element's on-screen frame and its centre point, or nil when it has no on-screen area.
    private func onScreen(_ target: XCUIElement) -> (CGRect, XCUICoordinate)? {
        let visible = target.frame.intersection(app.frame)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
        return (visible, point(visible.midX, visible.midY))
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// Press and hold the element's centre past the long-press threshold (the Android driver holds 800 ms).
    private func longPress(_ body: [String: Any]) -> HTTPResponse {
        let (element, failure) = resolve(body)
        if let failure = failure { return failure }
        guard let target = element, let (_, centre) = onScreen(target) else {
            return .error(409, "element exists but has no on-screen area")
        }
        centre.press(forDuration: 0.8)
        return .json(200, ["ok": true])
    }

    /// Fling across 80% of the element's width toward `direction` (`left` | `right`).
    private func swipe(_ body: [String: Any]) -> HTTPResponse {
        guard let direction = body["direction"] as? String, direction == "left" || direction == "right" else {
            return .error(400, "direction must be left or right")
        }
        let (element, failure) = resolve(body)
        if let failure = failure { return failure }
        guard let target = element, let (visible, _) = onScreen(target) else {
            return .error(409, "element exists but has no on-screen area")
        }
        let reach = visible.width * 0.4
        let (from, to) = direction == "left" ? (visible.midX + reach, visible.midX - reach) : (visible.midX - reach, visible.midX + reach)
        point(from, visible.midY).press(forDuration: 0.05, thenDragTo: point(to, visible.midY))
        return .json(200, ["ok": true])
    }

    private func tap(_ body: [String: Any]) -> HTTPResponse {
        let (element, failure) = resolve(body)
        if let failure = failure { return failure }
        guard let target = element else { return .error(404, "not found") }
        if let refused = tapCentre(target) { return refused }
        return .json(200, ["ok": true])
    }

    private func type(_ body: [String: Any]) -> HTTPResponse {
        guard let text = body["text"] as? String else { return .error(400, "text must be a string") }
        let (element, failure) = resolve(body)
        if let failure = failure { return failure }
        guard let target = element else { return .error(404, "not found") }
        let input = editable(target)
        if let refused = tapCentre(input) { return refused }
        guard waitForKeyboardFocus(input) else {
            return .error(409, "the field took no keyboard focus after the tap")
        }
        input.typeText(text)
        return .json(200, ["ok": true])
    }

    /// A field id stamps the field's container; the text input is the element itself when it is one,
    /// else its first text-input descendant.
    private func editable(_ element: XCUIElement) -> XCUIElement {
        let inputs: [XCUIElement.ElementType] = [.textField, .secureTextField, .textView, .searchField]
        if inputs.contains(element.elementType) { return element }
        for kind in inputs {
            let found = element.descendants(matching: kind).firstMatch
            if found.exists { return found }
        }
        return element
    }

    /// Typing into an element without keyboard focus raises a test failure that ends the driver.
    private func waitForKeyboardFocus(_ input: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        repeat {
            if (input.value(forKey: "hasKeyboardFocus") as? Bool) == true { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    private func tree(includeHittable: Bool) -> HTTPResponse {
        let snapshot: XCUIElementSnapshot
        do {
            snapshot = try app.snapshot()
        } catch {
            return .error(409, "snapshot failed: \(error)")
        }
        var nodes: [[String: Any]] = []
        collect(snapshot, ancestors: [], screen: snapshot.frame, includeHittable: includeHittable, into: &nodes)
        return .json(200, ["elements": nodes])
    }

    private func collect(
        _ node: XCUIElementSnapshot,
        ancestors: [String],
        screen: CGRect,
        includeHittable: Bool,
        into nodes: inout [[String: Any]]
    ) {
        var scope = ancestors
        let id = node.identifier
        if !id.isEmpty {
            let frame = node.frame
            var entry: [String: Any] = [
                "id": id,
                "type": typeName(node.elementType),
                "label": node.label,
                "value": stringValue(node.value),
                "frame": ["x": frame.origin.x, "y": frame.origin.y, "w": frame.size.width, "h": frame.size.height],
                "enabled": node.isEnabled,
                "ancestors": ancestors,
            ]
            // Same definition as the Android tree (enabled, with on-screen area); XCUIElement.isHittable
            // raises a test failure on elements without an activation point, which ends the driver.
            if includeHittable {
                let visible = frame.intersection(screen)
                entry["hittable"] = node.isEnabled && !visible.isNull && visible.width > 0 && visible.height > 0
            }
            nodes.append(entry)
            scope.append(id)
        }
        for child in node.children {
            collect(child, ancestors: scope, screen: screen, includeHittable: includeHittable, into: &nodes)
        }
    }

    private func stringValue(_ value: Any?) -> String {
        guard let value = value else { return "" }
        return "\(value)"
    }

    private func typeName(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .any: return "any"
        case .other: return "other"
        case .application: return "application"
        case .window: return "window"
        case .button: return "button"
        case .staticText: return "staticText"
        case .textField: return "textField"
        case .secureTextField: return "secureTextField"
        case .textView: return "textView"
        case .image: return "image"
        case .icon: return "icon"
        case .switch: return "switch"
        case .toggle: return "toggle"
        case .slider: return "slider"
        case .picker: return "picker"
        case .pickerWheel: return "pickerWheel"
        case .table: return "table"
        case .collectionView: return "collectionView"
        case .cell: return "cell"
        case .scrollView: return "scrollView"
        case .navigationBar: return "navigationBar"
        case .tabBar: return "tabBar"
        case .tab: return "tab"
        case .alert: return "alert"
        case .sheet: return "sheet"
        case .link: return "link"
        case .searchField: return "searchField"
        case .segmentedControl: return "segmentedControl"
        case .checkBox: return "checkBox"
        case .progressIndicator: return "progressIndicator"
        case .activityIndicator: return "activityIndicator"
        case .group: return "group"
        case .stepper: return "stepper"
        case .menu: return "menu"
        case .menuItem: return "menuItem"
        case .webView: return "webView"
        default: return "elementType(\(type.rawValue))"
        }
    }
}

private enum DriverError: Error {
    case socket(String)
}
