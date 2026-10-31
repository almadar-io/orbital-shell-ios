import Foundation
import SwiftUI
import Combine
import os

class OrbitalViewModel: ObservableObject {
    @Published var states: [String: String] = [:]
    /// Per-trait `main`-slot render output, keyed by SOURCE trait — resolves
    /// `@trait.X` (mirrors `ClientCore.trait_content`). The page body reads
    /// `traitContent[pageTrait]`; peer traits that render only to an overlay
    /// slot are still indexed here so a splice can reach them.
    @Published var traitContent: [String: AnyCodable] = [:]
    /// Bumped on every fold.
    @Published private(set) var paintGeneration: UInt64 = 0

    /// Predicted skeletons (`AwaitRenders`) of round trips that have outlasted the theme's busy
    /// delay: by the trait that will render `main`, and by any other slot name.
    @Published private(set) var awaitingMain: [String: AwaitRender] = [:]
    @Published private(set) var awaitingSlots: [String: AwaitRender] = [:]
    /// Server legs still in flight per dispatch, and the predictions it raised.
    private var awaitingLegs: [UUID: Int] = [:]
    private var awaitingRaised: [UUID: [AwaitRender]] = [:]
    /// `traitContent`, with a `skeleton` node for an awaiting trait that has not rendered yet.
    var contentWithAwaiting: [String: AnyCodable] {
        var content = traitContent.mapValues(paintedRowSets)
        for (name, render) in awaitingMain where content[name] == nil {
            content[name] = .dict(["type": .string("skeleton"), "spec": render.skeleton])
        }
        return content
    }
    /// `value` with every row-set marker replaced by the rows the kernel's one resolver answers now, re-checked
    /// for the signed-in viewer (EXEC-RENDER-3). A rows-changed repaint re-applies the render and lands here again.
    private func paintedRowSets(_ value: AnyCodable) -> AnyCodable {
        kernel?.resolvingRowSets(value) ?? value
    }
    /// `uiSlots`, with a `skeleton` node in an awaiting slot that is still empty.
    var slotsWithAwaiting: [String: AnyCodable] {
        var slots = uiSlots.mapValues(paintedRowSets)
        for (slot, render) in awaitingSlots where slots[slot] == nil {
            slots[slot] = .dict(["type": .string("skeleton"), "spec": render.skeleton])
        }
        return slots
    }
    /// `mainOrder`, then awaiting `main` traits that have not rendered yet.
    var mainOrderWithAwaiting: [String] {
        mainOrder + awaitingMain.keys.filter { !mainOrder.contains($0) && traitContent[$0] == nil && !Self.embeddedTraits.contains($0) }.sorted()
    }
    /// Traits whose `main`-slot render-ui is live, in first-write order (a re-render keeps
    /// its position, a clear removes only that trait). A page stacks its bound traits found
    /// here, mirroring `useUISlots.aggregateSlot`; `traitContent` also indexes overlay-only peers.
    @Published var mainOrder: [String] = []
    /// The trait that most recently wrote `main` (cleared when that trait clears).
    @Published var lastMainWriter: String?
    /// Non-main slots only (`modal`/`drawer`/`toast`/…) — a `main`-role
    /// render-ui is NEVER stored here, see `traitContent`.
    @Published var uiSlots: [String: AnyCodable] = [:]
    @Published var entityData: [String: [AnyCodable]] = [:]
    @Published var fields: [String: AnyCodable] = [:]
    /// The kernel's frames as last painted, with the version they are at (EXEC-DIST-7); `fields` mirrors them by frame key.
    private var frameView = KernelFrameView()
    @Published var navigationPath: NavigationPath = NavigationPath() {
        didSet { syncRoute() }
    }
    /// The page at the root of the NavigationStack; every other page is pushed onto `navigationPath`.
    @Published var rootRoute: String = OrbitalViewModel.startRoute
    @Published var alertMessage: String?
    /// The signed-in session (`OrbitalAuth`), or nil while signed out.
    @Published var session: OrbitalAuthSession?
    // set by the kernel snapshot (wave B7)
    @Published var theme: AlmadarTheme = .fallback
    /// The kernel-resolved mode of `theme` (`resolvedMode` of the web `useTheme()` context).
    @Published private(set) var themeIsDark: Bool = false
    /// The kernel's `canvasTheme` (orbital-core `canvas_theme`): what the Rust-drawn canvases paint with.
    @Published private(set) var canvasTheme: AnyCodable?
    /// The kernel's resolved `motion` (orbital-core `resolve_motion`): what entries and surfaces animate.
    @Published private(set) var motion: AnyCodable?
    /// False until the in-app kernel has loaded `resolved_schema.json` and
    /// mounted (B7) — the app root shows a loading state until this flips.
    @Published var isReady: Bool = false

