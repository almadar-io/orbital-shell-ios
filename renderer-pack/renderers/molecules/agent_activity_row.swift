import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

@ViewBuilder
func AgentActivityRowRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    let activity = props.dictValue?["activity"] ?? AnyCodable.dict([:])
    let facts = props.dictValue?["facts"] ?? AnyCodable.dict([:])
    AnyView(AtomAgentRow(activity: activity, settled: facts.bool("settled"), ready: facts.int("readyCount"), onEvent: onEvent))
}
