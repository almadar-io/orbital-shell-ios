import Foundation
import os

/// What a slot shows while `requestTrait`, having taken `event` from one of `from` (any state when
/// nil), awaits its server round trip: the compiler's `await_render` prediction.
struct AwaitRender: Decodable {
    let requestTrait: String
    let event: String
    let from: [String]?
    let `trait`: String
    let slot: String
    let skeleton: AnyCodable
}

enum AwaitRenders {
    private static let log = Logger(subsystem: "com.orbital", category: "await-render")

    static let all: [AwaitRender] = {
        do {
            return try JSONDecoder().decode([AwaitRender].self, from: Data(json.utf8))
        } catch {
            log.error("await-render table failed to decode: \(String(describing: error), privacy: .public)")
            return []
        }
    }()

    static func matching(_ awaiting: KernelAwaitingTrait) -> [AwaitRender] {
        all.filter { row in
            row.requestTrait == awaiting.trait && row.event == awaiting.event && (row.from?.contains(awaiting.from) ?? true)
        }
    }

    private static let json = #"__ROWS__"#
}
