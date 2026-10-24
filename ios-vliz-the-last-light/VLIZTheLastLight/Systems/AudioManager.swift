import AVFoundation

enum MusicTrack: String {
    case menu = "dark_ambient_menu_theme"
    case gameplay = "dark_synthwave_action"
    case boss = "boss_battle_music"
}

/// Music via AVAudioPlayer (looped, crossfaded); SFX via a small pool of
/// AVAudioPlayerNodes playing pre-synthesized buffers. Failure anywhere just means silence.
@MainActor
final class AudioManager {
    static let shared = AudioManager()

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var nextNode = 0
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var engineReady = false
    private var lastPlayed: [SFX: CFTimeInterval] = [:]

    private var musicPlayer: AVAudioPlayer?
    private var fadingPlayers: [AVAudioPlayer] = []
    private(set) var currentTrack: MusicTrack?
    private var musicVolume: Float = 0.6
    private var sfxVolume: Float = 0.8
    private var musicDuck: Float = 1

    private init() {}

    func start(settings: GameSettings) {
        apply(settings: settings)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[Audio] Session error: \(error)")
        }
        setupEngine()
    }

    private func setupEngine() {
        guard !engineReady else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: SynthBank.sampleRate, channels: 1) else { return }
        for sfx in SFX.allCases {
            let samples = SynthBank.samples(for: sfx)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else { continue }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                if let base = src.baseAddress { channel.update(from: base, count: samples.count) }
            }
            buffers[sfx] = buffer
        }
        for _ in 0..<10 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        engine.mainMixerNode.outputVolume = sfxVolume
        do {
            try engine.start()
            nodes.forEach { $0.play() }
            engineReady = true
        } catch {
            print("[Audio] Engine failed: \(error)")
        }
    }

    func apply(settings: GameSettings) {
        musicVolume = Float(settings.musicVolume)
        sfxVolume = Float(settings.sfxVolume)
        engine.mainMixerNode.outputVolume = sfxVolume
        musicPlayer?.volume = musicVolume * musicDuck
        Haptics.enabled = settings.haptics
    }

    /// Plays a sound effect. `volume` scales relative to the SFX setting; rapid repeats are throttled.
    func play(_ sfx: SFX, volume: Float = 1, pitchless: Bool = true) {
        guard sfxVolume > 0.001 else { return }
        if !engineReady || !engine.isRunning {
            engineReady = false
            do { try engine.start(); nodes.forEach { $0.play() }; engineReady = true } catch { return }
        }
        guard let buffer = buffers[sfx], !nodes.isEmpty else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlayed[sfx], now - last < 0.035 { return }
        lastPlayed[sfx] = now
        let node = nodes[nextNode]
        nextNode = (nextNode + 1) % nodes.count
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: Music

    func playMusic(_ track: MusicTrack, fade: TimeInterval = 1.2) {
        guard track != currentTrack else { return }
        currentTrack = track
        if let old = musicPlayer {
            old.setVolume(0, fadeDuration: fade)
            fadingPlayers.append(old)
            let captured = old
            DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.1) { [weak self] in
                captured.stop()
                self?.fadingPlayers.removeAll { $0 === captured }
            }
        }
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            musicPlayer = nil
            return
        }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        player.setVolume(musicVolume * musicDuck, fadeDuration: fade)
        musicPlayer = player
    }

    func stopMusic(fade: TimeInterval = 1) {
        currentTrack = nil
        guard let old = musicPlayer else { return }
        old.setVolume(0, fadeDuration: fade)
        musicPlayer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + fade + 0.1) { old.stop() }
    }

    /// Lowers music (e.g. while paused).
    func duckMusic(_ ducked: Bool) {
        musicDuck = ducked ? 0.35 : 1
        musicPlayer?.setVolume(musicVolume * musicDuck, fadeDuration: 0.3)
    }
}
