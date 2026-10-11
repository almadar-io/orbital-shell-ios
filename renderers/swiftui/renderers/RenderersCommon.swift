import Foundation
import SwiftUI

extension AnyCodable {
    func string(_ key: String, default defaultValue: String = "") -> String {
        guard let value = dictValue?[key] else { return defaultValue }
        switch value {
        case .string(let text): return text
        case .int(let number): return String(number)
        case .double(let number):
            if number.isFinite && number == number.rounded() && abs(number) < 1e15 { return String(Int(number)) }
            return String(number)
        default: return defaultValue
        }
    }

    func int(_ key: String, default defaultValue: Int = 0) -> Int {
        dictValue?[key]?.intValue ?? defaultValue
    }

    func float(_ key: String, default defaultValue: Double = 0) -> Double {
        dictValue?[key]?.doubleValue ?? defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        dictValue?[key]?.boolValue ?? defaultValue
    }

    func children() -> [AnyCodable] {
        guard let c = dictValue?["children"] else { return [] }
        if let arr = c.arrayValue { return arr }
        if let text = c.stringValue { return [AnyCodable.string(text)] }
        if c.dictValue != nil { return [c] }
        return []
    }

    func merging(_ overrides: [String: AnyCodable]) -> AnyCodable {
        var merged = dictValue ?? [:]
        for (key, value) in overrides { merged[key] = value }
        return .dict(merged)
    }
}

extension View {
    func verificationId(_ id: String) -> some View {
        accessibilityIdentifier(id)
    }

    func verificationContainer(_ id: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}

/// The one shape every renderer body's `onEvent(name, …)` call must pass as
/// its payload (Program C, `docs/Almadar_Compiler_Gaps.md` §157/§162):
/// `{"sourceTrait": <props' own sourceTrait, verbatim>, "actionPayload": <resolved payload, absent — never JSON null — when there is none>}`.
/// `actionPayload` resolves to `props`' own DECLARED `actionPayload` when it
/// is a non-null object, else the caller's computed `payload` (e.g.
/// `{searchTerm, entity}`, `{id}`, `{href}`) when THAT is a non-null object,
/// else the key is omitted entirely. The page (`GeneratedPage.onEvent`)
/// reads `envelope.sourceTrait ?? traitName` and sends `envelope.actionPayload`.
func eventEnvelope(_ props: AnyCodable, payload: AnyCodable? = nil) -> AnyCodable {
    var envelope: [String: AnyCodable] = [:]
    if let sourceTrait = props.dictValue?["sourceTrait"] {
        envelope["sourceTrait"] = sourceTrait
    }
    let declared = props.dictValue?["actionPayload"]
    if let declared = declared, declared.dictValue != nil {
        envelope["actionPayload"] = declared
    } else if let payload = payload, payload.dictValue != nil {
        envelope["actionPayload"] = payload
    }
    return .dict(envelope)
}

@ViewBuilder
func RenderChild(_ child: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) -> some View {
    if let text = child.stringValue {
        Text(text)
    } else if let dict = child.dictValue,
              let typeName = dict["type"]?.stringValue {
        CorePatternRegistry.renderer(for: typeName)(child, nil, onEvent)
    }
}
