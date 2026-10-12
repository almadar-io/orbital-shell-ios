import Combine
import Foundation
import SwiftUI

private struct AlmadarGameOverlayKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var almadarGameOverlay: Bool {
        get { self[AlmadarGameOverlayKey.self] }
        set { self[AlmadarGameOverlayKey.self] = newValue }
    }
}

struct AtomTone {
    let background: Color
    let foreground: Color
    let border: Color
    let raised: Bool
}

enum AtomKit {
    static let navigateEvent: String = "NAVIGATE"
    static let signOutEvent: String = "SIGN_OUT"
    static let localEvent: String = "local"

    static func eventOrLocal(_ event: String) -> String {
        event.isEmpty ? localEvent : event
    }

    static func clear(_ theme: AlmadarTheme) -> Color {
        theme.color.background.opacity(0)
    }

    static func noShadow(_ theme: AlmadarTheme) -> AlmadarTheme.ElevationScale.Shadow {
        AlmadarTheme.ElevationScale.Shadow(color: clear(theme), radius: 0, x: 0, y: 0)
    }

    static func cssColor(_ theme: AlmadarTheme, _ raw: String) -> Color {
        let prefix = "var(--color-"
        if raw.hasPrefix(prefix), raw.hasSuffix(")") {
            let name = String(raw.dropFirst(prefix.count).dropLast())
            switch name {
            case "primary": return theme.color.primary
            case "secondary": return theme.color.secondary
            case "accent": return theme.color.accent
            case "foreground": return theme.color.foreground
            case "muted-foreground": return theme.color.mutedForeground
            case "success": return theme.color.success
            case "warning": return theme.color.warning
            case "error": return theme.color.error
            case "info": return theme.color.info
            case "border": return theme.color.border
            default: return theme.color.primary
            }
        }
        if raw.hasPrefix("#") || raw.hasPrefix("rgb") || raw.hasPrefix("hsl") {
            return AlmadarThemeParse.color(raw, fallback: theme.color.primary)
        }
        return tone(theme, raw)
    }

    static func length(_ raw: String) -> CGFloat? {
        raw.isEmpty ? nil : AlmadarThemeParse.length(raw, fallback: .infinity)
    }

    static func entry(_ theme: AlmadarTheme, _ key: String) -> AlmadarTheme.TypeScale.Entry {
        let scale = theme.typeScale.scale
        switch key {
        case "xs": return scale.xs
        case "sm": return scale.sm
        case "lg": return scale.lg
        case "xl": return scale.xl
        case "2xl": return scale.xl2
        case "3xl": return scale.xl3
        case "4xl": return scale.xl4
        default: return scale.base
        }
    }

    static func weight(_ token: String) -> Font.Weight? {
        switch token {
        case "light", "normal": return .regular
        case "medium": return .medium
        case "semibold", "bold": return .bold
        default: return nil
        }
    }

    static func font(_ theme: AlmadarTheme, _ key: String, _ weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        let family = AlmadarThemeParse.fontFamilyName(mono ? theme.typeScale.monoFamily : theme.typeScale.bodyFamily)
        let sizeKey = key == "md" ? "base" : key
        return AlmadarThemeParse.scaledFont(family: family, sizeKey: sizeKey, size: entry(theme, sizeKey).size, weight: weight)
    }

    static func space(_ theme: AlmadarTheme, _ token: String) -> CGFloat {
        let spacing = theme.density.spacing
        switch token {
        case "none": return spacing.space0
        case "xs": return spacing.space1
        case "sm": return spacing.space2
        case "lg": return spacing.space6
        case "xl": return spacing.space8
        case "2xl": return spacing.space12
        default: return spacing.space4
        }
    }

    static func iconSize(_ theme: AlmadarTheme, _ token: String) -> CGFloat {
        let spacing = theme.density.spacing
        switch token {
        case "xs": return spacing.space3
        case "sm": return spacing.space4
        case "lg": return spacing.space6
        case "xl": return spacing.space8
        default: return theme.iconography.defaultSize + spacing.space1
        }
    }

    static func radius(_ theme: AlmadarTheme, _ token: String) -> CGFloat {
        switch token {
        case "sm": return theme.geometry.radiusInteractive / 2
        case "md": return theme.geometry.radiusInteractive
        case "lg", "xl", "2xl": return theme.geometry.radiusContainer
        case "full": return theme.geometry.radiusPill
        default: return theme.density.spacing.space0
        }
    }

    static func tone(_ theme: AlmadarTheme, _ token: String) -> Color {
        switch token {
        case "primary": return theme.color.primary
        case "secondary": return theme.color.secondaryForeground
        case "accent": return theme.color.accent
        case "success": return theme.color.success
        case "warning": return theme.color.warning
        case "error", "danger", "critical": return theme.color.error
        case "info": return theme.color.info
        case "muted", "neutral": return theme.color.mutedForeground
        case "inverse": return theme.color.background
        default: return theme.color.foreground
        }
    }

    static func typographyColor(_ theme: AlmadarTheme, _ token: String) -> Color? {
        switch token {
        case "secondary", "muted": return theme.color.mutedForeground
        case "error": return theme.color.error
        case "success": return theme.color.success
        case "warning": return theme.color.warning
        case "inherit": return nil
        default: return theme.color.foreground
        }
    }

    static func statusColor(_ theme: AlmadarTheme, _ status: String) -> Color {
        switch status {
        case "online", "active", "success": return theme.color.success
        case "away", "warning", "pending": return theme.color.warning
        case "busy", "error", "critical": return theme.color.error
        default: return theme.color.mutedForeground
        }
    }

    static func buttonTone(_ theme: AlmadarTheme, _ variant: String, pressed: Bool) -> AtomTone {
        let none = clear(theme)
        switch variant {
        case "secondary":
            return AtomTone(background: pressed ? theme.color.accent : none, foreground: pressed ? theme.color.accentForeground : theme.color.foreground, border: theme.color.accent, raised: false)
        case "ghost":
            return AtomTone(background: pressed ? theme.color.primary : none, foreground: pressed ? theme.color.primaryForeground : theme.color.mutedForeground, border: pressed ? theme.color.primary : none, raised: false)
        case "danger", "destructive":
            return AtomTone(background: pressed ? theme.color.error : theme.color.surface, foreground: pressed ? theme.color.errorForeground : theme.color.foreground, border: theme.color.error, raised: true)
        case "success":
            return AtomTone(background: pressed ? theme.color.success : theme.color.surface, foreground: pressed ? theme.color.successForeground : theme.color.foreground, border: theme.color.success, raised: true)
        case "warning":
            return AtomTone(background: pressed ? theme.color.warning : theme.color.surface, foreground: pressed ? theme.color.warningForeground : theme.color.foreground, border: theme.color.warning, raised: true)
        case "default":
            return AtomTone(background: pressed ? theme.color.secondaryHover : theme.color.secondary, foreground: theme.color.secondaryForeground, border: theme.color.border, raised: false)
        case "link":
            return AtomTone(background: none, foreground: pressed ? theme.color.foreground : theme.color.mutedForeground, border: none, raised: false)
        default:
            return AtomTone(background: pressed ? theme.color.primaryHover : theme.color.primary, foreground: theme.color.primaryForeground, border: pressed ? theme.color.primaryHover : theme.color.primary, raised: true)
        }
    }

    static func scalar(_ value: AnyCodable?) -> String? {
        guard let value = value else { return nil }
        switch value {
        case .string(let text): return text
        case .int(let number): return String(number)
        case .double(let number):
            if number.isFinite && number == number.rounded() && abs(number) < 1e15 { return String(Int(number)) }
            return String(number)
        case .bool(let flag): return flag ? "true" : "false"
        default: return nil
        }
    }

    static func nodes(_ props: AnyCodable, _ key: String) -> [AnyCodable] {
        guard let raw = props.dictValue?[key] else { return [] }
        if let list = raw.arrayValue { return list }
        if raw.stringValue != nil || raw.dictValue != nil { return [raw] }
        return []
    }

    static func text(_ props: AnyCodable, _ key: String) -> String {
        scalar(props.dictValue?[key]) ?? ""
    }

    static func assetURL(_ props: AnyCodable, _ key: String) -> String {
        guard let value = props.dictValue?[key] else { return "" }
        if let direct = value.stringValue { return direct }
        return value.dictValue?["url"]?.stringValue ?? ""
    }

    static func strings(_ props: AnyCodable, _ key: String) -> [String] {
        (props.dictValue?[key]?.arrayValue ?? []).compactMap { scalar($0) }
    }

    static func options(_ list: [AnyCodable]) -> [(value: String, label: String)] {
        list.compactMap { item in
            if let dict = item.dictValue {
                let label = scalar(dict["label"]) ?? scalar(dict["value"]) ?? ""
                return (value: scalar(dict["value"]) ?? label, label: label)
            }
            guard let plain = scalar(item) else { return nil }
            return (value: plain, label: plain)
        }
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == " " }).map(String.init)
        guard let first = parts.first else { return "" }
        if parts.count == 1 { return String(first.prefix(2)).uppercased() }
        return (String(first.prefix(1)) + String((parts.last ?? "").prefix(1))).uppercased()
    }

    static func busId(_ eventKey: String, _ props: AnyCodable) -> String {
        if eventKey.isEmpty || props.bool("local") { return "" }
        return VerificationIds.action(eventKey)
    }

    /// The id of an element whose `gesture` dispatches `eventKey` (`VerificationIds.longPress` / `swipeLeft` / `swipeRight`).
    static func gestureId(_ eventKey: String, _ props: AnyCodable, _ gesture: (String) -> String) -> String {
        if eventKey.isEmpty || props.bool("local") { return "" }
        return gesture(eventKey)
    }

    static func controlId(name: String, event: String, props: AnyCodable) -> String {
        if props.bool("local") { return "" }
        if !name.isEmpty { return VerificationIds.field(name) }
        return busId(event, props)
    }

    static func formatted(_ raw: String, format: String) -> String {
        guard !format.isEmpty, format != "none" else { return raw }
        switch format {
        case "number", "currency", "percent":
            guard let number = Double(raw) else { return raw }
            let formatter = NumberFormatter()
            if format == "currency" {
                formatter.numberStyle = .currency
                formatter.currencyCode = "USD"
            } else if format == "percent" {
                formatter.numberStyle = .percent
                formatter.maximumFractionDigits = 0
                return formatter.string(from: NSNumber(value: number / 100)) ?? raw
            } else {
                formatter.numberStyle = .decimal
            }
            return formatter.string(from: NSNumber(value: number)) ?? raw
        case "date", "time", "datetime":
            let parsed = ISO8601DateFormatter()
            parsed.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            let day = DateFormatter()
            day.dateFormat = "yyyy-MM-dd"
            guard let date = parsed.date(from: raw) ?? plain.date(from: raw) ?? day.date(from: raw) else { return raw }
            let output = DateFormatter()
            output.dateStyle = format == "time" ? .none : .medium
            output.timeStyle = format == "date" ? .none : .short
            return output.string(from: date)
        default:
            return raw
        }
    }
}

extension View {
    @ViewBuilder
    func gestureContainer(_ id: String) -> some View {
        if id.isEmpty { self } else { self.verificationContainer(id) }
    }

    @ViewBuilder
    func atomId(_ id: String) -> some View {
        if id.isEmpty { self } else { self.verificationId(id) }
    }

    @ViewBuilder
    func atomAction(_ eventKey: String, _ props: AnyCodable) -> some View {
        self.atomId(AtomKit.busId(eventKey, props))
    }

    func atomShadow(_ shadow: AlmadarTheme.ElevationScale.Shadow) -> some View {
        ([shadow] + shadow.underlays).reduce(AnyView(self)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }

    func atomFieldBox(_ theme: AlmadarTheme, error: Bool, disabled: Bool, elevated: Bool = false) -> some View {
        self
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .frame(minHeight: theme.density.inputHeightMd)
            .background(disabled ? theme.color.muted : theme.color.card)
            .atomClip(theme, .interactive)
            .atomBorder(theme, .interactive, color: error ? theme.color.error : theme.color.border, width: theme.geometry.borderStandard)
            .atomElevation(theme, .interactive, elevated ? theme.elevation.interactiveElevation : AtomKit.noShadow(theme))
            .opacity(disabled ? 0.5 : 1)
    }
}

enum AtomRole {
    case container, pill, interactive
}

struct AtomShape: InsettableShape {
    let corner: AlmadarTheme.CornerShape
    let radius: CGFloat
    var insetAmount: CGFloat = 0

    private static let arcKappa: CGFloat = (4.0 / 3.0) * (2.0.squareRoot() - 1.0)
    private static let cornerSteps: Int = 24

