// Swift↔Rust bridge for the orbital-game-renderer Metal surface.
//
// @_silgen_name maps each symbol to the #[no_mangle] extern "C" fn exported by
// orbital-game-renderer/src/c_api.rs.  The static lib is linked via
// OrbitalGameRenderer.modulemap (project.yml adds it as a linked library).
//
// Usage: OrbitalGameRendererView owns one OpaquePointer (the *mut GameRenderer
// from Rust) and drives init → set_scene → render → destroy through MTKViewDelegate.

import CoreText
import Foundation
import MetalKit
import SwiftUI

// MARK: - Rust c_api bindings

/// Opaque handle to a `GameRenderer` allocated on the Rust heap.
typealias OrbitalGameRendererHandle = OpaquePointer

@_silgen_name("orbital_game_renderer_init")
func orbital_game_renderer_init(
    _ rawSurface: UnsafeMutableRawPointer?,
    _ width: UInt32,
    _ height: UInt32,
    _ resourceBaseUrl: UnsafePointer<CChar>?
) -> OrbitalGameRendererHandle?

@_silgen_name("orbital_game_renderer_destroy")
func orbital_game_renderer_destroy(_ renderer: OrbitalGameRendererHandle)

@_silgen_name("orbital_game_renderer_submit")
func orbital_game_renderer_submit(
    _ renderer: OrbitalGameRendererHandle,
    _ jsonPacket: UnsafePointer<CChar>
)

@_silgen_name("orbital_game_renderer_set_scene")
func orbital_game_renderer_set_scene(
    _ renderer: OrbitalGameRendererHandle,
    _ sceneJson: UnsafePointer<CChar>
) -> Int32

