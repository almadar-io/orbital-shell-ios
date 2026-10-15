import Foundation
import Security

/// Where the app's identity provider lives. Declared by the build (Info.plist keys fed from the
/// `ORBITAL_FIREBASE_*` / `ORBITAL_AUTH_EMULATOR_HOST` build settings); nothing is inferred.
struct OrbitalAuthConfig: Equatable {
    let apiKey: String
    let projectId: String
    let emulatorHost: String?

    var identityToolkitBase: String {
        emulatorHost.map { "http://\($0)/identitytoolkit.googleapis.com/v1" } ?? "https://identitytoolkit.googleapis.com/v1"
    }

    var secureTokenBase: String {
        emulatorHost.map { "http://\($0)/securetoken.googleapis.com/v1" } ?? "https://securetoken.googleapis.com/v1"
    }

    /// `nil` when the build declares no provider (the sign-in view then says so; requests stay anonymous).
    /// `emulatorOverride` is the DEBUG launch override and takes precedence over the Info.plist host.
    static func declared(info: [String: AnyCodable], emulatorOverride: String?) -> OrbitalAuthConfig? {
        guard let apiKey = info["OrbitalFirebaseApiKey"]?.stringValue, !apiKey.isEmpty,
              let projectId = info["OrbitalFirebaseProjectId"]?.stringValue, !projectId.isEmpty else { return nil }
        let declaredHost = info["OrbitalAuthEmulatorHost"]?.stringValue
        let host = [emulatorOverride, declaredHost].compactMap { $0 }.first { !$0.isEmpty }
        return OrbitalAuthConfig(apiKey: apiKey, projectId: projectId, emulatorHost: host)
    }
}

struct OrbitalAuthSession: Codable, Equatable {
    let idToken: String
    let refreshToken: String
    let expiresAt: Date
    let uid: String
}

struct OrbitalPersona: Equatable {
    let id: String
    let label: String
}

enum OrbitalAuthError: LocalizedError, Equatable {
    case notConfigured
    case provider(String)
    case malformedResponse(String)
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Sign-in is not configured for this build"
        case .provider(let message): return message
        case .malformedResponse(let what): return "Unexpected sign-in response: \(what)"
        case .notSignedIn: return "Not signed in"
        }
    }
}

protocol AuthTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

struct URLSessionAuthTransport: AuthTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}

protocol AuthSessionStore {
    func read() -> Data?
    func write(_ data: Data) throws
    func delete()
}

