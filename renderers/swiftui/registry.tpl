import Foundation
import SwiftUI

struct CorePatternRegistry {
    private static let registry: [String: PatternRenderer] = [
{{entries}}
    ]

    static func renderer(for patternName: String) -> PatternRenderer {
        let inner: PatternRenderer = registry[patternName] ?? { props, modifier, onEvent in
            FallbackRendererView(patternName: patternName, props: props, modifier: modifier, onEvent: onEvent)
        }
        return { props, modifier, onEvent in
            let view = inner(props, modifier, onEvent)
            let enter = props.string("enter")
            if enter.isEmpty || enter == "none" {
                return AnyView(view.verificationContainer(VerificationIds.pattern(patternName)))
            }
            return AnyView(view.modifier(AlmadarNodeEnter(enter: enter, step: props.float("enterDelay"))).verificationContainer(VerificationIds.pattern(patternName)))
        }
    }
}
