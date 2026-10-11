import Foundation
import SwiftUI

// tier: atoms — a single SwiftUI control

import AVFoundation

final class AtomAudioDriver: ObservableObject {
    private var music: AVPlayer?
    private var musicKey = ""
    private var observer: NSObjectProtocol?
    private var cues: [AVPlayer] = []

    func play(cue key: String, props: AnyCodable, volume: Float) {
        guard let url = source(key, props), let entry = props.dictValue?["manifest"]?.dictValue?[key] else { return }
        let player = AVPlayer(url: url)
        player.volume = min(1, Float(entry.dictValue?["volume"]?.doubleValue ?? 1) * volume)
        cues.removeAll { $0.timeControlStatus == .paused }
        cues.append(player)
        player.play()
    }

    func play(music key: String, props: AnyCodable, volume: Float) {
        guard key != musicKey else {
            music?.volume = volume
            return
        }
        stopMusic()
        guard let url = source(key, props) else { return }
        musicKey = key
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = min(1, Float(props.dictValue?["manifest"]?.dictValue?[key]?.dictValue?["volume"]?.doubleValue ?? 1) * volume)
        observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        music = player
        player.play()
    }

    func stopMusic() {
        music?.pause()
        music = nil
        musicKey = ""
        if let observer = observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    func mute(_ muted: Bool) {
        music?.isMuted = muted
        cues.forEach { $0.isMuted = muted }
    }

    private func source(_ key: String, _ props: AnyCodable) -> URL? {
        guard let entry = props.dictValue?["manifest"]?.dictValue?[key]?.dictValue, let path = entry["path"] else { return nil }
        let chosen = path.arrayValue.flatMap { $0.randomElement() } ?? path
        guard let relative = chosen.stringValue else { return nil }
        return URL(string: props.string("baseUrl") + relative)
    }

    deinit { stopMusic() }
}

struct GameAudioCueAtomView: View {
    let props: AnyCodable
    let onEvent: (String, AnyCodable?) -> Void
    @StateObject private var driver = AtomAudioDriver()

    var body: some View {
        let cue = props.string("cue")
        let seq = props.int("cueSeq", default: -1)
        let music = props.string("music")
        let muted = props.bool("muted")
        let volume = Float(props.float("volume", default: 1))
        Spacer()
            .frame(width: 0, height: 0)
            .onAppear {
                driver.mute(muted)
                if !music.isEmpty && !muted { driver.play(music: music, props: props, volume: volume) }
            }
            .onChange(of: seq) { _ in
                if !cue.isEmpty && !muted { driver.play(cue: cue, props: props, volume: volume) }
            }
            .onChange(of: music) { key in
                if key.isEmpty || muted { driver.stopMusic() } else { driver.play(music: key, props: props, volume: volume) }
            }
            .onChange(of: muted) { value in
                driver.mute(value)
                if value { driver.stopMusic() } else if !music.isEmpty { driver.play(music: music, props: props, volume: volume) }
            }
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