@_silgen_name("orbital_game_renderer_last_error")
func orbital_game_renderer_last_error(_ renderer: OrbitalGameRendererHandle?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_game_renderer_render")
func orbital_game_renderer_render(_ renderer: OrbitalGameRendererHandle)

@_silgen_name("orbital_game_renderer_resize")
func orbital_game_renderer_resize(
    _ renderer: OrbitalGameRendererHandle,
    _ width: UInt32,
    _ height: UInt32
)

@_silgen_name("orbital_game_renderer_set_scale")
func orbital_game_renderer_set_scale(
    _ renderer: OrbitalGameRendererHandle,
    _ scale: Float
) -> Int32

/// The host frame clock in milliseconds, handed over before each render; the first value is scene time zero.
@_silgen_name("orbital_game_renderer_set_clock")
func orbital_game_renderer_set_clock(_ renderer: OrbitalGameRendererHandle, _ ms: Double)

/// Allow (1) or forbid (0) motion; forbidden, animated scenes draw their rest frame.
@_silgen_name("orbital_game_renderer_set_motion")
func orbital_game_renderer_set_motion(_ renderer: OrbitalGameRendererHandle, _ enabled: Int32)

/// 1 while frames should keep coming (the scene animates, or its assets are arriving), else 0.
@_silgen_name("orbital_game_renderer_wants_frames")
func orbital_game_renderer_wants_frames(_ renderer: OrbitalGameRendererHandle) -> Int32

@_silgen_name("orbital_game_renderer_input")
func orbital_game_renderer_input(
    _ renderer: OrbitalGameRendererHandle,
    _ eventType: UnsafePointer<CChar>,
    _ x: Float,
    _ y: Float,
    _ button: Int32,
    _ key: UnsafePointer<CChar>?
) -> Int32

/// Scene events that taps queued since the last call, as a JSON array of `{event, payload}`.
/// Free the result with `orbital_game_renderer_free_string`.
@_silgen_name("orbital_game_renderer_take_events")
func orbital_game_renderer_take_events(_ renderer: OrbitalGameRendererHandle) -> UnsafeMutablePointer<CChar>?

/// The scene's own size in logical units, so a host can size its view before a renderer exists.
@_silgen_name("orbital_game_renderer_scene_size")
func orbital_game_renderer_scene_size(
    _ sceneJson: UnsafePointer<CChar>,
    _ outW: UnsafeMutablePointer<Float>,
    _ outH: UnsafeMutablePointer<Float>
) -> Int32

/// One-shot headless render of a scene into RGBA bytes (physical pixels at density `scale`).
@_silgen_name("orbital_game_renderer_render_scene_rgba")
func orbital_game_renderer_render_scene_rgba(
    _ sceneJson: UnsafePointer<CChar>,
    _ width: UInt32,
    _ height: UInt32,
    _ scale: Float,
    _ outPixels: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ outLen: UnsafeMutablePointer<Int>
) -> Int32

@_silgen_name("orbital_game_renderer_render_to_rgba")
func orbital_game_renderer_render_to_rgba(
    _ renderer: OrbitalGameRendererHandle,
    _ outPixels: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ outLen: UnsafeMutablePointer<Int>
) -> Int32

@_silgen_name("orbital_game_renderer_free_rgba")
func orbital_game_renderer_free_rgba(_ pixels: UnsafeMutablePointer<UInt8>, _ len: Int)

@_silgen_name("orbital_game_renderer_free_string")
func orbital_game_renderer_free_string(_ s: UnsafeMutablePointer<CChar>)

/// A pinch zooming a pannable scene (a graph) by `factor` about the focus, in points.
@_silgen_name("orbital_game_renderer_zoom")
func orbital_game_renderer_zoom(_ renderer: OrbitalGameRendererHandle, _ factor: Float, _ x: Float, _ y: Float)

/// A view button on a pannable scene: `zoom-in`, `zoom-out` or `reset`; 1 when applied.
@_silgen_name("orbital_game_renderer_view_command")
func orbital_game_renderer_view_command(_ renderer: OrbitalGameRendererHandle, _ command: UnsafePointer<CChar>) -> Int32

/// The asset cache counter: moves when a sprite sheet, atlas or image finishes loading.
@_silgen_name("orbital_game_renderer_asset_generation")
func orbital_game_renderer_asset_generation() -> UInt64

/// Published asset counter: canvas hosts that size from the scene re-measure when it moves (a
/// sprite with no authored size takes its aspect from the loaded image).
final class AssetGeneration: ObservableObject {
    static let shared = AssetGeneration()
    @Published private(set) var value: UInt64 = 0

    /// Publish the counter after a frame (main thread, the MTKView delegate).
    func poll() {
        let now = orbital_game_renderer_asset_generation()
        if now != value { value = now }
    }
}

/// Scripts painted text needed and no face covers, each once: JSON `[{"script", "sample"}]`.
/// Free the result with `orbital_game_renderer_free_string`.
@_silgen_name("orbital_game_renderer_take_missing_scripts")
func orbital_game_renderer_take_missing_scripts() -> UnsafeMutablePointer<CChar>?

/// Register face `index` of a font for `script` (ISO 15924); 1 when accepted, 0 when refused.
@_silgen_name("orbital_game_renderer_add_font")
func orbital_game_renderer_add_font(
    _ script: UnsafePointer<CChar>,
    _ bytes: UnsafePointer<UInt8>,
    _ len: Int,
    _ index: UInt32
) -> Int32

/// Answers the renderer's missing scripts from the platform: Core Text's own font for the
/// script's sample char (`CTFontCreateForString`), handed over as one sfnt rebuilt from its
/// tables (Core Text exposes a system font's tables, not its file).
enum SystemFontSource {
    /// True when a face was added, so the caller draws again.
    static func supplyMissing() -> Bool {
        guard let raw = orbital_game_renderer_take_missing_scripts() else { return false }
        defer { orbital_game_renderer_free_string(raw) }
        guard let missing = try? JSONDecoder().decode([[String: String]].self, from: Data(String(cString: raw).utf8)) else {
            return false
        }
        var added = false
        for entry in missing {
            guard let script = entry["script"], let sample = entry["sample"] else { continue }
            if supply(script: script, sample: sample) {
                added = true
            } else {
                NSLog("[OrbitalGame] no system font for script %@", script)
            }
        }
        return added
    }

    private static func supply(script: String, sample: String) -> Bool {
        let base = CTFontCreateUIFontForLanguage(.system, 16, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        let font = CTFontCreateForString(base, sample as CFString, CFRange(location: 0, length: (sample as NSString).length))
        guard let data = sfnt(of: font), !data.isEmpty else { return false }
        let accepted = data.withUnsafeBytes { buffer -> Int32 in
            guard let bytes = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return script.withCString { orbital_game_renderer_add_font($0, bytes, buffer.count, 0) }
        }
        return accepted == 1
    }

    private static func sfnt(of font: CTFont) -> Data? {
        guard let available = CTFontCopyAvailableTables(font, CTFontTableOptions(rawValue: 0)) else { return nil }
        var tables: [(tag: UInt32, data: Data)] = []
        for i in 0..<CFArrayGetCount(available) {
            let tag = CTFontTableTag(UInt(bitPattern: CFArrayGetValueAtIndex(available, i)))
            if let table = CTFontCopyTable(font, tag, CTFontTableOptions(rawValue: 0)) as Data? {
                tables.append((tag, table))
            }
        }
        guard !tables.isEmpty else { return nil }
        tables.sort { $0.tag < $1.tag }
        func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff)] }
        func be16(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xff)] }
        let cff: UInt32 = 0x4346_4620
        let count = UInt16(tables.count)
        var power: UInt16 = 1
        var log2: UInt16 = 0
        while power * 2 <= count { power *= 2; log2 += 1 }
        var out = Data(be32(tables.contains { $0.tag == cff } ? 0x4F54_544F : 0x0001_0000))
        out.append(contentsOf: be16(count) + be16(power * 16) + be16(log2) + be16(count * 16 - power * 16))
        var offset = UInt32(12 + 16 * tables.count)
        var body = Data()
        for table in tables {
            let padded = (table.data.count + 3) & ~3
            var sum: UInt32 = 0
            var word = Data(table.data)
            word.append(Data(count: padded - table.data.count))
            word.withUnsafeBytes { raw in
                for k in stride(from: 0, to: padded, by: 4) {
                    let hi: UInt32 = UInt32(raw[k]) << 24 | UInt32(raw[k + 1]) << 16
                    let lo: UInt32 = UInt32(raw[k + 2]) << 8 | UInt32(raw[k + 3])
                    sum = sum &+ (hi | lo)
                }
            }
            out.append(contentsOf: be32(table.tag) + be32(sum) + be32(offset) + be32(UInt32(table.data.count)))
            body.append(word)
            offset += UInt32(padded)
        }
        out.append(body)
        return out
    }
}