/// The session lives in the iOS Keychain, readable only after first unlock and never synced off the device.
struct KeychainSessionStore: AuthSessionStore {
    let service: String
    private let account = "orbital-auth-session"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read() -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    func write(_ data: Data) throws {
        delete()
        var request = query
        request[kSecValueData as String] = data
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(request as CFDictionary, nil)
        guard status == errSecSuccess else { throw OrbitalAuthError.provider("Keychain write failed (\(status))") }
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

/// Native sign-in against the provider's REST API (Firebase Identity Toolkit and Secure Token), the
/// platform twin of `@almadar/auth/browser`. It performs the provider call, holds the session and
/// reports each change; it never routes, hides or gates anything from auth state.
final class OrbitalAuth: @unchecked Sendable {
    private let config: OrbitalAuthConfig?
    private let transport: AuthTransport
    private let store: AuthSessionStore
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private let lock = NSLock()
    private var refreshTask: Task<Void, Never>?
    private var current: OrbitalAuthSession?

    var session: OrbitalAuthSession? {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// Fired after every change of the session: sign-in, refresh, restore, sign-out (`nil`).
    var onChange: ((OrbitalAuthSession?) -> Void)?

    init(config: OrbitalAuthConfig?, transport: AuthTransport = URLSessionAuthTransport(), store: AuthSessionStore, now: @escaping () -> Date = Date.init,
         sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }) {
        self.config = config
        self.transport = transport
        self.store = store
        self.now = now
        self.sleep = sleep
    }

    var isConfigured: Bool { config != nil }

    func loadStoredSession() {
        guard let data = store.read(), let stored = try? JSONDecoder().decode(OrbitalAuthSession.self, from: data) else { return }
        adopt(stored, persist: false)
    }

    func signIn(email: String, password: String) async throws {
        let config = try requireConfig()
        let body = AnyCodable.dict(["email": .string(email), "password": .string(password), "returnSecureToken": .bool(true)])
        let reply = try await post("\(config.identityToolkitBase)/accounts:signInWithPassword?key=\(config.apiKey)", body)
        adopt(try Self.session(fromSignInReply: reply, now: now()), persist: true)
    }

    func signIn(customToken: String) async throws {
        let config = try requireConfig()
        let body = AnyCodable.dict(["token": .string(customToken), "returnSecureToken": .bool(true)])
        let reply = try await post("\(config.identityToolkitBase)/accounts:signInWithCustomToken?key=\(config.apiKey)", body)
        adopt(try Self.session(fromSignInReply: reply, now: now()), persist: true)
    }

    /// The dev persona roster a server's `personasRouter` offers (only while it runs on the Auth emulator).
    func personas(apiBase: String) async -> [OrbitalPersona] {
        guard let url = URL(string: "\(apiBase)/api/personas") else { return [] }
        guard let (data, status) = try? await transport.send(URLRequest(url: url)), (200..<300).contains(status),
              let reply = try? JSONDecoder().decode(AnyCodable.self, from: data),
              let rows = reply["personas"]?.arrayValue else { return [] }
        return rows.compactMap { row in
            guard let id = row["id"]?.stringValue else { return nil }
            let name = row["name"]?.stringValue ?? id
            let role = row["role"]?.stringValue ?? "no role"
            return OrbitalPersona(id: id, label: "\(name) - \(role)")
        }
    }

    func signInAsPersona(id: String, apiBase: String) async throws {
        guard let url = URL(string: "\(apiBase)/api/personas/sign-in") else { throw OrbitalAuthError.malformedResponse("persona sign-in url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AnyCodable.dict(["id": .string(id)]))
        let (data, status) = try await transport.send(request)
        let reply = try JSONDecoder().decode(AnyCodable.self, from: data)
        guard (200..<300).contains(status), let customToken = reply["customToken"]?.stringValue else {
            throw OrbitalAuthError.provider(reply["error"]?.stringValue ?? "persona sign-in failed (\(status))")
        }
        try await signIn(customToken: customToken)
    }

    /// Refreshes the ID token when fewer than `margin` seconds remain.
    func refreshIfNeeded(margin: TimeInterval = 60) async throws {
        guard let held = session, held.expiresAt.timeIntervalSince(now()) <= margin else { return }
        let config = try requireConfig()
        let body = AnyCodable.dict(["grant_type": .string("refresh_token"), "refresh_token": .string(held.refreshToken)])
        let reply = try await post("\(config.secureTokenBase)/token?key=\(config.apiKey)", body)
        guard let idToken = reply["id_token"]?.stringValue, let refreshToken = reply["refresh_token"]?.stringValue,
              let expiresIn = reply["expires_in"]?.doubleValue else { throw OrbitalAuthError.malformedResponse("token refresh") }
        let uid = try Self.claims(ofIdToken: idToken)["sub"]?.stringValue ?? held.uid
        adopt(OrbitalAuthSession(idToken: idToken, refreshToken: refreshToken, expiresAt: now().addingTimeInterval(expiresIn), uid: uid), persist: true)
    }

    func signOut() {
        lock.lock()
        refreshTask?.cancel()
        refreshTask = nil
        current = nil
        lock.unlock()
        store.delete()
        onChange?(nil)
    }

    private func requireConfig() throws -> OrbitalAuthConfig {
        guard let config = config else { throw OrbitalAuthError.notConfigured }
        return config
    }

    private func adopt(_ next: OrbitalAuthSession, persist: Bool) {
        if persist, let data = try? JSONEncoder().encode(next) { try? store.write(data) }
        let wait = max(next.expiresAt.timeIntervalSince(now()) - 60, 0)
        lock.lock()
        current = next
        refreshTask?.cancel()
        refreshTask = Task { [weak self, sleep] in
            do { try await sleep(wait) } catch { return }
            try? await self?.refreshIfNeeded()
        }
        lock.unlock()
        onChange?(next)
    }

    private func post(_ urlString: String, _ body: AnyCodable) async throws -> AnyCodable {
        guard let url = URL(string: urlString) else { throw OrbitalAuthError.malformedResponse("url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, status) = try await transport.send(request)
        guard let reply = try? JSONDecoder().decode(AnyCodable.self, from: data) else {
            throw OrbitalAuthError.malformedResponse("non-JSON body (\(status))")
        }
        guard (200..<300).contains(status) else {
            throw OrbitalAuthError.provider(reply["error"]?["message"]?.stringValue ?? "sign-in failed (\(status))")
        }
        return reply
    }

    private static func session(fromSignInReply reply: AnyCodable, now: Date) throws -> OrbitalAuthSession {
        guard let idToken = reply["idToken"]?.stringValue, let refreshToken = reply["refreshToken"]?.stringValue,
              let expiresIn = reply["expiresIn"]?.doubleValue else { throw OrbitalAuthError.malformedResponse("sign-in") }
        guard let uid = try claims(ofIdToken: idToken)["sub"]?.stringValue else { throw OrbitalAuthError.malformedResponse("id token has no subject") }
        return OrbitalAuthSession(idToken: idToken, refreshToken: refreshToken, expiresAt: now.addingTimeInterval(expiresIn), uid: uid)
    }

    /// The ID token's payload claims. The server verifies the token; the client only reads it, as the web does.
    nonisolated static func claims(ofIdToken idToken: String) throws -> [String: AnyCodable] {
        let parts = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw OrbitalAuthError.malformedResponse("id token is not a JWT") }
        var encoded = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while encoded.count % 4 != 0 { encoded.append("=") }
        guard let data = Data(base64Encoded: encoded), let payload = try? JSONDecoder().decode(AnyCodable.self, from: data),
              let claims = payload.dictValue else { throw OrbitalAuthError.malformedResponse("id token payload") }
        return claims
    }

    /// `@user` for the kernel: `normalizeUserContext({...claims, uid: sub})`. `nil` for a token with no subject.
    nonisolated static func viewerJSON(idToken: String) throws -> String? {
        var claims = try claims(ofIdToken: idToken)
        guard let uid = claims["sub"]?.stringValue, !uid.isEmpty else { return nil }
        claims["uid"] = .string(uid)
        var user: [String: AnyCodable] = ["id": .string(uid)]
        for (key, value) in claims where !["id", "name", "displayName", "email"].contains(key) { user[key] = value }
        if let name = claims["name"]?.stringValue ?? claims["displayName"]?.stringValue, !name.isEmpty { user["name"] = .string(name) }
        if let email = claims["email"]?.stringValue, !email.isEmpty { user["email"] = .string(email) }
        return String(data: try JSONEncoder().encode(AnyCodable.dict(user)), encoding: .utf8)
    }
}

protocol BearerSink: AnyObject {
    func setAuthToken(_ token: String?)
}

protocol ViewerSink: AnyObject {
    func setCurrentUser(json: String)
}

/// Applies a session to the two places a signed-in viewer shows up: the `Authorization: Bearer`
/// plumbing every request reads, and the kernel's `@user`. It only reports whether the signed-in
/// identity changed; what an identity change repaints is the host's call, never inferred here.
final class OrbitalSessionBinding {
    private let api: BearerSink
    private let kernel: () -> ViewerSink?
    private var uid: String?

    init(api: BearerSink, kernel: @escaping () -> ViewerSink?) {
        self.api = api
        self.kernel = kernel
    }

    @discardableResult
    func apply(_ session: OrbitalAuthSession?) -> Bool {
        api.setAuthToken(session?.idToken)
        let viewer = session.flatMap { try? OrbitalAuth.viewerJSON(idToken: $0.idToken) }.flatMap { $0 }
        kernel()?.setCurrentUser(json: viewer ?? "null")
        let changed = uid != session?.uid
        uid = session?.uid
        return changed
    }
}
