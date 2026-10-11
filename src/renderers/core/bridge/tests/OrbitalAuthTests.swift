import Foundation
import XCTest
@testable import __APP_MODULE__

final class FakeAuthTransport: AuthTransport {
    struct Reply { let status: Int; let body: String }
    var replies: [Reply] = []
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let reply = replies.removeFirst()
        return (Data(reply.body.utf8), reply.status)
    }
}

final class MemoryStore: AuthSessionStore {
    var data: Data?
    func read() -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
    func delete() { data = nil }
}

func jwt(_ claims: String) -> String {
    let payload = Data(claims.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "e30.\(payload).sig"
}

final class OrbitalAuthTests: XCTestCase {
    private let emulator = OrbitalAuthConfig(apiKey: "k", projectId: "demo-app", emulatorHost: "127.0.0.1:9099")
    private let production = OrbitalAuthConfig(apiKey: "k", projectId: "app", emulatorHost: nil)
    private let epoch = Date(timeIntervalSince1970: 1_000_000)

    private func signInReply(token: String, expiresIn: Int = 3600) -> FakeAuthTransport.Reply {
        .init(status: 200, body: "{\"idToken\":\"\(token)\",\"refreshToken\":\"r1\",\"expiresIn\":\"\(expiresIn)\"}")
    }

    private let never: (TimeInterval) async throws -> Void = { _ in try await Task.sleep(nanoseconds: UInt64.max) }

    private func auth(_ config: OrbitalAuthConfig?, _ transport: FakeAuthTransport, _ store: MemoryStore = MemoryStore(),
                      now: (() -> Date)? = nil, sleep: ((TimeInterval) async throws -> Void)? = nil) -> OrbitalAuth {
        OrbitalAuth(config: config, transport: transport, store: store, now: now ?? { self.epoch }, sleep: sleep ?? never)
    }

    func test_email_sign_in_posts_to_the_emulator_and_stores_the_session() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [signInReply(token: jwt("{\"sub\":\"u1\"}"))]
        let store = MemoryStore()
        let sut = auth(emulator, transport, store)
        var seen: [OrbitalAuthSession?] = []
        sut.onChange = { seen.append($0) }

        try await sut.signIn(email: "a@b.c", password: "pw")

        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=k")
        XCTAssertEqual(sut.session?.uid, "u1")
        XCTAssertEqual(sut.session?.expiresAt, epoch.addingTimeInterval(3600))
        XCTAssertNotNil(store.data)
        XCTAssertEqual(seen.count, 1)
    }

    func test_production_sign_in_uses_the_google_hosts_and_a_failure_stores_nothing() async {
        let transport = FakeAuthTransport()
        transport.replies = [.init(status: 400, body: "{\"error\":{\"code\":400,\"message\":\"INVALID_PASSWORD\"}}")]
        let store = MemoryStore()
        let sut = auth(production, transport, store)
        var changes = 0
        sut.onChange = { _ in changes += 1 }

        do {
            try await sut.signIn(email: "a@b.c", password: "bad")
            XCTFail("a provider rejection must throw")
        } catch {
            XCTAssertEqual(error as? OrbitalAuthError, .provider("INVALID_PASSWORD"))
        }

        XCTAssertEqual(transport.requests.first?.url?.host, "identitytoolkit.googleapis.com")
        XCTAssertNil(sut.session)
        XCTAssertNil(store.data)
        XCTAssertEqual(changes, 0)
    }

    func test_unconfigured_build_refuses_without_a_request() async {
        let transport = FakeAuthTransport()
        let sut = auth(nil, transport)
        XCTAssertFalse(sut.isConfigured)
        do {
            try await sut.signIn(email: "a@b.c", password: "pw")
            XCTFail("an unconfigured build must throw")
        } catch {
            XCTAssertEqual(error as? OrbitalAuthError, .notConfigured)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func test_persona_sign_in_exchanges_the_server_custom_token() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [
            .init(status: 200, body: "{\"success\":true,\"customToken\":\"ct\",\"authEmulatorHost\":\"127.0.0.1:9099\",\"projectId\":\"demo-app\"}"),
            signInReply(token: jwt("{\"sub\":\"p-1\",\"role\":\"admin\"}")),
        ]
        let sut = auth(emulator, transport)

        try await sut.signInAsPersona(id: "p-1", apiBase: "http://127.0.0.1:3030")

        XCTAssertEqual(transport.requests[0].url?.absoluteString, "http://127.0.0.1:3030/api/personas/sign-in")
        XCTAssertTrue(transport.requests[1].url?.absoluteString.contains("accounts:signInWithCustomToken") == true)
        XCTAssertEqual(sut.session?.uid, "p-1")
    }

    func test_persona_sign_in_failure_surfaces_the_server_error_and_signs_nobody_in() async {
        let transport = FakeAuthTransport()
        transport.replies = [.init(status: 404, body: "{\"success\":false,\"error\":\"no persona with id x\"}")]
        let sut = auth(emulator, transport)
        do {
            try await sut.signInAsPersona(id: "x", apiBase: "http://127.0.0.1:3030")
            XCTFail("an unknown persona must throw")
        } catch {
            XCTAssertEqual(error as? OrbitalAuthError, .provider("no persona with id x"))
        }
        XCTAssertNil(sut.session)
        XCTAssertEqual(transport.requests.count, 1)
    }

    func test_personas_lists_the_roster_and_is_empty_when_the_server_offers_none() async {
        let transport = FakeAuthTransport()
        transport.replies = [
            .init(status: 200, body: "{\"success\":true,\"personas\":[{\"id\":\"p-1\",\"name\":\"Maya\",\"role\":\"admin\"},{\"id\":\"p-2\"}]}"),
            .init(status: 404, body: "{}"),
        ]
        let sut = auth(emulator, transport)
        let roster = await sut.personas(apiBase: "http://h")
        XCTAssertEqual(roster, [OrbitalPersona(id: "p-1", label: "Maya - admin"), OrbitalPersona(id: "p-2", label: "p-2 - no role")])
        let none = await sut.personas(apiBase: "http://h")
        XCTAssertEqual(none, [])
    }

    func test_refresh_runs_only_when_the_token_is_near_expiry() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [
            signInReply(token: jwt("{\"sub\":\"u1\"}"), expiresIn: 30),
            .init(status: 200, body: "{\"id_token\":\"\(jwt("{\"sub\":\"u1\"}"))\",\"refresh_token\":\"r2\",\"expires_in\":\"3600\"}"),
        ]
        let sut = auth(emulator, transport)
        try await sut.signIn(email: "a@b.c", password: "pw")

        try await sut.refreshIfNeeded()

        XCTAssertTrue(transport.requests[1].url?.absoluteString.contains("securetoken.googleapis.com/v1/token?key=k") == true)
        XCTAssertEqual(sut.session?.refreshToken, "r2")
        XCTAssertEqual(sut.session?.expiresAt, epoch.addingTimeInterval(3600))

        try await sut.refreshIfNeeded()
        XCTAssertEqual(transport.requests.count, 2, "a fresh token must not be refreshed again")
    }

    func test_a_session_schedules_its_refresh_a_minute_before_expiry_and_the_refresh_adopts_the_new_token() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [
            signInReply(token: jwt("{\"sub\":\"u1\"}"), expiresIn: 3600),
            .init(status: 200, body: "{\"id_token\":\"\(jwt("{\"sub\":\"u1\"}"))\",\"refresh_token\":\"r2\",\"expires_in\":\"3600\"}"),
        ]
        var waits: [TimeInterval] = []
        var clock = epoch
        let refreshed = expectation(description: "refresh adopted")
        let sut = auth(emulator, transport, now: { clock }, sleep: {
            waits.append($0)
            if waits.count > 1 { try await Task.sleep(nanoseconds: UInt64.max) }
            clock = clock.addingTimeInterval($0)
        })
        sut.onChange = { if $0?.refreshToken == "r2" { refreshed.fulfill() } }

        try await sut.signIn(email: "a@b.c", password: "pw")
        await fulfillment(of: [refreshed], timeout: 2)

        XCTAssertEqual(waits.first, 3540)
        XCTAssertEqual(sut.session?.refreshToken, "r2")
    }

    func test_sign_out_clears_the_stored_session_and_reports_nil() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [signInReply(token: jwt("{\"sub\":\"u1\"}"))]
        let store = MemoryStore()
        let sut = auth(emulator, transport, store)
        try await sut.signIn(email: "a@b.c", password: "pw")
        var last: OrbitalAuthSession?? = .none
        sut.onChange = { last = .some($0) }

        sut.signOut()

        XCTAssertNil(sut.session)
        XCTAssertNil(store.data)
        XCTAssertEqual(last, .some(nil))
    }

    func test_restore_adopts_the_stored_session_and_an_empty_store_restores_nothing() async throws {
        let transport = FakeAuthTransport()
        transport.replies = [signInReply(token: jwt("{\"sub\":\"u1\"}"))]
        let store = MemoryStore()
        try await auth(emulator, transport, store).signIn(email: "a@b.c", password: "pw")

        let restored = auth(emulator, FakeAuthTransport(), store)
        restored.loadStoredSession()
        XCTAssertEqual(restored.session?.uid, "u1")

        let empty = auth(emulator, FakeAuthTransport())
        empty.loadStoredSession()
        XCTAssertNil(empty.session)
    }

    func test_viewer_normalizes_claims_like_the_web_client() throws {
        let token = jwt("{\"sub\":\"u1\",\"name\":\"Maya\",\"email\":\"m@x.io\",\"role\":\"admin\",\"user_id\":\"u1\"}")
        let json = try XCTUnwrap(OrbitalAuth.viewerJSON(idToken: token))
        let user = try XCTUnwrap(try JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8)).dictValue)
        XCTAssertEqual(user["id"]?.stringValue, "u1")
        XCTAssertEqual(user["uid"]?.stringValue, "u1")
        XCTAssertEqual(user["name"]?.stringValue, "Maya")
        XCTAssertEqual(user["email"]?.stringValue, "m@x.io")
        XCTAssertEqual(user["role"]?.stringValue, "admin")
    }

    func test_viewer_is_nil_without_a_subject_and_a_malformed_token_throws() throws {
        XCTAssertNil(try OrbitalAuth.viewerJSON(idToken: jwt("{\"role\":\"admin\"}")))
        XCTAssertThrowsError(try OrbitalAuth.viewerJSON(idToken: "not-a-jwt"))
    }

    func test_config_needs_key_and_project_and_the_debug_override_wins() {
        let info: [String: AnyCodable] = ["OrbitalFirebaseApiKey": .string("k"), "OrbitalFirebaseProjectId": .string("p"), "OrbitalAuthEmulatorHost": .string("plist:9099")]
        XCTAssertEqual(OrbitalAuthConfig.declared(info: info, emulatorOverride: "env:9099")?.emulatorHost, "env:9099")
        XCTAssertEqual(OrbitalAuthConfig.declared(info: info, emulatorOverride: nil)?.emulatorHost, "plist:9099")
        XCTAssertNil(OrbitalAuthConfig.declared(info: ["OrbitalFirebaseApiKey": .string(""), "OrbitalFirebaseProjectId": .string("p")], emulatorOverride: nil))
        XCTAssertNil(OrbitalAuthConfig.declared(info: ["OrbitalFirebaseApiKey": .string("k")], emulatorOverride: nil))
        XCTAssertNil(OrbitalAuthConfig.declared(info: ["OrbitalFirebaseApiKey": .string("k"), "OrbitalFirebaseProjectId": .string("p")], emulatorOverride: nil)?.emulatorHost)
    }
}

