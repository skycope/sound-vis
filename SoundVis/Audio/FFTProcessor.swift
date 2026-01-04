import Foundation
import Accelerate

class FFTProcessor {
    private let fftSize: Int = 2048
    private let fftSetup: vDSP_DFT_Setup

    private var inputBuffer: [Float]
    private var window: [Float]
    private var realPart: [Float]
    private var imagPart: [Float]
    private var magnitudes: [Float]

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)!

        inputBuffer = [Float](repeating: 0, count: fftSize)
        window = [Float](repeating: 0, count: fftSize)
        realPart = [Float](repeating: 0, count: fftSize)
        imagPart = [Float](repeating: 0, count: fftSize)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)

        // Create Hann window
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }

    func process(_ samples: [Float]) -> [Float] {
        // Fill input buffer (take last fftSize samples)
        let start = max(0, samples.count - fftSize)
        let count = min(samples.count, fftSize)

        for i in 0..<count {
            inputBuffer[fftSize - count + i] = samples[start + i]
        }

        // Apply window
        var windowedInput = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(inputBuffer, 1, window, 1, &windowedInput, 1, vDSP_Length(fftSize))

        // Prepare for FFT (real input -> complex)
        for i in 0..<fftSize {
            realPart[i] = windowedInput[i]
            imagPart[i] = 0
        }

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, realPart, imagPart, &realPart, &imagPart)

        // Compute magnitudes (only first half is meaningful for real input)
        for i in 0..<fftSize/2 {
            let real = realPart[i]
            let imag = imagPart[i]
            magnitudes[i] = sqrt(real * real + imag * imag) / Float(fftSize)
        }

        return magnitudes
    }

    var binCount: Int {
        return fftSize / 2
    }

    func frequencyForBin(_ bin: Int, sampleRate: Float) -> Float {
        return Float(bin) * sampleRate / Float(fftSize)
    }

    func binForFrequency(_ frequency: Float, sampleRate: Float) -> Int {
        return Int(frequency * Float(fftSize) / sampleRate)
    }
}
