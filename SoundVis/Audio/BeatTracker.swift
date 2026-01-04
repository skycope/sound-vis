import Foundation

class BeatTracker {
    // Output state
    private(set) var currentBPM: Double = 0
    private(set) var beatPhase: Double = 0  // 0-1, where 0 = beat just happened
    private(set) var confidence: Double = 0
    private(set) var timeToNextBeat: TimeInterval = 0

    // Onset detection
    private var previousSpectrum: [Float] = []
    private var onsetHistory: [Float] = []
    private let onsetHistorySize = 512  // ~10 seconds at 48fps

    // Tempo estimation
    private let minBPM: Double = 60
    private let maxBPM: Double = 180
    private var tempoEstimates: [Double] = []
    private let tempoHistorySize = 16

    // Phase tracking
    private var lastBeatTime: Date = Date()
    private var beatInterval: TimeInterval = 0.5  // default 120 BPM
    private var phaseAccumulator: Double = 0

    // Timing
    private let sampleRate: Float = 48000
    private let hopSize: Int = 1024  // ~21ms between frames
    private var frameCount: Int = 0

    func process(spectrum: [Float]) {
        let onset = computeOnset(spectrum: spectrum)
        onsetHistory.append(onset)
        if onsetHistory.count > onsetHistorySize {
            onsetHistory.removeFirst()
        }

        previousSpectrum = spectrum
        frameCount += 1

        // Update tempo estimation every 8 frames (~170ms)
        if frameCount % 8 == 0 && onsetHistory.count > 256 {
            estimateTempo()
        }

        // Update phase
        updatePhase()
    }

    private func computeOnset(spectrum: [Float]) -> Float {
        guard !previousSpectrum.isEmpty else {
            return 0
        }

        // Spectral flux: sum of positive differences
        var flux: Float = 0
        let count = min(spectrum.count, previousSpectrum.count)

        for i in 0..<count {
            let diff = spectrum[i] - previousSpectrum[i]
            if diff > 0 {
                flux += diff
            }
        }

        return flux
    }

    private func estimateTempo() {
        // Normalize onset history
        let onsets = normalizeOnsets(onsetHistory)

        // Compute autocorrelation for tempo range
        let minLag = lagForBPM(maxBPM)  // higher BPM = shorter lag
        let maxLag = lagForBPM(minBPM)

        var bestBPM: Double = 0
        var bestCorrelation: Float = 0

        for lag in minLag...maxLag {
            let correlation = autocorrelation(onsets, lag: lag)
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestBPM = bpmForLag(lag)
            }
        }

        // Update tempo estimate with smoothing
        if bestBPM > 0 {
            tempoEstimates.append(bestBPM)
            if tempoEstimates.count > tempoHistorySize {
                tempoEstimates.removeFirst()
            }

            // Median filter for stability
            let sortedEstimates = tempoEstimates.sorted()
            let medianBPM = sortedEstimates[sortedEstimates.count / 2]

            // Smooth transition
            if currentBPM == 0 {
                currentBPM = medianBPM
            } else {
                currentBPM = currentBPM * 0.9 + medianBPM * 0.1
            }

            beatInterval = 60.0 / currentBPM
            confidence = Double(bestCorrelation)
        }
    }

    private func normalizeOnsets(_ onsets: [Float]) -> [Float] {
        guard !onsets.isEmpty else { return [] }

        let mean = onsets.reduce(0, +) / Float(onsets.count)
        var variance: Float = 0
        for o in onsets {
            variance += (o - mean) * (o - mean)
        }
        let std = sqrt(variance / Float(onsets.count))

        if std < 0.0001 { return onsets }

        return onsets.map { ($0 - mean) / std }
    }

    private func autocorrelation(_ signal: [Float], lag: Int) -> Float {
        guard lag < signal.count else { return 0 }

        var sum: Float = 0
        let n = signal.count - lag
        for i in 0..<n {
            sum += signal[i] * signal[i + lag]
        }
        return sum / Float(n)
    }

    private func lagForBPM(_ bpm: Double) -> Int {
        // lag in frames for given BPM
        let beatsPerSecond = bpm / 60.0
        let framesPerSecond = Double(sampleRate) / Double(hopSize)
        return Int(framesPerSecond / beatsPerSecond)
    }

    private func bpmForLag(_ lag: Int) -> Double {
        let framesPerSecond = Double(sampleRate) / Double(hopSize)
        let beatsPerSecond = framesPerSecond / Double(lag)
        return beatsPerSecond * 60.0
    }

    private func updatePhase() {
        guard beatInterval > 0 else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastBeatTime)

        // Accumulate phase
        phaseAccumulator = elapsed / beatInterval
        beatPhase = phaseAccumulator.truncatingRemainder(dividingBy: 1.0)

        // Reset phase at beat boundary
        if phaseAccumulator >= 1.0 {
            lastBeatTime = now.addingTimeInterval(-beatPhase * beatInterval)
            phaseAccumulator = beatPhase
        }

        timeToNextBeat = (1.0 - beatPhase) * beatInterval
    }

    // For external beat anticipation
    func predictNextBeatTime() -> Date {
        return Date().addingTimeInterval(timeToNextBeat)
    }

    func predictBeatTimes(count: Int) -> [Date] {
        var times: [Date] = []
        let now = Date()
        for i in 0..<count {
            times.append(now.addingTimeInterval(timeToNextBeat + Double(i) * beatInterval))
        }
        return times
    }
}
