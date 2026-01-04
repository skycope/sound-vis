import Foundation
import AVFoundation
import Accelerate

// MARK: - FFT Processor

class FFTProcessor {
    private let fftSize: Int = 2048
    private let fftSetup: vDSP_DFT_Setup
    private var window: [Float]
    private var realPart: [Float]
    private var imagPart: [Float]

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)!
        window = [Float](repeating: 0, count: fftSize)
        realPart = [Float](repeating: 0, count: fftSize)
        imagPart = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }

    func process(_ samples: [Float]) -> [Float] {
        let count = min(samples.count, fftSize)
        var input = [Float](repeating: 0, count: fftSize)
        for i in 0..<count {
            input[fftSize - count + i] = samples[i]
        }

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        for i in 0..<fftSize {
            realPart[i] = windowed[i]
            imagPart[i] = 0
        }

        vDSP_DFT_Execute(fftSetup, realPart, imagPart, &realPart, &imagPart)

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realPart[i] * realPart[i] + imagPart[i] * imagPart[i]) / Float(fftSize)
        }
        return magnitudes
    }
}

// MARK: - Beat Tracker

class BeatTracker {
    private(set) var currentBPM: Double = 0
    private(set) var beatPhase: Double = 0
    private(set) var confidence: Double = 0

    private var previousSpectrum: [Float] = []
    private var onsetHistory: [Float] = []
    private let onsetHistorySize = 512
    private var tempoEstimates: [Double] = []
    private var lastBeatTime = Date()
    private var beatInterval: TimeInterval = 0.5
    private var frameCount = 0

    func process(spectrum: [Float]) {
        let onset = computeOnset(spectrum: spectrum)
        onsetHistory.append(onset)
        if onsetHistory.count > onsetHistorySize { onsetHistory.removeFirst() }
        previousSpectrum = spectrum
        frameCount += 1

        if frameCount % 8 == 0 && onsetHistory.count > 256 {
            estimateTempo()
        }
        updatePhase()
    }

    private func computeOnset(spectrum: [Float]) -> Float {
        guard !previousSpectrum.isEmpty else { return 0 }
        var flux: Float = 0
        for i in 0..<min(spectrum.count, previousSpectrum.count) {
            let diff = spectrum[i] - previousSpectrum[i]
            if diff > 0 { flux += diff }
        }
        return flux
    }

    private func estimateTempo() {
        let onsets = onsetHistory
        let minLag = 20  // ~180 BPM
        let maxLag = 60  // ~60 BPM

        var bestBPM: Double = 0
        var bestCorr: Float = 0

        for lag in minLag...maxLag {
            var sum: Float = 0
            let n = onsets.count - lag
            for i in 0..<n { sum += onsets[i] * onsets[i + lag] }
            let corr = sum / Float(n)
            if corr > bestCorr {
                bestCorr = corr
                bestBPM = 60.0 * 46.875 / Double(lag)  // ~47 fps at 48kHz/1024
            }
        }

        if bestBPM > 0 {
            tempoEstimates.append(bestBPM)
            if tempoEstimates.count > 16 { tempoEstimates.removeFirst() }
            let sorted = tempoEstimates.sorted()
            let median = sorted[sorted.count / 2]
            currentBPM = currentBPM == 0 ? median : currentBPM * 0.9 + median * 0.1
            beatInterval = 60.0 / currentBPM
            confidence = Double(bestCorr)
        }
    }

    private func updatePhase() {
        guard beatInterval > 0 else { return }
        let elapsed = Date().timeIntervalSince(lastBeatTime)
        beatPhase = (elapsed / beatInterval).truncatingRemainder(dividingBy: 1.0)
        if elapsed >= beatInterval {
            lastBeatTime = Date()
        }
    }
}

// MARK: - Voice Tracker

struct Voice {
    let id: UUID
    var name: String
    var frequencyRange: ClosedRange<Float>
    var isActive: Bool
    var energy: Float
    var lastActiveTime: Date
}

class VoiceTracker {
    private(set) var voices: [Voice] = []
    private(set) var isCalibrating = true

    private var spectralHistory: [[Float]] = []
    private let calibrationFrames = 1400  // ~30 seconds

    func process(spectrum: [Float]) {
        if isCalibrating {
            spectralHistory.append(spectrum)
            if spectralHistory.count >= calibrationFrames {
                finalizeCalibration()
            }
        } else {
            matchVoices(spectrum: spectrum)
        }
    }

    var calibrationProgress: Double {
        return Double(spectralHistory.count) / Double(calibrationFrames)
    }