    func inset(by amount: CGFloat) -> AtomShape {
        AtomShape(corner: corner, radius: radius, insetAmount: insetAmount + amount)
    }

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let r = max(min(radius - insetAmount, min(box.width, box.height) / 2), 0)
        if r <= 0 { return Path(box) }
        switch corner {
        case .round: return RoundedRectangle(cornerRadius: r, style: .circular).path(in: box)
        case .squircle: return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: box)
        default: break
        }
        var path = Path()
        path.move(to: CGPoint(x: box.minX + r, y: box.minY))
        addCorner(&path, c: CGPoint(x: box.maxX, y: box.minY), a: CGPoint(x: box.maxX - r, y: box.minY), b: CGPoint(x: box.maxX, y: box.minY + r))
        addCorner(&path, c: CGPoint(x: box.maxX, y: box.maxY), a: CGPoint(x: box.maxX, y: box.maxY - r), b: CGPoint(x: box.maxX - r, y: box.maxY))
        addCorner(&path, c: CGPoint(x: box.minX, y: box.maxY), a: CGPoint(x: box.minX + r, y: box.maxY), b: CGPoint(x: box.minX, y: box.maxY - r))
        addCorner(&path, c: CGPoint(x: box.minX, y: box.minY), a: CGPoint(x: box.minX, y: box.minY + r), b: CGPoint(x: box.minX + r, y: box.minY))
        path.closeSubpath()
        return path
    }

    private func addCorner(_ path: inout Path, c: CGPoint, a: CGPoint, b: CGPoint) {
        path.addLine(to: a)
        let q = CGPoint(x: a.x + b.x - c.x, y: a.y + b.y - c.y)
        switch corner {
        case .round, .squircle, .bevel:
            path.addLine(to: b)
        case .notch:
            path.addLine(to: q)
            path.addLine(to: b)
        case .scoop:
            let k = AtomShape.arcKappa
            path.addCurve(
                to: b,
                control1: CGPoint(x: a.x + k * (b.x - c.x), y: a.y + k * (b.y - c.y)),
                control2: CGPoint(x: b.x + k * (a.x - c.x), y: b.y + k * (a.y - c.y))
            )
        case .superellipse(let exponent):
            let power = 2.0 / pow(2.0, exponent)
            for step in 1...AtomShape.cornerSteps {
                let t = Double(step) / Double(AtomShape.cornerSteps) * Double.pi / 2
                let u = CGFloat(pow(max(cos(t), 0), power))
                let v = CGFloat(pow(max(sin(t), 0), power))
                path.addLine(to: CGPoint(x: q.x + (a.x - q.x) * u + (b.x - q.x) * v, y: q.y + (a.y - q.y) * u + (b.y - q.y) * v))
            }
        }
    }
}

extension AtomKit {
    static func corner(_ theme: AlmadarTheme, _ role: AtomRole) -> AlmadarTheme.CornerShape {
        switch role {
        case .container: return theme.geometry.cornerShape
        case .pill: return theme.geometry.cornerShapePill
        case .interactive: return theme.geometry.cornerShapeInteractive
        }
    }

    static func roleRadius(_ theme: AlmadarTheme, _ role: AtomRole) -> CGFloat {
        switch role {
        case .container: return theme.geometry.radiusContainer
        case .pill: return theme.geometry.radiusPill
        case .interactive: return theme.geometry.radiusInteractive
        }
    }

    static func borderStyle(_ theme: AlmadarTheme, _ role: AtomRole) -> AlmadarTheme.BorderLineStyle {
        role == .interactive ? theme.geometry.borderStyleInteractive : theme.geometry.borderStyle
    }

    static func shape(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil) -> AtomShape {
        AtomShape(corner: corner(theme, role), radius: radius ?? roleRadius(theme, role))
    }

    /// CSS backdrop blur radius (pt) to the nearest system Material: <= 6 ultraThin, <= 16 thin, <= 24 regular, else thick.
    static let backdropBuckets: [(upTo: CGFloat, material: Material)] = [(6, .ultraThinMaterial), (16, .thinMaterial), (24, .regularMaterial)]

    static func backdropMaterial(_ radius: CGFloat) -> Material {
        backdropBuckets.first(where: { radius <= $0.upTo })?.material ?? .thickMaterial
    }

    static func headingFont(_ theme: AlmadarTheme, _ key: String, _ weight: Font.Weight) -> Font {
        let family = AlmadarThemeParse.fontFamilyName(theme.typeScale.displayFamily)
        return AlmadarThemeParse.scaledFont(family: family, sizeKey: key, size: entry(theme, key).size, weight: weight)
    }

    static func headingText(_ theme: AlmadarTheme, _ raw: String, _ key: String, weight: Font.Weight? = nil) -> Text {
        let voice = theme.typeScale.heading
        let shown: String
        switch voice.transform {
        case .none: shown = raw
        case .uppercase: shown = raw.uppercased()
        case .lowercase: shown = raw.lowercased()
        case .capitalize: shown = raw.capitalized
        }
        let size = entry(theme, key).size
        let text = Text(shown)
            .font(headingFont(theme, key, weight ?? voice.weight))
            .tracking(voice.tracking.isEm ? voice.tracking.value * size : voice.tracking.value)
        return voice.style == .normal ? text : text.italic()
    }
}

struct AtomBorder: View {
    let shape: AtomShape
    let theme: AlmadarTheme
    let color: Color
    let width: CGFloat
    let style: AlmadarTheme.BorderLineStyle