/// Whether the Rust renderer draws `pattern` with `props`: a host composing a scene (a mermaid
/// fence in markdown) shows its own fallback when this is false.
func orbitalSceneDrawable(_ pattern: String, _ props: AnyCodable) -> Bool {
    var fields = props.dictValue ?? [:]
    fields["type"] = .string(pattern)
    guard let data = try? JSONEncoder().encode(AnyCodable.dict(fields)),
          let json = String(data: data, encoding: .utf8) else { return false }
    var w: Float = 0
    var h: Float = 0
    return json.withCString { orbital_game_renderer_scene_size($0, &w, &h) } == 1 && h > 0
}

// MARK: - MTKView coordinator

/// Drives the Rust renderer from an MTKView.  One instance per canvas widget.
final class OrbitalGameMTKCoordinator: NSObject, MTKViewDelegate {
    private var handle: OrbitalGameRendererHandle?
    private var pendingScene: String?
    private weak var view: MTKView?
    private var motionObserver: NSObjectProtocol?

    /// Receives each event a tap on the scene produced (name, payload).
    var onSceneEvent: ((String, AnyCodable?) -> Void)?

    /// Forward a touch in logical points (UIKit points); a tap that ends on an interactive
    /// scene's shape comes back from the renderer as that shape's authored event; a drag reports
    /// its moves as they happen.
    func touch(_ type: String, at point: CGPoint) {
        guard let h = handle else { return }
        _ = type.withCString { orbital_game_renderer_input(h, $0, Float(point.x), Float(point.y), 0, nil) }
        if type == "touch-up" || type == "touch-move" || type == "double-tap" { drainSceneEvents(h) }
        wake()
    }

    /// Pinch zooms a pannable scene, a double tap fires `onNodeDoubleClick` and a long press is
    /// hover; all three leave the
    /// single-touch stream (taps, drags, pans) to `touch`.
    private func installGestures(on view: MTKView) {
        view.isMultipleTouchEnabled = true
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.cancelsTouchesInView = false
        view.addGestureRecognizer(pinch)
        let double = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        double.cancelsTouchesInView = false
        double.delaysTouchesEnded = false
        view.addGestureRecognizer(double)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        press.cancelsTouchesInView = false
        view.addGestureRecognizer(press)
    }