final class RecordingApi: BearerSink {
    var tokens: [String?] = []
    func setAuthToken(_ token: String?) { tokens.append(token) }
}

final class RecordingKernel: ViewerSink {
    var users: [String] = []
    func setCurrentUser(json: String) { users.append(json) }
}

final class OrbitalSessionBindingTests: XCTestCase {
    private func session(_ uid: String, token: String? = nil) -> OrbitalAuthSession {
        OrbitalAuthSession(idToken: token ?? jwt("{\"sub\":\"\(uid)\",\"role\":\"admin\"}"), refreshToken: "r", expiresAt: Date(timeIntervalSince1970: 2_000_000), uid: uid)
    }

    func test_a_session_attaches_its_token_and_binds_the_viewer_on_the_kernel() throws {
        let api = RecordingApi()
        let kernel = RecordingKernel()
        let binding = OrbitalSessionBinding(api: api, kernel: { kernel })
        let signedIn = session("u1")

        XCTAssertTrue(binding.apply(signedIn))

        XCTAssertEqual(api.tokens, [signedIn.idToken])
        let user = try XCTUnwrap(JSONDecoder().decode(AnyCodable.self, from: Data(try XCTUnwrap(kernel.users.first).utf8)).dictValue)
        XCTAssertEqual(user["id"]?.stringValue, "u1")
        XCTAssertEqual(user["role"]?.stringValue, "admin")
    }

    func test_sign_out_clears_the_token_and_the_kernel_viewer() {
        let api = RecordingApi()
        let kernel = RecordingKernel()
        let binding = OrbitalSessionBinding(api: api, kernel: { kernel })
        binding.apply(session("u1"))

        XCTAssertTrue(binding.apply(nil))

        XCTAssertEqual(api.tokens.last ?? "unset", nil)
        XCTAssertEqual(kernel.users.last, "null")
    }

    func test_a_refresh_of_the_same_identity_is_not_an_identity_change() {
        let binding = OrbitalSessionBinding(api: RecordingApi(), kernel: { RecordingKernel() })
        XCTAssertTrue(binding.apply(session("u1")))
        XCTAssertFalse(binding.apply(session("u1", token: jwt("{\"sub\":\"u1\",\"iat\":2}"))))
        XCTAssertTrue(binding.apply(session("u2")))
    }

    func test_signing_out_when_nobody_is_signed_in_changes_nothing() {
        XCTAssertFalse(OrbitalSessionBinding(api: RecordingApi(), kernel: { nil }).apply(nil))
    }
}
