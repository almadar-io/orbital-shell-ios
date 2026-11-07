import AVFoundation
import Foundation
import SwiftUI

/// A sound std-audio-cue resolved; the host plays it as given.
private struct AudioPlay: Codable, Equatable {
    let key: String
    let source: String
    let volume: Float
    let loop: Bool
    let poolSize: Int
    let fadeMs: Double
}

private func decodePlan<T: Decodable>(_ value: AnyCodable?, as type: T.Type) -> T? {
    guard let value else { return nil }
    do {
        return try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    } catch {
        NSLog("OrbitalAudio: invalid game-audio-cue plan: %@", String(describing: error))
        return nil
    }
}

final class AtomAudioDriver: ObservableObject {
    private struct CueVoice {
        let player: AVPlayer
        let observer: NSObjectProtocol
        let entry: AudioPlay
    }

    private var cues: [String: [CueVoice]] = [:]
    private var music: AVPlayer?
    private var musicEntry: AudioPlay?
    private var musicObserver: NSObjectProtocol?
    private var fadeTimer: Timer?
    private var fadeOutgoing: AVPlayer?
    private var priorCueSeq: Double?
    private var priorMusic: AudioPlay?
    private var synced = false
    private var autostart: [AudioPlay] = []
    private var unlocked = false
    private var suspended = false
    private var muted = false
    private var volume: Float = 1

    func sync(_ next: AnyCodable) {
        muted = next.bool("muted")
        volume = Float(next.float("volume", default: 1))
        autostart = decodePlan(next["autostart"], as: [AudioPlay].self) ?? []
        let cueSeq = next["cueSeq"]?.doubleValue
        let music = decodePlan(next["musicPlay"], as: AudioPlay.self)
        if !synced || music != priorMusic, let music {
            changeMusic(music)
        }
        if synced, let before = priorCueSeq, let now = cueSeq, before != now,
           let cue = decodePlan(next["cuePlay"], as: AudioPlay.self), !cue.key.isEmpty {
            play(cue)
        }
        synced = true
        priorCueSeq = cueSeq
        priorMusic = music
        if !unlocked && !muted {
            autostart.forEach(play)
            unlocked = true
        }
        applyVolumes()
    }

    private func source(_ path: String) -> URL? {
        if let url = URL(string: path), url.scheme != nil { return url }
        return Bundle.main.resourceURL?.appendingPathComponent(path)
    }

    private func level(_ entry: AudioPlay) -> Float {
        muted || suspended ? 0 : min(1, entry.volume * volume)
    }

    private func play(_ sound: AudioPlay) {
        let key = sound.key
        guard !muted, let url = source(sound.source) else { return }
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

    private func changeMusic(_ sound: AudioPlay) {
        clearFade()
        let outgoing = music
        if let musicObserver { NotificationCenter.default.removeObserver(musicObserver) }
        musicObserver = nil
        music = nil
        musicEntry = nil
        guard !sound.key.isEmpty, let url = source(sound.source) else {
            fadeOut(outgoing, over: sound.fadeMs)
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
        guard let outgoing, sound.fadeMs > 0 else {
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
            let fraction = min(1, Float((ProcessInfo.processInfo.systemUptime - started) * 1000 / sound.fadeMs))
            incoming.volume = self.level(sound) * fraction
            outgoing.volume = oldVolume * (1 - fraction)
            if fraction >= 1 { self.clearFade() }
        }
    }

    private func fadeOut(_ outgoing: AVPlayer?, over fadeMs: Double) {
        guard let outgoing else { return }
        guard fadeMs > 0, !suspended else { outgoing.pause(); return }
        fadeOutgoing = outgoing
        let oldVolume = outgoing.volume
        let started = ProcessInfo.processInfo.systemUptime
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak outgoing] timer in
            guard let self, let outgoing else { timer.invalidate(); return }
            let fraction = min(1, Float((ProcessInfo.processInfo.systemUptime - started) * 1000 / fadeMs))
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
        priorCueSeq = nil
        priorMusic = nil
        synced = false
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
