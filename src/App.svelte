<script>
  import { audioState, audioFeatures } from './lib/stores/audio.js';
  import { vibe, vibeSmooth, updateVibeSmooth } from './lib/stores/vibe.js';
  import { AudioEngine } from './lib/audio/AudioEngine.js';
  import VisualizerCanvas from './lib/visual/VisualizerCanvas.svelte';
  import ShyUI from './lib/ui/ShyUI.svelte';

  let audioEngine = null;
  let starting = $state(false);

  // Smooth vibe interpolation loop
  $effect(() => {
    if (!$audioState.listening) return;

    let animationId;
    const updateLoop = () => {
      vibeSmooth.update(current => updateVibeSmooth(current, $vibe));
      animationId = requestAnimationFrame(updateLoop);
    };
    updateLoop();

    return () => cancelAnimationFrame(animationId);
  });

  async function startListening() {
    if (starting) return;
    starting = true;

    try {
      audioEngine = new AudioEngine();
      await audioEngine.initialize();

      // Start calibration phase
      audioState.update(s => ({ ...s, calibrating: true, calibrationProgress: 0 }));

      await audioEngine.calibrateNoiseFloor(1500, (progress) => {
        audioState.update(s => ({ ...s, calibrationProgress: progress }));
      });

      audioState.update(s => ({
        ...s,
        initialized: true,
        listening: true,
        calibrating: false
      }));

      // Start audio analysis loop
      audioEngine.startAnalysis((features) => {
        audioFeatures.set(features);
      });

    } catch (err) {
      console.error('Failed to start audio:', err);
      audioState.update(s => ({ ...s, error: err.message }));
    } finally {
      starting = false;
    }
  }
</script>

<main>
  {#if !$audioState.listening}
    <div class="start-screen">
      {#if $audioState.calibrating}
        <div class="calibrating">
          <p>Calibrating...</p>
          <div class="progress-bar">
            <div class="progress-fill" style="width: {$audioState.calibrationProgress * 100}%"></div>
          </div>
          <p class="hint">Stay quiet</p>
        </div>
      {:else if $audioState.error}
        <div class="error">
          <h2>Error</h2>
          <p>{$audioState.error}</p>
          <button onclick={startListening}>Try Again</button>
        </div>
      {:else}
        <button class="start-button" onclick={startListening} disabled={starting}>
          {starting ? 'Initializing...' : 'Start Listening'}
        </button>
        <p class="hint">Microphone access required</p>
      {/if}
    </div>
  {:else}
    <VisualizerCanvas />
    <ShyUI />
  {/if}
</main>

<style>
  main {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(120% 100% at 50% 10%, #0c1a2f 0%, #05070b 55%, #020203 100%);
    color: #fff;
  }

  .start-screen {
    text-align: center;
    padding: 2rem;
  }

  .start-button {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.3);
    color: #fff;
    padding: 1rem 2.5rem;
    font-size: 1rem;
    cursor: pointer;
    border-radius: 2px;
    transition: all 0.3s ease;
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .start-button:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.5);
  }

  .start-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .hint {
    margin-top: 1rem;
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.05em;
  }

  .calibrating {
    text-align: center;
  }

  .calibrating p {
    margin-bottom: 1rem;
    font-size: 0.9rem;
    letter-spacing: 0.05em;
  }

  .progress-bar {
    width: 200px;
    height: 2px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 1px;
    overflow: hidden;
    margin: 0 auto;
  }

  .progress-fill {
    height: 100%;
    background: rgba(255, 255, 255, 0.8);
    transition: width 0.1s ease;
  }

  .error h2 {
    margin-bottom: 0.5rem;
    font-weight: 400;
  }

  .error p {
    color: rgba(255, 100, 100, 0.8);
    margin-bottom: 1rem;
  }

  .error button {
    background: transparent;
    border: 1px solid rgba(255, 255, 255, 0.3);
    color: #fff;
    padding: 0.5rem 1.5rem;
    cursor: pointer;
    border-radius: 2px;
  }
</style>
