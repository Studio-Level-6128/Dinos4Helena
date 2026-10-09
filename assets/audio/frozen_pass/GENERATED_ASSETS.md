# Frozen Pass sound effects

Generated on 2026-10-09 by `scripts/generate-frozen-pass-sounds.py` using
Python's standard library; no recordings or external assets are sampled.
Reproduce with `python3 scripts/generate-frozen-pass-sounds.py`.

All clips use mono, 16-bit PCM at 22,050 Hz with short fade envelopes:

- `checkpoint.wav`: ascending three-note chime, 0.7 seconds.
- `retry.wav`: gently descending tone, 0.6 seconds.
- `wind.wav`: smoothed noise with changing amplitude, 3 seconds.
- `ice_crack.wav`: short noise impact and low resonant tone, 1.2 seconds.
- `avalanche.wav`: low rumble and filtered noise, 2.5 seconds.

Effects accompany visual warnings and localized objective text. They are not
required to understand or complete a mission.