    private func finalizeCalibration() {
        guard !spectralHistory.isEmpty else { isCalibrating = false; return }

        let binCount = spectralHistory[0].count
        var meanSpectrum = [Float](repeating: 0, count: binCount)
        for s in spectralHistory {
            for i in 0..<binCount { meanSpectrum[i] += s[i] }
        }
        for i in 0..<binCount { meanSpectrum[i] /= Float(spectralHistory.count) }

        // Find peaks
        var peaks: [(bin: Int, mag: Float)] = []
        for i in 2..<(binCount - 2) {
            if meanSpectrum[i] > meanSpectrum[i-1] && meanSpectrum[i] > meanSpectrum[i+1] &&
               meanSpectrum[i] > meanSpectrum[i-2] && meanSpectrum[i] > meanSpectrum[i+2] &&
               meanSpectrum[i] > 0.02 {
                peaks.append((i, meanSpectrum[i]))
            }
        }

        peaks.sort { $0.mag > $1.mag }
        var usedBins = Set<Int>()

        for peak in peaks.prefix(6) {
            if usedBins.contains(peak.bin) { continue }
            let low = max(0, peak.bin - 5)
            let high = min(binCount - 1, peak.bin + 5)
            for b in low...high { usedBins.insert(b) }

            let freq = Float(peak.bin) * 48000 / 2048
            voices.append(Voice(
                id: UUID(),
                name: nameFor(freq),
                frequencyRange: Float(low) * 48000 / 2048 ... Float(high) * 48000 / 2048,
                isActive: false,
                energy: 0,
                lastActiveTime: Date()
            ))
        }

        voices.sort { $0.frequencyRange.lowerBound < $1.frequencyRange.lowerBound }
        spectralHistory.removeAll()
        isCalibrating = false
    }

    private func matchVoices(spectrum: [Float]) {
        for i in 0..<voices.count {
            let lowBin = Int(voices[i].frequencyRange.lowerBound * 2048 / 48000)
            let highBin = Int(voices[i].frequencyRange.upperBound * 2048 / 48000)

            var energy: Float = 0
            if lowBin >= 0 && highBin < spectrum.count && highBin > lowBin {
                for b in lowBin...highBin { energy += spectrum[b] }
                energy /= Float(highBin - lowBin + 1)
            }

            voices[i].energy = energy
            voices[i].isActive = energy > 0.08
            if voices[i].isActive { voices[i].lastActiveTime = Date() }
        }
    }

    private func nameFor(_ freq: Float) -> String {
        switch freq {
        case 0..<100: return "Sub"
        case 100..<250: return "Bass"
        case 250..<500: return "Low"
        case 500..<1000: return "Mid"
        case 1000..<2000: return "High"
        case 2000..<4000: return "Bright"
        default: return "Air"
        }
    }
}

// MARK: - Audio Capture (Microphone)

class MicrophoneCapture: NSObject {
    private var audioEngine: AVAudioEngine?
    var onSamples: (([Float]) -> Void)?

    func start() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            self?.onSamples?(samples)
        }

        try engine.start()
        audioEngine = engine
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - Main

let fft = FFTProcessor()
let beatTracker = BeatTracker()
let voiceTracker = VoiceTracker()
let mic = MicrophoneCapture()

print("🎤 SoundVis CLI - Microphone Audio Analyzer")
print("─────────────────────────────────────────────")
print("Calibrating for 30 seconds... play some music!\n")

var lastPrint = Date()

mic.onSamples = { samples in
    let spectrum = fft.process(samples)
    beatTracker.process(spectrum: spectrum)
    voiceTracker.process(spectrum: spectrum)

    // Update display ~4 times per second
    if Date().timeIntervalSince(lastPrint) > 0.25 {
        lastPrint = Date()

        // Clear line and move cursor
        print("\u{1B}[2K\u{1B}[A\u{1B}[2K\u{1B}[A\u{1B}[2K\u{1B}[A", terminator: "")

        if voiceTracker.isCalibrating {
            let progress = Int(voiceTracker.calibrationProgress * 30)
            let bar = String(repeating: "█", count: progress) + String(repeating: "░", count: 30 - progress)
            print("Calibrating: [\(bar)] \(Int(voiceTracker.calibrationProgress * 100))%")
            print("")
            print("")
        } else {
            // BPM line
            let bpm = beatTracker.currentBPM > 0 ? String(format: "%.0f", beatTracker.currentBPM) : "---"
            let phase = Int(beatTracker.beatPhase * 4)
            let dots = (0..<4).map { $0 == phase ? "●" : "○" }.joined(separator: " ")
            print("BPM: \(bpm)  \(dots)")

            // Voices line
            if voiceTracker.voices.isEmpty {
                print("Voices: (none detected)")
            } else {
                let voiceStr = voiceTracker.voices.map { v in
                    v.isActive ? "[\(v.name)]" : " \(v.name) "
                }.joined(separator: " ")
                print("Voices: \(voiceStr)")
            }
            print("")
        }
    }
}

do {
    try mic.start()
    print("\n\n")  // Space for updating lines
    RunLoop.main.run()
} catch {
    print("Error: \(error.localizedDescription)")
    print("Make sure Terminal has microphone permission (System Settings → Privacy → Microphone)")
}
