/**
 * FeatureExtractor - Minimal band + voice tracking
 * Keeps latency low and focuses on persistent frequency entities.
 */

export class FeatureExtractor {
  constructor(sampleRate, frequencyBins) {
    this.sampleRate = sampleRate;
    this.frequencyBins = frequencyBins;
    this.nyquist = sampleRate / 2;

    this.previousSpectrum = new Float32Array(frequencyBins);

    this.frequencies = new Float32Array(frequencyBins);
    for (let i = 0; i < frequencyBins; i++) {
      this.frequencies[i] = (i * this.nyquist) / frequencyBins;
    }

    this.bands = [
      { name: 'low', min: 40, max: 160, color: [0.15, 0.35, 0.75] },
      { name: 'lowMid', min: 160, max: 450, color: [0.2, 0.55, 0.7] },
      { name: 'mid', min: 450, max: 1400, color: [0.25, 0.65, 0.55] },
      { name: 'highMid', min: 1400, max: 3200, color: [0.5, 0.55, 0.35] },
      { name: 'presence', min: 3200, max: 6000, color: [0.65, 0.4, 0.45] },
      { name: 'air', min: 6000, max: 14000, color: [0.55, 0.35, 0.6] }
    ];

    this.bandEnergies = new Float32Array(this.bands.length);
    this.bandEnergiesSmooth = new Float32Array(this.bands.length);

    this.voices = [];
    this.nextVoiceId = 0;
    this.maxVoices = 5;
    this.frameCount = 0;
    this.voiceTimeoutFrames = 900;
  }

  extract(spectrum, timeDomain) {
    this.frameCount++;

    const rms = this.calculateRMS(timeDomain);
    this.calculateBandEnergies(spectrum);
    this.updateVoices(spectrum, rms);

    this.previousSpectrum.set(spectrum);

    return {
      spectrum,
      rms,
      bandEnergies: this.bandEnergiesSmooth,
      bands: this.bands,
      voices: this.voices.map(v => ({
        id: v.id,
        frequency: this.frequencies[v.binCenter],
        freqNorm: v.binCenter / this.frequencyBins,
        energy: v.smoothedEnergy,
        age: v.age,
        color: v.color,
        bandIndex: v.bandIndex
      }))
    };
  }

  calculateRMS(timeDomain) {
    let sum = 0;
    for (let i = 0; i < timeDomain.length; i++) {
      sum += timeDomain[i] * timeDomain[i];
    }
    return Math.sqrt(sum / timeDomain.length);
  }

  calculateBandEnergies(spectrum) {
    for (let b = 0; b < this.bands.length; b++) {
      const band = this.bands[b];
      let energy = 0;
      let count = 0;

      for (let i = 0; i < this.frequencyBins; i++) {
        const freq = this.frequencies[i];
        if (freq >= band.min && freq < band.max) {
          energy += spectrum[i];
          count++;
        }
      }

      this.bandEnergies[b] = count > 0 ? energy / count : 0;
      this.bandEnergiesSmooth[b] += (this.bandEnergies[b] - this.bandEnergiesSmooth[b]) * 0.12;
    }
  }

  updateVoices(spectrum, rms) {
    const quiet = rms < 0.008;

    if (quiet) {
      for (const voice of this.voices) {
        voice.smoothedEnergy *= 0.985;
        voice.energy *= 0.96;
      }

      this.voices = this.voices.filter(voice => {
        const timeSinceActive = this.frameCount - voice.lastActiveFrame;
        return voice.smoothedEnergy > 0.015 || timeSinceActive < this.voiceTimeoutFrames;
      });
      return;
    }

    const peaks = [];
    const threshold = 0.18;

    for (let i = 2; i < spectrum.length - 2; i++) {
      if (
        spectrum[i] > threshold &&
        spectrum[i] > spectrum[i - 1] &&
        spectrum[i] > spectrum[i + 1] &&
        spectrum[i] > spectrum[i - 2] &&
        spectrum[i] > spectrum[i + 2]
      ) {
        peaks.push({ bin: i, energy: spectrum[i] });
      }
    }

    peaks.sort((a, b) => b.energy - a.energy);
    const topPeaks = peaks.slice(0, this.maxVoices);

    const matchedVoices = new Set();

    for (const peak of topPeaks) {
      let bestMatch = null;
      let bestDist = 6;

      for (const voice of this.voices) {
        if (matchedVoices.has(voice.id)) continue;
        const dist = Math.abs(voice.binCenter - peak.bin);
        if (dist < bestDist) {
          bestDist = dist;
          bestMatch = voice;
        }
      }

      if (bestMatch) {
        matchedVoices.add(bestMatch.id);
        bestMatch.binCenter = Math.round(bestMatch.binCenter * 0.85 + peak.bin * 0.15);
        bestMatch.energy = peak.energy;
        bestMatch.smoothedEnergy += (peak.energy - bestMatch.smoothedEnergy) * 0.2;
        bestMatch.age++;
        bestMatch.lastActiveFrame = this.frameCount;
      } else if (this.voices.length < this.maxVoices && peak.energy > 0.24) {
        const bandIndex = this.getBandForBin(peak.bin);
        const band = this.bands[bandIndex];

        this.voices.push({
          id: this.nextVoiceId++,
          binCenter: peak.bin,
          energy: peak.energy,
          smoothedEnergy: peak.energy,
          age: 0,
          bandIndex,
          color: [...band.color],
          lastActiveFrame: this.frameCount
        });
      }
    }

    this.voices = this.voices.filter(voice => {
      const timeSinceActive = this.frameCount - voice.lastActiveFrame;

      if (!matchedVoices.has(voice.id)) {
        voice.smoothedEnergy *= 0.94;
        voice.energy *= 0.92;
      }

      return voice.smoothedEnergy > 0.015 || timeSinceActive < this.voiceTimeoutFrames;
    });
  }

  getBandForBin(bin) {
    const freq = this.frequencies[bin];
    for (let i = 0; i < this.bands.length; i++) {
      if (freq >= this.bands[i].min && freq < this.bands[i].max) {
        return i;
      }
    }
    return this.bands.length - 1;
  }
}
