import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

struct ImageAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme

    var body: some View {
        if AtomKit.assetURL(props, "src").isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let src = AtomKit.assetURL(props, "src")
        let alt = props.string("alt")
        let fit = props.string("fit", default: "cover")
        let roundedToken = props.string("rounded", default: "md")
        let role: AtomRole = roundedToken == "full" ? .pill : .container
        let radius = AtomKit.radius(theme, roundedToken)
        let shape = AtomKit.shape(theme, role, radius: radius)
        ImageSource(src: src) { image in
            switch fit {
            case "contain", "scale-down": image.resizable().aspectRatio(contentMode: .fit)
            case "fill": image.resizable()
            case "none": image
            default: image.resizable().aspectRatio(contentMode: .fill)
            }
        } failed: {
            theme.color.muted.overlay(Image(systemName: IconMap.resolve("image")).foregroundColor(theme.color.mutedForeground))
        } loading: {
            theme.color.muted.overlay(ProgressView().tint(theme.color.mutedForeground))
        }
        .aspectRatio(ratio(props.string("aspect", default: "auto")), contentMode: .fit)
        .clipShape(shape)
        .atomBorder(theme, role, radius: radius, color: props.bool("bordered") ? theme.color.border : AtomKit.clear(theme), width: theme.geometry.borderStandard)
        .accessibilityLabel(Text(alt))
        .accessibilityHidden(alt.isEmpty)
    }

    private func ratio(_ token: String) -> CGFloat? {
        switch token {
        case "1/1": return 1
        case "4/3": return 4.0 / 3.0
        case "3/2": return 3.0 / 2.0
        case "16/9": return 16.0 / 9.0
        case "21/9": return 21.0 / 9.0
        default: return nil
        }
    }
}

/// Fetches `src` and paints it: SVG (by the canvas asset rule) through orbital-canvas at the drawn
/// width times the display scale, anything else through UIKit's decoders.
private struct ImageSource<Painted: View, Failed: View, Loading: View>: View {
    let src: String
    @ViewBuilder let painted: (Image) -> Painted
    @ViewBuilder let failed: () -> Failed
    @ViewBuilder let loading: () -> Loading
    @Environment(\.displayScale) private var displayScale
    @State private var fetched: Fetched?
    @State private var drawnWidth: CGFloat = 0

    private enum Fetched {
        case raster(UIImage)
        case svg(Data, intrinsic: CGSize)
        case failed
    }

    var body: some View {
        Group {
            switch fetched {
            case .raster(let image)?: painted(Image(uiImage: image))
            case .svg(let data, let intrinsic)?:
                if let image = OrbitalSvg.image(key: src, data: data, pixelsPerUnit: pixelsPerUnit(intrinsic)) {
                    painted(Image(uiImage: image))
                        .background(GeometryReader { geo in
                            Color.clear
                                .onAppear { drawnWidth = geo.size.width }
                                .onChange(of: geo.size.width) { drawnWidth = $0 }
                        })
                } else {
                    failed()
                }
            case .failed?: failed()
            case nil: loading()
            }
        }
        .task(id: src) { fetched = await Self.fetch(src) }
    }

    private func pixelsPerUnit(_ intrinsic: CGSize) -> CGFloat {
        guard drawnWidth > 0, intrinsic.width > 0 else { return displayScale }
        return displayScale * max(1, drawnWidth / intrinsic.width)
    }

    private static func fetch(_ src: String) async -> Fetched {
        guard let url = URL(string: src) else {
            NSLog("[ImageAtom] not a URL: %@", src)
            return .failed
        }
        let data: Data
        let mime: String?
        if url.scheme == "data" {
            guard let decoded = OrbitalSvg.decodeDataURL(src) else { return .failed }
            (data, mime) = decoded
        } else {
            do {
                let (body, response) = try await URLSession.shared.data(from: url)
                (data, mime) = (body, response.mimeType)
            } catch {
                NSLog("[ImageAtom] load failed (%@): %@", error.localizedDescription, src)
                return .failed
            }
        }
        if OrbitalSvg.isSvg(url: src, contentType: mime) {
            guard let intrinsic = OrbitalSvg.intrinsicSize(key: src, data: data) else { return .failed }
            return .svg(data, intrinsic: intrinsic)
        }
        guard let image = UIImage(data: data) else {
            NSLog("[ImageAtom] did not decode as an image: %@", src)
            return .failed
        }
        return .raster(image)
    }
}

@ViewBuilder
func ImageRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(ImageAtomView(props: props, onEvent: onEvent))
}
