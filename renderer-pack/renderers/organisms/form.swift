import Foundation
import SwiftUI

// tier: organisms — a List/Form/ScrollView fragment

@ViewBuilder
func FormRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(FormSectionOrganismView(
        props: props.merging([
            "fields": .array(AtomKit.fieldDefs(props, ["fields"])),
            "submitEvent": .string(props.string("submitEvent", default: "SAVE")),
            "cancelEvent": .string(props.string("cancelEvent", default: "CANCEL")),
        ]),
        onEvent: onEvent
    ))
}
