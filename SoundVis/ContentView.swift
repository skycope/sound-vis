import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioAnalyzer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                // Calibration overlay
                if audioManager.isCalibrating {
                    CalibrationView(progress: audioManager.calibrationProgress)
                } else {
                    // BPM Display
                    BPMView(
                        bpm: audioManager.bpm,
                        beatPhase: audioManager.beatPhase,
                        confidence: audioManager.bpmConfidence
                    )

                    // Voice Boxes
                    VoiceGridView(voices: audioManager.voices)
                }

                // Status
                if let error = audioManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(40)
        }
        .onAppear {
            audioManager.start()
        }
    }
}

struct CalibrationView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 20) {
            Text("Calibrating...")
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .tint(.white.opacity(0.6))

            Text("Listening for voices")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct BPMView: View {
    let bpm: Double
    let beatPhase: Double
    let confidence: Double

    var body: some View {
        VStack(spacing: 16) {
            // BPM number
            Text(bpm > 0 ? String(format: "%.0f", bpm) : "—")
                .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white)

            Text("BPM")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))

            // Beat dots
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    let dotPhase = Double(i) / 4.0
                    let isActive = beatPhase >= dotPhase && beatPhase < dotPhase + 0.25

                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 12, height: 12)
                        .scaleEffect(isActive ? 1.3 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: isActive)
                }
            }
        }
        .opacity(confidence > 0.3 ? 1.0 : 0.3)
    }
}

struct VoiceGridView: View {
    let voices: [Voice]

    var body: some View {
        if voices.isEmpty {
            Text("No voices detected")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ForEach(voices) { voice in
                    VoiceBox(voice: voice)
                }
            }
        }
    }
}

struct VoiceBox: View {
    let voice: Voice

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(voice.isActive ? voice.color : voice.color.opacity(0.15))
                .frame(width: 80, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(voice.color.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: voice.isActive ? voice.color.opacity(0.6) : .clear, radius: 10)
                .animation(.easeOut(duration: 0.15), value: voice.isActive)

            Text(voice.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    ContentView()
}
