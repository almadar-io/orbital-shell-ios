import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct PaginationMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var jump = ""

    private var current: Int { props.int("currentPage", default: 1) }
    private var total: Int { max(props.int("totalPages", default: 1), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            HStack(spacing: theme.density.spacing.space3) {
                if props.bool("showTotal"), let items = props.dictValue?["totalItems"]?.intValue {
                    AtomKit.typo("Total \(items)", "small", color: "muted", onEvent: onEvent)
                }
                if props.bool("showPageSize"), props.int("pageSize") > 0 { sizePicker }
            }
            ViewThatFits(in: .horizontal) {
                controls(numbered: true)
                controls(numbered: false)
            }
            if props.bool("showJumpToPage") { jumper }
        }
        .accessibilityElement(children: .contain)
    }

    private func go(_ page: Int) -> AnyCodable {
        AtomKit.child(props, [
            "variant": "secondary",
            "size": "sm",
            "action": .string(props.string("pageChangeEvent")),
            "actionPayload": ["page": .int(page)],
        ])
    }

    private func controls(numbered: Bool) -> some View {
        HStack(spacing: theme.density.spacing.space1) {
            ButtonRenderer(props: go(current - 1).merging(["icon": "chevron-left", "label": "Previous", "aria-label": "Previous", "disabled": .bool(current <= 1)]), modifier: nil, onEvent: onEvent)
            if numbered {
                ForEach(pages(), id: \.self) { page in
                    if page == 0 {
                        AtomKit.typo("…", "small", color: "muted", onEvent: onEvent)
                            .padding(.horizontal, theme.density.spacing.space2)
                    } else {
                        ButtonRenderer(props: go(page).merging(["variant": page == current ? "primary" : "ghost", "label": .string("\(page)")]), modifier: nil, onEvent: onEvent)
                    }
                }
            } else {
                AtomKit.typo("Page \(current) of \(total)", "small", color: "muted", onEvent: onEvent)
                    .padding(.horizontal, theme.density.spacing.space2)
            }
            ButtonRenderer(props: go(current + 1).merging(["rightIcon": "chevron-right", "label": "Next", "aria-label": "Next", "disabled": .bool(current >= total)]), modifier: nil, onEvent: onEvent)
        }
    }

    private func pages() -> [Int] {
        let visible = max(props.int("maxVisiblePages", default: 7), 5)
        if total <= visible { return Array(1...total) }
        let half = visible / 2
        if current <= half + 1 { return Array(1...(visible - 2)) + [0, total] }
        if current >= total - half { return [1, 0] + Array((total - visible + 3)...total) }
        return [1, 0] + Array((current - half + 2)...(current + half - 2)) + [0, total]
    }

    private var sizePicker: some View {
        let options = (props.dictValue?["pageSizeOptions"]?.arrayValue ?? [10, 20, 50, 100]).compactMap { AtomKit.scalar($0) }
        return HStack(spacing: theme.density.spacing.space2) {
            AtomKit.typo("Show", "small", color: "muted", onEvent: onEvent)
            SelectRenderer(
                props: AtomKit.child(props, ["options": .array(options.map { AnyCodable.string($0) }), "value": .string(String(props.int("pageSize"))), "action": .string(props.string("pageSizeChangeEvent"))]),
                modifier: nil,
                onEvent: { _, payload in
                    let chosen = Int(AtomKit.scalar(payload?.dictValue?["actionPayload"]?.dictValue?["value"]) ?? "") ?? props.int("pageSize")
                    let event = props.string("pageSizeChangeEvent")
                    if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["pageSize": .int(chosen)])) }
                }
            )
        }
    }

    private var jumper: some View {
        HStack(spacing: theme.density.spacing.space2) {
            AtomKit.typo("Go to", "small", color: "muted", onEvent: onEvent)
            InputRenderer(
                props: ["inputType": "number", "value": .string(jump), "placeholder": "Page", "onChange": "jump-input", "local": true],
                modifier: nil,
                onEvent: { _, payload in jump = AtomKit.scalar(payload?.dictValue?["actionPayload"]?.dictValue?["value"]) ?? "" }
            )
            .frame(width: theme.density.spacing.space12 * 2)
            ButtonRenderer(
                props: ["variant": "ghost", "size": "sm", "label": "Go", "action": "jump-go", "local": true],
                modifier: nil,
                onEvent: { _, _ in
                    guard let page = Int(jump), page >= 1, page <= total else { return }
                    let event = props.string("pageChangeEvent")
                    if !event.isEmpty { onEvent(event, eventEnvelope(props, payload: ["page": .int(page)])) }
                    jump = ""
                }
            )
        }
    }
}

@ViewBuilder
func PaginationRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(PaginationMoleculeView(props: props, onEvent: onEvent))
}
