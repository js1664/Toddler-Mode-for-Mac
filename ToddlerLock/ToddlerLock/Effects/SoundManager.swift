import AVFoundation
import AppKit

/// Manages sound effects for the toddler lock modes.
/// Uses AVAudioEngine for low-latency synthesized tones.
/// Keys are mapped to a pentatonic scale (always sounds pleasant).
final class SoundManager {
    static let shared = SoundManager()

    private var engine: AVAudioEngine?
    private var isRunning = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    /// Whether sounds are enabled
    var enabled: Bool = true

    /// Pentatonic scale frequencies (C major pentatonic across 2 octaves)
    /// These always sound pleasant together no matter the order.
    private let frequencies: [Float] = [
        261.63, // C4
        293.66, // D4
        329.63, // E4
        392.00, // G4
        440.00, // A4
        523.25, // C5
        587.33, // D5
        659.25, // E5
        783.99, // G5
        880.00, // A5
    ]

    /// Pop sound for shape/bubble interactions
    private let popFrequencies: [Float] = [880.0, 1108.73, 1318.51]

    private init() {
        // Defer engine setup until first use to avoid crash at launch
    }

    /// Lazily start the audio engine. Called on first sound play.
    private func ensureEngine() {
        guard engine == nil else { return }

        let eng = AVAudioEngine()

        // We must attach and connect at least one player node before starting,
        // otherwise AVAudioEngine crashes with "inputNode != nullptr" assertion.
        let silentNode = AVAudioPlayerNode()
        eng.attach(silentNode)
        eng.connect(silentNode, to: eng.mainMixerNode, format: format)

        do {
            try eng.start()
            engine = eng
            isRunning = true
            // Detach the bootstrap node now that the engine is running
            eng.detach(silentNode)
            print("[SoundManager] Audio engine started successfully")
        } catch {
            print("[SoundManager] Failed to start audio engine: \(error)")
            isRunning = false
        }
    }

    /// Play a tone for a key press. Maps keyCode to a pentatonic note.
    func playKeyTone(keyCode: UInt16) {
        guard enabled else { return }
        ensureEngine()
        guard isRunning else { return }

        let index = Int(keyCode) % frequencies.count
        let frequency = frequencies[index]
        playTone(frequency: frequency, duration: 0.2, volume: 0.3)
    }

    /// Play a pop sound for clicking/popping.
    func playPop() {
        guard enabled else { return }
        ensureEngine()
        guard isRunning else { return }

        let freq = popFrequencies.randomElement() ?? 880.0
        playTone(frequency: freq, duration: 0.1, volume: 0.25, decay: true)
    }

    /// Play a short whoosh for mouse actions.
    func playWhoosh() {
        guard enabled else { return }
        ensureEngine()
        guard isRunning else { return }

        playTone(frequency: 600, duration: 0.15, volume: 0.15, decay: true)
    }

    // MARK: - Tone Generation

    private func playTone(frequency: Float, duration: Float, volume: Float, decay: Bool = false) {
        guard let engine = engine else { return }

        let sampleRate: Float = 44100.0
        let sampleCount = Int(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        guard let floatData = buffer.floatChannelData?[0] else { return }

        for i in 0..<sampleCount {
            let t = Float(i) / sampleRate
            var sample = sin(2.0 * .pi * frequency * t)

            // Apply envelope
            let attackSamples = Int(sampleRate * 0.01) // 10ms attack
            let releaseSamples = Int(sampleRate * 0.05) // 50ms release

            if i < attackSamples {
                sample *= Float(i) / Float(attackSamples)
            } else if i > sampleCount - releaseSamples {
                let releasePos = Float(sampleCount - i) / Float(releaseSamples)
                sample *= releasePos
            }

            if decay {
                sample *= 1.0 - (t / duration)
            }

            floatData[i] = sample * volume
        }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        playerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async { [weak engine] in
                engine?.detach(playerNode)
            }
        }
        playerNode.play()
    }
}
