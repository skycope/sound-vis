import Foundation

class VoiceTracker {
    private(set) var voices: [Voice] = []
    private(set) var isCalibrating: Bool = true

    // Calibration data
    private var spectralHistory: [[Float]] = []
    private var peakHistory: [[SpectralPeak]] = []
    private let maxHistorySize = 1024  // ~20 seconds of data

    // Voice matching
    private let voiceTimeoutDuration: TimeInterval = 180  // 3 minutes before dropping a voice
    private let activeThreshold: Float = 0.15
    private let matchingThreshold: Float = 0.7

    // Sample rate for frequency calculations
    private var sampleRate: Float = 48000

    struct SpectralPeak {
        let binIndex: Int
        let frequency: Float
        let magnitude: Float
        let bandwidth: Int  // bins on each side above threshold
    }

    func process(spectrum: [Float], sampleRate: Float) {
        self.sampleRate = sampleRate

        if isCalibrating {
            collectCalibrationData(spectrum: spectrum)
        } else {
            matchVoices(spectrum: spectrum)
        }
    }

    private func collectCalibrationData(spectrum: [Float]) {
        spectralHistory.append(spectrum)
        if spectralHistory.count > maxHistorySize {
            spectralHistory.removeFirst()
        }

        // Also collect peaks
        let peaks = findPeaks(spectrum: spectrum)
        peakHistory.append(peaks)
        if peakHistory.count > maxHistorySize {
            peakHistory.removeFirst()
        }
    }

    func finalizeCalibration() {
        guard !spectralHistory.isEmpty else {
            isCalibrating = false
            return
        }

        // Compute mean spectrum
        let binCount = spectralHistory[0].count
        var meanSpectrum = [Float](repeating: 0, count: binCount)

        for spectrum in spectralHistory {
            for i in 0..<binCount {
                meanSpectrum[i] += spectrum[i]
            }
        }
        for i in 0..<binCount {
            meanSpectrum[i] /= Float(spectralHistory.count)
        }

        // Find consistent peaks across calibration period
        let voiceRegions = identifyVoiceRegions(meanSpectrum: meanSpectrum)

        // Create voices from regions
        voices = voiceRegions.enumerated().map { index, region in
            Voice(
                id: UUID(),
                name: nameForFrequency(region.centroid),
                frequencyRange: region.lowFreq...region.highFreq,
                spectralCentroid: region.centroid,
                spectralShape: region.shape,
                isActive: false,
                energy: 0,
                lastActiveTime: Date()
            )
        }

        isCalibrating = false
        spectralHistory.removeAll()
        peakHistory.removeAll()
    }

    private struct VoiceRegion {
        let lowFreq: Float
        let highFreq: Float
        let centroid: Float
        let shape: [Float]
    }

    private func identifyVoiceRegions(meanSpectrum: [Float]) -> [VoiceRegion] {
        // Find significant peaks in mean spectrum
        let peaks = findPeaks(spectrum: meanSpectrum)
            .filter { $0.magnitude > 0.05 }  // Only significant peaks
            .sorted { $0.magnitude > $1.magnitude }  // Strongest first

        var regions: [VoiceRegion] = []
        var usedBins = Set<Int>()

        for peak in peaks.prefix(8) {  // Max 8 voices
            // Skip if this bin is already part of a voice
            if usedBins.contains(peak.binIndex) { continue }

            // Determine region around peak
            let lowBin = max(0, peak.binIndex - peak.bandwidth - 2)
            let highBin = min(meanSpectrum.count - 1, peak.binIndex + peak.bandwidth + 2)

            // Check for overlap
            var overlaps = false
            for bin in lowBin...highBin {
                if usedBins.contains(bin) {
                    overlaps = true
                    break
                }
            }
            if overlaps { continue }

            // Mark bins as used
            for bin in lowBin...highBin {
                usedBins.insert(bin)
            }

            // Extract spectral shape (normalized)
            var shape: [Float] = []
            var maxVal: Float = 0
            for bin in lowBin...highBin {
                shape.append(meanSpectrum[bin])
                maxVal = max(maxVal, meanSpectrum[bin])
            }
            if maxVal > 0 {
                shape = shape.map { $0 / maxVal }
            }

            let lowFreq = frequencyForBin(lowBin)
            let highFreq = frequencyForBin(highBin)
            let centroid = frequencyForBin(peak.binIndex)

            regions.append(VoiceRegion(
                lowFreq: lowFreq,
                highFreq: highFreq,
                centroid: centroid,
                shape: shape
            ))
        }

        return regions.sorted { $0.centroid < $1.centroid }
    }

