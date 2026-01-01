# Agent Notes

## Product intent
- Keep the engine simple, refined, and low latency.
- Avoid glitchy or fast behaviors.
- Visuals should be smooth, evolving landscapes with persistent voice entities.

## Workflow
- Use `npm run dev` for local development.
- Test with microphone input; voice markers should drift without jitter.

## Code conventions
- Prefer minimal audio features: RMS, band energies, and tracked voices.
- Avoid adding BPM or heavy analysis unless explicitly requested.