    var body: some View {
        switch style {
        case .none, .hidden:
            EmptyView()
        case .solid:
            shape.strokeBorder(color, lineWidth: width)
        case .dashed:
            shape.strokeBorder(color, style: StrokeStyle(lineWidth: width, dash: [width * 3, width * 2]))
        case .dotted:
            shape.strokeBorder(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [0, width * 2]))
        case .double:
            ZStack {
                shape.strokeBorder(color, lineWidth: width / 3)
                shape.inset(by: width * 2 / 3).strokeBorder(color, lineWidth: width / 3)
            }
        case .groove:
            ZStack {
                shape.strokeBorder(color, lineWidth: width / 2)
                shape.inset(by: width / 2).strokeBorder(theme.color.background, lineWidth: width / 2)
            }
        case .ridge:
            ZStack {
                shape.strokeBorder(theme.color.background, lineWidth: width / 2)
                shape.inset(by: width / 2).strokeBorder(color, lineWidth: width / 2)
            }
        case .inset:
            shape.strokeBorder(split(color, theme.color.background), lineWidth: width)
        case .outset:
            shape.strokeBorder(split(theme.color.background, color), lineWidth: width)
        }
    }

    private func split(_ first: Color, _ second: Color) -> LinearGradient {
        LinearGradient(
            stops: [
                Gradient.Stop(color: first, location: 0),
                Gradient.Stop(color: first, location: 0.5),
                Gradient.Stop(color: second, location: 0.5),
                Gradient.Stop(color: second, location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AtomShadowLayers: View {
    let theme: AlmadarTheme
    let shape: AtomShape
    let shadow: AlmadarTheme.ElevationScale.Shadow

    var body: some View {
        let layers = [shadow] + shadow.underlays
        ZStack {
            ForEach(layers.indices, id: \.self) { index in
                layer(layers[index])
            }
        }
    }

    @ViewBuilder
    private func layer(_ s: AlmadarTheme.ElevationScale.Shadow) -> some View {
        let bleed = s.radius * 3 + abs(s.spread) + abs(s.x) + abs(s.y)
        if s.inset {
            Rectangle().fill(s.color)
                .atomReverseMask(bleed: bleed) { shape.inset(by: s.spread).offset(x: s.x, y: s.y).fill(theme.color.foreground) }
                .blur(radius: s.radius)
                .clipShape(shape)
        } else {
            shape.inset(by: -s.spread).fill(s.color)
                .offset(x: s.x, y: s.y)
                .blur(radius: s.radius)
                .atomReverseMask(bleed: bleed) { shape.fill(theme.color.foreground) }
        }
    }
}

extension View {
    func atomReverseMask<Cut: View>(bleed: CGFloat, @ViewBuilder _ cut: () -> Cut) -> some View {
        self.mask(
            Rectangle()
                .padding(-bleed)
                .overlay(cut().blendMode(.destinationOut))
                .compositingGroup()
        )
    }

    func atomClip(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil) -> some View {
        self.clipShape(AtomKit.shape(theme, role, radius: radius))
    }

    @ViewBuilder
    func atomBackdrop(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil) -> some View {
        if let backdrop = theme.surface.backdrop {
            self.background(AtomKit.backdropMaterial(backdrop.blurRadius), in: AtomKit.shape(theme, role, radius: radius))
        } else {
            self
        }
    }

    /// `surface.cardImage` between the fill behind it and the content: applied just before the card fill, because a later `.background` lies behind an earlier one.
    @ViewBuilder
    func atomSurfaceImage(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil) -> some View {
        let layers = AtomKit.cardImageLayers(theme)
        if layers.isEmpty {
            self
        } else {
            self.background(SurfaceImageLayers(layers: layers).clipShape(AtomKit.shape(theme, role, radius: radius)))
        }
    }

    func atomBorder(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil, color: Color, width: CGFloat, style: AlmadarTheme.BorderLineStyle? = nil) -> some View {
        self.overlay(AtomBorder(shape: AtomKit.shape(theme, role, radius: radius), theme: theme, color: color, width: width, style: style ?? AtomKit.borderStyle(theme, role)))
    }

    func atomElevation(_ theme: AlmadarTheme, _ role: AtomRole, radius: CGFloat? = nil, _ shadow: AlmadarTheme.ElevationScale.Shadow) -> some View {
        self.background(AtomShadowLayers(theme: theme, shape: AtomKit.shape(theme, role, radius: radius), shadow: shadow))
    }

    func atomTextShadow(_ shadow: AlmadarTheme.ElevationScale.Shadow?) -> some View {
        let layers = shadow.map { [$0] + $0.underlays } ?? []
        return layers.reduce(AnyView(self)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }
}

struct AtomChildren: View {
    let props: AnyCodable
    let key: String
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        let children = AtomKit.nodes(props, key)
        ForEach(children.indices, id: \.self) { index in
            RenderChild(children[index], onEvent: onEvent)
        }
    }
}

struct AtomButtonStyle: ButtonStyle {
    let theme: AlmadarTheme
    let variant: String
    let size: String
    @Environment(\.atomButtonTint) private var tint

    func makeBody(configuration: Configuration) -> some View {
        let tone = AtomKit.buttonTone(theme, variant, pressed: configuration.isPressed)
        let link = variant == "link"
        let horizontal: CGFloat = size == "sm" ? theme.density.spacing.space3 : (size == "lg" ? theme.density.spacing.space6 : theme.density.spacing.space4)
        let height: CGFloat = size == "sm" ? theme.density.buttonHeightSm : (size == "lg" ? theme.density.buttonHeightLg : theme.density.buttonHeightMd)
        let shadow = tone.raised ? (configuration.isPressed ? theme.elevation.pressedElevation : theme.elevation.interactiveElevation) : AtomKit.noShadow(theme)
        configuration.label
            .font(AtomKit.font(theme, size == "lg" ? "base" : "sm", .medium))
            .foregroundColor(tint ?? tone.foreground)
            .padding(.horizontal, link ? theme.density.spacing.space0 : horizontal)
            .frame(minHeight: link ? nil : height)
            .background(tone.background)
            .atomClip(theme, .interactive)
            .atomBorder(theme, .interactive, color: tone.border, width: theme.geometry.borderStandard)
            .atomElevation(theme, .interactive, shadow)
            .underline(link && configuration.isPressed)
            .contentShape(AtomKit.shape(theme, .interactive))
    }
}

struct AtomFieldFrame<Content: View>: View {
    let theme: AlmadarTheme
    let label: String
    let helper: String
    let error: String
    let isRequired: Bool
    let content: Content

    init(theme: AlmadarTheme, label: String, helper: String, error: String, isRequired: Bool, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.label = label
        self.helper = helper
        self.error = error
        self.isRequired = isRequired
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            if !label.isEmpty {
                HStack(spacing: theme.density.spacing.space1) {
                    Text(label).font(AtomKit.font(theme, "sm", .medium)).foregroundColor(theme.color.foreground)
                    if isRequired { Text("*").foregroundColor(theme.color.error).accessibilityHidden(true) }
                }
            }
            content
            if !error.isEmpty {
                Text(error).font(AtomKit.font(theme, "xs")).foregroundColor(theme.color.error)
            } else if !helper.isEmpty {
                Text(helper).font(AtomKit.font(theme, "xs")).foregroundColor(theme.color.mutedForeground)
            }
        }
    }
}

struct AtomTextEntry: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    let multiline: Bool
    let changeEvent: String
    let submitEvent: String
    @Environment(\.almadarTheme) private var theme
    @Environment(\.almadarFieldFocusToken) private var focusToken
    @State private var text: String
    @State private var echoes: Set<String> = []
    @FocusState private var focused: Bool

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void, multiline: Bool, changeEvent: String, submitEvent: String) {
        self.props = props
        self.onEvent = onEvent
        self.multiline = multiline
        self.changeEvent = changeEvent
        self.submitEvent = submitEvent
        _text = State(initialValue: AtomKit.text(props, "value"))
    }

    var body: some View {
        let incoming = AtomKit.text(props, "value")
        let inputType = props.string("inputType", default: "text")
        let name = props.string("name")
        let clearEvent = props.string("onClear")
        let error = props.string("error")
        let disabled = props.bool("disabled")
        let leading = props.string("leftIcon", default: props.string("icon"))
        let trailing = props.string("rightIcon")
        let prompt = props.string("placeholder")
        let rows = props.int("rows", default: 3)
        let binding = Binding<String>(
            get: { text },
            set: { newValue in
                text = newValue
                echoes.insert(newValue)
                if !changeEvent.isEmpty {
                    onEvent(changeEvent, eventEnvelope(props, payload: ["value": .string(newValue)]))
                }
            }
        )
        AtomFieldFrame(theme: theme, label: props.string("label"), helper: props.string("helperText"), error: error, isRequired: props.bool("required")) {
            HStack(spacing: theme.density.spacing.space2) {
                if !leading.isEmpty {
                    Image(systemName: IconMap.resolve(leading)).foregroundColor(theme.color.mutedForeground)
                }
                entry(binding: binding, prompt: prompt, rows: rows, inputType: inputType)
                    .focused($focused)
                    .foregroundColor(theme.color.foreground)
                    .disabled(disabled)
                if props.bool("clearable") && !text.isEmpty {
                    Button(action: {
                        binding.wrappedValue = ""
                        if !clearEvent.isEmpty { onEvent(clearEvent, eventEnvelope(props)) }
                    }) {
                        Image(systemName: IconMap.resolve("x-circle")).foregroundColor(theme.color.mutedForeground)
                    }
                    .accessibilityLabel(Text("Clear"))
                } else if !trailing.isEmpty {
                    Image(systemName: IconMap.resolve(trailing)).foregroundColor(theme.color.mutedForeground)
                }
            }
            .atomFieldBox(theme, error: !error.isEmpty, disabled: disabled, elevated: multiline)
        }
        .atomId(AtomKit.controlId(name: name, event: changeEvent.isEmpty ? submitEvent : changeEvent, props: props))
        .onChange(of: focusToken) { token in if token != nil { focused = true } }
        .onAppear { if focusToken != nil { focused = true } }
        .onChange(of: incoming) { value in
            if echoes.contains(value) {
                echoes.remove(value)
                return
            }
            echoes.removeAll()
            text = value
        }
    }

    @ViewBuilder
    private func entry(binding: Binding<String>, prompt: String, rows: Int, inputType: String) -> some View {
        if multiline {
            TextField(prompt, text: binding, axis: .vertical)
                .lineLimit(rows...)
                .onSubmit { submit(inputType: inputType) }
        } else if inputType == "password" {
            SecureField(prompt, text: binding)
                .onSubmit { submit(inputType: inputType) }
        } else {
            TextField(prompt, text: binding)
                .keyboardType(keyboard(inputType))
                .textInputAutocapitalization(inputType == "text" || inputType == "search" ? .sentences : .never)
                .autocorrectionDisabled(inputType != "text" && inputType != "search")
                .submitLabel(inputType == "search" ? .search : .done)
                .onSubmit { submit(inputType: inputType) }
        }
    }

    private func keyboard(_ inputType: String) -> UIKeyboardType {
        switch inputType {
        case "email": return .emailAddress
        case "number": return .decimalPad
        case "tel": return .phonePad
        case "url": return .URL
        default: return .default
        }
    }

    private func submit(inputType: String) {
        guard !submitEvent.isEmpty else { return }
        if inputType == "number" {
            guard let number = Double(text.trimmingCharacters(in: .whitespaces)), number.isFinite else { return }
            onEvent(submitEvent, eventEnvelope(props, payload: ["value": .double(number)]))
            return
        }
        onEvent(submitEvent, eventEnvelope(props, payload: ["value": .string(text)]))
    }
}

extension AtomKit {
    static func child(_ owner: AnyCodable, _ values: [String: AnyCodable]) -> AnyCodable {
        var merged = values
        if let trait = owner.dictValue?["sourceTrait"] { merged["sourceTrait"] = trait }
        return .dict(merged)
    }

    static func normalizedField(_ raw: AnyCodable) -> AnyCodable? {
        if let name = raw.stringValue { return name.isEmpty ? nil : .dict(["name": .string(name)]) }
        guard var dict = raw.dictValue else { return nil }
        let name = scalar(dict["name"]) ?? scalar(dict["field"]) ?? scalar(dict["key"]) ?? ""
        if name.isEmpty { return nil }
        dict["name"] = .string(name)
        if dict["label"] == nil, let header = dict["header"] { dict["label"] = header }
        return .dict(dict)
    }

    static func fieldDefs(_ props: AnyCodable, _ keys: [String]) -> [AnyCodable] {
        for key in keys {
            if let list = props.dictValue?[key]?.arrayValue { return list.compactMap { normalizedField($0) } }
        }
        return []
    }

    static func rows(_ props: AnyCodable, _ key: String = "entity") -> [AnyCodable] {
        guard let raw = props.dictValue?[key] else { return [] }
        if let list = raw.arrayValue { return list }
        if raw.dictValue != nil { return [raw] }
        return []
    }

    static func cell(_ row: AnyCodable, _ path: String) -> AnyCodable? {
        var current: AnyCodable? = row
        for part in path.split(separator: ".") {
            current = current?.dictValue?[String(part)]
        }
        if case .some(.null) = current { return nil }
        return current
    }

    static func blank(_ value: AnyCodable?) -> Bool {
        guard let value = value else { return true }
        if case .null = value { return true }
        if let text = value.stringValue { return text.isEmpty }
        return false
    }

    static func relationLabel(_ value: AnyCodable?, _ options: [AnyCodable]) -> String? {
        guard !options.isEmpty, let value = value else { return nil }
        let ids = value.arrayValue ?? [value]
        let labels = ids.compactMap { id -> String? in
            guard let key = scalar(id) else { return nil }
            return options.first(where: { scalar($0.dictValue?["value"]) == key }).flatMap { scalar($0.dictValue?["label"]) }
        }
        return labels.isEmpty ? nil : labels.joined(separator: ", ")
    }

    static func display(_ value: AnyCodable?, format: String, options: [AnyCodable] = []) -> String {
        if let related = relationLabel(value, options) { return related }
        guard let value = value else { return "" }
        if case .bool(let flag) = value { return flag ? "Yes" : "No" }
        if format == "boolean", let flag = value.boolValue { return flag ? "Yes" : "No" }
        if let list = value.arrayValue { return list.compactMap { scalar($0) }.joined(separator: ", ") }
        return formatted(scalar(value) ?? "", format: format)
    }

    static func fieldText(_ row: AnyCodable, _ field: AnyCodable, relations: AnyCodable? = nil) -> String {
        let name = field.string("name")
        let options = relations?.dictValue?[name]?.arrayValue ?? []
        return display(cell(row, name), format: field.string("format"), options: options)
    }

    static func labelled(_ text: String, _ field: AnyCodable) -> String {
        field.dictValue?["labels"]?.dictValue?[text]?.stringValue ?? text
    }

    static func badgeVariant(_ field: AnyCodable, _ raw: String) -> String {
        let declared = field.dictValue?["colorMap"]?.dictValue?[raw]?.stringValue ?? ""
        switch declared {
        case "": return "default"
        case "destructive": return "danger"
        default: return declared
        }
    }

    static func rowKey(_ row: AnyCodable, _ index: Int) -> String {
        guard let id = scalar(row.dictValue?["id"]), !id.isEmpty else { return String(index) }
        return id
    }

    static func rowPayload(_ row: AnyCodable) -> AnyCodable {
        var payload: [String: AnyCodable] = ["row": row]
        if let id = row.dictValue?["id"] { payload["id"] = id }
        return .dict(payload)
    }

    static func sortedRows(_ rows: [AnyCodable], by field: String, descending: Bool) -> [AnyCodable] {
        if field.isEmpty { return rows }
        func order(_ left: AnyCodable?, _ right: AnyCodable?) -> Bool {
            let leftText = left.flatMap { scalar($0) } ?? ""
            let rightText = right.flatMap { scalar($0) } ?? ""
            if leftText.isEmpty || rightText.isEmpty { return !leftText.isEmpty && rightText.isEmpty }
            if let leftNumber = Double(leftText), let rightNumber = Double(rightText) {
                return descending ? leftNumber > rightNumber : leftNumber < rightNumber
            }
            let result = leftText.localizedStandardCompare(rightText)
            return descending ? result == .orderedDescending : result == .orderedAscending
        }
        return rows.enumerated().sorted { first, second in
            let a = cell(first.element, field)
            let b = cell(second.element, field)
            if order(a, b) { return true }
            if order(b, a) { return false }
            return first.offset < second.offset
        }.map { $0.element }
    }

    static func grouped(_ rows: [AnyCodable], by field: String, format: String) -> [(label: String, rows: [AnyCodable])] {
        if field.isEmpty { return [(label: "", rows: rows)] }
        var order: [String] = []
        var buckets: [String: [AnyCodable]] = [:]
        for row in rows {
            let key = display(cell(row, field), format: format)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }
        return order.map { (label: $0, rows: buckets[$0] ?? []) }
    }

    static func errorText(_ props: AnyCodable) -> String {
        guard let raw = props.dictValue?["error"] else { return "" }
        if case .null = raw { return "" }
        if let text = raw.stringValue { return text }
        return scalar(raw.dictValue?["message"]) ?? ""
    }

    static func emptyProps(_ owner: AnyCodable, fallback: String) -> AnyCodable {
        var values: [String: AnyCodable] = [:]
        if let icon = owner.dictValue?["emptyIcon"] { values["icon"] = icon }
        let title = owner.string("emptyTitle", default: owner.string("emptyMessage", default: fallback))
        values["title"] = .string(title)
        if let description = owner.dictValue?["emptyDescription"] { values["description"] = description }
        if let action = owner.dictValue?["emptyAction"]?.dictValue {
            if let label = action["label"] { values["actionLabel"] = label }
            if let event = action["event"] { values["actionEvent"] = event }
        }
        return child(owner, values)
    }

    static func skeletonProps(_ owner: AnyCodable, fallback: String) -> AnyCodable {
        child(owner, ["spec": owner.dictValue?["skeleton"] ?? .string(fallback)])
    }

    static func navigate(_ item: AnyCodable) -> (event: String, payload: AnyCodable?, href: String) {
        let event = item.string("event", default: item.string("action"))
        if !event.isEmpty { return (event, nil, "") }
        let href = item.string("href", default: item.string("path"))
        if href.isEmpty { return ("", nil, "") }
        if href.contains("://") || href.hasPrefix("mailto:") || href.hasPrefix("tel:") { return ("", nil, href) }
        return (navigateEvent, .dict(["href": .string(href), "url": .string(href)]), "")
    }

    static func isAbsoluteHref(_ href: String) -> Bool {
        href.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil
    }

    static func actionable(_ action: AnyCodable) -> Bool {
        !action.string("event").isEmpty || !action.string("navigatesTo").isEmpty
    }

    static func expand(_ template: String, row: AnyCodable?) -> String {
        guard let row = row, let pattern = try? NSRegularExpression(pattern: "\\{\\{(?:row\\.)?([\\w.]+)\\}\\}") else { return template }
        var result = template
        let matches = pattern.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed()
        for match in matches {
            guard let whole = Range(match.range, in: template), let path = Range(match.range(at: 1), in: template) else { continue }
            let value = scalar(cell(row, String(template[path]))) ?? ""
            result.replaceSubrange(whole, with: value)
        }
        return result
    }

    static func route(_ action: AnyCodable, row: AnyCodable?) -> (event: String, payload: AnyCodable?) {
        let target = action.string("navigatesTo")
        if !target.isEmpty {
            var payload: [String: AnyCodable] = ["url": .string(expand(target, row: row))]
            if let row = row { payload["row"] = row }
            return (navigateEvent, .dict(payload))
        }
        return (action.string("event"), row.map { rowPayload($0) })
    }

    static func actionProps(_ owner: AnyCodable, _ action: AnyCodable, row: AnyCodable?, size: String, fallback: String, iconOnly: Bool = false) -> AnyCodable {
        let routed = route(action, row: row)
        var values: [String: AnyCodable] = [
            "variant": .string(action.string("variant", default: fallback)),
            "size": .string(size),
            "action": .string(routed.event),
        ]
        let label = action.string("label")
        let icon = action.string("icon")
        if iconOnly && !icon.isEmpty {
            values["icon"] = .string(icon)
            values["aria-label"] = .string(label)
        } else {
            values["label"] = .string(label)
            if !icon.isEmpty { values["leftIcon"] = .string(icon) }
        }
        if let payload = routed.payload { values["actionPayload"] = payload }
        return child(owner, values)
    }
}

extension AtomKit {
    static func typo(_ text: String, _ variant: String = "body1", color: String = "primary", weight: String = "", align: String = "", truncate: Bool = false, onEvent: @escaping (String, AnyCodable?) -> Void) -> AnyView {
        var values: [String: AnyCodable] = ["content": .string(text), "variant": .string(variant), "color": .string(color)]
        if !weight.isEmpty { values["weight"] = .string(weight) }
        if !align.isEmpty { values["align"] = .string(align) }
        if truncate { values["truncate"] = .bool(true) }
        return TypographyRenderer(props: .dict(values), modifier: nil, onEvent: onEvent)
    }

    static func icon(_ name: String, _ size: String = "md", color: String = "", label: String = "", animation: String = "", onEvent: @escaping (String, AnyCodable?) -> Void) -> AnyView {
        var values: [String: AnyCodable] = ["icon": .string(name), "size": .string(size)]
        if !animation.isEmpty { values["animation"] = .string(animation) }
        if !color.isEmpty { values["color"] = .string(color) }
        if !label.isEmpty { values["aria-label"] = .string(label) }
        return IconRenderer(props: .dict(values), modifier: nil, onEvent: onEvent)
    }

    static func badge(_ text: String, _ variant: String = "default", size: String = "sm", onEvent: @escaping (String, AnyCodable?) -> Void) -> AnyView {
        BadgeRenderer(props: ["label": .string(text), "variant": .string(variant), "size": .string(size)], modifier: nil, onEvent: onEvent)
    }
}

struct AtomFieldBadges: View {
    let row: AnyCodable
    let fields: [AnyCodable]
    let relations: AnyCodable?
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        HStack(spacing: theme.density.spacing.space2) {
            ForEach(fields.indices, id: \.self) { index in
                let field = fields[index]
                let raw = AtomKit.cell(row, field.string("name"))
                if !AtomKit.blank(raw) {
                    let text = AtomKit.fieldText(row, field, relations: relations)
                    HStack(spacing: theme.density.spacing.space1) {
                        if !field.string("icon").isEmpty { AtomKit.icon(field.string("icon"), "xs", onEvent: onEvent) }
                        AtomKit.badge(AtomKit.labelled(text, field), AtomKit.badgeVariant(field, AtomKit.scalar(raw) ?? text), size: "sm", onEvent: onEvent)
                    }
                }
            }
        }
    }
}

