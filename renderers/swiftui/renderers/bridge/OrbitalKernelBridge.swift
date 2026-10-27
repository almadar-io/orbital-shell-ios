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

@_silgen_name("orbital_kernel_abandon_server_leg")
func orbital_kernel_abandon_server_leg(
    _ handle: OrbitalKernelHandleRef?,
    _ traitName: UnsafePointer<CChar>?,
    _ event: UnsafePointer<CChar>?,
    _ error: UnsafePointer<CChar>?
)

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

@_silgen_name("orbital_kernel_set_current_user")
func orbital_kernel_set_current_user(
    _ handle: OrbitalKernelHandleRef?,
    _ userJson: UnsafePointer<CChar>?
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

// Verify bridge (orbital-ffi `verify-bridge`): exported by every orbital-ffi
// build (inert stubs unless the feature is on), referenced from DEBUG code only.
typealias OrbitalVerifyDispatchCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?,
    UnsafePointer<CChar>?
) -> Void

@_silgen_name("orbital_verify_bridge_start")
func orbital_verify_bridge_start(_ handle: OrbitalKernelHandleRef?, _ port: UInt16) -> Int32

@_silgen_name("orbital_verify_bridge_stop")
func orbital_verify_bridge_stop(_ handle: OrbitalKernelHandleRef?)

