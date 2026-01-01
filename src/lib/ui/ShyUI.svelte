<script>
  import { vibe } from '../stores/vibe.js';
  import { audioFeatures } from '../stores/audio.js';
  import VibeSlider from './VibeSlider.svelte';

  let visible = $state(true);
  let hideTimeout = $state(null);
  const HIDE_DELAY = 4000;

  function handleMouseMove() {
    visible = true;
    clearTimeout(hideTimeout);
    hideTimeout = setTimeout(() => {
      visible = false;
    }, HIDE_DELAY);
  }

  $effect(() => {
    hideTimeout = setTimeout(() => {
      visible = false;
    }, HIDE_DELAY);
    return () => clearTimeout(hideTimeout);
  });

  function updateVibe(key, value) {
    vibe.update(v => ({ ...v, [key]: value }));
  }

  let voiceCount = $derived(($audioFeatures.voices || []).length);
</script>

<svelte:window on:mousemove={handleMouseMove} />

<div class="shy-ui" class:visible>
  <div class="controls">
    <div class="sliders">
      <VibeSlider
        label="Flow"
        sublabel="Wild / Calm"
        value={$vibe.viscosity}
        onchange={(v) => updateVibe('viscosity', v)}
        gradient="linear-gradient(90deg, #2f7b3f, #365da6)"
      />

      <VibeSlider
        label="Relief"
        sublabel="Flat / Rugged"
        value={$vibe.harmonics}
        onchange={(v) => updateVibe('harmonics', v)}
        gradient="linear-gradient(90deg, #1f4b2a, #2b4f8e)"
      />

      <VibeSlider
        label="Depth"
        sublabel="Near / Far"
        value={$vibe.atmosphere}
        onchange={(v) => updateVibe('atmosphere', v)}
        gradient="linear-gradient(90deg, #05070b, #365da6)"
      />
    </div>

    <div class="stats">
      <div class="voice-count">
        <span class="number">{voiceCount}</span>
        <span class="label">voices</span>
      </div>
    </div>
  </div>
</div>

<style>
  .shy-ui {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 2rem;
    pointer-events: none;
    opacity: 0;
    transform: translateY(20px);
    transition: opacity 0.5s ease, transform 0.5s ease;
    z-index: 100;
  }

  .shy-ui.visible {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
  }

  .controls {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    max-width: 750px;
    margin: 0 auto;
    background: rgba(6, 8, 12, 0.7);
    backdrop-filter: blur(30px);
    -webkit-backdrop-filter: blur(30px);
    border: 1px solid rgba(80, 120, 170, 0.2);
    border-radius: 20px;
    padding: 1.25rem 2rem;
  }

  .sliders {
    display: flex;
    gap: 1.75rem;
    flex: 1;
  }

  .stats {
    display: flex;
    align-items: flex-end;
    gap: 1.5rem;
    padding-left: 1.5rem;
    border-left: 1px solid rgba(80, 120, 170, 0.2);
  }

  .voice-count {
    display: flex;
    flex-direction: column;
    align-items: center;
    min-width: 50px;
  }

  .voice-count .number {
    font-size: 1.5rem;
    font-weight: 300;
    color: rgba(180, 210, 255, 0.9);
    font-variant-numeric: tabular-nums;
  }

  .voice-count .label {
    font-size: 0.55rem;
    color: rgba(140, 170, 210, 0.55);
    text-transform: uppercase;
    letter-spacing: 0.1em;
  }

  @media (max-width: 768px) {
    .shy-ui {
      padding: 1rem;
    }

    .controls {
      flex-direction: column;
      gap: 1.25rem;
      padding: 1rem;
    }

    .sliders {
      flex-direction: column;
      gap: 0.75rem;
      width: 100%;
    }

    .stats {
      padding-left: 0;
      padding-top: 1rem;
      border-left: none;
      border-top: 1px solid rgba(80, 120, 170, 0.2);
      width: 100%;
      justify-content: center;
    }
  }
</style>
