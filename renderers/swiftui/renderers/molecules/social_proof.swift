import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SocialProofMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        let items = props.dictValue?["items"]?.arrayValue ?? []
        switch props.string("variant", default: "logos") {
        case "quotes":
            AtomGridLayout(minWidth: theme.density.spacing.space12 * 4, maxColumns: 3, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                ForEach(items.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        if !items[index].string("quote").isEmpty {
                            AtomKit.typo("“" + items[index].string("quote") + "”", "body1", onEvent: onEvent)
                        }
                        AtomKit.typo(items[index].string("name"), "caption", color: "muted", onEvent: onEvent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .atomSurface(theme)
                }
            }
        case "badges":
            AtomGridLayout(minWidth: theme.density.spacing.space12 * 2, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space2) {
                ForEach(items.indices, id: \.self) { index in
                    AtomKit.badge(items[index].string("name"), "default", size: "md", onEvent: onEvent)
                }
            }
        default:
            AtomGridLayout(minWidth: theme.density.spacing.space12 * 2, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space6) {
                ForEach(items.indices, id: \.self) { index in
                    VStack(spacing: theme.density.spacing.space1) {
                        if !items[index].string("logo").isEmpty {
                            ImageRenderer(props: ["src": .string(items[index].string("logo")), "alt": .string(items[index].string("name")), "fit": "contain"], modifier: nil, onEvent: onEvent)
                                .frame(width: theme.density.spacing.space12, height: theme.density.spacing.space12)
                        }
                        AtomKit.typo(items[index].string("name"), "caption", color: "muted", align: "center", onEvent: onEvent)
                    }
                    .opacity(0.6)
                }
            }
        }
    }
}

@ViewBuilder
func SocialProofRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SocialProofMoleculeView(props: props, onEvent: onEvent))
}
