import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct ContainerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let size = props.string("maxWidth", default: props.string("size", default: "lg"))
        let cap = limit(size)
        BoxRenderer(
            props: ["paddingX": .string(padding(props.string("padding", default: "md"))), "fullWidth": true, "children": props.dictValue?["children"] ?? .null],
            modifier: nil,
            onEvent: onEvent
        )
        .frame(maxWidth: cap, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: props.bool("center", default: true) ? .center : .leading)
    }

    private func limit(_ size: String) -> CGFloat {
        switch size {
        case "xs": return AlmadarSizes.maxWXs
        case "sm": return AlmadarBreakpoints.sm
        case "md": return AlmadarBreakpoints.md
        case "xl": return AlmadarBreakpoints.xl
        case "2xl": return AlmadarBreakpoints.xxl
        case "full": return .infinity
        default: return AlmadarBreakpoints.lg
        }
    }

    private func padding(_ token: String) -> String {
        token == "xl" ? "xl" : (token == "lg" ? "lg" : (token == "sm" ? "sm" : (token == "none" ? "none" : "md")))
    }
}

@ViewBuilder
func ContainerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ContainerMoleculeView(props: props, onEvent: onEvent))
}
