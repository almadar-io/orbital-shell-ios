import Foundation

final class Indirect<Value: Codable>: Codable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    required init(from decoder: Decoder) throws {
        value = try Value(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