struct AtomFieldMeta: View {
    let row: AnyCodable
    let fields: [AnyCodable]
    let relations: AnyCodable?
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        AtomFlowLayout(spacing: theme.density.spacing.space3) {
            ForEach(fields.indices, id: \.self) { index in
                let field = fields[index]
                let raw = AtomKit.cell(row, field.string("name"))
                if !AtomKit.blank(raw) {
                    let label = field.string("label", default: field.string("name"))
                    let text = AtomKit.fieldText(row, field, relations: relations)
                    HStack(spacing: theme.density.spacing.space1) {
                        if !field.string("icon").isEmpty { AtomKit.icon(field.string("icon"), "xs", color: "muted", onEvent: onEvent) }
                        if field.string("format") == "boolean" {
                            AtomKit.typo(label, "caption", color: "secondary", onEvent: onEvent)
                            AtomKit.badge(text, raw?.boolValue == true ? "success" : "neutral", size: "sm", onEvent: onEvent)
                        } else {
                            AtomKit.typo(text, "small", color: "secondary", onEvent: onEvent)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(label): \(text)")
                }
            }
        }
    }
}

struct AtomFieldProgress: View {
    let row: AnyCodable
    let fields: [AnyCodable]
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
            ForEach(fields.indices, id: \.self) { index in
                let field = fields[index]
                if let value = AtomKit.cell(row, field.string("name")), value.stringValue == nil, let number = value.doubleValue {
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        HStack(spacing: theme.density.spacing.space1) {
                            if !field.string("icon").isEmpty { AtomKit.icon(field.string("icon"), "xs", color: "muted", onEvent: onEvent) }
                            AtomKit.typo(field.string("label", default: field.string("name")), "caption", color: "secondary", onEvent: onEvent)
                        }
                        ProgressBarRenderer(props: ["value": .double(number), "max": 100], modifier: nil, onEvent: onEvent)
                    }
                }
            }
        }
    }
}

struct AtomMonoText: View {
    let text: String
    let size: String
    let color: Color?
    @Environment(\.almadarTheme) private var theme

    init(_ text: String, size: String = "xs", color: Color? = nil) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(AtomKit.font(theme, size, .regular, mono: true))
            .foregroundColor(color ?? theme.color.foreground)
            .textSelection(.enabled)
    }
}

struct AtomDiffLine {
    let type: String
    let before: Int?
    let after: Int?
    let content: String
}

extension AtomKit {
    static func lineDiff(_ before: String, _ after: String) -> [AtomDiffLine] {
        let a = before.isEmpty ? [] : before.components(separatedBy: "\n")
        let b = after.isEmpty ? [] : after.components(separatedBy: "\n")
        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var result: [AtomDiffLine] = []
        var i = 0
        var j = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] {
                result.append(AtomDiffLine(type: "unchanged", before: i + 1, after: j + 1, content: a[i]))
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                result.append(AtomDiffLine(type: "removed", before: i + 1, after: nil, content: a[i]))
                i += 1
            } else {
                result.append(AtomDiffLine(type: "added", before: nil, after: j + 1, content: b[j]))
                j += 1
            }
        }
        while i < a.count { result.append(AtomDiffLine(type: "removed", before: i + 1, after: nil, content: a[i])); i += 1 }
        while j < b.count { result.append(AtomDiffLine(type: "added", before: nil, after: j + 1, content: b[j])); j += 1 }
        return result
    }

    static func agentFacts(_ activities: [AnyCodable]) -> [(settled: Bool, ready: Int)] {
        var facts = Array(repeating: (settled: false, ready: 0), count: activities.count)
        var open: [String: [Int]] = [:]
        var ready: Set<String> = []
        for (index, activity) in activities.enumerated() {
            let name = activity.string("orbitalName")
            switch activity.string("type") {
            case "orbital_started":
                open[name, default: []].append(index)
            case "orbital_done":
                if let last = open[name]?.popLast() { facts[last].settled = true }
                ready.insert(name)
            case "done":
                facts[index].ready = ready.count
                ready = []
            default:
                break
            }
        }
        return facts
    }
}

struct AtomAgentRow: View {
    let activity: AnyCodable
    let settled: Bool
    let ready: Int
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var open = false

    var body: some View {
        let type = activity.string("type")
        if type == "llm_response" {
            llm
        } else if type == "message" && activity.string("role") != "system" {
            bubble
        } else {
            row
        }
    }

    private var bubble: some View {
        let mine = activity.string("role") == "user"
        let content = activity.string("content")
        return HStack {
            if mine { Spacer(minLength: theme.density.spacing.space8) }
            Group {
                if mine {
                    AtomKit.typo(content, "body2", color: "inherit", onEvent: onEvent)
                } else {
                    MarkdownContentRenderer(props: ["content": .string(content)], modifier: nil, onEvent: onEvent)
                }
            }
            .foregroundColor(mine ? theme.color.primaryForeground : theme.color.foreground)
            .padding(.horizontal, theme.density.spacing.space3)
            .padding(.vertical, theme.density.spacing.space2)
            .background(mine ? theme.color.primary : theme.color.surface)
            .atomClip(theme, .container)
            if !mine { Spacer(minLength: theme.density.spacing.space8) }
        }
        .frame(maxWidth: .infinity)
    }

    private var row: some View {
        let spec = describe()
        return HStack(alignment: .top, spacing: theme.density.spacing.space2) {
            AtomKit.icon(spec.icon, "sm", color: spec.color, animation: spec.icon == "loader" ? "spin" : "", onEvent: onEvent)
            VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
                if let raw = spec.raw, !raw.isEmpty {
                    DisclosureGroup(isExpanded: $open) {
                        AtomMonoText(raw, size: "xs")
                    } label: {
                        AtomKit.typo(spec.text, "body2", onEvent: onEvent)
                    }
                } else {
                    AtomKit.typo(spec.text, "body2", onEvent: onEvent)
                }
                ForEach(spec.details.indices, id: \.self) { index in
                    AtomKit.typo(spec.details[index], "caption", color: "muted", onEvent: onEvent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var llm: some View {
        let detail = activity.dictValue?["llm"]
        let content = activity.string("content")
        return DisclosureGroup(isExpanded: $open) {
            VStack(alignment: .leading, spacing: theme.density.spacing.space2) {
                section("Response", content)
                if let detail = detail {
                    section("System prompt", detail.string("systemPrompt"))
                    section("User prompt", detail.string("userPrompt"))
                    if !detail.string("toolCallsJson").isEmpty { section("Tool calls", detail.string("toolCallsJson")) }
                }
            }
        } label: {
            HStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("cpu", "sm", color: "muted", onEvent: onEvent)
                AtomKit.typo(summary(detail), "caption", color: "muted", truncate: true, onEvent: onEvent)
            }
        }
    }

    private func section(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space0) {
            AtomKit.typo(label, "caption", color: "muted", weight: "semibold", onEvent: onEvent)
            AtomMonoText(text, size: "xs")
        }
    }

    private func summary(_ detail: AnyCodable?) -> String {
        guard let detail = detail else { return "Raw LLM response" }
        var parts = ["\(detail.string("service")) \u{00B7} \(detail.string("model"))"]
        parts.append(String(format: "%.1fs", detail.float("durationMs") / 1000))
        if detail.dictValue?["promptTokens"] != nil || detail.dictValue?["completionTokens"] != nil {
            parts.append("\(detail.int("promptTokens")) in / \(detail.int("completionTokens")) out tokens")
        }
        if detail.dictValue?["costUSD"] != nil { parts.append(String(format: "$%.4f", detail.float("costUSD"))) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func change(_ kind: String, _ orbital: String) -> String {
        switch kind {
        case "orbital-added": return "Added \(orbital)"
        case "orbital-removed": return "Removed \(orbital)"
        case "entity-fields-changed": return "Changed the data fields of \(orbital)"
        case "trait-added": return "Added a behavior to \(orbital)"
        case "trait-removed": return "Removed a behavior from \(orbital)"
        case "state-machine-changed": return "Changed the flow of \(orbital)"
        case "guard-changed": return "Changed a rule in \(orbital)"
        case "effect-changed": return "Changed what \(orbital) does"
        case "render-ui-changed": return "Changed the design of \(orbital)"
        case "event-wiring-changed": return "Changed the connections of \(orbital)"
        case "page-changed": return "Changed the pages of \(orbital)"
        case "behavior-composed": return "Composed a behavior into \(orbital)"
        case "trait-config-changed": return "Changed the settings of \(orbital)"
        case "theme-changed": return "Changed the theme of \(orbital)"
        default: return kind
        }
    }

    private func glyph(_ kind: String) -> String {
        switch kind {
        case "orbital-added": return "circle-plus"
        case "orbital-removed": return "circle-minus"
        case "entity-fields-changed": return "database"
        case "trait-added": return "plus-square"
        case "trait-removed": return "minus-square"
        case "trait-config-changed": return "sliders-horizontal"
        case "state-machine-changed": return "git-branch"
        case "guard-changed": return "shield"
        case "effect-changed": return "zap"
        case "render-ui-changed": return "layout-panel-top"
        case "event-wiring-changed": return "cable"
        case "page-changed": return "file"
        case "theme-changed": return "palette"
        default: return "layers"
        }
    }

    private func describe() -> (icon: String, color: String, text: String, details: [String], raw: String?) {
        let a = activity
        switch a.string("type") {
        case "message":
            return ("info", "muted", a.string("content"), [], nil)
        case "tool_call":
            let args = a.string("argsText")
            return ("wrench", "muted", "Called \(a.string("tool"))", [], args.isEmpty || args == "{}" ? nil : args)
        case "tool_result":
            var details: [String] = []
            if !a.string("detail").isEmpty { details.append(a.string("detail")) }
            if a.dictValue?["rows"] != nil { details.append("\(a.int("rows")) rows") }
            return (a.bool("success") ? "corner-down-right" : "alert-circle", a.bool("success") ? "muted" : "error", "\(a.string("tool")) returned", details, a.string("resultText"))
        case "file_operation":
            return ("file-text", "muted", a.string("operation"), [a.string("path")], nil)
        case "schema_diff":
            return ("file-diff", "muted", "Edited \(a.string("filePath"))", [], nil)
        case "error":
            return ("alert-circle", "error", a.string("message"), a.string("code").isEmpty ? [] : [a.string("code")], nil)
        case "coordinator_decision":
            return ("compass", "muted", "Chose \(a.string("organism"))", [a.string("reason")], nil)
        case "plan_committed":
            let names = AtomKit.strings(a, "orbitals")
            return ("layers", "muted", "Planning \(names.count) orbitals", [names.joined(separator: ", ")], nil)
        case "pending_question":
            return ("help-circle", "warning", a.string("question"), [], nil)
        case "clarification_question":
            let options = (a.dictValue?["candidates"]?.arrayValue ?? []).map { candidate -> String in
                let why = candidate.string("whyThisFits")
                return why.isEmpty ? candidate.string("label") : "\(candidate.string("label")) \u{2014} \(why)"
            }
            return ("help-circle", "warning", a.string("question"), options, nil)
        case "analysis":
            var details: [String] = []
            if !a.string("organismReason").isEmpty { details.append(a.string("organismReason")) }
            if let reasoning = a.dictValue?["complexity"]?.string("reasoning"), !reasoning.isEmpty { details.append(reasoning) }
            for rename in a.dictValue?["renames"]?.arrayValue ?? [] { details.append("Rename \(rename.string("from")) \u{2192} \(rename.string("to"))") }
            for removed in AtomKit.strings(a, "deletes") { details.append("Remove \(removed)") }
            return ("check", "success", "Analyzed your request \u{2014} \(a.string("organism"))", details, nil)
        case "orbital_started":
            return settled
                ? ("layers", "muted", "Started \(a.string("orbitalName"))", [], nil)
                : ("loader", "primary", "Working on \(a.string("orbitalName"))\u{2026}", [], nil)
        case "orbital_done":
            let counts = a.dictValue?["traitCount"] != nil || a.dictValue?["transitionCount"] != nil
                ? ["\(a.int("traitCount")) traits, \(a.int("transitionCount")) transitions"] : []
            return ("check", "success", "\(a.string("orbitalName")) ready", counts, nil)
        case "schema_change":
            let kind = a.string("changeKind")
            return (glyph(kind), "primary", change(kind, a.string("orbitalName")), [a.string("traitName"), a.string("transitionEvent")].filter { !$0.isEmpty }, nil)
        case "done":
            return ("check-circle", "success", "Done \u{2014} \(ready) orbitals ready", [], nil)
        case "cancelled":
            return ("circle-x", "muted", a.string("message").isEmpty ? "Cancelled" : a.string("message"), [], nil)
        default:
            return ("info", "muted", a.string("type"), [], nil)
        }
    }
}

struct AtomRowActions: View {
    let owner: AnyCodable
    let row: AnyCodable?
    let inline: [AnyCodable]
    let menu: [AnyCodable]
    let iconOnlyInline: Bool
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    init(owner: AnyCodable, row: AnyCodable?, inline: [AnyCodable], menu: [AnyCodable], iconOnlyInline: Bool = false, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.owner = owner
        self.row = row
        self.inline = inline
        self.menu = menu
        self.iconOnlyInline = iconOnlyInline
        self.onEvent = onEvent
    }

    var body: some View {
        HStack(spacing: theme.density.spacing.space1) {
            ForEach(inline.indices, id: \.self) { index in
                ButtonRenderer(props: AtomKit.actionProps(owner, inline[index], row: row, size: "sm", fallback: "ghost", iconOnly: iconOnlyInline), modifier: nil, onEvent: onEvent)
            }
            if !menu.isEmpty {
                Menu {
                    ForEach(menu.indices, id: \.self) { index in
                        ButtonRenderer(props: AtomKit.actionProps(owner, menu[index], row: row, size: "sm", fallback: "ghost"), modifier: nil, onEvent: onEvent)
                    }
                } label: {
                    IconRenderer(props: ["icon": "more-horizontal", "size": "sm", "aria-label": "Actions"], modifier: nil, onEvent: onEvent)
                        .frame(minWidth: theme.density.buttonHeightSm, minHeight: theme.density.buttonHeightSm)
                }
                .verificationId(VerificationIds.actionOverflow)
            }
        }
    }

    static func split(_ actions: [AnyCodable], inlineLimit: Int?) -> (inline: [AnyCodable], menu: [AnyCodable]) {
        let usable = actions.filter { AtomKit.actionable($0) }
        guard let limit = inlineLimit else { return (usable, []) }
        return (Array(usable.prefix(limit)), Array(usable.dropFirst(limit)))
    }
}

struct AtomGridLayout: Layout {
    let minWidth: CGFloat
    let maxColumns: Int
    let fixedColumns: Int
    let spacing: CGFloat
    var breakpointColumns: Bool = false

    private func columns(for width: CGFloat) -> Int {
        let fit = max(1, Int((width + spacing) / (minWidth + spacing)))
        if fixedColumns > 0 && breakpointColumns {
            if width < AlmadarBreakpoints.sm { return 1 }
            if width < AlmadarBreakpoints.lg { return min(fixedColumns, 2) }
            if width < AlmadarBreakpoints.xl { return min(fixedColumns, 3) }
            return fixedColumns
        }
        if fixedColumns > 0 { return min(fixedColumns, fit) }
        return maxColumns > 0 ? min(fit, maxColumns) : fit
    }

    private func measure(width: CGFloat, subviews: Subviews) -> (heights: [CGFloat], count: Int, cell: CGFloat) {
        let count = columns(for: width)
        let cell = (width - spacing * CGFloat(count - 1)) / CGFloat(count)
        var heights: [CGFloat] = []
        var index = 0
        while index < subviews.count {
            let row = subviews[index..<min(index + count, subviews.count)]
            heights.append(row.map { $0.sizeThatFits(ProposedViewSize(width: cell, height: nil)).height }.max() ?? 0)
            index += count
        }
        return (heights, count, cell)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minWidth
        let laid = measure(width: width, subviews: subviews)
        let total = laid.heights.reduce(0, +) + spacing * CGFloat(max(laid.heights.count - 1, 0))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let laid = measure(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (rowIndex, height) in laid.heights.enumerated() {
            for column in 0..<laid.count {
                let index = rowIndex * laid.count + column
                if index >= subviews.count { break }
                let x = bounds.minX + CGFloat(column) * (laid.cell + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: laid.cell, height: height))
            }
            y += height + spacing
        }
    }
}

struct AtomRatioLayout: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat
    let alignment: VerticalAlignment
    let stretch: Bool

    private func widths(_ total: CGFloat, count: Int) -> [CGFloat] {
        let usable = max(total - spacing * CGFloat(max(count - 1, 0)), 0)
        let sum = weights.prefix(count).reduce(0, +)
        return (0..<count).map { usable * (sum > 0 ? weights[$0] / sum : 1 / CGFloat(count)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 320
        let cells = widths(total, count: subviews.count)
        let height = subviews.indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cells[$0], height: nil)).height }.max() ?? 0
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cells = widths(bounds.width, count: subviews.count)
        var x = bounds.minX
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: cells[index], height: nil))
            let y: CGFloat
            if alignment == .center { y = bounds.minY + (bounds.height - size.height) / 2 }
            else if alignment == .bottom { y = bounds.maxY - size.height }
            else { y = bounds.minY }
            subviews[index].place(at: CGPoint(x: x, y: stretch ? bounds.minY : y), anchor: .topLeading, proposal: ProposedViewSize(width: cells[index], height: stretch ? bounds.height : size.height))
            x += cells[index] + spacing
        }
    }
}

