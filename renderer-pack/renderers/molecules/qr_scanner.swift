import Foundation
import SwiftUI

// tier: molecules — a grouped container styled by tokens only

import AVFoundation

final class AtomQrPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
}

final class AtomQrSession: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "almadar.qr.session")
    private let metadata = AVCaptureMetadataOutput()
    private var lastValue = ""
    var onScan: (String) -> Void = { _ in }
    var onState: (String?, Bool) -> Void = { _, _ in }

    private func report(_ failure: String?, ready: Bool) {
        DispatchQueue.main.async { self.onState(failure, ready) }
    }

    func apply(facing: String, running: Bool) {
        queue.async {
            if !running {
                if self.session.isRunning { self.session.stopRunning() }
                DispatchQueue.main.async { self.lastValue = "" }
                self.report(nil, ready: false)
                return
            }
            let position: AVCaptureDevice.Position = facing == "user" ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                self.report("Camera API not available in this environment", ready: false)
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.start(device)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    self.queue.async {
                        if granted { self.start(device) } else { self.report("Camera permission denied", ready: false) }
                    }
                }
            default:
                self.report("Camera permission denied", ready: false)
            }
        }
    }

    private func start(_ device: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            if session.canAddInput(input) { session.addInput(input) }
            if !session.outputs.contains(metadata), session.canAddOutput(metadata) {
                session.addOutput(metadata)
                metadata.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadata.metadataObjectTypes = [.qr]
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
            DispatchQueue.main.async { self.lastValue = "" }
            report(nil, ready: true)
        } catch {
            report(error.localizedDescription, ready: false)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let code = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }.first { $0.type == .qr }?.stringValue ?? ""
        if code.isEmpty {
            lastValue = ""
        } else if code != lastValue {
            lastValue = code
            onScan(code)
        }
    }
}

struct AtomQrCamera: UIViewRepresentable {
    let facing: String
    let running: Bool
    let onScan: (String) -> Void
    let onState: (String?, Bool) -> Void

    final class Coordinator {
        let session = AtomQrSession()
        var applied = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AtomQrPreviewView {
        let view = AtomQrPreviewView()
        view.previewLayer?.session = context.coordinator.session.session
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: AtomQrPreviewView, context: Context) {
        let coordinator = context.coordinator
        coordinator.session.onScan = onScan
        coordinator.session.onState = onState
        let key = "\(facing)|\(running)"
        if coordinator.applied != key {
            coordinator.applied = key
            coordinator.session.apply(facing: facing, running: running)
        }
    }

    static func dismantleUIView(_ view: AtomQrPreviewView, coordinator: Coordinator) {
        coordinator.session.apply(facing: "", running: false)
    }
}

struct AtomQrOverlay: View {
    let color: Color
    let arm: CGFloat
    let weight: CGFloat
    let hairline: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let left = proxy.size.width * 0.15
            let right = proxy.size.width * 0.85
            let top = proxy.size.height * 0.15
            let bottom = proxy.size.height * 0.85
            let middle = proxy.size.height / 2
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: left, y: top + arm))
                    path.addLine(to: CGPoint(x: left, y: top))
                    path.addLine(to: CGPoint(x: left + arm, y: top))
                    path.move(to: CGPoint(x: right - arm, y: top))
                    path.addLine(to: CGPoint(x: right, y: top))
                    path.addLine(to: CGPoint(x: right, y: top + arm))
                    path.move(to: CGPoint(x: left, y: bottom - arm))
                    path.addLine(to: CGPoint(x: left, y: bottom))
                    path.addLine(to: CGPoint(x: left + arm, y: bottom))
                    path.move(to: CGPoint(x: right - arm, y: bottom))
                    path.addLine(to: CGPoint(x: right, y: bottom))
                    path.addLine(to: CGPoint(x: right, y: bottom - arm))
                }
                .stroke(color, lineWidth: weight)
                Path { path in
                    path.move(to: CGPoint(x: left, y: middle))
                    path.addLine(to: CGPoint(x: right, y: middle))
                }
                .stroke(color.opacity(0.6), lineWidth: hairline)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct QrScannerMoleculeView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @Environment(\.almadarTheme) private var theme
    @State private var facing: String
    @State private var paused: Bool
    @State private var failure: String?
    @State private var ready = false

    init(props: AnyCodable, onEvent: @escaping (String, AnyCodable?) -> Void) {
        self.props = props
        self.onEvent = onEvent
        _facing = State(initialValue: props.string("facingMode", default: "environment"))
        _paused = State(initialValue: props.bool("paused"))
    }

    private var hasFallback: Bool {
        guard let node = props.dictValue?["fallback"] else { return false }
        if let text = node.stringValue { return !text.isEmpty }
        if let list = node.arrayValue { return !list.isEmpty }
        return node.dictValue != nil
    }

    private func emit(_ text: String) {
        let event = props.string("scanEvent")
        if event.isEmpty { return }
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        onEvent(event, eventEnvelope(props, payload: .dict(["text": .string(text), "format": "QR_CODE", "timestamp": .int(timestamp)])))
    }

    private func control(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        AtomKit.icon(icon, "sm", color: "inverse", onEvent: onEvent)
            .padding(theme.density.spacing.space2)
            .background(theme.color.foreground.opacity(0.6), in: Circle())
            .contentShape(Circle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var failureLayer: some View {
        if let failure = failure {
            VStack(spacing: theme.density.spacing.space2) {
                AtomKit.icon("camera", "lg", color: "inverse", onEvent: onEvent)
                AtomKit.ink(theme, "Camera unavailable", "sm", color: theme.color.background)
                AtomKit.ink(theme, failure, "xs", color: theme.color.background).opacity(0.7)
            }
            .multilineTextAlignment(.center)
            .padding(theme.density.spacing.space4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var body: some View {
        if failure != nil, hasFallback {
            AtomSlot(props.dictValue?["fallback"], onEvent: onEvent)
        } else {
            ZStack {
                theme.color.foreground
                AtomQrCamera(
                    facing: facing,
                    running: !paused,
                    onScan: { text in emit(text) },
                    onState: { message, isReady in
                        failure = message
                        ready = isReady
                    }
                )
                if props.bool("showOverlay", default: true), ready, !paused {
                    AtomQrOverlay(color: theme.color.background, arm: theme.density.spacing.space8, weight: theme.geometry.borderHeavy, hairline: theme.geometry.borderHairline)
                }
                failureLayer
                if paused, failure == nil {
                    ZStack {
                        theme.color.scrim
                        AtomKit.ink(theme, "Paused", "sm", color: theme.color.background)
                    }
                }
                if props.bool("showCameraControls", default: true) {
                    VStack {
                        Spacer(minLength: theme.density.spacing.space0)
                        HStack(spacing: theme.density.spacing.space2) {
                            control(paused ? "play" : "pause", paused ? "Resume scanning" : "Pause scanning") { paused.toggle() }
                            control("refresh-cw", facing == "environment" ? "Switch to front camera" : "Switch to rear camera") { facing = facing == "environment" ? "user" : "environment" }
                        }
                        .padding(.bottom, theme.density.spacing.space3)
                    }
                }
            }
            .frame(maxWidth: AlmadarSizes.maxWMd)
            .aspectRatio(1, contentMode: .fit)
            .atomClip(theme, .interactive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: props.bool("paused")) { next in paused = next }
            .onChange(of: props.string("facingMode", default: "environment")) { next in facing = next }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(props.string("aria-label", default: "QR scanner"))
        }
    }
}

@ViewBuilder
func QrScannerRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(QrScannerMoleculeView(props: props, onEvent: onEvent))
}
