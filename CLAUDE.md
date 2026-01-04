# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Swift App (SoundVis/)

Native macOS app capturing system audio via ScreenCaptureKit.

### Setup
1. Create new Xcode macOS App project (SwiftUI)
2. Add all `.swift` files from `SoundVis/`
3. Add Screen Recording permission in Info.plist
4. Build and run

### Architecture

```
ScreenCaptureKit → FFTProcessor → BeatTracker + VoiceTracker → SwiftUI View
```

- **AudioCaptureManager**: ScreenCaptureKit wrapper for system audio
- **FFTProcessor**: 2048-point FFT via Accelerate/vDSP
- **BeatTracker**: Onset detection → autocorrelation tempo → phase tracking
- **VoiceTracker**: 30s calibration → signature extraction → matching

### Key Concepts

**Beat Anticipation**: `beatPhase` (0-1) + `predictNextBeatTime()` enable predictive visuals

**Voice Persistence**: Voices survive 3 minutes of silence, re-identify returning instruments via spectral shape matching

---

## Web App (Legacy)

Svelte 5 + Three.js + Vite app using microphone input.

```bash
npm install && npm run dev
```

### Data Flow
```
AudioEngine (WebAudio FFT) → FeatureExtractor → scene.js (Three.js)
```

Voices are spectral peaks that drift spatially and timeout after ~15 seconds.
