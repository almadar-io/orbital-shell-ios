import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct PopoverMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var shown: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _shown = State(initialValue: props.bool("open"))
    }

    var body: some View {
        let open = props.dictValue?["open"] != nil ? props.bool("open") : shown
        let above = props.string("position", default: "bottom") == "top"
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            if above && open { panel }
            AtomChildren(props: props, key: "children", onEvent: onEvent)
                .contentShape(Rectangle())
                .onTapGesture { shown.toggle() }
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(open ? "expanded" : "collapsed")
            if !above && open { panel }
        }
        .accessibilityElement(children: .contain)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            AtomChildren(props: props, key: "content", onEvent: onEvent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atomSurface(theme, padding: theme.density.spacing.space3)
        .atomShadow(theme.elevation.popoverElevation)
        .modifier(AlmadarSurfaceEnter(shape: "popoverEnter", timing: .popover))
    }
}

@ViewBuilder
func PopoverRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PopoverMoleculeView(props: props, onEvent: onEvent))
}