    /// Owns the in-process `RuntimeKernel` (`orbital-ffi`, B5/B7) — every
    /// dispatch runs through this handle, never a direct HTTP call.
    private var kernel: OrbitalKernel?
    private let api: OrbitalAPI
    let auth: OrbitalAuth
    private lazy var sessionBinding = OrbitalSessionBinding(api: api)
    /// The server the host sign-in lists dev personas from and exchanges their custom token with.
    var apiBase: String { api.baseUrl }
    /// Per-launch id, the live-broadcast origin-exclusion key — mirrors the
    /// web bridge's `crypto.randomUUID()` (`useOrbitalBridge.ts`).
    private let clientId = UUID().uuidString
    private var didStart = false
    private var didInitAllTraits = false
    private var liveSubscription: LivePushSubscription?
    /// Drives the kernel's tick clock once per display refresh; nil when the schema declares no ticks.
    private var frameLoop: OrbitalFrameLoop?
    private var isForeground = false
    private var loggedDroppedServerEffects = false

    private static let traitsWithInit: [String] = __TRAITS_WITH_INIT__
    private static let gatedPageTraits: [String: [String]] = __GATED_PAGE_TRAITS__
    /// Viewer each gated trait was last INITed for: a new viewer re-INITs it (the web keys the page by viewer).
    private var gatedInitViewer: [String: String] = [:]
    /// A gated page that appeared before the kernel mounted; mounted right after `initAllTraits`.
    private var pendingGatedMount: (path: String, viewer: String)?
    private static let knownRoutes: [String] = __KNOWN_ROUTES__
    /// Traits embedded via `@trait.X` by a sibling: indexed in `traitContent` for the splice, never a `main` owner.
    static let embeddedTraits: Set<String> = __EMBEDDED_TRAITS__
    private static let startRoute = "__START_ROUTE__"
    private static let notFoundRoute: String? = __NOT_FOUND_ROUTE__
    /// The host's own sign-in route (`HOST_SIGN_IN_ROUTE`): no page declares it, `GeneratedApp` renders `OrbitalSignInView`.
    static let hostSignInRoute = "__HOST_SIGN_IN_ROUTE__"
    /// The event name a renderer emits for a `navigatesTo` action or a nav item; the page routes it
    /// to `navigate(to:)` before kernel dispatch, as the web router hears the unscoped `UI:NAVIGATE`.
    static let navigateEvent = "NAVIGATE"
    private var routeStack: [String] = []
    private static let eventLog = Logger(subsystem: "com.orbital", category: "dispatch")

    /// One owner for every `clientEffectsByTrait` entry — render-ui indexing/slot
    /// writes and `emit` re-dispatch live in `EffectHandlers.apply`, never
    /// duplicated here.
    private lazy var effectHandlers: EffectHandlers = EffectHandlers(viewModel: self)

    init(api: OrbitalAPI = OrbitalAPI(baseUrl: OrbitalViewModel.resolvedBaseUrl()), auth: OrbitalAuth = OrbitalViewModel.makeAuth()) {
        self.api = api
        self.auth = auth
#if DEBUG
        if let token = OrbitalViewModel.launchAuthToken() {
            api.setAuthToken(token)
        }
#endif
    }

    /// The build-declared provider (`OrbitalFirebaseApiKey`, `OrbitalFirebaseProjectId`, `OrbitalAuthEmulatorHost`
    /// in Info.plist); a DEBUG launch may point sign-in at another Auth emulator with `ORBITAL_AUTH_EMULATOR_HOST`.
    static func makeAuth() -> OrbitalAuth {
        var info: [String: AnyCodable] = [:]
        for key in ["OrbitalFirebaseApiKey", "OrbitalFirebaseProjectId", "OrbitalAuthEmulatorHost"] {
            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String { info[key] = .string(value) }
        }
        var emulatorOverride: String?
#if DEBUG
        emulatorOverride = ProcessInfo.processInfo.environment["ORBITAL_AUTH_EMULATOR_HOST"]
#endif
        return OrbitalAuth(
            config: OrbitalAuthConfig.declared(info: info, emulatorOverride: emulatorOverride),
            store: KeychainSessionStore(service: Bundle.main.bundleIdentifier ?? "orbital")
        )
    }

    func signOut() {
        auth.signOut()
    }