@_silgen_name("orbital_verify_bridge_set_dispatch_callback")
func orbital_verify_bridge_set_dispatch_callback(
    _ handle: OrbitalKernelHandleRef?,
    _ callback: OrbitalVerifyDispatchCallback?,
    _ ctx: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("orbital_verify_bridge_set_route")
func orbital_verify_bridge_set_route(_ handle: OrbitalKernelHandleRef?, _ route: UnsafePointer<CChar>?) -> Int32

@_silgen_name("orbital_verify_bridge_set_ready")
func orbital_verify_bridge_set_ready(_ handle: OrbitalKernelHandleRef?, _ ready: Int32) -> Int32

@_silgen_name("orbital_verify_bridge_folded")
func orbital_verify_bridge_folded(_ handle: OrbitalKernelHandleRef?, _ generation: UInt64) -> Int32

@_silgen_name("orbital_verify_bridge_painted")
func orbital_verify_bridge_painted(_ handle: OrbitalKernelHandleRef?, _ generation: UInt64) -> Int32

// MARK: - Wire models (mirror orbital-core's canonical EventResponse/EventRequest/
// TraitSnapshot/DispatchMode JSON exactly — see kernel_c_api.rs's doc comment for
// the envelope shape `orbital_kernel_dispatch` returns)

struct KernelEventSource: Codable {
    let orbital: String?
    let trait: String?
}

struct KernelEmittedEvent: Codable {
    let event: String
    let payload: AnyCodable?
    let source: KernelEventSource?
}

/// Mirror of `orbital_core::EventResponse` — NOT the same type as this
/// project's generated `EventResponse` (ApiClient.swift), which carries the
/// old per-shell wire shape.
struct KernelEventResponse: Codable {
    let success: Bool
    let transitioned: Bool
    let states: [String: String]
    let emittedEvents: [KernelEmittedEvent]
    let data: [String: [AnyCodable]]?
    let entityByTrait: [String: AnyCodable]?
    let clientEffectsByTrait: [AnyCodable]?
    let effectResults: [AnyCodable]?
    let guardFailed: String?
    let error: String?
}

struct KernelTraitFrom: Codable {
    let trait: String
    let from: String
}

/// Mirror of `orbital_core::EventRequest` — the "server leg" a dispatch
/// produces when its resolved `DispatchMode` isn't `hybridClientOnly`.
struct KernelServerLeg: Codable {
    let event: String
    let eventId: String?
    let payload: AnyCodable?
    let entityId: String?
    let targetTrait: String?
    let user: AnyCodable?
    let clientId: String?
    let tick: String?
    let sourceTrait: String?
    let traits: [KernelTraitFrom]?
    let entityByTrait: [String: AnyCodable]?
    let behavior: String?
    let delivery: AnyCodable?
    let dispatchLog: AnyCodable?
}

/// The `(trait, event)` that began a dispatch; a leg failure is reported against its event.
struct KernelSeed: Codable {
    let trait: String
    let event: String
}

/// A server leg and the orbital that owns the trait it is addressed to (the route it posts to).
struct KernelRoutedLeg: Codable {
    let orbital: String
    let leg: KernelServerLeg
}

/// Mirror of `orbital_core::runtime::TraitSnapshot`.
struct KernelTraitSnapshot: Codable {
    let state: String
    let entity: AnyCodable
}

/// Mirror of `orbital_core::runtime::DispatchMode`.
enum KernelDispatchMode: String, Codable {
    case persistedAwaited
    case hybridClientOnly
    case runtimeOptimistic
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

/// One `(trait, event)` pair already realized locally — decoded from the
/// `alreadyDelivered`/`applied` wire arrays (`[[trait, event], ...]`).
struct KernelTraitEventPair {
    let trait: String
    let event: String
}

private func decodePairs(_ raw: [[String]]) -> [KernelTraitEventPair] {
    raw.compactMap { pair in
        guard pair.count == 2 else { return nil }
        return KernelTraitEventPair(trait: pair[0], event: pair[1])
    }
}

/// `orbital_kernel_dispatch`'s decoded envelope.
struct KernelDispatchResult {
    /// The orbital that owns the dispatched trait; the server leg posts to `/api/orbitals/<orbital>/events`.
    let orbital: String
    let seed: KernelSeed
    let response: KernelEventResponse
    let serverLegs: [KernelRoutedLeg]
    let mode: KernelDispatchMode
    let snapshot: KernelTraitSnapshot?
    let alreadyDelivered: [KernelTraitEventPair]
    /// The traits awaiting this dispatch's server legs (orbital-core `AwaitingTrait`).
    let awaiting: [KernelAwaitingTrait]

    fileprivate struct Wire: Codable {
        let orbital: String
        let seed: KernelSeed
        let response: KernelEventResponse
        let serverLegs: [KernelRoutedLeg]
        let mode: KernelDispatchMode
        let snapshot: KernelTraitSnapshot?
        let alreadyDelivered: [[String]]
        let awaiting: [KernelAwaitingTrait]
    }
}

/// A trait awaiting a server round trip, keyed by the transition its local run took.
struct KernelAwaitingTrait: Codable {
    let trait: String
    let event: String
    let from: String
}

/// One `(trait, tick)` pair a frame ran.
struct KernelFiredTick: Codable {
    let trait: String
    let tick: String
}

/// A cascade a tick's `emit` started: the dispatch envelope plus the emitting trait, folded and
/// (when it carries a server leg) posted exactly like a tapped event.
struct KernelFrameDispatch {
    let trait: String
    let result: KernelDispatchResult

    fileprivate struct Wire: Decodable {
        let trait: String
        let dispatch: KernelDispatchResult.Wire

        private enum CodingKeys: String, CodingKey { case trait }

        init(from decoder: Decoder) throws {
            trait = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .trait)
            dispatch = try KernelDispatchResult.Wire(from: decoder)
        }
    }
}

/// `orbital_kernel_frame`'s decoded envelope: the merged tick response plus one dispatch per tick `emit`.
struct KernelFrameResult {
    let fired: [KernelFiredTick]
    let response: KernelEventResponse
    let dispatches: [KernelFrameDispatch]
    /// Server effects a tick delegated: a tick has no server leg, so they are discarded.
    let droppedServerEffects: Int
    let errors: [String]

    fileprivate struct Wire: Decodable {
        let fired: [KernelFiredTick]
        let response: KernelEventResponse
        let dispatches: [KernelFrameDispatch.Wire]
        let droppedServerEffects: Int
        let errors: [String]
    }
}

/// What one `OrbitalKernel.frame` call produced.
enum KernelFrameOutcome {
    /// No tick was due (or none passed its guard): nothing to fold.
    case idle
    case fired(KernelFrameResult)
    case failed(String)
}

/// `orbital_kernel_resolve_rows`'s answer: the rows a row-set reference resolves to now, in its order. An
/// `{"error": ...}` answer has no `rows` and fails this decode.
struct KernelRowPage: Decodable {
    let rows: [AnyCodable]
    let total: Int
}

/// `orbital_kernel_apply_server_response`'s decoded envelope. A `{"error":
/// ...}` response (no `applied` key) fails this decode — `applyServerResponse`
/// returns `nil` and the caller reads `lastError`, same contract as `dispatch`.
struct KernelAppliedResult {
    let applied: [KernelTraitEventPair]
    let response: KernelEventResponse

    fileprivate struct Wire: Codable {
        let applied: [[String]]
        let response: KernelEventResponse
    }
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

    /// The native side's own last error message, read right after a `nil`/
    /// decode-failure return from any call below.
    var lastError: String {
        guard let ptr = orbital_kernel_last_error(handle) else { return "" }
        defer { orbital_kernel_free_string(ptr) }
        return String(cString: ptr)
    }

    private func consume(_ ptr: UnsafeMutablePointer<CChar>?) -> Data? {
        guard let ptr = ptr else { return nil }
        defer { orbital_kernel_free_string(ptr) }
        return String(cString: ptr).data(using: .utf8)
    }

    func dispatch(trait: String, entityId: String?, event: String, payloadJSON: String?) -> KernelDispatchResult? {
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            event.withCString { eventPtr in
                withOptionalCString(entityId) { entityPtr in
                    withOptionalCString(payloadJSON) { payloadPtr in
                        orbital_kernel_dispatch(handle, traitPtr, entityPtr, eventPtr, payloadPtr)
                    }
                }
            }
        }
        guard let data = consume(raw) else { return nil }
        guard let wire = try? JSONDecoder().decode(KernelDispatchResult.Wire.self, from: data) else { return nil }
        return KernelDispatchResult(
            orbital: wire.orbital,
            seed: wire.seed,
            response: wire.response,
            serverLegs: wire.serverLegs,
            mode: wire.mode,
            snapshot: wire.snapshot,
            alreadyDelivered: decodePairs(wire.alreadyDelivered),
            awaiting: wire.awaiting
        )
    }

    func applyServerResponse(responseJSON: String, alreadyDelivered: [KernelTraitEventPair]) -> KernelAppliedResult? {
        let alreadyDeliveredJSON = (try? JSONEncoder().encode(alreadyDelivered.map { [$0.trait, $0.event] }))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let raw: UnsafeMutablePointer<CChar>? = responseJSON.withCString { responsePtr in
            alreadyDeliveredJSON.withCString { alreadyPtr in
                orbital_kernel_apply_server_response(handle, responsePtr, alreadyPtr)
            }
        }
        guard let data = consume(raw) else { return nil }
        guard let wire = try? JSONDecoder().decode(KernelAppliedResult.Wire.self, from: data) else { return nil }
        return KernelAppliedResult(applied: decodePairs(wire.applied), response: wire.response)
    }

    /// A server leg failed at transport level with no snapshot to restore: lowers the
    /// verify bridge's `pending` and journals `server-leg-failed`. Inert in release builds.
    func abandonServerLeg(trait: String, event: String, error: String) {
        trait.withCString { traitPtr in
            event.withCString { eventPtr in
                error.withCString { errorPtr in
                    orbital_kernel_abandon_server_leg(handle, traitPtr, eventPtr, errorPtr)
                }
            }
        }
    }

    /// Roll `trait` back; returns the repaint the rollback owes traits bound to its entity.
    func restore(trait: String, entityId: String?, snapshot: KernelTraitSnapshot) -> KernelEventResponse? {
        guard let data = try? JSONEncoder().encode(snapshot),
              let snapshotJSON = String(data: data, encoding: .utf8)
        else { return nil }
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            snapshotJSON.withCString { snapshotPtr in
                withOptionalCString(entityId) { entityPtr in
                    orbital_kernel_restore(handle, traitPtr, entityPtr, snapshotPtr)
                }
            }
        }
        guard let repaint = consume(raw) else { return nil }
        return try? JSONDecoder().decode(KernelEventResponse.self, from: repaint)
    }

    func tick(trait: String, tickName: String, entityId: String?) -> KernelEventResponse? {
        let raw: UnsafeMutablePointer<CChar>? = trait.withCString { traitPtr in
            tickName.withCString { tickPtr in
                withOptionalCString(entityId) { entityPtr in
                    orbital_kernel_tick(handle, traitPtr, tickPtr, entityPtr)
                }
            }
        }
        guard let data = consume(raw) else { return nil }
        return try? JSONDecoder().decode(KernelEventResponse.self, from: data)
    }

    /// Runs one host frame of the native tick clock (`nowMs` = the host's monotonic frame time).
    func frame(nowMs: UInt64) -> KernelFrameOutcome {
        guard let data = consume(orbital_kernel_frame(handle, nowMs)) else { return .idle }
        if let wire = try? JSONDecoder().decode(KernelFrameResult.Wire.self, from: data) {
            return .fired(KernelFrameResult(
                fired: wire.fired,
                response: wire.response,
                dispatches: wire.dispatches.map { d in
                    KernelFrameDispatch(
                        trait: d.trait,
                        result: KernelDispatchResult(
                            orbital: d.dispatch.orbital,
                            seed: d.dispatch.seed,
                            response: d.dispatch.response,
                            serverLegs: d.dispatch.serverLegs,
                            mode: d.dispatch.mode,
                            snapshot: d.dispatch.snapshot,
                            alreadyDelivered: decodePairs(d.dispatch.alreadyDelivered),
                            awaiting: d.dispatch.awaiting
                        )
                    )
                },
                droppedServerEffects: wire.droppedServerEffects,
                errors: wire.errors
            ))
        }
        return .failed(lastError.isEmpty ? "frame failed" : lastError)
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
    /// for every trait on the handle's bound orbital (C1c/B7) — `theme` is
    /// `nil` only if the native side's `theme` field somehow fails to decode
    /// (the generated view model falls back to `AlmadarTheme.fallback`).
    func snapshot() -> (states: [String: String], theme: KernelResolvedTheme?, canvasTheme: AnyCodable?, motion: AnyCodable?) {
        guard let data = consume(orbital_kernel_snapshot(handle)) else { return ([:], nil, nil, nil) }
        struct Wire: Decodable { let states: [String: String]; let theme: KernelResolvedTheme?; let canvasTheme: AnyCodable?; let motion: AnyCodable? }
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return ([:], nil, nil, nil) }
        return (wire.states, wire.theme, wire.canvasTheme, wire.motion)
    }

    /// The rows a row-set reference (the `ref` of a `$rowSet` marker) resolves to now for the current viewer, in the
    /// reference's order (`orbital_kernel_resolve_rows`); `nil` when the kernel cannot resolve it (read `lastError`).
    func resolveRows(reference: AnyCodable) -> [AnyCodable]? {
        guard let data = try? JSONEncoder().encode(reference),
              let referenceJSON = String(data: data, encoding: .utf8)
        else { return nil }
        let raw: UnsafeMutablePointer<CChar>? = referenceJSON.withCString { orbital_kernel_resolve_rows(handle, $0) }
        guard let answer = consume(raw), let page = try? JSONDecoder().decode(KernelRowPage.self, from: answer) else { return nil }
        return page.rows
    }

    /// `value` with every row-set marker replaced by the rows [resolveRows] answers; a reference that cannot be
    /// resolved becomes an empty list, never a stale copy.
    func resolvingRowSets(_ value: AnyCodable) -> AnyCodable {
        switch value {
        case .dict(let fields):
            if fields["$rowSet"]?.boolValue == true, let reference = fields["ref"] {
                return .array(resolveRows(reference: reference) ?? [])
            }
            return .dict(fields.mapValues { resolvingRowSets($0) })
        case .array(let items):
            return .array(items.map { resolvingRowSets($0) })
        default:
            return value
        }
    }

    /// Overrides the kernel's tracked light/dark toggle for every subsequent
    /// `@currentTheme` resolution (`orbital_kernel_set_theme_mode`, C1c).
    func setThemeMode(_ mode: String) {
        mode.withCString { orbital_kernel_set_theme_mode(handle, $0) }
    }

    func setCurrentUser(json: String) {
        json.withCString { orbital_kernel_set_current_user(handle, $0) }
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

#if DEBUG
    /// Starts the verify bridge on 127.0.0.1:`port`; returns the bound port, 0 on failure
    /// (read `lastError`). Debug builds only — never compiled into a release shell.
    func startVerifyBridge(port: UInt16) -> Int32 {
        orbital_verify_bridge_start(handle, port)
    }

    func stopVerifyBridge() {
        orbital_verify_bridge_stop(handle)
    }

    /// Registers the host function the bridge's `/send` invokes (on the bridge thread).
    @discardableResult
    func setVerifyDispatchCallback(_ callback: OrbitalVerifyDispatchCallback?, ctx: UnsafeMutableRawPointer?) -> Bool {
        orbital_verify_bridge_set_dispatch_callback(handle, callback, ctx) == 1
    }

    /// Publishes the current route for the bridge's `/snapshot` and `/route`.
    @discardableResult
    func setVerifyRoute(_ route: String) -> Bool {
        route.withCString { orbital_verify_bridge_set_route(handle, $0) } == 1
    }

    /// Marks the host mounted (`true`: every page-mount `INIT` has been dispatched) or mounting
    /// (`false`); the bridge's `/idle` never reports idle while mounting.
    @discardableResult
    func setVerifyReady(_ ready: Bool) -> Bool {
        orbital_verify_bridge_set_ready(handle, ready ? 1 : 0) == 1
    }

    /// The view state now holds render generation `generation`; `/idle` waits for its paint.
    @discardableResult
    func setVerifyFolded(_ generation: UInt64) -> Bool {
        orbital_verify_bridge_folded(handle, generation) == 1
    }

    /// The page committed render generation `generation` to the screen.
    @discardableResult
    func setVerifyPainted(_ generation: UInt64) -> Bool {
        orbital_verify_bridge_painted(handle, generation) == 1
    }
#endif
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
