<script>
  let {
    label = '',
    sublabel = '',
    value = 0.5,
    onchange = () => {},
    gradient = 'linear-gradient(90deg, #333, #666)'
  } = $props();

  let dragging = $state(false);
  let sliderEl;

  function handlePointerDown(e) {
    dragging = true;
    updateValue(e);
    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerUp);
  }

  function handlePointerMove(e) {
    if (!dragging) return;
    updateValue(e);
  }

  function handlePointerUp() {
    dragging = false;
    window.removeEventListener('pointermove', handlePointerMove);
    window.removeEventListener('pointerup', handlePointerUp);
  }

  function updateValue(e) {
    if (!sliderEl) return;
    const rect = sliderEl.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const newValue = Math.max(0, Math.min(1, x / rect.width));
    onchange(newValue);
  }

  function handleKeyDown(e) {
    if (e.key === 'ArrowLeft') {
      onchange(Math.max(0, value - 0.05));
    } else if (e.key === 'ArrowRight') {
      onchange(Math.min(1, value + 0.05));
    }
  }
</script>

<div class="vibe-slider">
  <div class="labels">
    <span class="label">{label}</span>
    <span class="sublabel">{sublabel}</span>
  </div>

  <div
    class="track"
    bind:this={sliderEl}
    onpointerdown={handlePointerDown}
    onkeydown={handleKeyDown}
    role="slider"
    tabindex="0"
    aria-label={label}
    aria-valuemin="0"
    aria-valuemax="100"
    aria-valuenow={Math.round(value * 100)}
  >
    <div class="track-bg" style="background: {gradient}"></div>
    <div class="track-fill" style="width: {value * 100}%"></div>
    <div class="thumb" style="left: {value * 100}%" class:dragging></div>
  </div>
</div>

<style>
  .vibe-slider {
    min-width: 150px;
    flex: 1;
  }

  .labels {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    margin-bottom: 0.5rem;
  }

  .label {
    font-size: 0.7rem;
    font-weight: 500;
    color: rgba(255, 255, 255, 0.9);
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .sublabel {
    font-size: 0.6rem;
    color: rgba(255, 255, 255, 0.35);
    letter-spacing: 0.05em;
  }

  .track {
    position: relative;
    height: 4px;
    border-radius: 2px;
    cursor: pointer;
    overflow: hidden;
  }

  .track:focus {
    outline: none;
  }

  .track:focus-visible {
    box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.3);
  }

  .track-bg {
    position: absolute;
    inset: 0;
    opacity: 0.2;
    border-radius: 2px;
  }

  .track-fill {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    background: rgba(255, 255, 255, 0.4);
    border-radius: 2px;
    transition: width 0.05s ease-out;
  }

  .thumb {
    position: absolute;
    top: 50%;
    width: 12px;
    height: 12px;
    background: rgba(255, 255, 255, 0.9);
    border-radius: 50%;
    transform: translate(-50%, -50%);
    transition: transform 0.1s ease, box-shadow 0.2s ease;
    box-shadow: 0 0 10px rgba(255, 255, 255, 0.3);
  }

  .thumb.dragging {
    transform: translate(-50%, -50%) scale(1.2);
    box-shadow: 0 0 20px rgba(255, 255, 255, 0.5);
  }

  .thumb:hover {
    transform: translate(-50%, -50%) scale(1.1);
  }
</style>
