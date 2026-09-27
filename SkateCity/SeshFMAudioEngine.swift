// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import AVFoundation

/// Two-layer audio system for SkateCity.
///
/// Layer 1 — SeshFM: shuffled background music stream.
/// Layer 2 — Trick SFX: spatial one-shot pops, flips, grind loops, and landing hits.
///
/// Add audio files to the Xcode bundle to activate each layer:
///   Music : seshfm_track1.mp3 · seshfm_track2.mp3 · seshfm_track3.mp3
///   SFX   : sfx_ollie.wav · sfx_kickflip.wav · sfx_heelflip.wav
///           sfx_pop_shuvit.wav · sfx_grind_loop.wav · sfx_land.wav · sfx_bail.wav
final class SeshFMAudioEngine {

    static let shared = SeshFMAudioEngine()

    // MARK: - Engine graph

    private let engine      = AVAudioEngine()
    private let musicPlayer = AVAudioPlayerNode()
    private let sfxPlayer   = AVAudioPlayerNode()
    private let grindPlayer = AVAudioPlayerNode()
    private let masterMix   = AVAudioMixerNode()

    private var isRunning  = false
    private var trackIndex = 0

    private static let trackList: [String] = ["seshfm_track1", "seshfm_track2", "seshfm_track3"]
    private static let mixFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

    private init() { buildGraph() }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        configureSession()
        do {
            try engine.start()
            isRunning = true
            scheduleNextTrack()
        } catch {
            // Engine unavailable — game continues silently
        }
    }

    func stop() {
        [musicPlayer, sfxPlayer, grindPlayer].forEach { $0.stop() }
        engine.stop()
        isRunning = false
    }

    // MARK: - SeshFM music stream

    private func scheduleNextTrack() {
        let name = Self.trackList[trackIndex % Self.trackList.count]
        trackIndex += 1
        guard let url  = Bundle.main.url(forResource: name, withExtension: "mp3"),
              let file = try? AVAudioFile(forReading: url) else { return }
        musicPlayer.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async { self?.scheduleNextTrack() }
        }
        if !musicPlayer.isPlaying { musicPlayer.play() }
    }

    func setMusicVolume(_ v: Float) { musicPlayer.volume = v.clamped(to: 0...1) }

    // MARK: - Trick SFX

    func playTrickSFX(for trick: TrickRegistryType) {
        switch trick {
        case .ollie:
            playSFX("sfx_ollie")
        case .kickflip, .doubleKickflip, .varialKickflip, .hardflip, .threeFlip, .impossible:
            playSFX("sfx_kickflip")
        case .heelflip, .varialHeelflip:
            playSFX("sfx_heelflip")
        case .popShuvit, .threeShoveIt:
            playSFX("sfx_pop_shuvit")
        }
    }

    func playLandingSFX() { playSFX("sfx_land") }
    func playBailSFX()    { playSFX("sfx_bail") }

    private func playSFX(_ name: String) {
        guard let url  = Bundle.main.url(forResource: name, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url) else { return }
        sfxPlayer.scheduleFile(file, at: nil)
        if !sfxPlayer.isPlaying { sfxPlayer.play() }
    }

    // MARK: - Grind loop (looping buffer with volume fade)

    func startGrindLoop() {
        guard let url = Bundle.main.url(forResource: "sfx_grind_loop", withExtension: "wav"),
              let buf = makeLoopBuffer(from: url) else { return }
        grindPlayer.scheduleBuffer(buf, at: nil, options: .loops)
        grindPlayer.volume = 0
        grindPlayer.play()
        fadeGrind(to: 0.65, over: 0.15)
    }

    func stopGrindLoop() {
        fadeGrind(to: 0, over: 0.10) { [weak self] in self?.grindPlayer.stop() }
    }

    private func fadeGrind(to target: Float, over duration: TimeInterval, completion: (() -> Void)? = nil) {
        let steps = 10
        let dt    = duration / Double(steps)
        let start = grindPlayer.volume
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + dt * Double(i)) { [weak self] in
                guard let self else { return }
                grindPlayer.volume = start + (target - start) * Float(i) / Float(steps)
                if i == steps { completion?() }
            }
        }
    }

    private func makeLoopBuffer(from url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buf  = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        try? file.read(into: buf)
        return buf
    }

    // MARK: - Graph construction

    private func buildGraph() {
        [musicPlayer, sfxPlayer, grindPlayer, masterMix].forEach { engine.attach($0) }
        let fmt = Self.mixFormat
        engine.connect(musicPlayer, to: masterMix, format: fmt)
        engine.connect(sfxPlayer,   to: masterMix, format: fmt)
        engine.connect(grindPlayer, to: masterMix, format: fmt)
        engine.connect(masterMix,   to: engine.mainMixerNode, format: fmt)
        musicPlayer.volume  = 0.55
        sfxPlayer.volume    = 0.90
        grindPlayer.volume  = 0.00
    }

    private func configureSession() {
        #if os(iOS)
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: .mixWithOthers)
        try? s.setActive(true)
        #endif
    }
}

// MARK: - Float clamp helper

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
