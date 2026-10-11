import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

struct SkeletonMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        let shown = resolve()
        if let node = shown {
            node
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .opacity(dim ? 0.45 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: theme.motion.durations.dramatic).repeatForever(autoreverses: true)) { dim = true }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func resolve() -> AnyView? {
        guard let spec = props.dictValue?["spec"] else {
            return AnyView(shape(props.string("variant", default: "text"), rows: props.dictValue?["rows"]?.intValue, columns: props.dictValue?["columns"]?.intValue, fields: props.dictValue?["fields"]?.intValue))
        }
        if spec.stringValue == "none" { return nil }
        return AnyView(node(spec))
    }

    private func node(_ spec: AnyCodable) -> AnyView {
        if let variant = spec.stringValue { return AnyView(shape(variant, rows: nil, columns: nil, fields: nil)) }
        if let stack = spec.dictValue?["stack"]?.arrayValue {
            return AnyView(VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                ForEach(stack.indices, id: \.self) { index in node(stack[index]) }
            })
        }
        let inner = spec.dictValue?["shape"] ?? spec
        return AnyView(shape(inner.string("variant", default: "text"), rows: inner.dictValue?["rows"]?.intValue, columns: inner.dictValue?["columns"]?.intValue, fields: inner.dictValue?["fields"]?.intValue))
    }

    private func unit(_ count: CGFloat) -> CGFloat { theme.density.spacing.space1 * count }

    private func bar(_ width: CGFloat?, _ height: CGFloat, pill: Bool = false, interactive: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: pill ? theme.geometry.radiusPill : (interactive ? theme.geometry.radiusInteractive : theme.geometry.radiusContainer))
            .fill(theme.color.muted)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func frame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: theme.density.spacing.space0, content: content)
            .clipShape(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer))
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    @ViewBuilder
    private func shape(_ variant: String, rows: Int?, columns: Int?, fields: Int?) -> some View {
        switch variant {
        case "header":
            AtomFlowLayout(spacing: theme.density.spacing.space4) {
                VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                    bar(unit(48), unit(7))
                    bar(unit(64), unit(4))
                }
                HStack(spacing: theme.density.spacing.space2) {
                    bar(unit(24), unit(9), interactive: true)
                    bar(unit(32), unit(9), interactive: true)
                }
            }
        case "table":
            let count = max(rows ?? 5, 0)
            let cols = max(columns ?? 4, 1)
            frame {
                HStack(spacing: theme.density.spacing.space4) {
                    ForEach(0..<cols, id: \.self) { _ in bar(nil, unit(4)) }
                }
                .padding(theme.density.spacing.space3)
                .background(theme.color.tableHeader)
                ForEach(0..<count, id: \.self) { _ in
                    HStack(spacing: theme.density.spacing.space4) {
                        ForEach(0..<cols, id: \.self) { _ in bar(nil, unit(4)) }
                    }
                    .padding(theme.density.spacing.space3)
                }
            }
        case "list":
            let count = max(rows ?? 5, 0)
            frame {
                ForEach(0..<count, id: \.self) { _ in
                    HStack(spacing: theme.density.spacing.space3) {
                        Circle().fill(theme.color.muted).frame(width: unit(10), height: unit(10))
                        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                            bar(unit(32), unit(4))
                            bar(nil, unit(3))
                        }
                        bar(unit(16), unit(6), pill: true)
                    }
                    .padding(theme.density.spacing.space3)
                }
            }
        case "grid":
            AtomGridLayout(minWidth: AlmadarSizes.w64, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                ForEach(0..<max(rows ?? 6, 0), id: \.self) { _ in card }
            }
        case "stats":
            AtomGridLayout(minWidth: AlmadarSizes.w44, maxColumns: 0, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                ForEach(0..<max(columns ?? 4, 0), id: \.self) { _ in
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        bar(unit(24), unit(3))
                        bar(unit(36), unit(7))
                    }
                    .padding(theme.density.spacing.space4)
                    .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
                }
            }
        case "detail":
            VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                AtomFlowLayout(spacing: theme.density.spacing.space3) {
                    bar(unit(56), unit(8))
                    bar(unit(20), unit(6), pill: true)
                    bar(unit(24), unit(9), interactive: true)
                }
                HStack(spacing: theme.density.spacing.space4) {
                    ForEach(0..<3, id: \.self) { _ in bar(nil, unit(20)) }
                }
                AtomGridLayout(minWidth: AlmadarSizes.w48, maxColumns: 3, fixedColumns: 0, spacing: theme.density.spacing.space4) {
                    ForEach(0..<max(rows ?? 6, 0), id: \.self) { _ in
                        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                            bar(unit(16), unit(3))
                            bar(unit(32), unit(5))
                        }
                    }
                }
                lines(3)
            }
            .padding(theme.density.spacing.space6)
            .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
        case "form":
            VStack(alignment: .leading, spacing: theme.density.spacing.space6) {
                bar(unit(40), unit(6))
                ForEach(0..<max(fields ?? 4, 0), id: \.self) { _ in
                    VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                        bar(unit(24), unit(4))
                        bar(nil, unit(10), interactive: true)
                    }
                }
                HStack(spacing: theme.density.spacing.space3) {
                    Spacer(minLength: theme.density.spacing.space0)
                    bar(unit(20), unit(10), interactive: true)
                    bar(unit(24), unit(10), interactive: true)
                }
            }
            .padding(theme.density.spacing.space6)
        case "card":
            card
        default:
            lines(rows ?? 3)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space3) {
            HStack(spacing: theme.density.spacing.space3) {
                Circle().fill(theme.color.muted).frame(width: unit(10), height: unit(10))
                VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                    bar(unit(32), unit(5))
                    bar(unit(48), unit(4))
                }
            }
            bar(nil, unit(4))
            bar(unit(60), unit(4))
            HStack(spacing: theme.density.spacing.space2) {
                bar(unit(16), unit(6), pill: true)
                bar(unit(20), unit(6), pill: true)
            }
        }
        .padding(theme.density.spacing.space5)
        .overlay(RoundedRectangle(cornerRadius: theme.geometry.radiusContainer).stroke(theme.color.border, lineWidth: theme.geometry.borderStandard))
    }

    private func lines(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            ForEach(0..<max(count, 0), id: \.self) { index in
                bar(index == count - 1 ? unit(48) : nil, unit(4))
            }
        }
    }
}

@ViewBuilder
func SkeletonRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(SkeletonMoleculeView(props: props, onEvent: onEvent))
}