    /// Answers one `host-ask` client effect (`ClientEffect::HostAsk`): `auth/sign-out` ends the session and
    /// `auth/sign-in` signs in by email or custom token and returns its answer to `completion`; an ask this host has
    /// no action for, or one with arguments it does not take, is refused by name (and fails the ask's failure route).
    func answerHostAsk(op: String, args: [AnyCodable], completion: AnyCodable? = nil) {
        switch op {
        case "auth/sign-out":
            guard args.isEmpty else {
                OrbitalViewModel.eventLog.error("host-ask auth/sign-out refused: it takes no arguments")
                return
            }
            signOut()
        case "auth/sign-in":
            Task { @MainActor [weak self] in await self?.answerSignIn(args: args, completion: completion) }
        case "auth/consent":
            OrbitalViewModel.eventLog.error("host-ask auth/consent refused: this host has no web authentication session")
            returnHostAsk(completion, error: "auth/consent: this host has no web authentication session", kind: "unavailable")
        default:
            OrbitalViewModel.eventLog.error("host-ask \(op, privacy: .public) refused: this host has no action for it")
            returnHostAsk(completion, error: "\(op): this host has no action for it", kind: "unavailable")
        }
    }

    private func answerSignIn(args: [AnyCodable], completion: AnyCodable?) async {
        guard args.count == 1, let request = args[0].dictValue, let method = request["method"]?.stringValue else {
            returnHostAsk(completion, error: "auth/sign-in takes one request object with a method", kind: "invalid")
            return
        }
        do {
            switch method {
            case "email":
                guard request.count == 3, let email = request["email"]?.stringValue, !email.isEmpty, let password = request["password"]?.stringValue, !password.isEmpty else {
                    returnHostAsk(completion, error: "auth/sign-in: email takes an email and a password", kind: "invalid")
                    return
                }
                try await auth.signIn(email: email, password: password)
            case "customToken":
                guard request.count == 2, let token = request["token"]?.stringValue, !token.isEmpty else {
                    returnHostAsk(completion, error: "auth/sign-in: customToken takes a token", kind: "invalid")
                    return
                }
                try await auth.signIn(customToken: token)
            case "google", "emailLink":
                returnHostAsk(completion, error: "auth/sign-in: this host has no \(method) sign-in", kind: "unavailable")
                return
            default:
                returnHostAsk(completion, error: "auth/sign-in: method must be google, email, emailLink or customToken", kind: "invalid")
                return
            }
            guard let uid = auth.session?.uid else {
                returnHostAsk(completion, error: "auth/sign-in: the provider returned no session", kind: "unavailable")
                return
            }
            returnHostAsk(completion, ok: ["uid": .string(uid)])
        } catch OrbitalAuthError.provider(let message) {
            returnHostAsk(completion, error: message, kind: "denied")
        } catch {
            returnHostAsk(completion, error: error.localizedDescription, kind: "unavailable")
        }
    }

    /// Returns a host ask's answer: dispatches the event of the outcome it reached to the asking trait, with the call's
    /// key. An ask that declared no route for the outcome fires nothing.
    private func returnHostAsk(_ completion: AnyCodable?, ok: [String: AnyCodable]? = nil, error: String = "", kind: String = "") {
        guard let completion = completion?.dictValue, let trait = completion["trait"]?.stringValue else { return }
        guard let event = (ok != nil ? completion["success"] : completion["failure"])?.stringValue else { return }
        var payload: [String: AnyCodable] = ok ?? ["error": .string(error), "kind": .string(kind)]
        if let key = completion["key"]?.stringValue { payload["key"] = .string(key) }
        sendEvent(trait: trait, event: event, payload: .dict(payload), entityId: completion["entityId"]?.stringValue)
    }

    private func apply(resolvedTheme: KernelResolvedTheme?) {
        guard let resolved = resolvedTheme else { return }
        themeIsDark = resolved.mode == "dark"
        theme = AlmadarTheme.from(tokens: resolved.tokens, mode: themeIsDark ? .dark : .light, fallbackChain: nil)
    }

    /// The host's `toggleMode`: asks the kernel for the opposite mode (`orbital_kernel_set_theme_mode`)
    /// and re-resolves the theme from its snapshot.
    func toggleThemeMode() {
        guard let kernel = kernel else { return }
        kernel.setThemeMode(themeIsDark ? "light" : "dark")
        let snap = kernel.snapshot()
        apply(resolvedTheme: snap.theme)
        canvasTheme = snap.canvasTheme
        motion = snap.motion
    }

    /// What the host's auth has resolved the viewer to be. A DEBUG launch carrying the persona
    /// token is authenticated by it (the stored session is deliberately kept out in that case).
    var isAuthenticated: Bool {
        if session != nil { return true }
#if DEBUG
        return OrbitalViewModel.launchAuthToken() != nil
#else
        return false
#endif
    }

    /// `PageAccessHost`'s `onDenied`: a gated page the viewer is not admitted to is replaced by the
    /// app's declared `signIn` route, once it is the page on top. Without a declared route it stays empty.
    func denyPageAccess(path: String, signIn: String) {
        guard !signIn.isEmpty, (routeStack.last ?? rootRoute) == path else { return }
        if routeStack.isEmpty {
            rootRoute = signIn
            navigationPath = NavigationPath()
        } else {
            routeStack.removeLast()
            navigationPath.removeLast()
            pushRoute(signIn)
        }
        syncRoute()
    }

#if DEBUG
    /// The persona's ID token: a DEBUG build launched with `ORBITAL_AUTH_TOKEN` sends it as
    /// `Authorization: Bearer` on every request. Release builds never read it.
    static func launchAuthToken() -> String? {
        guard let token = ProcessInfo.processInfo.environment["ORBITAL_AUTH_TOKEN"], !token.isEmpty else { return nil }
        return token
    }
#endif

