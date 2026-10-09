# Heart of the Volcano effects

Generated on 2026-10-09 using `scripts/generate-volcano-sounds.py` and Python's
standard library. No recordings or externally licensed sounds are sampled.
Reproduce with `python3 scripts/generate-volcano-sounds.py`.

Ten mono 16-bit PCM WAV clips at 22,050 Hz use deterministic random seeds and
short fade envelopes:

- `short_call.wav` (0.4 s) and `long_call.wav` (1.2 s): layered resonant tones.
- `checkpoint.wav` and `opening.wav` (0.7 s): ascending three-note chimes.
- `retry.wav` (0.6 s): descending tone.
- `crack.wav` (0.9 s): decaying noise impact.
- `launch.wav` (1.0 s) and `rumble.wav` (1.5 s): filtered noise and low tones.
- `deflect.wav` (0.5 s): rising metallic tone.
- `warning.wav` (0.8 s): pulsed warning tone.

Every gameplay cue also has a visible symbol, ground marker, or localized
objective message. Players can complete the quest with audio muted.