struct AtomSlot: View {
    let raw: AnyCodable?
    let variant: String
    let weight: String
    let color: String
    let onEvent: (String, AnyCodable?) -> Void

    init(_ raw: AnyCodable?, variant: String = "body1", weight: String = "", color: String = "primary", onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.raw = raw
        self.variant = variant
        self.weight = weight
        self.color = color
        self.onEvent = onEvent
    }

    var body: some View {
        if let raw = raw {
            if let text = AtomKit.scalar(raw) {
                if !text.isEmpty { AtomKit.typo(text, variant, color: color, weight: weight, onEvent: onEvent) }
            } else if let list = raw.arrayValue {
                ForEach(list.indices, id: \.self) { index in
                    RenderChild(list[index], onEvent: onEvent)
                }
            } else if raw.dictValue != nil {
                RenderChild(raw, onEvent: onEvent)
            }
        }
    }
}

extension View {
    func atomSurface(_ theme: AlmadarTheme, padding: CGFloat? = nil) -> some View {
        self
            .padding(padding ?? theme.density.cardPaddingMd)
            .background(theme.color.card)
            .atomClip(theme, .container)
            .atomBorder(theme, .container, color: theme.color.border, width: theme.geometry.borderStandard)
    }
}

struct AtomMarkdownBlock {
    enum Kind { case heading, paragraph, code, quote, list, rule, table, image }
    let kind: Kind
    let level: Int
    let text: String
    let items: [String]
    let ordered: Bool
    let rows: [[String]]

    init(_ kind: Kind, level: Int = 0, text: String = "", items: [String] = [], ordered: Bool = false, rows: [[String]] = []) {
        self.kind = kind
        self.level = level
        self.text = text
        self.items = items
        self.ordered = ordered
        self.rows = rows
    }
}

enum AtomMarkdown {
    static func matches(_ line: String, _ pattern: String) -> Bool {
        line.range(of: pattern, options: .regularExpression) != nil
    }

    static func cells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func stripListMarker(_ line: String) -> String {
        guard let range = line.range(of: "^\\s*([-*+]|\\d+[.)])\\s+", options: .regularExpression) else { return line }
        return String(line[range.upperBound...])
    }

    static func parse(_ source: String) -> [AtomMarkdownBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [AtomMarkdownBlock] = []
        var paragraph: [String] = []
        var index = 0
        func flush() {
            if !paragraph.isEmpty { blocks.append(AtomMarkdownBlock(.paragraph, text: paragraph.joined(separator: " "))) }
            paragraph = []
        }
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flush()
                index += 1
            } else if trimmed.hasPrefix("```") {
                flush()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                index += 1
                blocks.append(AtomMarkdownBlock(.code, text: code.joined(separator: "\n"), items: [language]))
            } else if matches(trimmed, "^#{1,6}\\s+") {
                flush()
                let level = trimmed.prefix(while: { $0 == "#" }).count
                blocks.append(AtomMarkdownBlock(.heading, level: level, text: String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
                index += 1
            } else if matches(trimmed, "^(-{3,}|\\*{3,}|_{3,})$") {
                flush()
                blocks.append(AtomMarkdownBlock(.rule))
                index += 1
            } else if matches(trimmed, "^!\\[[^\\]]*\\]\\([^)]+\\)$") {
                flush()
                blocks.append(AtomMarkdownBlock(.image, text: trimmed))
                index += 1
            } else if trimmed.hasPrefix(">") {
                flush()
                var quote: [String] = []
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quote.append(String(lines[index].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(AtomMarkdownBlock(.quote, text: quote.joined(separator: " ")))
            } else if trimmed.hasPrefix("|") && index + 1 < lines.count && matches(lines[index + 1].trimmingCharacters(in: .whitespaces), "^\\|?\\s*:?-{2,}") {
                flush()
                var rows: [[String]] = [cells(trimmed)]
                index += 2
                while index < lines.count && lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(cells(lines[index]))
                    index += 1
                }
                blocks.append(AtomMarkdownBlock(.table, rows: rows))
            } else if matches(line, "^\\s*([-*+]|\\d+[.)])\\s+") {
                flush()
                let ordered = matches(line, "^\\s*\\d+[.)]\\s+")
                var items: [String] = []
                while index < lines.count && matches(lines[index], "^\\s*([-*+]|\\d+[.)])\\s+") {
                    items.append(stripListMarker(lines[index]))
                    index += 1
                }
                blocks.append(AtomMarkdownBlock(.list, items: items, ordered: ordered))
            } else {
                paragraph.append(trimmed)
                index += 1
            }
        }
        flush()
        return blocks
    }
}

struct AtomInlineText: View {
    let text: String
    let sizeKey: String
    let weight: Font.Weight
    let colorToken: String
    let mono: Bool
    let annotations: [AnyCodable]
    let onAnnotation: (String) -> Void
    @Environment(\.almadarTheme) private var theme

    init(_ text: String, sizeKey: String = "base", weight: Font.Weight = .regular, colorToken: String = "primary", mono: Bool = false, annotations: [AnyCodable] = [], onAnnotation: @escaping (String) -> Void = { _ in }) {
        self.text = text
        self.sizeKey = sizeKey
        self.weight = weight
        self.colorToken = colorToken
        self.mono = mono
        self.annotations = annotations
        self.onAnnotation = onAnnotation
    }

    var body: some View {
        Text(attributed())
            .font(AtomKit.font(theme, sizeKey, weight, mono: mono))
            .foregroundColor(AtomKit.typographyColor(theme, colorToken))
            .tint(theme.color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "almadar-annotation" {
                    onAnnotation(url.host?.removingPercentEncoding ?? "")
                    return .handled
                }
                return .systemAction
            })
    }

    private func attributed() -> AttributedString {
        var out = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        for annotation in annotations {
            let needle = annotation.string("text")
            let id = annotation.string("id")
            guard !needle.isEmpty, let range = out.range(of: needle) else { continue }
            out[range].backgroundColor = (annotation.string("kind") == "question" ? theme.color.primary : theme.color.warning).opacity(0.25)
            if let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                out[range].link = URL(string: "almadar-annotation://" + encoded)
            }
        }
        return out
    }
}

struct AtomStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.4
        var path = Path()
        for point in 0..<10 {
            let radius = point % 2 == 0 ? outer : inner
            let angle = Double(point) * .pi / 5 - .pi / 2
            let vertex = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        return path
    }
}

extension AtomKit {
    static func linkProps(_ owner: AnyCodable, _ link: AnyCodable, _ values: [String: AnyCodable]) -> AnyCodable {
        let target = navigate(link)
        var merged = values
        if !target.event.isEmpty {
            merged["action"] = .string(target.event)
            if let payload = target.payload { merged["actionPayload"] = payload }
        } else if !target.href.isEmpty {
            merged["href"] = .string(target.href)
        }
        return child(owner, merged)
    }
}

extension AtomKit {
    static func sexpr(_ value: AnyCodable) -> String {
        if let list = value.arrayValue { return "(" + list.map { sexpr($0) }.joined(separator: " ") + ")" }
        if let dict = value.dictValue { return "{" + dict.keys.sorted().map { $0 + ": " + sexpr(dict[$0] ?? .null) }.joined(separator: ", ") + "}" }
        if case .null = value { return "null" }
        return scalar(value) ?? ""
    }
}

struct AtomPieShape: Shape {
    let start: Double
    let end: Double
    let hole: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let from = Angle(degrees: -90 + 360 * start)
        let to = Angle(degrees: -90 + 360 * end)
        var path = Path()
        if hole > 0 {
            path.addArc(center: center, radius: outer, startAngle: from, endAngle: to, clockwise: false)
            path.addArc(center: center, radius: outer * hole, startAngle: to, endAngle: from, clockwise: true)
        } else {
            path.move(to: center)
            path.addArc(center: center, radius: outer, startAngle: from, endAngle: to, clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

enum AtomRowTemplate {
    static func bind(_ node: AnyCodable, _ row: AnyCodable) -> AnyCodable {
        if let text = node.stringValue { return .string(AtomKit.expand(text, row: row)) }
        if let list = node.arrayValue { return .array(list.map { bind($0, row) }) }
        if let dict = node.dictValue { return .dict(dict.mapValues { bind($0, row) }) }
        return node
    }
}

struct AtomRowFields: View {
    let row: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void

    var body: some View {
        let entries = (row.dictValue ?? [:]).keys.sorted().compactMap { key -> String? in
            guard let text = AtomKit.scalar(row.dictValue?[key]), !text.isEmpty else { return nil }
            return text
        }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries.indices, id: \.self) { index in
                AtomKit.typo(entries[index], index == 0 ? "body1" : "caption", color: index == 0 ? "primary" : "muted", onEvent: onEvent)
            }
        }
    }
}

extension AtomKit {
    static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        return fractional.date(from: raw) ?? plain.date(from: raw) ?? day.date(from: String(raw.prefix(10)))
    }

