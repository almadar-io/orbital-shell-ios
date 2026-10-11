import Foundation

enum VerificationIds {
    static let actionOverflow: String = "action-overflow"

    static func action(_ eventKey: String) -> String {
        "action-" + eventKey
    }

    static func longPress(_ eventKey: String) -> String {
        "action-long-press:" + eventKey
    }

    static func swipeLeft(_ eventKey: String) -> String {
        "action-swipe-left:" + eventKey
    }

    static func swipeRight(_ eventKey: String) -> String {
        "action-swipe-right:" + eventKey
    }

    /// One identifier for an element that dispatches several actions (a tap and a gesture).
    static func ids(_ ids: String...) -> String {
        ids.filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func pattern(_ name: String) -> String {
        "pattern-" + name
    }

    static func row(_ id: String) -> String {
        "row-" + id
    }

    static func field(_ name: String) -> String {
        "field-" + name
    }

    static func slot(_ name: String) -> String {
        "slot-" + name
    }
}
