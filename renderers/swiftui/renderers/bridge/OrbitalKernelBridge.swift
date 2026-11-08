// Swift↔Rust bridge for the in-app orbital_core::runtime::RuntimeKernel
// (B5/B7, ledger §159). @_silgen_name maps each symbol to the
// #[no_mangle] extern "C" fn exported by orbital-ffi/src/kernel_c_api.rs —
// the same static lib the game renderer bridge (OrbitalGameBridge.swift)
// links, via OrbitalCanvas.modulemap.
//
// These Codable models mirror orbital-core's canonical wire types
// (EventResponse/EventRequest/TraitSnapshot/DispatchMode — see
// crates/orbital-core/src/effects/response.rs and
// crates/orbital-core/src/runtime/{kernel,dispatch_mode}.rs) and are
// intentionally named `Kernel*` — DISTINCT from this project's generated
// `EventResponse`/`EmittedEvent` (ApiClient.swift, the OLD per-shell wire
// §156 is converging away from) so the two never collide in one module.

import Foundation
import QuartzCore

// MARK: - Rust c_api bindings

/// Opaque handle to an `OrbitalKernelHandle` allocated on the Rust heap.
typealias OrbitalKernelHandleRef = OpaquePointer

@_silgen_name("orbital_kernel_init")
func orbital_kernel_init(
    _ resolvedSchemaJson: UnsafePointer<CChar>?,
    _ clientId: UnsafePointer<CChar>?
) -> OrbitalKernelHandleRef?

