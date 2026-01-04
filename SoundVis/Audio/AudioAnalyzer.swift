import Foundation
import Combine

struct Voice: Identifiable {
    let id: UUID
    var name: String
    var frequencyRange: ClosedRange<Float>
    var spectralCentroid: Float
    var spectralShape: [Float]
    var isActive: Bool
    var energy: Float
    var lastActiveTime: Date

    var color: Color {
        // Map frequency to color (low = warm, high = cool)
        let normalizedFreq = (spectralCentroid - 100) / 4000
        let hue = 0.6 - Double(normalizedFreq) * 0.5 // blue to red
        return Color(hue: max(0, min(1, hue)), saturation: 0.7, brightness: 0.9)
    }
}

import SwiftUI

@MainActor
class AudioAnalyzer: ObservableObject {
    @Published var bpm: Double = 0
    @Published var beatPhase: Double = 0
    @Published var bpmConfidence: Double = 0
    @Published var voices: [Voice] = []
    @Published var isCalibrating: Bool = true
    @Published var calibrationProgress: Double = 0
    @Published var error: String?

    private var captureManager: AudioCaptureManager?
    private var fftProcessor: FFTProcessor?
    private var beatTracker: BeatTracker?
    private var voiceTracker: VoiceTracker?

    private let calibrationDuration: TimeInterval = 30.0
    private var calibrationStartTime: Date?

    func start() {
        Task {
            do {
                // Initialize components
                fftProcessor = FFTProcessor()
                beatTracker = BeatTracker()
                voiceTracker = VoiceTracker()

                captureManager = AudioCaptureManager()
                captureManager?.onAudioBuffer = { [weak self] samples in
                    self?.processAudio(samples)
                }

                try await captureManager?.start()
                calibrationStartTime = Date()

            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func stop() {
        Task {
            await captureManager?.stop()
        }
    }

    private func processAudio(_ samples: [Float]) {
        guard let fftProcessor = fftProcessor,
              let beatTracker = beatTracker,
              let voiceTracker = voiceTracker else { return }

        // FFT
        let spectrum = fftProcessor.process(samples)

        // Beat tracking
        beatTracker.process(spectrum: spectrum)

        // Voice tracking
        voiceTracker.process(spectrum: spectrum, sampleRate: 48000)

        // Update UI on main thread
        Task { @MainActor in
            // Update BPM
            self.bpm = beatTracker.currentBPM
            self.beatPhase = beatTracker.beatPhase
            self.bpmConfidence = beatTracker.confidence

            // Update calibration
            if self.isCalibrating {
                if let startTime = self.calibrationStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    self.calibrationProgress = min(1.0, elapsed / self.calibrationDuration)

                    if elapsed >= self.calibrationDuration {
                        voiceTracker.finalizeCalibration()
                        self.isCalibrating = false
                    }
                }
            }

            // Update voices
            self.voices = voiceTracker.voices
        }
    }
}