    static func plainHTML(_ html: String) -> String {
        var text = html
        for (pattern, replacement) in [("<br\\s*/?>", "\n"), ("</(p|div|li|h[1-6]|blockquote|pre)>", "\n"), ("<[^>]+>", "")] {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AtomKit {
    static func node(_ type: String, _ values: [String: AnyCodable]) -> AnyCodable {
        var merged = values
        merged["type"] = .string(type)
        return .dict(merged)
    }

    static func tailwindSize(_ token: String) -> CGFloat? {
        switch token.split(separator: "-").last.map(String.init) ?? token {
        case "14": return AlmadarSizes.w14
        case "16": return AlmadarSizes.w16
        case "20": return AlmadarSizes.w20
        case "24": return AlmadarSizes.w24
        case "28": return AlmadarSizes.w28
        case "32": return AlmadarSizes.w32
        case "36": return AlmadarSizes.w36
        case "40": return AlmadarSizes.w40
        case "44": return AlmadarSizes.w44
        case "48": return AlmadarSizes.w48
        case "52": return AlmadarSizes.w52
        case "56": return AlmadarSizes.w56
        case "60": return AlmadarSizes.w60
        case "64": return AlmadarSizes.w64
        case "72": return AlmadarSizes.w72
        case "80": return AlmadarSizes.w80
        case "96": return AlmadarSizes.w96
        default: return length(token).flatMap { $0.isFinite ? $0 : nil }
        }
    }
}

struct AtomContentSegment {
    let kind: String
    let language: String
    let text: String
    let answer: String
}

extension AtomKit {
    static func node(_ owner: AnyCodable, _ type: String, _ values: [String: AnyCodable]) -> AnyCodable {
        var merged = values
        merged["type"] = .string(type)
        return child(owner, merged)
    }

    static func contentSegments(_ content: String) -> [AtomContentSegment] {
        guard !content.isEmpty, let tags = try? NSRegularExpression(pattern: "<question>([\\s\\S]*?)</question>\\s*<answer>([\\s\\S]*?)</answer>", options: [.caseInsensitive]) else { return [] }
        let whole = content as NSString
        var out: [AtomContentSegment] = []
        var last = 0
        for match in tags.matches(in: content, range: NSRange(location: 0, length: whole.length)) {
            let before = whole.substring(with: NSRange(location: last, length: match.range.location - last))
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(contentsOf: markdownSegments(before)) }
            out.append(AtomContentSegment(kind: "quiz", language: "", text: whole.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines), answer: whole.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)))
            last = match.range.location + match.range.length
        }
        let rest = whole.substring(from: last)
        if !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(contentsOf: markdownSegments(rest)) }
        return out
    }

    static func markdownSegments(_ content: String) -> [AtomContentSegment] {
        guard !content.isEmpty, let fences = try? NSRegularExpression(pattern: "```(\\w+)?\\n([\\s\\S]*?)```") else { return [] }
        let whole = content as NSString
        var out: [AtomContentSegment] = []
        var last = 0
        for match in fences.matches(in: content, range: NSRange(location: 0, length: whole.length)) {
            let before = whole.substring(with: NSRange(location: last, length: match.range.location - last))
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(AtomContentSegment(kind: "markdown", language: "", text: before, answer: "")) }
            let language = match.range(at: 1).location == NSNotFound ? "text" : whole.substring(with: match.range(at: 1))
            out.append(AtomContentSegment(kind: "code", language: language, text: whole.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines), answer: ""))
            last = match.range.location + match.range.length
        }
        let rest = whole.substring(from: last)
        if !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { out.append(AtomContentSegment(kind: "markdown", language: "", text: rest, answer: "")) }
        return out
    }
}

enum AtomFx {
    static func hash01(_ seed: String, _ salt: Int) -> Double {
        var h: UInt32 = 2166136261 ^ UInt32(truncatingIfNeeded: salt)
        for unit in seed.utf16 {
            h ^= UInt32(unit)
            h = h &* 16777619
        }
        h ^= h >> 13
        h = h &* 1274126177
        h ^= h >> 16
        return Double(h) / 4294967296
    }

    struct Particle {
        let id: Int
        let palette: Int
        let left: Double
        let delay: Double
        let angle: Double
        let distance: Double
        let rotation: Double
        let size: Double
    }

    static func confetti(_ count: Int, seed: String) -> [Particle] {
        (0..<max(count, 0)).map { i in
            Particle(
                id: i,
                palette: Int((hash01(seed, i * 7 + 1) * 6).rounded(.down)),
                left: 30 + hash01(seed, i * 7 + 2) * 40,
                delay: hash01(seed, i * 7 + 3) * 300,
                angle: hash01(seed, i * 7 + 4) * 360,
                distance: 40 + hash01(seed, i * 7 + 5) * 80,
                rotation: hash01(seed, i * 7 + 6) * 720 - 360,
                size: 4 + hash01(seed, i * 7 + 7) * 6
            )
        }
    }

    static func color(_ theme: AlmadarTheme, _ palette: Int) -> Color {
        switch palette {
        case 0: return theme.color.primary
        case 1: return theme.color.success
        case 2: return theme.color.warning
        case 3: return theme.color.error
        case 4: return AlmadarThemeParse.color("#FFD700", fallback: theme.color.warning)
        default: return AlmadarThemeParse.color("#1E90FF", fallback: theme.color.info)
        }
    }

    static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var low = 0.0
        var high = 1.0
        for _ in 0..<24 {
            let s = (low + high) / 2
            let u = 1 - s
            let bx = 3 * u * u * s * x1 + 3 * u * s * s * x2 + s * s * s
            if bx < x { low = s } else { high = s }
        }
        let s = (low + high) / 2
        let u = 1 - s
        return 3 * u * u * s * y1 + 3 * u * s * s * y2 + s * s * s
    }

    static func easeOut(_ x: Double) -> Double { bezier(x, 0, 0, 0.58, 1) }

    static func easeInOut(_ x: Double) -> Double { bezier(x, 0.42, 0, 0.58, 1) }

    static func segment(_ t: Double, _ from: Double, _ to: Double) -> Double {
        easeInOut(min(max((t - from) / (to - from), 0), 1))
    }
}