    /// A long press is the touch stand-in for hover (a truncated label's full text).
    @objc private func onLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let view = gesture.view, gesture.state == .began else { return }
        touch("long-press", at: gesture.location(in: view))
    }

    @objc private func onPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let h = handle, let view = gesture.view, gesture.state == .changed else { return }
        let focus = gesture.location(in: view)
        orbital_game_renderer_zoom(h, Float(gesture.scale), Float(focus.x), Float(focus.y))
        gesture.scale = 1
        wake()
    }

    @objc private func onDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        touch("double-tap", at: gesture.location(in: view))
    }

    private func drainSceneEvents(_ h: OrbitalGameRendererHandle) {
        guard let raw = orbital_game_renderer_take_events(h) else { return }
        defer { orbital_game_renderer_free_string(raw) }
        guard let events = try? JSONDecoder().decode([AnyCodable].self, from: Data(String(cString: raw).utf8)) else { return }
        for event in events {
            guard let name = event["event"]?.stringValue else { continue }
            onSceneEvent?(name, event["payload"])
        }
    }

    // Called once when the MTKView is ready (metalLayer is valid).
    func attach(to view: MTKView, width: UInt32, height: UInt32) {
        guard handle == nil else { return }
        let layer = view.layer  // CAMetalLayer* is the backing layer for MTKView
        let rawLayer = Unmanaged.passUnretained(layer).toOpaque()
        handle = orbital_game_renderer_init(rawLayer, width, height, nil)
        self.view = view
        installGestures(on: view)
        if let h = handle {
            applyScale(h, view)
            applyMotion(h)
            motionObserver = NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self, let h = self.handle else { return }
                self.applyMotion(h)
                self.wake()
            }
        }
        // else: no Metal device available (simulator without GPU support).
    }

    /// drawableSize is physical pixels; the renderer lays the scene out in points
    /// (physical / scale) so a board is the same logical size as on the web.
    private func applyScale(_ h: OrbitalGameRendererHandle, _ view: MTKView) {
        if orbital_game_renderer_set_scale(h, Float(view.contentScaleFactor)) == 0 {
            NSLog("[OrbitalGame] set_scale refused: %@", lastRendererError())
        }
    }

    /// The OS reduced-motion setting: forbidden, animated scenes draw their rest frame.
    private func applyMotion(_ h: OrbitalGameRendererHandle) {
        orbital_game_renderer_set_motion(h, UIAccessibility.isReduceMotionEnabled ? 0 : 1)
    }

    /// Start the display link again. `draw` stops it once the scene is static and its assets have
    /// landed, so a still diagram costs no frames; a new scene, a touch or a resize wakes it.
    private func wake() {
        view?.enableSetNeedsDisplay = false
        view?.isPaused = false
    }

    private func idle(_ view: MTKView) {
        view.isPaused = true
        view.enableSetNeedsDisplay = true
    }

    func detach() {
        if let observer = motionObserver {
            NotificationCenter.default.removeObserver(observer)
            motionObserver = nil
        }
        if let h = handle {
            orbital_game_renderer_destroy(h)
            handle = nil
        }
    }

    /// Enqueue the canvas render-ui node (JSON) for the next frame. The Rust
    /// renderer maps it to a display list (`set_scene`); nothing is interpreted here.
    func setScene(json: String) {
        guard json != lastScene else { return }
        pendingScene = json
        wake()
    }

    private var lastScene: String?

    private func lastRendererError() -> String {
        guard let raw = orbital_game_renderer_last_error(handle) else { return "" }
        defer { orbital_game_renderer_free_string(raw) }
        return String(cString: raw)
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let h = handle else { return }
        applyScale(h, view)
        orbital_game_renderer_resize(h, UInt32(size.width), UInt32(size.height))
        wake()
    }

    func draw(in view: MTKView) {
        guard let h = handle else { return }
        if let scene = pendingScene {
            let accepted = scene.withCString { ptr in
                orbital_game_renderer_set_scene(h, ptr)
            }
            if accepted == 0 {
                NSLog("[OrbitalGame] set_scene refused: %@", lastRendererError())
            }
            lastScene = scene
            pendingScene = nil
        }
        orbital_game_renderer_set_clock(h, CACurrentMediaTime() * 1000)
        orbital_game_renderer_render(h)
        if SystemFontSource.supplyMissing() { orbital_game_renderer_render(h) }
        AssetGeneration.shared.poll()
        if orbital_game_renderer_wants_frames(h) == 0 { idle(view) }
    }
}

/// The MTKView that reports touches to the coordinator as renderer input.
final class OrbitalGameMTKView: MTKView {
    weak var coordinator: OrbitalGameMTKCoordinator?