    private func findPeaks(spectrum: [Float]) -> [SpectralPeak] {
        var peaks: [SpectralPeak] = []
        let threshold: Float = 0.02

        for i in 2..<(spectrum.count - 2) {
            // Local maximum check
            if spectrum[i] > spectrum[i-1] &&
               spectrum[i] > spectrum[i+1] &&
               spectrum[i] > spectrum[i-2] &&
               spectrum[i] > spectrum[i+2] &&
               spectrum[i] > threshold {

                // Compute bandwidth (bins above half magnitude)
                let halfMag = spectrum[i] / 2
                var bandwidth = 0
                for j in 1..<20 {
                    let left = i - j >= 0 ? spectrum[i - j] : 0
                    let right = i + j < spectrum.count ? spectrum[i + j] : 0
                    if left < halfMag && right < halfMag { break }
                    bandwidth = j
                }

                peaks.append(SpectralPeak(
                    binIndex: i,
                    frequency: frequencyForBin(i),
                    magnitude: spectrum[i],
                    bandwidth: bandwidth
                ))
            }
        }

        return peaks
    }

    private func matchVoices(spectrum: [Float]) {
        let now = Date()

        for i in 0..<voices.count {
            // Get energy in voice's frequency range
            let lowBin = binForFrequency(voices[i].frequencyRange.lowerBound)
            let highBin = binForFrequency(voices[i].frequencyRange.upperBound)

            var energy: Float = 0
            var shapeMatch: Float = 0

            if highBin > lowBin && lowBin >= 0 && highBin < spectrum.count {
                // Compute energy
                for bin in lowBin...highBin {
                    energy += spectrum[bin]
                }
                energy /= Float(highBin - lowBin + 1)

                // Shape matching (if we have a shape template)
                if !voices[i].spectralShape.isEmpty {
                    var extractedShape: [Float] = []
                    var maxVal: Float = 0
                    for bin in lowBin...highBin {
                        extractedShape.append(spectrum[bin])
                        maxVal = max(maxVal, spectrum[bin])
                    }
                    if maxVal > 0 {
                        extractedShape = extractedShape.map { $0 / maxVal }
                    }

                    // Compute correlation with template
                    shapeMatch = correlate(extractedShape, voices[i].spectralShape)
                }
            }

            // Update voice state
            let wasActive = voices[i].isActive
            voices[i].energy = energy
            voices[i].isActive = energy > activeThreshold && shapeMatch > matchingThreshold

            if voices[i].isActive {
                voices[i].lastActiveTime = now
            }
        }

        // Remove voices that haven't been active for too long
        voices.removeAll { voice in
            now.timeIntervalSince(voice.lastActiveTime) > voiceTimeoutDuration
        }
    }

    private func correlate(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }

        var sum: Float = 0
        var sumA: Float = 0
        var sumB: Float = 0

        for i in 0..<n {
            sum += a[i] * b[i]
            sumA += a[i] * a[i]
            sumB += b[i] * b[i]
        }

        let denom = sqrt(sumA * sumB)
        return denom > 0 ? sum / denom : 0
    }

    private func frequencyForBin(_ bin: Int) -> Float {
        let fftSize = 2048  // Must match FFTProcessor
        return Float(bin) * sampleRate / Float(fftSize)
    }

    private func binForFrequency(_ frequency: Float) -> Int {
        let fftSize = 2048
        return Int(frequency * Float(fftSize) / sampleRate)
    }

    private func nameForFrequency(_ freq: Float) -> String {
        // Generate descriptive names based on frequency range
        switch freq {
        case 0..<100: return "Sub"
        case 100..<250: return "Bass"
        case 250..<500: return "Low"
        case 500..<1000: return "Mid"
        case 1000..<2000: return "High"
        case 2000..<4000: return "Bright"
        case 4000..<8000: return "Air"
        default: return "Ultra"
        }
    }
}
