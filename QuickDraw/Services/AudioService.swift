//
//  AudioService.swift
//  QuickDraw
//
//  All sounds are sine tones synthesized at runtime with AVAudioEngine — no
//  copyrighted assets, no bundle resources. Uses the .ambient session
//  category so the game respects the silent switch and mixes with music.
//

import Foundation
import AVFoundation

final class AudioService {

    /// Set from SettingsStore; when false every play call is a no-op.
    var isEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                            channels: 1)!
    private var started = false

    // MARK: Game cues

    func buttonTap() { play([Tone(frequency: 660, duration: 0.05, volume: 0.25)]) }
    func playerConnected() { play([Tone(frequency: 523, duration: 0.10, volume: 0.4),
                                   Tone(frequency: 784, duration: 0.12, volume: 0.4)]) }
    func readyCue() { play([Tone(frequency: 587, duration: 0.10, volume: 0.35)]) }
    func countdownReady() { play([Tone(frequency: 440, duration: 0.15, volume: 0.5)]) }
    func countdownSteady() { play([Tone(frequency: 554, duration: 0.15, volume: 0.5)]) }
    /// The DRAW cue is deliberately louder, higher and longer than everything
    /// else so it is audibly unmistakable.
    func drawSignal() { play([Tone(frequency: 1318, duration: 0.35, volume: 0.9)]) }
    func falseStart() { play([Tone(frequency: 196, duration: 0.35, volume: 0.7),
                              Tone(frequency: 147, duration: 0.35, volume: 0.7)]) }
    func win() { play([Tone(frequency: 523, duration: 0.12, volume: 0.6),
                       Tone(frequency: 659, duration: 0.12, volume: 0.6),
                       Tone(frequency: 784, duration: 0.20, volume: 0.6)]) }
    func lose() { play([Tone(frequency: 330, duration: 0.15, volume: 0.5),
                        Tone(frequency: 262, duration: 0.25, volume: 0.5)]) }

    // MARK: Synthesis

    private struct Tone {
        let frequency: Double
        let duration: Double
        let volume: Float
    }

    private func play(_ tones: [Tone]) {
        guard isEnabled else { return }
        ensureStarted()
        guard started else { return }
        for tone in tones {
            if let buffer = makeBuffer(tone) {
                player.scheduleBuffer(buffer, completionHandler: nil)
            }
        }
        if !player.isPlaying { player.play() }
    }

    private func ensureStarted() {
        guard !started else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            started = true
        } catch {
            Log.audio.error("Audio unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeBuffer(_ tone: Tone) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(tone.duration * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        // 8 ms attack/release envelope avoids clicks at buffer edges.
        let ramp = min(Int(0.008 * sampleRate), Int(frames) / 2)
        for i in 0..<Int(frames) {
            var amplitude = tone.volume
            if i < ramp { amplitude *= Float(i) / Float(ramp) }
            if i > Int(frames) - ramp { amplitude *= Float(Int(frames) - i) / Float(ramp) }
            channel[i] = sinf(Float(2.0 * .pi * tone.frequency * Double(i) / sampleRate)) * amplitude
        }
        return buffer
    }
}