struct AtomConfettiBurst: View {
    let particles: [AtomFx.Particle]
    let elapsedMs: Double
    let lifeMs: Double
    let reach: Double
    let tint: Color?
    let anchor: CGPoint?
    let minDurationMs: Double
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(particles.indices, id: \.self) { index in
                    piece(particles[index], proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func piece(_ p: AtomFx.Particle, _ size: CGSize) -> some View {
        let local = elapsedMs - p.delay
        let t = min(local / max(lifeMs - p.delay, minDurationMs), 1)
        if local >= 0 {
            let travel = AtomFx.easeOut(t)
            let radians = p.angle * Double.pi / 180
            let tx = cos(radians) * p.distance * reach
            let ty = sin(radians) * p.distance * reach - 20
            let originX = anchor.map { Double($0.x * size.width) + (p.left - 50) * 2 } ?? p.left / 100 * Double(size.width)
            let originY = anchor.map { Double($0.y * size.height) - 10 } ?? Double(size.height) / 2
            let fade = t < 0.7 ? 1 : 1 - AtomFx.easeOut((t - 0.7) / 0.3)
            RoundedRectangle(cornerRadius: AtomKit.radius(theme, "sm"))
                .fill(tint ?? AtomFx.color(theme, p.palette))
                .frame(width: p.size, height: p.size)
                .scaleEffect(1 - 0.5 * travel)
                .rotationEffect(.degrees(p.rotation * travel))
                .opacity(fade)
                .position(x: originX + p.size / 2 + tx * travel, y: originY + p.size / 2 + ty * travel)
        }
    }
}

extension AtomKit {
    static func ink(_ theme: AlmadarTheme, _ raw: String, _ key: String, weight: Font.Weight = .regular, color: Color) -> Text {
        Text(raw).font(font(theme, key, weight)).foregroundColor(color)
    }
}
struct AtomMonoRun {
    let text: String
    let color: Color?
    let bold: Bool
}

struct AtomMonoRuns: View {
    let runs: [AtomMonoRun]
    let size: String
    @Environment(\.almadarTheme) private var theme

    init(_ runs: [AtomMonoRun], size: String = "xs") {
        self.runs = runs
        self.size = size
    }

    var body: some View {
        runs.reduce(Text("")) { joined, run in
            joined + Text(run.text)
                .font(AtomKit.font(theme, size, run.bold ? .bold : .regular, mono: true))
                .foregroundColor(run.color ?? theme.color.foreground)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct AtomButtonTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var atomButtonTint: Color? {
        get { self[AtomButtonTintKey.self] }
        set { self[AtomButtonTintKey.self] = newValue }
    }
}

enum SurfaceLength {
    case fraction(Double)
    case length(CGFloat)

    func resolve(_ total: CGFloat) -> CGFloat {
        switch self {
        case .fraction(let amount): return CGFloat(amount) * total
        case .length(let points): return points
        }
    }
}

struct SurfaceStop {
    let color: Color
    let position: SurfaceLength?

    static func resolve(_ stops: [SurfaceStop], length: CGFloat) -> [Gradient.Stop] {
        var places: [Double?] = stops.map { stop in
            guard let position = stop.position else { return nil }
            switch position {
            case .fraction(let amount): return amount
            case .length(let points): return length > 0 ? Double(points / length) : 0
            }
        }
        if places[0] == nil { places[0] = 0 }
        if places[places.count - 1] == nil { places[places.count - 1] = 1 }
        var lowest = 0.0
        for index in places.indices {
            if let value = places[index] {
                places[index] = max(value, lowest)
                lowest = max(value, lowest)
            }
        }
        var index = 0
        while index < places.count {
            if places[index] != nil {
                index += 1
                continue
            }
            let before = index - 1
            var after = index
            while places[after] == nil { after += 1 }
            let lower = places[before] ?? 0
            let upper = places[after] ?? 1
            for gap in index..<after {
                places[gap] = lower + (upper - lower) * Double(gap - before) / Double(after - before)
            }
            index = after
        }
        return zip(stops, places).map { Gradient.Stop(color: $0.color, location: CGFloat(min(max($1 ?? 0, 0), 1))) }
    }
}

enum SurfaceDirection {
    case angle(Double)
    case corner(x: Double, y: Double)

    func vector(_ size: CGSize) -> CGPoint {
        switch self {
        case .angle(let degrees):
            let radians = degrees * .pi / 180
            return CGPoint(x: sin(radians), y: -cos(radians))
        case .corner(let x, let y):
            let norm = hypot(size.width, size.height)
            guard norm > 0 else { return CGPoint(x: 0, y: 1) }
            return CGPoint(x: CGFloat(x) * size.height / norm, y: CGFloat(y) * size.width / norm)
        }
    }
}

enum SurfaceRadialExtent {
    case closestSide
    case farthestSide
    case closestCorner
    case farthestCorner

    func radii(circle: Bool, center: CGPoint, size: CGSize) -> CGSize {
        let near = CGSize(width: min(center.x, size.width - center.x), height: min(center.y, size.height - center.y))
        let far = CGSize(width: max(center.x, size.width - center.x), height: max(center.y, size.height - center.y))
        let root = CGFloat(2).squareRoot()
        switch self {
        case .closestSide:
            let side = min(near.width, near.height)
            return circle ? CGSize(width: side, height: side) : near
        case .farthestSide:
            let side = max(far.width, far.height)
            return circle ? CGSize(width: side, height: side) : far
        case .closestCorner:
            let reach = hypot(near.width, near.height)
            return circle ? CGSize(width: reach, height: reach) : CGSize(width: near.width * root, height: near.height * root)
        case .farthestCorner:
            let reach = hypot(far.width, far.height)
            return circle ? CGSize(width: reach, height: reach) : CGSize(width: far.width * root, height: far.height * root)
        }
    }
}

enum SurfaceLayer {
    case linear(direction: SurfaceDirection, stops: [SurfaceStop])
    case radial(circle: Bool, extent: SurfaceRadialExtent, x: SurfaceLength, y: SurfaceLength, stops: [SurfaceStop])
}

/// Paints the layers of a theme `surface` image (`SurfaceImage.css`) top layer last; a layer the parser skipped is not here.
struct SurfaceImageLayers: View {
    let layers: [SurfaceLayer]

    var body: some View {
        Canvas { context, size in
            for layer in layers.reversed() { Self.paint(layer, context, size) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func paint(_ layer: SurfaceLayer, _ context: GraphicsContext, _ size: CGSize) {
        let bounds = Path(CGRect(origin: .zero, size: size))
        switch layer {
        case .linear(let direction, let stops):
            let vector = direction.vector(size)
            let length = abs(size.width * vector.x) + abs(size.height * vector.y)
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let half = CGPoint(x: vector.x * length / 2, y: vector.y * length / 2)
            let gradient = Gradient(stops: SurfaceStop.resolve(stops, length: length))
            context.fill(bounds, with: .linearGradient(gradient, startPoint: CGPoint(x: middle.x - half.x, y: middle.y - half.y), endPoint: CGPoint(x: middle.x + half.x, y: middle.y + half.y)))
        case .radial(let circle, let extent, let x, let y, let stops):
            let center = CGPoint(x: x.resolve(size.width), y: y.resolve(size.height))
            let radii = extent.radii(circle: circle, center: center, size: size)
            guard radii.width > 0, radii.height > 0 else { return }
            let squash = radii.height / radii.width
            var local = context
            local.translateBy(x: center.x, y: center.y)
            local.scaleBy(x: 1, y: squash)
            let area = Path(CGRect(x: -center.x, y: -center.y / squash, width: size.width, height: size.height / squash))
            local.fill(area, with: .radialGradient(Gradient(stops: SurfaceStop.resolve(stops, length: radii.width)), center: .zero, startRadius: 0, endRadius: radii.width))
        }
    }
}

extension AtomKit {
    static func cardImageLayers(_ theme: AlmadarTheme) -> [SurfaceLayer] {
        if case .css(let css) = theme.surface.cardImage { return surfaceLayers(theme, css) }
        return []
    }

    static func surfaceLayers(_ theme: AlmadarTheme, _ css: String) -> [SurfaceLayer] {
        AlmadarThemeParse.splitTopLevel(css, separator: ",").compactMap { surfaceLayer(theme, $0) }
    }

    private static func skipLayer(_ layer: String, _ reason: String) -> SurfaceLayer? {
        AlmadarThemeLog.warn("surfaceImage: skipped layer \"\(layer)\" (\(reason))")
        return nil
    }

    private static func surfaceLayer(_ theme: AlmadarTheme, _ layer: String) -> SurfaceLayer? {
        guard let open = layer.firstIndex(of: "("), layer.hasSuffix(")") else { return skipLayer(layer, "not an image function") }
        let name = String(layer[..<open])
        let inner = String(layer[layer.index(after: open)..<layer.index(before: layer.endIndex)])
        var args = AlmadarThemeParse.splitTopLevel(inner, separator: ",")
        switch name {
        case "linear-gradient":
            var direction = SurfaceDirection.angle(180)
            if let first = args.first, first.hasPrefix("to ") || first.range(of: "^-?[0-9.]+[a-z]+$", options: .regularExpression) != nil {
                guard let parsed = surfaceDirection(first) else { return skipLayer(layer, "unsupported gradient direction") }
                direction = parsed
                args.removeFirst()
            }
            guard let stops = surfaceStops(theme, args) else { return skipLayer(layer, "unsupported colour stop") }
            return .linear(direction: direction, stops: stops)
        case "radial-gradient":
            var circle = false
            var extent = SurfaceRadialExtent.farthestCorner
            var x = SurfaceLength.fraction(0.5)
            var y = SurfaceLength.fraction(0.5)
            if let first = args.first, surfaceColor(theme, AlmadarThemeParse.splitTopLevel(first, separator: " ").first ?? "") == nil {
                guard let config = surfaceRadialConfig(first) else { return skipLayer(layer, "unsupported radial shape, size, position or colour") }
                circle = config.circle
                extent = config.extent
                x = config.x
                y = config.y
                args.removeFirst()
            }
            guard let stops = surfaceStops(theme, args) else { return skipLayer(layer, "unsupported colour stop") }
            return .radial(circle: circle, extent: extent, x: x, y: y, stops: stops)
        default:
            return skipLayer(layer, "\(name) is not a gradient")
        }
    }

    private static func surfaceDirection(_ raw: String) -> SurfaceDirection? {
        if raw.hasSuffix("deg"), let degrees = Double(raw.dropLast(3)) { return .angle(degrees) }
        guard raw.hasPrefix("to ") else { return nil }
        let words = Set(raw.dropFirst(3).split(separator: " ").map(String.init))
        let known: Set<String> = ["left", "right", "top", "bottom"]
        guard !words.isEmpty, words.isSubset(of: known), !(words.contains("left") && words.contains("right")), !(words.contains("top") && words.contains("bottom")) else { return nil }
        let horizontal = words.contains("left") ? -1.0 : (words.contains("right") ? 1.0 : 0.0)
        let vertical = words.contains("top") ? -1.0 : (words.contains("bottom") ? 1.0 : 0.0)
        if horizontal == 0 { return .angle(vertical < 0 ? 0 : 180) }
        if vertical == 0 { return .angle(horizontal > 0 ? 90 : 270) }
        return .corner(x: horizontal, y: vertical)
    }

    private static func surfaceRadialConfig(_ raw: String) -> (circle: Bool, extent: SurfaceRadialExtent, x: SurfaceLength, y: SurfaceLength)? {
        var head = raw
        var place: String?
        if raw.hasPrefix("at ") {
            head = ""
            place = String(raw.dropFirst(3))
        } else if let split = raw.range(of: " at ") {
            head = String(raw[..<split.lowerBound])
            place = String(raw[split.upperBound...])
        }
        var circle = false
        var extent = SurfaceRadialExtent.farthestCorner
        for word in head.split(separator: " ").map(String.init) {
            switch word {
            case "circle": circle = true
            case "ellipse": circle = false
            case "closest-side": extent = .closestSide
            case "farthest-side": extent = .farthestSide
            case "closest-corner": extent = .closestCorner
            case "farthest-corner": extent = .farthestCorner
            default: return nil
            }
        }
        guard let place = place else { return (circle, extent, .fraction(0.5), .fraction(0.5)) }
        guard let spot = surfaceSpot(place) else { return nil }
        return (circle, extent, spot.x, spot.y)
    }

    private static func surfaceSpot(_ raw: String) -> (x: SurfaceLength, y: SurfaceLength)? {
        let words = raw.split(separator: " ").map(String.init)
        guard (1...2).contains(words.count) else { return nil }
        var x: SurfaceLength?
        var y: SurfaceLength?
        var free: [SurfaceLength] = []
        for word in words {
            switch word {
            case "left": x = .fraction(0)
            case "right": x = .fraction(1)
            case "top": y = .fraction(0)
            case "bottom": y = .fraction(1)
            case "center": free.append(.fraction(0.5))
            default:
                guard let length = surfaceLength(word) else { return nil }
                free.append(length)
            }
        }
        for value in free {
            if x == nil { x = value } else if y == nil { y = value } else { return nil }
        }
        return (x ?? .fraction(0.5), y ?? .fraction(0.5))
    }

    private static func surfaceStops(_ theme: AlmadarTheme, _ args: [String]) -> [SurfaceStop]? {
        var out: [SurfaceStop] = []
        for arg in args {
            let tokens = AlmadarThemeParse.splitTopLevel(arg, separator: " ")
            guard let head = tokens.first, tokens.count <= 3, let color = surfaceColor(theme, head) else { return nil }
            let places = tokens.dropFirst().map { surfaceLength($0) }
            if places.contains(where: { $0 == nil }) { return nil }
            if places.isEmpty { out.append(SurfaceStop(color: color, position: nil)) }
            for place in places { out.append(SurfaceStop(color: color, position: place)) }
        }
        return out.count >= 2 ? out : nil
    }

    private static func surfaceLength(_ raw: String) -> SurfaceLength? {
        if raw.hasSuffix("%"), let amount = Double(raw.dropLast()) { return .fraction(amount / 100) }
        if raw.hasSuffix("px"), let points = Double(raw.dropLast(2)) { return .length(CGFloat(points)) }
        return nil
    }

    /// A stop colour the theme parser can read as written, else nil: never a substitute colour.
    static func surfaceColor(_ theme: AlmadarTheme, _ raw: String) -> Color? {
        if raw == "transparent" { return clear(theme) }
        let prefix = "var(--color-"
        if raw.hasPrefix(prefix), raw.hasSuffix(")") {
            switch String(raw.dropFirst(prefix.count).dropLast()) {
            case "primary": return theme.color.primary
            case "primary-foreground": return theme.color.primaryForeground
            case "secondary": return theme.color.secondary
            case "accent": return theme.color.accent
            case "foreground": return theme.color.foreground
            case "muted": return theme.color.muted
            case "muted-foreground": return theme.color.mutedForeground
            case "background": return theme.color.background
            case "card": return theme.color.card
            case "border": return theme.color.border
            case "success": return theme.color.success
            case "warning": return theme.color.warning
            case "error": return theme.color.error
            case "info": return theme.color.info
            default: return nil
            }
        }
        let hex = "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
        let functional = "^(rgba?|hsla?)\\([-0-9.%\\s]+(,[-0-9.%\\s]+){2,3}\\)$"
        if raw.range(of: hex, options: .regularExpression) != nil || raw.range(of: functional, options: .regularExpression) != nil {
            return AlmadarThemeParse.color(raw, fallback: clear(theme))
        }
        return nil
    }

    /// The Rust scene for a ```mermaid fence, or nil when the renderer cannot draw this source (the host then shows the code block).
    static func mermaid(_ code: String, onEvent: @escaping (String, AnyCodable?) -> Void) -> AnyView? {
        let scene: AnyCodable = ["code": .string(code)]
        guard orbitalSceneDrawable("mermaid", scene) else { return nil }
        return LearningCanvasRenderer(pattern: "mermaid", props: scene, modifier: nil, onEvent: onEvent)
    }
}

struct TraitStateViewerView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    private var trait: AnyCodable { props.dictValue?["trait"] ?? .dict([:]) }
    private var states: [String] { (trait.dictValue?["states"]?.arrayValue ?? []).compactMap { AtomKit.scalar($0) } }
    private var current: String { trait.string("currentState") }
    private var transitions: [AnyCodable] { trait.dictValue?["transitions"]?.arrayValue ?? [] }
    private var outgoing: [AnyCodable] { transitions.filter { $0.string("from") == current } }
    private var size: String { props.string("size", default: "md") }
    private var fontKey: String { size == "sm" ? "xs" : (size == "lg" ? "base" : "sm") }

    private var gap: CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space2
        case "lg": return theme.density.spacing.space6
        default: return theme.density.spacing.space4
        }
    }

    private var nodeMinWidth: CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space12
        case "lg": return AlmadarSizes.w20
        default: return AlmadarSizes.w16
        }
    }

    private var nodeHeight: CGFloat {
        switch size {
        case "sm": return theme.density.spacing.space8
        case "lg": return theme.density.spacing.space12
        default: return theme.density.spacing.space10
        }
    }

    private func caption(_ text: String, _ color: Color, weight: Font.Weight = .regular) -> Text {
        AtomKit.ink(theme, text, "xs", weight: weight, color: color)
    }

    private func shell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space2) { content() }
            .padding(theme.density.spacing.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color.card)
            .atomClip(theme, .container)
            .atomBorder(theme, .container, color: theme.color.border, width: theme.geometry.borderStandard)
    }

    @ViewBuilder
    private var description: some View {
        let text = trait.string("description")
        if !text.isEmpty { caption(text, theme.color.mutedForeground) }
    }

    private func stateStyle(_ state: String) -> (glyph: String, fill: Color) {
        switch state {
        case "idle": return ("\u{23F8}", theme.color.muted)
        case "active": return ("\u{25B6}", theme.color.success)
        case "sleeping": return ("\u{1F4A4}", theme.color.muted)
        case "moving": return ("\u{1F6B6}", theme.color.info)
        case "eating": return ("\u{1F37D}", theme.color.success)
        case "waiting": return ("\u{23F3}", theme.color.warning)
        case "happy": return ("\u{1F60A}", theme.color.success)
        case "scared": return ("\u{1F628}", theme.color.error)
        case "done", "ready": return ("\u{2713}", theme.color.success)
        case "error": return ("\u{2717}", theme.color.error)
        case "cooldown": return ("\u{1F504}", theme.color.warning)
        default: return ("?", theme.color.muted)
        }
    }

    private var stateChip: some View {
        let style = stateStyle(current)
        return HStack(spacing: theme.density.spacing.space1) {
            caption(style.glyph, theme.color.foreground)
            caption(current, theme.color.foreground, weight: .medium)
        }
        .padding(.horizontal, theme.density.spacing.space1 + theme.density.spacing.space1 / 2)
        .padding(.vertical, theme.density.spacing.space1 / 2)
        .background(style.fill)
        .atomClip(theme, .pill)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack {
            AtomKit.typo(trait.string("name"), "body2", weight: "bold", onEvent: onEvent)
            Spacer(minLength: theme.density.spacing.space0)
            stateChip
        }
    }

    private func transitionChip(_ transition: AnyCodable, highlighted: Bool) -> some View {
        HStack(spacing: theme.density.spacing.space1) {
            caption(transition.string("event"), theme.color.accent, weight: highlighted ? .medium : .regular)
            caption("\u{2192}", theme.color.mutedForeground)
            caption(transition.string("to"), theme.color.success)
            if !transition.string("guardHint").isEmpty { caption("\u{26A0}", theme.color.warning) }
        }
        .padding(.horizontal, theme.density.spacing.space2)
        .padding(.vertical, theme.density.spacing.space1)
        .background(highlighted ? theme.color.primary.opacity(0.1) : theme.color.muted)
        .atomClip(theme, .interactive)
        .atomBorder(theme, .interactive, color: highlighted ? theme.color.primary.opacity(0.3) : AtomKit.clear(theme), width: theme.geometry.borderStandard)
    }

