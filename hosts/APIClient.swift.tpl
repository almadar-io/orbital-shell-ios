import Foundation

/// One live-broadcast item — `GET /api/events`'s `data:` line, mirrors
/// `@almadar/core`'s `LiveBroadcastItem` (event/payload/source/originClientId).
struct LiveBroadcastItem: Decodable {
    let event: String
    let payload: AnyCodable?
    let source: KernelEventSource?
    let originClientId: String?
}

/// A running `GET /api/events` subscription. `cancel()` (or `deinit`) stops
/// the reconnect loop and the underlying stream task.
final class LivePushSubscription {
    private let task: Task<Void, Never>

    fileprivate init(task: Task<Void, Never>) {
        self.task = task
    }

    func cancel() {
        task.cancel()
    }

    deinit {
        task.cancel()
    }
}

class OrbitalAPI {
    let baseUrl: String
    private let tokenLock = NSLock()
    private var storedToken: String?

    private var authToken: String? {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        return storedToken
    }

    init(baseUrl: String = "http://localhost:3030") {
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Auth hook: the signed-in session's ID token (`OrbitalAuth`), or the DEBUG verify
    /// persona's. Every request below then sends it; `nil` means anonymous requests.
    func setAuthToken(_ token: String?) {
        tokenLock.lock()
        storedToken = token
        tokenLock.unlock()
    }

    private func authorize(_ request: inout URLRequest) {
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Posts a kernel-produced server leg (`KernelServerLeg`, mirrors
    /// `orbital_core::EventRequest`) to the canonical `POST
    /// /api/orbitals/:orbital/events` route (ledger §156/A8a) — `orbital` is the
    /// owning orbital the kernel reported for the dispatched trait
    /// (`KernelDispatchResult.orbital`), never a baked constant — and decodes
    /// the response as `KernelEventResponse` (mirrors
    /// `orbital_core::EventResponse`) — hands back the raw JSON too, since
    /// `OrbitalKernel.applyServerResponse` takes the wire string, not the
    /// decoded struct. The route itself resolves the trait to dispatch from
    /// the body (`targetTrait`, else `traits[0].trait`) — no client-side
    /// per-trait URL table.
    func postServerLeg(
        _ leg: KernelServerLeg,
        orbital: String,
        requestTrait: String,
        completion: @escaping (Result<(json: String, response: KernelEventResponse), Error>) -> Void
    ) {
        guard let encodedOrbital = orbital.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))),
              let url = URL(string: "\(baseUrl)/api/orbitals/\(encodedOrbital)/events") else {
            completion(.failure(NSError(domain: "OrbitalAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid orbital events URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.httpBody = try? JSONEncoder().encode(leg)
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data, let json = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "OrbitalAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "empty response body"])))
                return
            }
            do {
                let response = try JSONDecoder().decode(KernelEventResponse.self, from: data)
                completion(.success((json, response)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// `GET /api/events` line reader (SSE `data:` lines decoded as
    /// `LiveBroadcastItem`), reconnecting with exponential backoff; a parse
    /// error on one line is logged and skipped, never a crash.
    @discardableResult
    func openLivePush(clientId: String, onItem: @escaping (LiveBroadcastItem) -> Void) -> LivePushSubscription {
        let baseUrl = self.baseUrl
        let task = Task.detached(priority: .background) { [weak self] in
            var backoffNanos: UInt64 = 1_000_000_000
            while !Task.isCancelled {
                guard let url = URL(string: "\(baseUrl)/api/events?clientId=\(clientId)") else { return }
                var request = URLRequest(url: url)
                if let authToken = self?.authToken {
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                }
                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        if Task.isCancelled { return }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard !payload.isEmpty, let data = payload.data(using: .utf8) else { continue }
                        do {
                            let item = try JSONDecoder().decode(LiveBroadcastItem.self, from: data)
                            onItem(item)
                        } catch {
                            NSLog("[Orbital] live push: unparseable event: %@", String(describing: error))
                        }
                    }
                } catch {
                    NSLog("[Orbital] live push: stream error: %@", String(describing: error))
                }
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: backoffNanos)
                backoffNanos = min(backoffNanos * 2, 30_000_000_000)
            }
        }
        return LivePushSubscription(task: task)
    }
}