    /// The compiled-in server URL; a DEBUG build launched with
    /// `ORBITAL_API_BASE_URL` talks to that server instead.
    static func resolvedBaseUrl() -> String {
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["ORBITAL_API_BASE_URL"], !override.isEmpty {
            return override
        }
#endif
        return BASE_URL
    }

    /// Loads `resolved_schema.json` OFF THE MAIN THREAD (B6's embedded
    /// bundle resource — no compiler runs on device), mounts the kernel,
    /// seeds `states`/`theme` from its snapshot, opens the live-push
    /// subscriber, then `INIT`s every trait that declares one. Idempotent —
    /// a re-appeared root view calling this again is a no-op.
    func start() {
        guard !didStart else { return }
        didStart = true
        let clientId = self.clientId
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let json = OrbitalViewModel.loadResolvedSchemaJSON()
            let kernel = json.flatMap { OrbitalKernel(resolvedSchemaJSON: $0, clientId: clientId) }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.kernel = kernel
                guard let kernel = kernel else {
                    OrbitalViewModel.eventLog.error("failed to load/mount the kernel from resolved_schema.json")
                    self.alertMessage = "Failed to load the app's resolved schema"
                    self.isReady = true
                    return
                }
                let snap = kernel.snapshot()
                self.states.merge(snap.states) { _, new in new }
                self.apply(resolvedTheme: snap.theme)
                self.canvasTheme = snap.canvasTheme
                self.motion = snap.motion
                self.restoreSession()
                self.openLivePush()
                self.initAllTraits()
                self.startFrameLoop(kernel: kernel)
                self.isReady = true
#if DEBUG
                self.openInitialRouteIfRequested()
#endif
            }
        }
    }

    /// The stored session (Keychain) is adopted before the first INIT so the first requests are signed.
    /// A DEBUG launch carrying `ORBITAL_AUTH_TOKEN` is the persona and keeps it instead.
    private func restoreSession() {
        var hasLaunchToken = false
#if DEBUG
        hasLaunchToken = OrbitalViewModel.launchAuthToken() != nil
#endif
        if !hasLaunchToken {
            auth.loadStoredSession()
            applySession(auth.session, reinit: false)
        }
        auth.onChange = { [weak self] next in
            DispatchQueue.main.async { self?.applySession(next, reinit: true) }
        }
    }

    private func openLivePush() {
        liveSubscription?.cancel()
        liveSubscription = api.openLivePush(clientId: clientId) { [weak self] item in
            DispatchQueue.main.async {
                self?.handleLivePush(item)
            }
        }
    }

    /// Binds the session's token; the server verifies it and binds the identity. A different identity
    /// re-enters the app under it, as the web does: the live-push channel reconnects signed and every
    /// trait INITs again. A token refresh of the same identity changes neither.
    private func applySession(_ next: OrbitalAuthSession?, reinit: Bool) {
        session = next
        let identityChanged = sessionBinding.apply(next)
        guard identityChanged, reinit, isReady else { return }
        openLivePush()
        didInitAllTraits = false
        initAllTraits()
    }

    /// Starts the tick clock's display-link loop when the schema declares any tick (`tickCount`
    /// is read once; a tickless app never creates a loop). The loop only runs in the foreground.
    private func startFrameLoop(kernel: OrbitalKernel) {
        guard kernel.tickCount > 0 else { return }
        frameLoop = OrbitalFrameLoop { [weak self] nowMs in self?.runFrame(nowMs: nowMs) }
        applyForeground()
    }

    /// `scenePhase == .active`: the tick clock runs only while the app is foregrounded.
    func setForeground(_ active: Bool) {
        isForeground = active
        applyForeground()
        if active { Task { try? await auth.refreshIfNeeded() } }
    }

    /// The view lifecycle's report that a trait's rendered output entered or left the screen (`[visible]` ticks, EXEC-TICK-4).
    func setTraitOnScreen(_ traitName: String, _ onScreen: Bool) {
        kernel?.setTraitOnScreen(traitName, onScreen)
    }

    private func applyForeground() {
        guard let kernel = kernel, let frameLoop = frameLoop else { return }
        if isForeground {
            kernel.frameResume()
            frameLoop.start()
        } else {
            frameLoop.stop()
            kernel.framePause()
        }
    }

    /// One display refresh: the kernel runs every due tick and hands back ONE envelope, folded
    /// through the same paths a dispatch uses.
    private func runFrame(nowMs: UInt64) {
        guard isReady, let kernel = kernel else { return }
        switch kernel.frame(nowMs: nowMs) {
        case .idle:
            return
        case .failed(let message):
            OrbitalViewModel.eventLog.error("frame failed: \(message, privacy: .public)")
        case .fired(let frame):
            foldFrame(frame)
        }
    }

    /// The tick response folds like a dispatch response; each tick `emit` cascade folds (and posts
    /// its server leg) exactly like a tapped event on the emitting trait.
    private func foldFrame(_ frame: KernelFrameResult) {
        foldResponse(frame.response)
        for dispatch in frame.dispatches {
            fold(result: dispatch.result, requestTrait: dispatch.trait, entityId: nil)
        }
        for error in frame.errors {
            OrbitalViewModel.eventLog.error("tick failed: \(error, privacy: .public)")
        }
        if frame.droppedServerEffects > 0 && !loggedDroppedServerEffects {
            loggedDroppedServerEffects = true
            OrbitalViewModel.eventLog.error("a tick delegated \(frame.droppedServerEffects, privacy: .public) server effect(s); ticks have no server leg, so they were discarded")
        }
    }

    private static func loadResolvedSchemaJSON() -> String? {
        guard let url = Bundle.main.url(forResource: "resolved_schema", withExtension: "json") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Seeds `states[trait]` from the kernel's own resolved state (never a
    /// local guess — `register_schema` already resolved every trait's
    /// initial state). A no-op once a trait is already present or before
    /// the kernel is ready.
    func initTrait(trait: String) {
        guard states[trait] == nil, let kernel = kernel else { return }
        states[trait] = kernel.state(of: trait, entityId: nil) ?? "idle"
    }

    /// The ONE navigation entry: the kernel `navigate` effect and a renderer's NAVIGATE event both
    /// land here. A path no page declares renders nothing (`default: EmptyView()`) and is logged.
    func navigate(to path: String) {
        if !OrbitalViewModel.knownRoutes.contains(path) && path != OrbitalViewModel.hostSignInRoute {
            OrbitalViewModel.eventLog.error("navigate to undeclared route \(path, privacy: .public)")
            if let notFound = OrbitalViewModel.notFoundRoute {
                pushRoute(notFound)
                return
            }
        }
        pushRoute(path)
    }

    private func pushRoute(_ path: String) {
        routeStack.append(path)
        navigationPath.append(GeneratedApp.Destination.route(path))
    }

    /// Routes a renderer-dispatched NAVIGATE envelope (`actionPayload.url`) to `navigate(to:)`.
    func navigate(envelope payload: AnyCodable?) {
        guard let url = payload?.dictValue?["actionPayload"]?.dictValue?["url"]?.stringValue, !url.isEmpty else {
            OrbitalViewModel.eventLog.error("NAVIGATE dropped: no actionPayload.url")
            return
        }
        navigate(to: url)
    }

    private func syncRoute() {
        if navigationPath.count < routeStack.count {
            routeStack.removeLast(routeStack.count - navigationPath.count)
        }
    }

    /// Mirrors `ClientKernel`/`ClientCore::init_all_traits_blocking`: `INIT`
    /// every trait that declares one, once, in declaration order, so every
    /// `@trait.X` peer's content is indexed before any page reads it.
    /// Idempotent — a page's own `onAppear` only seeds its state
    /// (`initTrait`), never a second `INIT`.
    func initAllTraits() {
        guard !didInitAllTraits else { return }
        didInitAllTraits = true
        kernel?.remount(traits: OrbitalViewModel.traitsWithInit)
        for trait in OrbitalViewModel.traitsWithInit {
            initTrait(trait: trait)
            sendEvent(trait: trait, event: "INIT")
        }
        if let gated = pendingGatedMount {
            pendingGatedMount = nil
            mountGatedPage(path: gated.path, viewer: gated.viewer)
        }
    }

    /// Mount a gated page's circuit for an authenticated `viewer` — the twin of the web
    /// `PageAccessHost` mounting the page only once its viewer is authenticated. Its gated-only
    /// traits join the mount and INIT once per viewer.
    func mountGatedPage(path: String, viewer: String) {
        guard didInitAllTraits else {
            pendingGatedMount = (path, viewer)
            return
        }
        let pending = (OrbitalViewModel.gatedPageTraits[path] ?? []).filter { gatedInitViewer[$0] != viewer }
        if pending.isEmpty { return }
        kernel?.mount(traits: pending)
        for trait in pending {
            gatedInitViewer[trait] = viewer
            initTrait(trait: trait)
            sendEvent(trait: trait, event: "INIT")
        }
    }

    /// The ONLY dispatch entry point — every control's event and `initTrait`
    /// route through here (mirrors `ClientKernel::dispatch`). A call before
    /// the kernel is ready is dropped and logged; nothing can fire before
    /// `start()` mounts it.
    func sendEvent(trait: String, event: String, payload: AnyCodable? = nil, entityId: String? = nil) {
        guard let kernel = kernel else {
            OrbitalViewModel.eventLog.error("dispatch \(trait, privacy: .public) \(event, privacy: .public) dropped: kernel not ready")
            return
        }
        let payloadJSON = payload.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        guard let result = kernel.dispatch(trait: trait, entityId: entityId, event: event, payloadJSON: payloadJSON) else {
            alertMessage = kernel.lastError.isEmpty ? "Event failed" : kernel.lastError
            return
        }
        OrbitalViewModel.eventLog.info("dispatch \(trait, privacy: .public) \(event, privacy: .public) mode=\(result.mode.rawValue, privacy: .public) states=\(result.response.states.keys.joined(separator: ","), privacy: .public) serverLegs=\(result.serverLegs.count, privacy: .public)")
        fold(result: result, requestTrait: trait, entityId: entityId)
    }

    /// The one fold of a kernel `EventResponse` into view-model state: a
    /// dispatch and an applied server response both land through here, so a
    /// cascade run by either repaints from the same code.
    private func foldResponse(_ response: KernelEventResponse) {
        states.merge(response.states) { _, new in new }
        if let data = response.data {
            entityData.merge(data) { _, new in new }
        }
        if let delta = response.frames {
            if frameView.apply(delta) == .gap, let snapshot = kernel?.framesSince(frameView.version) {
                _ = frameView.apply(snapshot)
            }
            fields = frameView.frames
        }
        for entry in response.clientEffectsByTrait ?? [] {
            guard let dict = entry.dictValue, let trait = dict["traitName"]?.stringValue, let effect = dict["effect"] else { continue }
            effectHandlers.apply(effect: effect, requestTrait: trait)
        }
        paintGeneration += 1
    }

    /// The ONE fold every dispatch (local, live-push) runs through. The
    /// local `response` applies immediately regardless of mode (render-ui
    /// IS the UI); the resolved `DispatchMode` then decides the server leg's
    /// fate (`orbital_core::runtime::dispatch_mode`, the one rule).
    /// `emittedEvents` is informational only — the kernel already fanned
    /// every emit out to its listeners inside this same dispatch call, so it
    /// is never re-dispatched here.
    private func fold(result: KernelDispatchResult, requestTrait: String, entityId: String?) {
        foldResponse(result.response)
        let awaitToken = beginAwaiting(result.awaiting.flatMap(AwaitRenders.matching), legs: result.serverLegs.count)

        switch result.mode {
        case .hybridClientOnly:
            // A `local` seed only carries a leg when its cascade reached a
            // server-bound trait (a persistor); the kernel raised the pending
            // count for it, so it is posted and applied/abandoned like any leg.
            for routed in result.serverLegs {
                let leg = routed.leg
                OrbitalViewModel.eventLog.info("posting cascade server leg for local seed \(requestTrait, privacy: .public) \(leg.event, privacy: .public)")
                postServerLeg(leg, requestTrait: requestTrait, orbital: routed.orbital, alreadyDelivered: result.alreadyDelivered) { [weak self] outcome in
                    self?.endAwaitingLeg(awaitToken)
                    if case .failed(let message) = outcome {
                        OrbitalViewModel.eventLog.error("hybridClientOnly cascade leg failed for \(requestTrait, privacy: .public): \(message, privacy: .public)")
                        self?.restoreOnServerFailure(message: message, trait: leg.targetTrait ?? requestTrait, event: result.seed.event, entityId: entityId, snapshot: result.snapshot)
                    }
                }
            }
        case .runtimeOptimistic:
            for routed in result.serverLegs {
                let leg = routed.leg
                postServerLeg(leg, requestTrait: requestTrait, orbital: routed.orbital, alreadyDelivered: result.alreadyDelivered) { [weak self] outcome in
                    self?.endAwaitingLeg(awaitToken)
                    if case .failed(let message) = outcome {
                        self?.restoreOnServerFailure(message: message, trait: requestTrait, event: result.seed.event, entityId: entityId, snapshot: result.snapshot)
                    }
                }
            }
        case .persistedAwaited:
            for routed in result.serverLegs {
                let leg = routed.leg
                postServerLeg(leg, requestTrait: requestTrait, orbital: routed.orbital, alreadyDelivered: result.alreadyDelivered) { [weak self] outcome in
                    self?.endAwaitingLeg(awaitToken)
                    if case .failed(let message) = outcome {
                        OrbitalViewModel.eventLog.error("persistedAwaited leg failed for \(requestTrait, privacy: .public): \(message, privacy: .public)")
                        self?.restoreOnServerFailure(message: message, trait: leg.targetTrait ?? requestTrait, event: result.seed.event, entityId: entityId, snapshot: result.snapshot)
                    }
                }
            }
        }
    }

    /// Raise `predicted` once the dispatch's legs outlast the theme's busy delay (never when the
    /// theme turns the awaiting skeleton off); nil when nothing is predicted or nothing is posted.
    private func beginAwaiting(_ predicted: [AwaitRender], legs: Int) -> UUID? {
        guard theme.motion.awaitingSkeleton, legs > 0, !predicted.isEmpty else { return nil }
        let token = UUID()
        awaitingLegs[token] = legs
        DispatchQueue.main.asyncAfter(deadline: .now() + theme.motion.busyDelay) { [weak self] in
            guard let self = self, self.awaitingLegs[token] != nil else { return }
            self.awaitingRaised[token] = predicted
            for render in predicted {
                if Self.framesTrait(render) { self.awaitingMain[render.trait] = render } else { self.awaitingSlots[render.slot] = render }
            }
        }
        return token
    }

    /// One leg of the dispatch settled; the last one clears the skeletons it raised.
    private func endAwaitingLeg(_ token: UUID?) {
        guard let token = token, let left = awaitingLegs[token] else { return }
        if left > 1 {
            awaitingLegs[token] = left - 1
            return
        }
        awaitingLegs[token] = nil
        for render in awaitingRaised.removeValue(forKey: token) ?? [] {
            if Self.framesTrait(render) { awaitingMain[render.trait] = nil } else { awaitingSlots[render.slot] = nil }
        }
    }

    /// A `main` render, or any render of an embedded trait (its host's frame), stands in as the
    /// trait's content; any other slot's stands in that slot.
    private static func framesTrait(_ render: AwaitRender) -> Bool {
        render.slot == "main" || embeddedTraits.contains(render.trait)
    }

    /// Dismiss every non-main slot `matches` selects, with any skeleton standing in it.
    func dismissSlots(where matches: (String) -> Bool) {
        uiSlots.keys.filter(matches).forEach { uiSlots.removeValue(forKey: $0) }
        awaitingSlots.keys.filter(matches).forEach { awaitingSlots.removeValue(forKey: $0) }
    }

    private enum ServerLegOutcome {
        case applied
        case failed(String)
    }

    /// POSTs `leg` and, on a successful response, folds it into the kernel
    /// (`applyServerResponse`) — the fold lands server-assigned data (ids,
    /// frame deltas) for the NEXT render, it does not replace what the
    /// local response already presented THIS call. Each leg the fold itself
    /// owes the host (an own continuation such as a refetch after a persist's
    /// success) is then posted and folded in turn, in order, until none is
    /// owed (EXEC-DIST-10), exactly as the native `ClientKernel` does; a failed
    /// owed leg alerts and never rolls back the confirmed leg that owed it.
    /// `outcome` reports back so each mode in `fold` decides its own
    /// rollback/alert policy.
    private func postServerLeg(
        _ leg: KernelServerLeg,
        requestTrait: String,
        orbital: String,
        alreadyDelivered: [KernelTraitEventPair],
        outcome: @escaping (ServerLegOutcome) -> Void
    ) {
        postAndApplyLeg(leg, requestTrait: requestTrait, orbital: orbital, alreadyDelivered: alreadyDelivered) { [weak self] result, owed in
            if case .failed = result {
                outcome(result)
                return
            }
            self?.postOwedLegs(owed, requestTrait: requestTrait) { [weak self] owedResult in
                if case .failed(let message) = owedResult {
                    OrbitalViewModel.eventLog.error("a leg owed by the fold of \(requestTrait, privacy: .public) failed: \(message, privacy: .public)")
                    self?.alertMessage = message
                }
                outcome(.applied)
            }
        }
    }

    /// Posts the legs a fold owes the host, first to last; a leg's own fold appends the legs it owes behind them.
    private func postOwedLegs(_ owed: [KernelRoutedLeg], requestTrait: String, outcome: @escaping (ServerLegOutcome) -> Void) {
        guard let next = owed.first else {
            outcome(.applied)
            return
        }
        postAndApplyLeg(next.leg, requestTrait: requestTrait, orbital: next.orbital, alreadyDelivered: []) { [weak self] result, more in
            if case .failed = result {
                outcome(result)
                return
            }
            self?.postOwedLegs(Array(owed.dropFirst()) + more, requestTrait: requestTrait, outcome: outcome)
        }
    }

    private func postAndApplyLeg(
        _ leg: KernelServerLeg,
        requestTrait: String,
        orbital: String,
        alreadyDelivered: [KernelTraitEventPair],
        outcome: @escaping (ServerLegOutcome, [KernelRoutedLeg]) -> Void
    ) {
        api.postServerLeg(leg, orbital: orbital, requestTrait: requestTrait) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, let kernel = self.kernel else { return }
                switch result {
                case .success(let posted) where posted.response.success:
                    guard let applied = kernel.applyServerResponse(responseJSON: posted.json, alreadyDelivered: alreadyDelivered) else {
                        outcome(.failed(kernel.lastError.isEmpty ? "apply_server_response failed" : kernel.lastError), [])
                        return
                    }
                    // `KernelTraitEventPair.event` carries the NEW STATE here
                    // (see `orbital_kernel_apply_server_response`'s doc comment).
                    for pair in applied.applied {
                        self.states[pair.trait] = pair.event
                    }
                    self.foldResponse(applied.response)
                    if let resync = applied.resync {
                        self.resyncFrames(resync, orbital: orbital, requestTrait: requestTrait, clientId: leg.clientId)
                    }
                    OrbitalViewModel.eventLog.info("applied server response for \(requestTrait, privacy: .public): \(applied.applied.map { $0.trait }.joined(separator: ","), privacy: .public)")
                    outcome(.applied, applied.serverLegs)
                case .success(let posted):
                    outcome(.failed(posted.response.error ?? posted.response.guardFailed ?? "Event failed"), [])
                case .failure(let error):
                    outcome(.failed(error.localizedDescription), [])
                }
            }
        }
    }

    /// The host numbered frames past the version the kernel holds: post `framesSince` and fold the snapshot it answers.
    private func resyncFrames(_ resync: KernelFramesResync, orbital: String, requestTrait: String, clientId: String?) {
        let ask = KernelServerLeg(event: "$FRAMES", eventId: nil, payload: nil, entityId: nil, targetTrait: requestTrait, user: nil, clientId: clientId, tick: nil, sourceTrait: nil, traits: nil, entityByTrait: nil, behavior: nil, delivery: nil, dispatchLog: nil, framesSince: resync.since)
        api.postServerLeg(ask, orbital: orbital, requestTrait: requestTrait) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, let kernel = self.kernel, case .success(let posted) = result, posted.response.success,
                      let applied = kernel.applyServerResponse(responseJSON: posted.json, alreadyDelivered: []) else { return }
                self.foldResponse(applied.response)
            }
        }
    }

    /// `RuntimeOptimistic` rollback: restores the pre-dispatch snapshot the
    /// kernel itself captured (`dispatch`'s own `snapshot` field) and
    /// reflects its state back into `states`, then surfaces the failure the
    /// way a failed response is surfaced today (alert + a logged error).
    private func restoreOnServerFailure(message: String, trait: String, event: String, entityId: String?, snapshot: KernelTraitSnapshot?) {
        OrbitalViewModel.eventLog.error("restoring \(trait, privacy: .public) after server error: \(message, privacy: .public)")
        if let kernel = kernel, let snapshot = snapshot {
            let repaint = kernel.restore(trait: trait, entityId: entityId, snapshot: snapshot)
            states[trait] = snapshot.state
            if let repaint = repaint { foldResponse(repaint) }
        }
        alertMessage = message
    }

    /// Live-push handler — feeds a pushed event through the SAME fold path a
    /// local dispatch uses. Ignores an item this client's own dispatch
    /// already produced (echo, matched by `clientId`) and any item with no
    /// trait to dispatch to. Called already hopped onto the main thread.
    private func handleLivePush(_ item: LiveBroadcastItem) {
        guard let kernel = kernel else { return }
        guard item.originClientId != clientId else { return }
        guard let trait = item.source?.trait else { return }
        let payloadJSON = item.payload.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        guard let result = kernel.dispatch(trait: trait, entityId: nil, event: item.event, payloadJSON: payloadJSON) else { return }
        OrbitalViewModel.eventLog.info("livepush \(trait, privacy: .public) \(item.event, privacy: .public) mode=\(result.mode.rawValue, privacy: .public)")
        fold(result: result, requestTrait: trait, entityId: nil)
    }

#if DEBUG
    /// `ORBITAL_INITIAL_ROUTE` (a debug launch) replaces the stack root with that page once the
    /// kernel is ready, as a web `page.goto` replaces the page: no pushed destination, no back
    /// chevron. The start route itself needs no replacement.
    private func openInitialRouteIfRequested() {
        guard let route = ProcessInfo.processInfo.environment["ORBITAL_INITIAL_ROUTE"], !route.isEmpty else { return }
        if route != OrbitalViewModel.startRoute { replaceRoot(with: route) }
    }

    private func replaceRoot(with path: String) {
        if !OrbitalViewModel.knownRoutes.contains(path) && path != OrbitalViewModel.hostSignInRoute {
            OrbitalViewModel.eventLog.error("initial route is undeclared: \(path, privacy: .public)")
        }
        routeStack = []
        rootRoute = path
        navigationPath = NavigationPath()
    }
#endif

    private static let BASE_URL = "__BASE_URL__"
}

extension OrbitalAPI: BearerSink {}
