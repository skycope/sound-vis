import Foundation
import ScreenCaptureKit
import AVFoundation

class AudioCaptureManager: NSObject {
    var onAudioBuffer: (([Float]) -> Void)?

    private var stream: SCStream?
    private var streamOutput: AudioStreamOutput?

    func start() async throws {
        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        // We need at least one display to capture audio from
        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplay
        }

        // Configure stream - we only want audio
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1

        // We don't need video, but SCStream requires it
        // Set minimal video config
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps minimum
        config.showsCursor = false

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        // Add audio output
        streamOutput = AudioStreamOutput { [weak self] samples in
            self?.onAudioBuffer?(samples)
        }

        try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))

        // Start capture
        try await stream?.startCapture()
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }
}

enum AudioCaptureError: LocalizedError {
    case noDisplay
    case captureStartFailed

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display available for audio capture"
        case .captureStartFailed: return "Failed to start audio capture"
        }
    }
}

class AudioStreamOutput: NSObject, SCStreamOutput {
    private let handler: ([Float]) -> Void

    init(handler: @escaping ([Float]) -> Void) {
        self.handler = handler
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Extract audio samples
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let dataPointer = dataPointer else { return }

        // Get audio format
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee

        guard let asbd = asbd else { return }

        // Convert to float samples
        let sampleCount = length / MemoryLayout<Float>.size

        var floatSamples = [Float](repeating: 0, count: sampleCount)

        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            // Already float
            dataPointer.withMemoryRebound(to: Float.self, capacity: sampleCount) { ptr in
                for i in 0..<sampleCount {
                    floatSamples[i] = ptr[i]
                }
            }
        } else if asbd.mBitsPerChannel == 16 {
            // 16-bit integer
            let int16Count = length / MemoryLayout<Int16>.size
            dataPointer.withMemoryRebound(to: Int16.self, capacity: int16Count) { ptr in
                for i in 0..<min(int16Count, sampleCount) {
                    floatSamples[i] = Float(ptr[i]) / 32768.0
                }
            }
        }

        handler(floatSamples)
    }
}
