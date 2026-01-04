# SoundVis - Swift Audio Visualizer

A native macOS app that captures system audio and visualizes:
- **BPM** with beat anticipation (phase tracking)
- **Voices** - dynamic instrument-like frequency signatures

## Requirements

- macOS 13.0+ (for ScreenCaptureKit)
- Xcode 15+

## Setup

1. Open Xcode and create a new project:
   - **macOS** → **App**
   - Product Name: `SoundVis`
   - Interface: **SwiftUI**
   - Language: **Swift**

2. Delete the auto-generated `ContentView.swift`

3. Drag all `.swift` files from this folder into the Xcode project

4. In Project Settings → **Signing & Capabilities**:
   - Add capability: **Hardened Runtime**
   - Check: **Audio Input** (not strictly needed but good to have)

5. In Project Settings → **Info**, add:
   - `Privacy - Screen Capture Usage Description`: "SoundVis needs screen recording permission to capture system audio."

6. Build and run (⌘R)

7. On first launch, grant **Screen Recording** permission when prompted (System Settings → Privacy & Security → Screen Recording)

## Usage

1. Launch the app
2. Wait ~30 seconds for calibration (app listens for distinct frequency regions)
3. BPM displays with beat phase dots
4. Voice boxes appear and glow when their frequency region is active

## Architecture

```
ContentView.swift     - SwiftUI UI
Audio/
  AudioAnalyzer.swift       - Coordinator
  AudioCaptureManager.swift - ScreenCaptureKit wrapper
  FFTProcessor.swift        - Accelerate/vDSP FFT
  BeatTracker.swift         - Onset detection, tempo, phase
  VoiceTracker.swift        - Calibration, signatures, matching
```

## Notes

- Voices persist for 3 minutes of inactivity before being dropped
- BPM uses autocorrelation for stable tempo tracking
- Beat phase (0-1) can be used for predictive animations
