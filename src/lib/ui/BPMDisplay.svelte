<script>
  let { bpm = 0, confidence = 0 } = $props();

  let locked = $derived(confidence > 0.9);
  let displayBpm = $derived(bpm > 0 ? Math.round(bpm) : '--');
</script>

<div class="bpm-display" class:locked>
  <div class="bpm-value">
    <span class="number">{displayBpm}</span>
    <span class="unit">BPM</span>
  </div>
  <div class="confidence-bar">
    <div class="confidence-fill" style="width: {confidence * 100}%"></div>
  </div>
  <div class="status">
    {#if locked}
      <span class="locked-indicator"></span>
      Locked
    {:else}
      Detecting...
    {/if}
  </div>
</div>

<style>
  .bpm-display {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    min-width: 80px;
    padding-left: 1.5rem;
    border-left: 1px solid rgba(255, 255, 255, 0.1);
  }

  .bpm-value {
    display: flex;
    align-items: baseline;
    gap: 0.25rem;
  }

  .number {
    font-size: 1.5rem;
    font-weight: 300;
    color: rgba(255, 255, 255, 0.9);
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.02em;
  }

  .unit {
    font-size: 0.6rem;
    color: rgba(255, 255, 255, 0.4);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .confidence-bar {
    width: 100%;
    height: 2px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 1px;
    margin: 0.5rem 0 0.25rem;
    overflow: hidden;
  }

  .confidence-fill {
    height: 100%;
    background: rgba(255, 255, 255, 0.4);
    transition: width 0.2s ease;
  }

  .bpm-display.locked .confidence-fill {
    background: rgba(100, 255, 150, 0.6);
  }

  .status {
    font-size: 0.55rem;
    color: rgba(255, 255, 255, 0.35);
    letter-spacing: 0.1em;
    text-transform: uppercase;
    display: flex;
    align-items: center;
    gap: 0.35rem;
  }

  .locked-indicator {
    width: 4px;
    height: 4px;
    background: rgba(100, 255, 150, 0.8);
    border-radius: 50%;
    animation: pulse 1s ease-in-out infinite;
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 0.5;
      transform: scale(1);
    }
    50% {
      opacity: 1;
      transform: scale(1.2);
    }
  }

  @media (max-width: 768px) {
    .bpm-display {
      flex-direction: row;
      align-items: center;
      gap: 1rem;
      padding-left: 0;
      padding-top: 1rem;
      border-left: none;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      width: 100%;
      justify-content: center;
    }

    .confidence-bar {
      width: 60px;
      margin: 0;
    }
  }
</style>
