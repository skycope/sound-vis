import { writable } from 'svelte/store';

export const audioState = writable({
  initialized: false,
  listening: false,
  calibrating: false,
  calibrationProgress: 0,
  error: null
});

export const audioFeatures = writable({
  spectrum: new Float32Array(128),
  rms: 0,
  bandEnergies: new Float32Array(6),
  bands: [],
  voices: []
});