@_silgen_name("orbital_kernel_init_error")
func orbital_kernel_init_error() -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_language_install")
func orbital_language_install(_ bundle: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_destroy")
func orbital_kernel_destroy(_ handle: OrbitalKernelHandleRef?)

@_silgen_name("orbital_kernel_dispatch")
func orbital_kernel_dispatch(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ entityId: UnsafePointer<CChar>?,
    _ event: UnsafePointer<CChar>?,
    _ payloadJson: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_apply_server_response")
func orbital_kernel_apply_server_response(
    _ handle: OrbitalKernelHandleRef?,
    _ responseJson: UnsafePointer<CChar>?,
    _ alreadyDeliveredJson: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_restore")
func orbital_kernel_restore(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ entityId: UnsafePointer<CChar>?,
    _ snapshotJson: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_frames_since")
func orbital_kernel_frames_since(_ handle: OrbitalKernelHandleRef?, _ since: UInt64) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_tick")
func orbital_kernel_tick(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ tickName: UnsafePointer<CChar>?,
    _ entityId: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_frame")
func orbital_kernel_frame(
    _ handle: OrbitalKernelHandleRef?,
    _ nowMs: UInt64
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_frame_pause")
func orbital_kernel_frame_pause(_ handle: OrbitalKernelHandleRef?)

@_silgen_name("orbital_kernel_frame_resume")
func orbital_kernel_frame_resume(_ handle: OrbitalKernelHandleRef?)

@_silgen_name("orbital_kernel_tick_count")
func orbital_kernel_tick_count(_ handle: OrbitalKernelHandleRef?) -> Int32

@_silgen_name("orbital_kernel_get_state")
func orbital_kernel_get_state(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ entityId: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_snapshot")
func orbital_kernel_snapshot(_ handle: OrbitalKernelHandleRef?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_resolve_rows")
func orbital_kernel_resolve_rows(
    _ handle: OrbitalKernelHandleRef?,
    _ refJson: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_set_theme_mode")
func orbital_kernel_set_theme_mode(
    _ handle: OrbitalKernelHandleRef?,
    _ mode: UnsafePointer<CChar>?
)

@_silgen_name("orbital_kernel_set_trait_on_screen")
func orbital_kernel_set_trait_on_screen(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ onScreen: Bool
)

@_silgen_name("orbital_kernel_seed")
func orbital_kernel_seed(
    _ handle: OrbitalKernelHandleRef?,
    _ entityType: UnsafePointer<CChar>?,
    _ rowsJson: UnsafePointer<CChar>?
)

@_silgen_name("orbital_kernel_mount")
func orbital_kernel_mount(
    _ handle: OrbitalKernelHandleRef?,
    _ traitsJson: UnsafePointer<CChar>?
)

@_silgen_name("orbital_kernel_remount")
func orbital_kernel_remount(
    _ handle: OrbitalKernelHandleRef?,
    _ traitsJson: UnsafePointer<CChar>?
)

@_silgen_name("orbital_kernel_last_error")
func orbital_kernel_last_error(_ handle: OrbitalKernelHandleRef?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("orbital_kernel_free_string")
func orbital_kernel_free_string(_ s: UnsafeMutablePointer<CChar>?)

// MARK: - Wire models
// The kernel's wire types are generated from orbital-core (`generated/KernelWire.swift`); this file
// names the ones the host uses and keeps the host-side view of the frames it holds.

typealias KernelEventSource = KernelBusEventSource
typealias KernelServerLeg = KernelEventRequest
typealias KernelSeed = KernelSeedWire
typealias KernelDispatchResult = KernelDispatchWire
typealias KernelFrameResult = KernelFrameWire
typealias KernelAppliedResult = KernelAppliedWire
typealias KernelTraitEventPair = KernelTupleStringString

extension KernelTupleStringString {
    var trait: String { first }
    var event: String { second }
}

extension KernelFrameDelta {
    /// A snapshot starts from nothing: `from` 0 and a leading `clear`.
    var isSnapshot: Bool {
        from == 0 && ops.first?.arrayValue?.first?.stringValue == "clear"
    }
}

/// The version of a kernel's frame record this view has painted, and the frames it holds. The kernel owns the
/// reconciliation; this only applies ops at the version they start from.
struct KernelFrameView {
    enum Outcome { case applied, stale, gap }

    var session: String?
    var version: UInt64 = 0
    var frames: [String: AnyCodable] = [:]

    mutating func apply(_ delta: KernelFrameDelta) -> Outcome {
        if let deltaSession = delta.session {
            if !delta.isSnapshot {
                let current = deltaSession == session && delta.from == version
                if deltaSession == session && delta.to <= version && !current { return .stale }
                if !current { return .gap }
            }
            session = deltaSession
            version = delta.to
        }
        for op in delta.ops {
            guard let parts = op.arrayValue, let name = parts.first?.stringValue else { continue }
            switch name {
            case "clear":
                frames.removeAll()
            case "del":
                if parts.count > 1, let frame = parts[1].stringValue { frames.removeValue(forKey: frame) }
            case "put":
                if parts.count > 2, let frame = parts[1].stringValue, let fields = parts[2].dictValue { frames[frame] = .dict(fields) }
            case "set":
                guard parts.count > 1, let sets = parts[1].dictValue else { continue }
                for (frame, written) in sets {
                    guard let writtenFields = written.dictValue else { continue }
                    var row = frames[frame]?.dictValue ?? [:]
                    row.merge(writtenFields) { _, new in new }
                    frames[frame] = .dict(row)
                }
            default:
                continue
            }
        }
        return .applied
    }
}

/// Mirror of `orbital_core::runtime::theme::ResolvedTheme` — the `@currentTheme`
/// snapshot value (`orbital_kernel_snapshot`'s `theme` field, C1c). `tokens`
/// decodes through the generated `ThemeTokensJSON` (`AlmadarTheme.swift`) so
/// the two never carry two competing field lists for the same wire shape.
struct KernelResolvedTheme: Decodable {
    let key: String
    let base: String
    let mode: String
    let tokens: ThemeTokensJSON
}

/// Why a call into the kernel gave no usable answer: the kernel said so, or its answer is not the wire shape.
enum KernelWireError: Error, CustomStringConvertible {
    case native(String)
    case decode(type: String, DecodingError)

    var description: String {
        switch self {
        case .native(let message): return message
        case .decode(let type, let error): return "the kernel's answer is not a \(type): \(error)"
        }
    }
}

private struct KernelErrorWire: Decodable {
    let error: String
}

private func decodeWire<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch let failure as DecodingError {
        if let answer = try? JSONDecoder().decode(KernelErrorWire.self, from: data) { throw KernelWireError.native(answer.error) }
        throw KernelWireError.decode(type: String(describing: T.self), failure)
    }
}

/// What one `OrbitalKernel.frame` call produced.
enum KernelFrameOutcome {
    /// No tick was due (or none passed its guard): nothing to fold.
    case idle
    case fired(KernelFrameResult)
    case failed(String)
}

/// `orbital_kernel_resolve_rows`'s answer: the rows a row-set reference resolves to now, in its order.
struct KernelRowPage: Decodable {
    let rows: [AnyCodable]
    let total: Int
}

// MARK: - Swift-facing kernel handle

/// Owns one `OrbitalKernelHandleRef` for the lifetime of the app's kernel —
/// `RuntimeKernel` in a `Client` environment, embedded via `orbital-ffi`.
/// Generated view models (B7) load this off the main thread and drive
/// `dispatch`/`applyServerResponse` from it; render-ui content still flows
/// through the existing splice/`CorePatternRegistry` path.
final class OrbitalKernel {
    private let handle: OrbitalKernelHandleRef

    /// `resolvedSchemaJSON` is the ALREADY-RESOLVED schema (`resolved_schema.json`,
    /// embedded into `Resources/` at compile time, B6) — no compiler runs on
    /// device. Returns `nil` when the native side fails to parse/register it.
    init?(resolvedSchemaJSON: String, clientId: String) {
        guard
            let h = resolvedSchemaJSON.withCString({ schemaPtr in
                clientId.withCString { clientPtr in
                    orbital_kernel_init(schemaPtr, clientPtr)
                }
            })
        else {
            return nil
        }
        handle = h
    }

    deinit {
        orbital_kernel_destroy(handle)
    }

    /// Why the last `init` returned nil, from the native side.
    static var initError: String {
        guard let ptr = orbital_kernel_init_error() else { return "" }
        defer { orbital_kernel_free_string(ptr) }
        return String(cString: ptr)
    }

    /// Installs the bundled language (`language.json`) before any kernel mounts; nil on success, else the error.
    static func installLanguage(_ bundleJSON: String) -> String? {
        guard let ptr = bundleJSON.withCString({ orbital_language_install($0) }) else { return nil }
        defer { orbital_kernel_free_string(ptr) }
        return String(cString: ptr)
    }

    /// The native side's own last error message, read right after a `nil`/
    /// decode-failure return from any call below.
    var lastError: String {
        guard let ptr = orbital_kernel_last_error(handle) else { return "" }
        defer { orbital_kernel_free_string(ptr) }
        return String(cString: ptr)
    }

    /// The answer the native call returned; a missing answer is the kernel's own last error.
    private func consume(_ ptr: UnsafeMutablePointer<CChar>?) throws -> Data {
        guard let ptr = ptr else { throw KernelWireError.native(lastError.isEmpty ? "the kernel gave no answer" : lastError) }
        defer { orbital_kernel_free_string(ptr) }
        return Data(String(cString: ptr).utf8)
    }

    func dispatch(trait: String, entityId: String?, event: String, payloadJSON: String?) throws -> KernelDispatchResult {
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            event.withCString { eventPtr in
                withOptionalCString(entityId) { entityPtr in
                    withOptionalCString(payloadJSON) { payloadPtr in
                        orbital_kernel_dispatch(handle, traitPtr, entityPtr, eventPtr, payloadPtr)
                    }
                }
            }
        }
        return try decodeWire(KernelDispatchResult.self, from: consume(raw))
    }

    /// The frame delta a painter at version `since` of this kernel's frames needs: empty when current, else a snapshot.
    func framesSince(_ since: UInt64) throws -> KernelFrameDelta {
        try decodeWire(KernelFrameDelta.self, from: consume(orbital_kernel_frames_since(handle, since)))
    }

    func applyServerResponse(responseJSON: String, alreadyDelivered: [KernelTraitEventPair]) throws -> KernelAppliedResult {
        let alreadyDeliveredJSON = String(decoding: try JSONEncoder().encode(alreadyDelivered), as: UTF8.self)
        let raw: UnsafeMutablePointer<CChar>? = responseJSON.withCString { responsePtr in
            alreadyDeliveredJSON.withCString { alreadyPtr in
                orbital_kernel_apply_server_response(handle, responsePtr, alreadyPtr)
            }
        }
        return try decodeWire(KernelAppliedResult.self, from: consume(raw))
    }

    /// Roll `trait` back; returns the repaint the rollback owes traits bound to its entity.
    func restore(trait: String, entityId: String?, snapshot: KernelTraitSnapshot) throws -> KernelEventResponse {
        let snapshotJSON = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            snapshotJSON.withCString { snapshotPtr in
                withOptionalCString(entityId) { entityPtr in
                    orbital_kernel_restore(handle, traitPtr, entityPtr, snapshotPtr)
                }
            }
        }
        return try decodeWire(KernelEventResponse.self, from: consume(raw))
    }

    func tick(trait: String, tickName: String, entityId: String?) throws -> KernelEventResponse {
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            tickName.withCString { tickPtr in
                withOptionalCString(entityId) { entityPtr in
                    orbital_kernel_tick(handle, traitPtr, tickPtr, entityPtr)
                }
            }
        }
        return try decodeWire(KernelEventResponse.self, from: consume(raw))
    }

    /// Runs one host frame of the native tick clock (`nowMs` = the host's monotonic frame time).
    func frame(nowMs: UInt64) -> KernelFrameOutcome {
        guard let ptr = orbital_kernel_frame(handle, nowMs) else { return .idle }
        defer { orbital_kernel_free_string(ptr) }
        do {
            return .fired(try decodeWire(KernelFrameResult.self, from: Data(String(cString: ptr).utf8)))
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// Stops the native tick clock (app backgrounded); declared ticks and their phase are kept.
    func framePause() { orbital_kernel_frame_pause(handle) }

    /// Restarts it after `framePause`; the paused span is never counted, so no tick bursts.
    func frameResume() { orbital_kernel_frame_resume(handle) }

    /// How many `(trait, tick)` pairs the schema declares; `0` means no frame loop is needed.
    var tickCount: Int { Int(orbital_kernel_tick_count(handle)) }

    func state(of trait: String, entityId: String?) -> String? {
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            withOptionalCString(entityId) { entityPtr in
                orbital_kernel_get_state(handle, traitPtr, entityPtr)
            }
        }
        guard let ptr = raw else { return nil }
        defer { orbital_kernel_free_string(ptr) }
        let s = String(cString: ptr)
        return s.isEmpty ? nil : s
    }

    /// `{"states": {"<trait>": "<state>", ...}, "theme": KernelResolvedTheme}`
    /// for every trait on the handle's bound orbital (C1c/B7).
    func snapshot() throws -> (states: [String: String], theme: KernelResolvedTheme?, canvasTheme: AnyCodable?, motion: AnyCodable?) {
        struct Wire: Decodable { let states: [String: String]; let theme: KernelResolvedTheme?; let canvasTheme: AnyCodable?; let motion: AnyCodable? }
        let wire = try decodeWire(Wire.self, from: consume(orbital_kernel_snapshot(handle)))
        return (wire.states, wire.theme, wire.canvasTheme, wire.motion)
    }

    /// The rows a row-set reference (the `ref` of a `$rowSet` marker) resolves to now for the current viewer, in the
    /// reference's order (`orbital_kernel_resolve_rows`).
    func resolveRows(reference: AnyCodable) throws -> [AnyCodable] {
        let referenceJSON = String(decoding: try JSONEncoder().encode(reference), as: UTF8.self)
        let raw: UnsafeMutablePointer<CChar>? = referenceJSON.withCString { orbital_kernel_resolve_rows(handle, $0) }
        return try decodeWire(KernelRowPage.self, from: consume(raw)).rows
    }

    /// `value` with every row-set marker replaced by the rows [resolveRows] answers; a reference that cannot be
    /// resolved throws its typed `KernelWireError` (never an empty list), so the caller fails that slot.
    func resolvingRowSets(_ value: AnyCodable) throws -> AnyCodable {
        switch value {
        case .dict(let fields):
            if fields["$rowSet"]?.boolValue == true, let reference = fields["ref"] {
                return .array(try resolveRows(reference: reference))
            }
            return .dict(try fields.mapValues { try resolvingRowSets($0) })
        case .array(let items):
            return .array(try items.map { try resolvingRowSets($0) })
        default:
            return value
        }
    }

    /// Overrides the kernel's tracked light/dark toggle for every subsequent
    /// `@currentTheme` resolution (`orbital_kernel_set_theme_mode`, C1c).
    func setThemeMode(_ mode: String) {
        mode.withCString { orbital_kernel_set_theme_mode(handle, $0) }
    }

    /// Reports whether a trait's rendered output is on screen, so its `[visible]` ticks run only then
    /// (`orbital_kernel_set_trait_on_screen`, EXEC-TICK-4).
    func setTraitOnScreen(_ traitName: String, _ onScreen: Bool) {
        traitName.withCString { orbital_kernel_set_trait_on_screen(handle, $0, onScreen) }
    }

    func seed(entityType: String, rowsJSON: String) {
        entityType.withCString { typePtr in
            rowsJSON.withCString { rowsPtr in
                orbital_kernel_seed(handle, typePtr, rowsPtr)
            }
        }
    }

    /// Declares a new mount before its INITs fire (`orbital_kernel_remount`):
    /// a routed delivery reaches none of `traits` before that trait's own
    /// `INIT`. Pass exactly the traits about to be INITed.
    func remount(traits: [String]) {
        guard let data = try? JSONEncoder().encode(traits),
              let json = String(data: data, encoding: .utf8) else { return }
        json.withCString { orbital_kernel_remount(handle, $0) }
    }

    /// Adds `traits` to the current mount (`orbital_kernel_mount`) without dropping the
    /// traits already mounted — a gated page's circuit joining once its viewer is authenticated.
    func mount(traits: [String]) {
        guard let data = try? JSONEncoder().encode(traits),
              let json = String(data: data, encoding: .utf8) else { return }
        json.withCString { orbital_kernel_mount(handle, $0) }
    }
}

/// `String?.withCString` has no stdlib overload — this fills the gap so
/// every optional-string FFI argument above reads the same way as a
/// required one.
private func withOptionalCString<R>(_ s: String?, _ body: (UnsafePointer<CChar>?) -> R) -> R {
    guard let s = s else { return body(nil) }
    return s.withCString(body)
}

// MARK: - Frame loop

/// One display-refresh callback source for the native tick clock. The host owns when it runs
/// (foreground only); the clock itself lives in Rust (`orbital_kernel_frame`), never here.
final class OrbitalFrameLoop: NSObject {
    private var link: CADisplayLink?
    private let onFrame: (UInt64) -> Void

    init(onFrame: @escaping (UInt64) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    deinit { link?.invalidate() }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        onFrame(UInt64(max(0, link.timestamp * 1000)))
    }
}