    private func ruled<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
            theme.color.border.frame(height: theme.geometry.borderStandard)
            content()
        }
        .padding(.top, theme.density.spacing.space1)
    }

    private var linear: some View {
        let index = states.firstIndex(of: current) ?? -1
        return shell {
            description
            AtomFlowLayout(spacing: theme.density.spacing.space1) {
                ForEach(states.indices, id: \.self) { position in
                    let done = position < index
                    let here = position == index
                    HStack(spacing: theme.density.spacing.space1) {
                        if position > 0 { AtomKit.ink(theme, "\u{2192}", "lg", color: done || here ? theme.color.primary : theme.color.mutedForeground) }
                        HStack(spacing: theme.density.spacing.space1) {
                            caption(done ? "\u{2714}" : (here ? "\u{25CF}" : "\u{25CB}"), here || done ? theme.color.foreground : theme.color.mutedForeground)
                            AtomKit.ink(theme, states[position], fontKey, weight: here ? .bold : .regular, color: here || done ? theme.color.foreground : theme.color.mutedForeground)
                        }
                        .padding(.horizontal, theme.density.spacing.space3)
                        .padding(.vertical, theme.density.spacing.space1)
                        .background(done ? theme.color.success.opacity(0.2) : (here ? theme.color.primary.opacity(0.2) : theme.color.muted))
                        .atomClip(theme, .pill)
                        .atomBorder(theme, .pill, color: done ? theme.color.success : (here ? theme.color.primary : theme.color.border), width: theme.geometry.borderHeavy)
                        .atomElevation(theme, .pill, here ? theme.elevation.cardElevation : AtomKit.noShadow(theme))
                        .accessibilityAddTraits(here ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var compact: some View {
        shell {
            header
            description
            if !outgoing.isEmpty {
                ruled {
                    caption("Available Actions:", theme.color.mutedForeground)
                    AtomFlowLayout(spacing: theme.density.spacing.space1) {
                        ForEach(outgoing.indices, id: \.self) { position in transitionChip(outgoing[position], highlighted: false) }
                    }
                }
            }
        }
    }

    private func node(_ state: String) -> some View {
        let here = state == current
        let live = transitions.contains { $0.string("from") == state }
        let click = props.string("onStateClick")
        let box = AtomKit.ink(theme, state, fontKey, weight: here ? .bold : .regular, color: here ? theme.color.primary : theme.color.foreground.opacity(0.8))
            .lineLimit(1)
            .padding(.horizontal, theme.density.spacing.space2)
            .frame(minWidth: nodeMinWidth, minHeight: nodeHeight)
            .background(here ? theme.color.primary.opacity(0.2) : (live ? theme.color.muted : theme.color.background))
            .atomClip(theme, .container)
            .atomBorder(theme, .container, color: here ? theme.color.primary : theme.color.border, width: theme.geometry.borderHeavy)
            .atomElevation(theme, .container, here ? theme.elevation.cardElevation : AtomKit.noShadow(theme))
            .opacity(here || live ? 1 : 0.6)
            .accessibilityAddTraits(here ? .isSelected : [])
        return Group {
            if click.isEmpty {
                box
            } else {
                box
                    .contentShape(Rectangle())
                    .onTapGesture { onEvent(click, eventEnvelope(props, payload: ["state": .string(state)])) }
                    .accessibilityAddTraits(.isButton)
                    .atomAction(click, props)
            }
        }
    }

    private var full: some View {
        let show = props.bool("showTransitions", default: true)
        return shell {
            header
            description
            AtomFlowLayout(spacing: gap) {
                ForEach(states.indices, id: \.self) { position in node(states[position]) }
            }
            if show {
                ruled {
                    caption("Transitions:", theme.color.mutedForeground)
                    VStack(alignment: .leading, spacing: theme.density.spacing.space1) {
                        ForEach(transitions.indices, id: \.self) { position in
                            let transition = transitions[position]
                            let active = transition.string("from") == current
                            HStack(spacing: theme.density.spacing.space1) {
                                caption(transition.string("from"), active ? theme.color.primary : theme.color.mutedForeground, weight: active ? .medium : .regular)
                                caption("\u{2014}[", theme.color.mutedForeground)
                                caption(transition.string("event"), theme.color.accent, weight: .medium)
                                caption("]\u{2192}", theme.color.mutedForeground)
                                caption(transition.string("to"), active ? theme.color.success : theme.color.foreground.opacity(0.7), weight: active ? .medium : .regular)
                                if !transition.string("guardHint").isEmpty { caption("\u{26A0} " + transition.string("guardHint"), theme.color.warning) }
                            }
                            .padding(.horizontal, theme.density.spacing.space2)
                            .padding(.vertical, theme.density.spacing.space1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(active ? theme.color.primary.opacity(0.1) : theme.color.muted.opacity(0.5))
                            .atomClip(theme, .interactive)
                        }
                    }
                }
                if !outgoing.isEmpty {
                    ruled {
                        caption("Available now:", theme.color.primary, weight: .medium)
                        AtomFlowLayout(spacing: theme.density.spacing.space1) {
                            ForEach(outgoing.indices, id: \.self) { position in transitionChip(outgoing[position], highlighted: true) }
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        switch props.string("variant", default: "compact") {
        case "linear": linear
        case "full": full
        default: compact
        }
    }
}

/// The theme's resolved motion (orbital-core `resolve_motion`, the kernel snapshot's `motion`), read as
/// numbers: no CSS transform is parsed on this side. nil outside an app (snapshot tests): nothing animates.
struct AlmadarMotionShape {
    let scale: CGFloat
    let translateX: CGFloat
    let translateY: CGFloat
    let inlineSigned: Bool

    static let fade = AlmadarMotionShape(scale: 1, translateX: 0, translateY: 0, inlineSigned: false)

    /// A surface's enter shape (`modalEnter`, `popoverEnter`, `toastEnter`, ...).
    static func surface(_ motion: AnyCodable?, _ key: String) -> AlmadarMotionShape? {
        guard let shape = motion?.dictValue?["shapes"]?.dictValue?[key]?.dictValue else { return nil }
        return AlmadarMotionShape(
            scale: CGFloat(shape["scale"]?.doubleValue ?? 1),
            translateX: CGFloat(shape["translateX"]?.doubleValue ?? 0),
            translateY: CGFloat(shape["translateY"]?.doubleValue ?? 0),
            inlineSigned: shape["inlineSigned"]?.boolValue ?? false
        )
    }

    /// The shape an `enter` keyword starts from (`lib/enter.ts`); nil for `none`, an unknown keyword or outside an app.
    static func entry(_ motion: AnyCodable?, _ enter: String) -> AlmadarMotionShape? {
        guard motion != nil else { return nil }
        switch enter {
        case "fade": return .fade
        case "rise": return surface(motion, "enterRise")
        case "scale": return surface(motion, "enterScale")
        case "slide": return surface(motion, "enterSlide")
        default: return nil
        }
    }

    /// The entry slot content plays when it changes (`--motion-enter-default`).
    static func entryDefault(_ motion: AnyCodable?) -> String {
        motion?.dictValue?["entryDefault"]?.stringValue ?? "none"
    }

    /// One `enterDelay` step (`--motion-enter-stagger`), in seconds.
    static func staggerSeconds(_ motion: AnyCodable?) -> Double {
        (motion?.dictValue?["staggerMs"]?.doubleValue ?? 0) / 1000
    }
}

/// The duration and easing each entry plays with, as the web keyframes time it: `.almadar-enter-*` and
/// `animate-toast-in` are normal + emphasized, `animate-modal-in` / `animate-page-in` normal + standard,
/// `animate-popover-in` fast + standard.
enum AlmadarEnterTiming {
    case element, modal, popover, toast, page

    func animation(_ theme: AlmadarTheme) -> Animation {
        let m = theme.motion
        let (duration, curve): (Double, AlmadarTheme.MotionScale.Curve) = switch self {
        case .element, .toast: (m.durations.normal, m.easings.emphasized)
        case .modal, .page: (m.durations.normal, m.easings.standard)
        case .popover: (m.durations.fast, m.easings.standard)
        }
        return .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: duration)
    }
}

/// Plays `from` to the resting view when it appears, and again when `replayKey` changes. Off under the
/// OS reduced-motion setting.
struct AlmadarEnterModifier: ViewModifier {
    let from: AlmadarMotionShape?
    var delay: Double = 0
    var timing: AlmadarEnterTiming = .element
    var replayKey: String = ""
    @Environment(\.almadarTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var direction
    @State private var entered = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if let from, !reduceMotion {
            let x = from.inlineSigned && direction == .rightToLeft ? -from.translateX : from.translateX
            content
                .opacity(entered ? 1 : 0)
                .scaleEffect(entered ? 1 : from.scale)
                .offset(x: entered ? 0 : x, y: entered ? 0 : from.translateY)
                .onAppear { play() }
                .onChange(of: replayKey) { _ in
                    entered = false
                    DispatchQueue.main.async { play() }
                }
        } else {
            content
        }
    }

    private func play() {
        withAnimation(timing.animation(theme).delay(delay)) {
            entered = true
        }
    }
}

/// A node's declared `enter` and `enterDelay` stagger step (`lib/enter.ts` `enterClassName`).
struct AlmadarNodeEnter: ViewModifier {
    let enter: String
    let step: Double
    @Environment(\.almadarResolvedMotion) private var motion

    func body(content: Content) -> some View {
        let staggered = step >= 1 && step <= 8 && step == step.rounded() ? step : 0
        content.modifier(AlmadarEnterModifier(from: AlmadarMotionShape.entry(motion, enter), delay: staggered * AlmadarMotionShape.staggerSeconds(motion)))
    }
}

/// A surface's enter shape (`modalEnter`, `toastEnter`, ...) played on its content.
struct AlmadarSurfaceEnter: ViewModifier {
    let shape: String?
    let timing: AlmadarEnterTiming
    var replayKey: String = ""
    @Environment(\.almadarResolvedMotion) private var motion

    func body(content: Content) -> some View {
        content.modifier(AlmadarEnterModifier(from: shape.flatMap { AlmadarMotionShape.surface(motion, $0) }, timing: timing, replayKey: replayKey))
    }
}

/// A slot's theme-default entry (`lib/enter.ts` `slotPlaysDefaultEnter` + `useSlotEnterRestart`): not when
/// the root node declares its own `enter`; replayed when another trait or root pattern takes the slot.
struct AlmadarSlotEnter: ViewModifier {
    let content: AnyCodable?
    let contentKey: String
    @Environment(\.almadarResolvedMotion) private var motion

    func body(content view: Content) -> some View {
        let declared = content?.dictValue?["enter"] != nil
        view.modifier(AlmadarEnterModifier(from: declared ? nil : AlmadarMotionShape.entry(motion, AlmadarMotionShape.entryDefault(motion)), replayKey: contentKey))
    }
}

/// A host focusing the text field inside it (`chat-bar` `focusRequest`): every new token focuses the field.
private struct AlmadarFieldFocusTokenKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var almadarFieldFocusToken: String? {
        get { self[AlmadarFieldFocusTokenKey.self] }
        set { self[AlmadarFieldFocusTokenKey.self] = newValue }
    }
}

/// Events the app emits, for a renderer that LISTENS to one (an event-listen prop, e.g. code-block `onSetMode`).
/// The app's effect handler posts every `emit`; a renderer subscribes by the event name its prop names.
final class AlmadarBus {
    static let shared = AlmadarBus()
    let events = PassthroughSubject<AlmadarBusEvent, Never>()
    func post(_ event: String, _ payload: AnyCodable?) { events.send(AlmadarBusEvent(event: event, payload: payload)) }
}

struct AlmadarBusEvent {
    let event: String
    let payload: AnyCodable?
}

extension AtomKit {
    /// The DOM `KeyboardEvent.key` chord: modifiers in the fixed Control, Alt, Shift, Meta order, then the key.
    static func keyChord(_ key: String, ctrl: Bool, alt: Bool, shift: Bool, meta: Bool) -> String {
        var parts: [String] = []
        if ctrl { parts.append("Control") }
        if alt { parts.append("Alt") }
        if shift { parts.append("Shift") }
        if meta { parts.append("Meta") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    /// A key press as DOM `KeyboardEvent.key`.
    @available(iOS 17.0, *)
    static func domKey(_ press: KeyPress) -> String {
        switch press.key {
        case .escape: return "Escape"
        case .return: return "Enter"
        case .delete: return "Backspace"
        case .deleteForward: return "Delete"
        case .tab: return "Tab"
        case .space: return " "
        case .upArrow: return "ArrowUp"
        case .downArrow: return "ArrowDown"
        case .leftArrow: return "ArrowLeft"
        case .rightArrow: return "ArrowRight"
        case .home: return "Home"
        case .end: return "End"
        case .pageUp: return "PageUp"
        case .pageDown: return "PageDown"
        default: return press.characters
        }
    }

    /// DOM `KeyboardEvent.code` for a `domKey`: letters are `KeyX`, digits `DigitN`, the space bar `Space`; named keys keep their name.
    static func domCode(_ key: String) -> String {
        if key == " " { return "Space" }
        guard key.count == 1, let ch = key.first else { return key }
        if ch.isLetter { return "Key" + key.uppercased() }
        if ch.isNumber { return "Digit" + key }
        return key
    }
}
