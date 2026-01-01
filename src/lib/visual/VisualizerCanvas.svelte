<script>
  import { onMount, onDestroy } from 'svelte';
  import { audioFeatures } from '../stores/audio.js';
  import { vibeSmooth } from '../stores/vibe.js';
  import { createScene, updateScene, disposeScene } from './scene.js';

  let container;
  let sceneContext = null;
  let animationId = null;

  onMount(async () => {
    try {
      sceneContext = await createScene(container);
      animate();
    } catch (err) {
      console.error('Failed to create WebGPU scene:', err);
    }
  });

  onDestroy(() => {
    if (animationId) {
      cancelAnimationFrame(animationId);
    }
    if (sceneContext) {
      disposeScene(sceneContext);
    }
  });

  function animate() {
    if (!sceneContext) return;

    // Get current audio features and vibe settings
    const features = $audioFeatures;
    const vibe = $vibeSmooth;

    // Update scene with audio data
    updateScene(sceneContext, features, vibe);

    animationId = requestAnimationFrame(animate);
  }
</script>

<div bind:this={container} class="canvas-container"></div>

<style>
  .canvas-container {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: 0;
  }

  .canvas-container :global(canvas) {
    display: block;
    width: 100%;
    height: 100%;
  }
</style>
