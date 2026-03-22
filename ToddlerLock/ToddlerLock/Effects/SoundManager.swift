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

    /// Background music melody — a gentle repeating pattern in C major pentatonic
    private let melodyPattern: [Float] = [
        261.63, 329.63, 392.00, 329.63, 440.00, 392.00, 329.63, 261.63,
        293.66, 392.00, 440.00, 392.00, 523.25, 440.00, 392.00, 293.66,
        329.63, 440.00, 523.25, 440.00, 392.00, 329.63, 293.66, 261.63,
    ]

    /// Whether background music is currently playing
    private var isMusicPlaying = false
    private var musicPlayerNode: AVAudioPlayerNode?

    /// Whether background music is enabled
    var musicEnabled: Bool = false

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

    // MARK: - Background Music

    /// Start looping background music.
    func startMusic() {
        guard musicEnabled, !isMusicPlaying else { return }
        ensureEngine()
        guard isRunning, let engine = engine else { return }

        let sampleRate: Float = 44100.0
        let noteLength: Float = 0.4  // seconds per note
        let totalNotes = melodyPattern.count
        let totalSamples = Int(sampleRate * noteLength) * totalNotes

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)
        guard let floatData = buffer.floatChannelData?[0] else { return }

        let samplesPerNote = Int(sampleRate * noteLength)
        let volume: Float = 0.12  // Quiet background

        for noteIndex in 0..<totalNotes {
            let freq = melodyPattern[noteIndex]
            let noteStart = noteIndex * samplesPerNote

            for i in 0..<samplesPerNote {
                let t = Float(i) / sampleRate
                var sample = sin(2.0 * .pi * freq * t)

                // Add a softer harmonic for warmth
                sample += 0.3 * sin(2.0 * .pi * freq * 2.0 * t)

                // Envelope: smooth attack and release per note
                let attackLen = Int(sampleRate * 0.03)
                let releaseLen = Int(sampleRate * 0.08)

                if i < attackLen {
                    sample *= Float(i) / Float(attackLen)
                } else if i > samplesPerNote - releaseLen {
                    sample *= Float(samplesPerNote - i) / Float(releaseLen)
                }

                floatData[noteStart + i] = sample * volume
            }
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Loop the buffer
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        musicPlayerNode = player
        isMusicPlaying = true
        print("[SoundManager] Background music started")
    }

    /// Stop background music.
    func stopMusic() {
        guard isMusicPlaying, let player = musicPlayerNode, let engine = engine else { return }
        player.stop()
        engine.detach(player)
        musicPlayerNode = nil
        isMusicPlaying = false
        print("[SoundManager] Background music stopped")
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
