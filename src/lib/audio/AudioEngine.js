/**
 * AudioEngine - Ultra-low-latency audio processing
 * Optimized for instant visual response
 */

import { FeatureExtractor } from './FeatureExtractor.js';

export class AudioEngine {
  constructor() {
    this.audioContext = null;
    this.analyser = null;
    this.microphone = null;
    this.featureExtractor = null;

    // FFT configuration - zero latency
    this.fftSize = 256; // Smaller = faster
    this.smoothingTimeConstant = 0.08; // Low-latency with a touch of smoothing

    // Noise floor calibration
    this.noiseFloor = null;
    this.noiseFloorMagnitudes = null;

    // Analysis data buffers
    this.frequencyData = null;
    this.timeDomainData = null;

    // Callback for sending features to visualization
    this.onFeatures = null;
    this.analysisFrameId = null;
  }

  async initialize() {
    // Create audio context with lowest possible latency
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 44100,
      latencyHint: 'interactive'
    });

    // Request microphone access
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
        channelCount: 1,
        latency: 0
      }
    });

    // Create microphone source
    this.microphone = this.audioContext.createMediaStreamSource(stream);

    // Create analyser node
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = this.fftSize;
    this.analyser.smoothingTimeConstant = this.smoothingTimeConstant;

    // Initialize data buffers
    const bufferLength = this.analyser.frequencyBinCount;
    this.frequencyData = new Float32Array(bufferLength);
    this.timeDomainData = new Float32Array(this.fftSize);

    // Connect microphone to analyser
    this.microphone.connect(this.analyser);

    // Initialize feature extractor
    this.featureExtractor = new FeatureExtractor(
      this.audioContext.sampleRate,
      bufferLength
    );

    console.log('AudioEngine initialized - low latency mode');
  }

  async calibrateNoiseFloor(durationMs = 2000, onProgress = () => {}) {
    const samples = [];
    const startTime = performance.now();
    const bufferLength = this.analyser.frequencyBinCount;

    return new Promise((resolve) => {
      const capture = () => {
        const elapsed = performance.now() - startTime;
        const progress = Math.min(elapsed / durationMs, 1);
        onProgress(progress);

        if (elapsed < durationMs) {
          this.analyser.getFloatFrequencyData(this.frequencyData);
          samples.push(new Float32Array(this.frequencyData));
          requestAnimationFrame(capture);
        } else {
          // Calculate noise floor
          this.noiseFloorMagnitudes = new Float32Array(bufferLength);
          for (let bin = 0; bin < bufferLength; bin++) {
            let sum = 0;
            for (const sample of samples) {
              sum += sample[bin];
            }
            this.noiseFloorMagnitudes[bin] = sum / samples.length;
          }
          this.noiseFloor = -60; // Simplified threshold
          resolve();
        }
      };
      capture();
    });
  }

  startAnalysis(callback) {
    this.onFeatures = callback;
    this.analysisLoop();
  }

  analysisLoop() {
    // Get raw FFT data
    this.analyser.getFloatFrequencyData(this.frequencyData);
    this.analyser.getFloatTimeDomainData(this.timeDomainData);

    // Quick noise gate and normalize
    const cleanSpectrum = this.processSpectrum(this.frequencyData);

    // Extract features
    const features = this.featureExtractor.extract(
      cleanSpectrum,
      this.timeDomainData
    );

    if (this.onFeatures) {
      this.onFeatures(features);
    }

    this.analysisFrameId = requestAnimationFrame(() => this.analysisLoop());
  }

  processSpectrum(spectrum) {
    const normalized = new Float32Array(spectrum.length);
    const minDb = -90;
    const maxDb = -10;
    const range = maxDb - minDb;

    for (let i = 0; i < spectrum.length; i++) {
      let val = spectrum[i];

      // Simple noise gate
      if (this.noiseFloorMagnitudes && val < this.noiseFloorMagnitudes[i] + 10) {
        val = minDb;
      }

      // Normalize to 0-1
      const clamped = Math.max(minDb, Math.min(maxDb, val));
      normalized[i] = (clamped - minDb) / range;
    }

    return normalized;
  }

  stop() {
    if (this.analysisFrameId) {
      cancelAnimationFrame(this.analysisFrameId);
    }
    if (this.microphone) {
      this.microphone.disconnect();
    }
    if (this.audioContext) {
      this.audioContext.close();
    }
  }
}
