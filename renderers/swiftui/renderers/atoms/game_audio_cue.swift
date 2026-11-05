import AVFoundation
import Foundation
import SwiftUI

@_silgen_name("orbital_audio_plan")
private func orbital_audio_plan(_ previous: UnsafePointer<CChar>?, _ next: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("orbital_audio_unlock")
private func orbital_audio_unlock(_ next: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
@_silgen_name("orbital_audio_free_string")
private func orbital_audio_free_string(_ value: UnsafeMutablePointer<CChar>)

private struct AudioPlan: Decodable {
    let actions: [AudioAction]?
    let error: String?
}

private struct AudioAction: Decodable {
    let kind: String
    let key: String?
    let sources: [String]?
    let volume: Float?
    let looping: Bool?
    let poolSize: Int?
    let crossfadeMs: Double?
}

private enum AudioPolicyBridge {
    static func plan(previous: String?, next: String, unlock: Bool = false) -> [AudioAction]? {
        let pointer = next.withCString { nextPointer in
            if unlock { return orbital_audio_unlock(nextPointer) }
            if let previous {
                return previous.withCString { orbital_audio_plan($0, nextPointer) }
            }
            return orbital_audio_plan(nil, nextPointer)
        }
        guard let pointer else { NSLog("OrbitalAudio: policy returned no plan"); return nil }
        defer { orbital_audio_free_string(pointer) }
        guard let data = String(cString: pointer).data(using: .utf8),
              let response = try? JSONDecoder().decode(AudioPlan.self, from: data) else {
            NSLog("OrbitalAudio: invalid policy plan")
            return nil
        }
        if let error = response.error { NSLog("OrbitalAudio: policy error: %@", error); return nil }
        return response.actions ?? []
    }
}

private struct AudioEntry {
    let paths: [String]
    let volume: Float
    let loop: Bool
    let poolSize: Int
    let crossfadeMs: Double

    init?(_ action: AudioAction) {
        paths = action.sources ?? []
        if paths.isEmpty { return nil }
        volume = action.volume ?? 1
        loop = action.looping ?? false
        poolSize = max(1, action.poolSize ?? 1)
        crossfadeMs = max(0, action.crossfadeMs ?? 1500)
    }
}

final class AtomAudioDriver: ObservableObject {
    private struct CueVoice {
        let player: AVPlayer
        let observer: NSObjectProtocol
        let entry: AudioEntry
    }

    private var cues: [String: [CueVoice]] = [:]
    private var music: AVPlayer?
    private var musicEntry: AudioEntry?
    private var musicObserver: NSObjectProtocol?
    private var fadeTimer: Timer?
    private var fadeOutgoing: AVPlayer?
    private var priorFrame: String?
    private var unlocked = false
    private var suspended = false
    private var muted = false
    private var volume: Float = 1

    func sync(_ next: AnyCodable) {
        muted = next.bool("muted")
        volume = min(1, max(0, Float(next.float("volume", default: 1))))
        guard let data = try? JSONEncoder().encode(next), let frame = String(data: data, encoding: .utf8),
              let actions = AudioPolicyBridge.plan(previous: priorFrame, next: frame) else { return }
        execute(actions)
        priorFrame = frame
        if !unlocked && !muted, let start = AudioPolicyBridge.plan(previous: nil, next: frame, unlock: true) {
            execute(start)
            unlocked = true
        }
        applyVolumes()
    }

    private func execute(_ actions: [AudioAction]) {
        for action in actions {
            switch action.kind {
            case "playCue":
                if let key = action.key, let entry = AudioEntry(action) { play(key, entry: entry) }
            case "changeMusic":
                if let key = action.key, let entry = AudioEntry(action) { changeMusic(key, entry: entry) }
            case "stopMusic": changeMusic("", entry: nil)
            case "setMuted", "setVolume": applyVolumes()
            default: NSLog("OrbitalAudio: unknown policy action %@", action.kind)
            }
        }
    }

    private func source(_ path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil { return url }
        return Bundle.main.resourceURL?.appendingPathComponent(path)
    }

    private func level(_ entry: AudioEntry) -> Float {
        muted || suspended ? 0 : min(1, entry.volume * volume)
    }

    private func play(_ key: String, entry sound: AudioEntry) {
        guard !muted, let path = sound.paths.randomElement(), let url = source(path) else { return }
        var pool = cues[key] ?? []
        if pool.count >= sound.poolSize {
            if sound.loop { return }
            let oldest = pool.removeFirst()
            NotificationCenter.default.removeObserver(oldest.observer)
            oldest.player.pause()
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = level(sound)
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self, weak player] _ in
            guard let self, let player else { return }
            if sound.loop {
                player.seek(to: .zero)
                if !self.suspended { player.play() }
            } else {
                self.removeCue(key, player: player)
            }
        }
        pool.append(CueVoice(player: player, observer: observer, entry: sound))
        cues[key] = pool
        if !suspended { player.play() }
    }

    private func removeCue(_ key: String, player: AVPlayer) {
        guard let pool = cues[key], let index = pool.firstIndex(where: { $0.player === player }) else { return }
        NotificationCenter.default.removeObserver(pool[index].observer)
        cues[key]?.remove(at: index)
    }

    private func clearFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeOutgoing?.pause()
        fadeOutgoing = nil
    }

    private func changeMusic(_ key: String, entry sound: AudioEntry?) {
        clearFade()
        let outgoing = music
        if let musicObserver { NotificationCenter.default.removeObserver(musicObserver) }
        musicObserver = nil
        music = nil
        musicEntry = nil
        guard !key.isEmpty, let sound, let path = sound.paths.first, let url = source(path) else {
            outgoing?.pause()
            return
        }
        let item = AVPlayerItem(url: url)
        let incoming = AVPlayer(playerItem: item)
        music = incoming
        musicEntry = sound
        musicObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self, weak incoming] _ in
            guard let self, let incoming else { return }
            incoming.seek(to: .zero)
            if !self.suspended { incoming.play() }
        }
        if !suspended { incoming.play() }
        guard let outgoing, sound.crossfadeMs > 0 else {
            outgoing?.pause()
            incoming.volume = level(sound)
            return
        }
        incoming.volume = 0
        fadeOutgoing = outgoing
        let oldVolume = outgoing.volume
        let started = ProcessInfo.processInfo.systemUptime
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak incoming, weak outgoing] timer in
            guard let self, let incoming, let outgoing else { timer.invalidate(); return }
            let fraction = min(1, Float((ProcessInfo.processInfo.systemUptime - started) * 1000 / sound.crossfadeMs))
            incoming.volume = self.level(sound) * fraction
            outgoing.volume = oldVolume * (1 - fraction)
            if fraction >= 1 { self.clearFade() }
        }
    }

    private func applyVolumes() {
        if let music, let musicEntry, fadeTimer == nil { music.volume = level(musicEntry) }
        music?.isMuted = muted
        fadeOutgoing?.isMuted = muted
        for voices in cues.values {
            for voice in voices {
                voice.player.volume = level(voice.entry)
                voice.player.isMuted = muted
            }
        }
    }

    func suspend() {
        suspended = true
        clearFade()
        music?.pause()
        for voices in cues.values { voices.forEach { $0.player.pause() } }
    }

    func resume() {
        suspended = false
        music?.play()
        for voices in cues.values { voices.forEach { $0.player.play() } }
        applyVolumes()
    }

    func close() {
        clearFade()
        music?.pause()
        if let musicObserver { NotificationCenter.default.removeObserver(musicObserver) }
        musicObserver = nil
        music = nil
        for voices in cues.values {
            for voice in voices {
                voice.player.pause()
                NotificationCenter.default.removeObserver(voice.observer)
            }
        }
        cues.removeAll()
        priorFrame = nil
        unlocked = false
    }

    deinit { close() }
}

struct GameAudioCueAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @StateObject private var driver = AtomAudioDriver()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Spacer()
            .frame(width: 0, height: 0)
            .onAppear { driver.sync(props) }
            .onChange(of: props) { value in driver.sync(value) }
            .onChange(of: scenePhase) { phase in
                if phase == .active { driver.resume() } else { driver.suspend() }
            }
            .onDisappear { driver.close() }
            .accessibilityHidden(true)
    }
}

@ViewBuilder
func GameAudioCueRenderer(
    props: AnyCodable,
    modifier: AnyView?,
    onEvent: @escaping (String, AnyCodable?) -> Void
) -> AnyView {
    AnyView(GameAudioCueAtomView(props: props, onEvent: onEvent))
}
