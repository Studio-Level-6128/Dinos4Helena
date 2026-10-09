# Generated mission narration

The original 18 MP3 introductions were generated on 2026-09-29 from the
localized `mission.*.intro` text in `translations/` using `edge-tts` 7.2.8.
Run `scripts/generate-mission-intros.py` to reproduce missing clips.

Voices:

- English: `en-GB-SoniaNeural`
- German: `de-DE-KatjaNeural`
- French: `fr-FR-DeniseNeural`

Generation settings use a 5% slower speaking rate and 5% increased volume.
Files are organized as `<mission_id>/<locale>.mp3` and selected using the
player's saved language, with English as a runtime fallback.

## Beyond the Frozen Pass — 2026-10-09

Added 18 localized MP3 introductions for `tracks_in_snow`, `whiteout`,
`singing_lake`, `sleeping_giants`, `snowplug`, and `last_avalanche` using
edge-tts 7.2.8, the voices above, and the same rate and volume settings.
The source text is the English, German, and French `mission.<id>.intro`
translation entry. The existing generator now includes all eighteen missions
and preserves previously generated audio by default.