    private func forward(_ type: String, _ touches: Set<UITouch>, _ event: UIEvent?) {
        guard let touch = touches.first else { return }
        if (event?.allTouches?.count ?? 1) > 1 {
            // A second finger makes the gesture a pinch: the one-finger pan or drag stops.
            if type == "touch-down" { coordinator?.touch("touch-cancel", at: touch.location(in: self)) }
            return
        }
        coordinator?.touch(type, at: touch.location(in: self))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward("touch-down", touches, event)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward("touch-move", touches, event)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward("touch-up", touches, event)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward("touch-cancel", touches, event)
        super.touchesCancelled(touches, with: event)
    }
}

// MARK: - CorePatternRegistry entry point

/// UIViewRepresentable hosting the MTKView; owns the coordinator across SwiftUI updates.
private struct OrbitalGameMTKHostView: UIViewRepresentable {
    let sceneJson: String
    var onSceneEvent: ((String, AnyCodable?) -> Void)? = nil

    func makeCoordinator() -> OrbitalGameMTKCoordinator {
        OrbitalGameMTKCoordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = OrbitalGameMTKView()
        view.coordinator = context.coordinator
        context.coordinator.onSceneEvent = onSceneEvent
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        context.coordinator.attach(
            to: view,
            width: UInt32(max(view.drawableSize.width, 1)),
            height: UInt32(max(view.drawableSize.height, 1))
        )
        context.coordinator.setScene(json: sceneJson)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.onSceneEvent = onSceneEvent
        context.coordinator.setScene(json: sceneJson)
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: OrbitalGameMTKCoordinator) {
        coordinator.detach()
    }
}

/// Registered in `CorePatternRegistry` for `canvas` / `game-canvas` / `canvas-2d` /
/// `game-canvas-2d`. Hands the node's props (JSON) to the Rust renderer through
/// `orbital_game_renderer_set_scene`: the renderer owns the children→drawables
/// routing, camera vocabulary and the drawable walk
/// (`orbital-game-renderer::mappers::game_canvas_2d::from_canvas_node`), shared with
/// the desktop shells. The draw-* children are never rendered as SwiftUI views.
func GameCanvas2dRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let sceneJson: String
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    if let data = try? encoder.encode(props),
       let encoded = String(data: data, encoding: .utf8) {
        sceneJson = encoded
    } else {
        sceneJson = "{}"
    }
    return AnyView(
        OrbitalGameMTKHostView(sceneJson: sceneJson)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .verificationId("game-canvas")
    )
}

/// Registered in `CorePatternRegistry` for the learning canvases (`math-canvas`,
/// `physics-canvas`, ...). The Rust renderer draws them (`mappers::learning`) on the same
/// Metal surface the game boards use; this host sizes the view to the scene's own aspect
/// ratio, shows the pattern's `title` above it, and forwards taps as the pattern's authored
/// events (`onShapeClick`, ...) through `onEvent`. No drawing happens here. A `fixedSize` pattern
/// (the web draws it in fixed CSS pixels) is capped at the scene's own width instead of filling the column.
func LearningCanvasRenderer(
    pattern: String,
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void,
    fixedSize: Bool = false
) -> AnyView {
    AnyView(
        LearningCanvasHostView(pattern: pattern, props: props, onEvent: onEvent, fixedSize: fixedSize)
            .verificationId("learning-canvas")
    )
}

/// How a canvas scene reaches pixels: the Metal surface of an app, or a one-shot Rust raster for
/// snapshot tests (a Metal layer is not captured by `drawHierarchy`).
enum OrbitalCanvasTarget { case surface, raster }

private struct OrbitalCanvasTargetKey: EnvironmentKey {
    static let defaultValue: OrbitalCanvasTarget = .surface
}

extension EnvironmentValues {
    var orbitalCanvasTarget: OrbitalCanvasTarget {
        get { self[OrbitalCanvasTargetKey.self] }
        set { self[OrbitalCanvasTargetKey.self] = newValue }
    }
    /// The app theme's resolved `canvasTheme` from the kernel snapshot; nil outside an app (snapshot tests).
    var almadarCanvasTheme: AnyCodable? {
        get { self[AlmadarCanvasThemeKey.self] }
        set { self[AlmadarCanvasThemeKey.self] = newValue }
    }
    /// The app theme's resolved motion (orbital-core `resolve_motion`) from the kernel snapshot: what an
    /// element entry and a surface's enter shape animate. nil outside an app (snapshot tests): nothing animates.
    var almadarResolvedMotion: AnyCodable? {
        get { self[AlmadarMotionKey.self] }
        set { self[AlmadarMotionKey.self] = newValue }
    }
    /// Set by a host that lays its children out at their natural size (`scaled-diagram`): a canvas
    /// takes its scene's own size instead of filling the column.
    var almadarCanvasNaturalSize: Bool {
        get { self[AlmadarCanvasNaturalSizeKey.self] }
        set { self[AlmadarCanvasNaturalSizeKey.self] = newValue }
    }
}

