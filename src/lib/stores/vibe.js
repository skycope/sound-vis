import { writable } from 'svelte/store';

export const vibe = writable({
  viscosity: 0.3,
  harmonics: 0.2,
  atmosphere: 0.4
});

export const vibeSmooth = writable({
  viscosity: 0.3,
  harmonics: 0.2,
  atmosphere: 0.4
});

const LERP_FACTOR = 0.12;

export function lerp(current, target, factor) {
  return current + (target - current) * factor;
}

export function updateVibeSmooth(currentSmooth, targetVibe) {
  return {
    viscosity: lerp(currentSmooth.viscosity, targetVibe.viscosity, LERP_FACTOR),
    harmonics: lerp(currentSmooth.harmonics, targetVibe.harmonics, LERP_FACTOR),
    atmosphere: lerp(currentSmooth.atmosphere, targetVibe.atmosphere, LERP_FACTOR)
  };
}
