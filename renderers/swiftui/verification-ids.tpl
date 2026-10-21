import Foundation

enum VerificationIds {
    static let actionOverflow: String = "{{actionOverflow}}"

    static func action(_ eventKey: String) -> String {
        "{{actionPrefix}}" + eventKey
    }

{{gestures}}    /// One identifier for an element that dispatches several actions (a tap and a gesture).
    static func ids(_ ids: String...) -> String {
        ids.filter { !$0.isEmpty }.joined(separator: "{{separator}}")
    }

    static func pattern(_ name: String) -> String {
        "{{patternPrefix}}" + name
    }

    static func row(_ id: String) -> String {
        "{{rowPrefix}}" + id
    }

    static func field(_ name: String) -> String {
        "{{fieldPrefix}}" + name
    }

    static func slot(_ name: String) -> String {
        "{{slotPrefix}}" + name
    }
}