private struct AlmadarMotionKey: EnvironmentKey {
    static let defaultValue: AnyCodable? = nil
}

private struct AlmadarCanvasNaturalSizeKey: EnvironmentKey {
    static let defaultValue = false
}

private struct AlmadarCanvasThemeKey: EnvironmentKey {
    static let defaultValue: AnyCodable? = nil
}

/// Shows a scene the Rust renderer drew once, headless, at this view's pixel size and the screen
/// scale — the same mapper and renderer the surface path runs. Snapshot tests only.
private struct OrbitalGameRasterView: View {
    let sceneJson: String

    var body: some View {
        GeometryReader { geo in
            if let image = Self.render(sceneJson, size: geo.size, scale: UIScreen.main.scale) {
                Image(uiImage: image).resizable()
            }
        }
    }

    private static func render(_ scene: String, size: CGSize, scale: CGFloat) -> UIImage? {
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        guard width > 0, height > 0 else { return nil }
        var pixels: UnsafeMutablePointer<UInt8>?
        var length = 0
        let ok = scene.withCString { orbital_game_renderer_render_scene_rgba($0, UInt32(width), UInt32(height), Float(scale), &pixels, &length) }
        guard ok == 1, let raw = pixels else {
            NSLog("[OrbitalGame] raster render refused (no GPU adapter or a scene the native painter refuses)")
            return nil
        }
        defer { orbital_game_renderer_free_rgba(raw, length) }
        let data = Data(bytes: raw, count: length)
        guard let provider = CGDataProvider(data: data as CFData),
              let cg = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

private struct LearningCanvasHostView: View {
    let pattern: String
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    var fixedSize: Bool = false
    @Environment(\.almadarThemeMode) private var themeMode
    @Environment(\.orbitalCanvasTarget) private var target
    @Environment(\.almadarCanvasTheme) private var canvasTheme
    @Environment(\.almadarCanvasNaturalSize) private var naturalSize
    @ObservedObject private var assets = AssetGeneration.shared

    private var sceneJson: String {
        var fields = props.dictValue ?? [:]
        fields["type"] = .string(pattern)
        fields["colorScheme"] = .string(themeMode.isDark ? "dark" : "light")
        if let canvasTheme { fields["canvasTheme"] = canvasTheme }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(AnyCodable.dict(fields)),
              let encoded = String(data: data, encoding: .utf8) else { return "{}" }
        return encoded
    }

    private func sceneSize(of scene: String) -> (width: CGFloat, height: CGFloat)? {
        var w: Float = 0
        var h: Float = 0
        let ok = scene.withCString { orbital_game_renderer_scene_size($0, &w, &h) }
        guard ok == 1, h > 0 else { return nil }
        return (CGFloat(w), CGFloat(h))
    }

    var body: some View {
        let scene = sceneJson
        let title = props.string("title")
        if let size = sceneSize(of: scene) {
            let ratio = size.width / size.height
            VStack(alignment: .leading, spacing: 8) {
                if !title.isEmpty {
                    TypographyRenderer(
                        props: .dict(["variant": .string("h4"), "content": .string(title)]),
                        modifier: nil,
                        onEvent: onEvent
                    )
                }
                Group {
                    switch target {
                    case .surface:
                        OrbitalGameMTKHostView(sceneJson: scene) { name, payload in
                            onEvent(name, eventEnvelope(props, payload: payload))
                        }
                    case .raster:
                        OrbitalGameRasterView(sceneJson: scene)
                    }
                }
                .aspectRatio(ratio, contentMode: .fit)
                .frame(width: naturalSize ? size.width : nil, height: naturalSize ? size.height : nil)
                .frame(maxWidth: naturalSize ? nil : (fixedSize ? size.width : .infinity), alignment: .leading)
            }
        } else {
            let _ = NSLog("[OrbitalGame] %@ scene refused by the native painter", pattern)
            EmptyView()
        }
    }
}
