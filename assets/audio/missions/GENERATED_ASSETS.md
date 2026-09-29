# Generated mission narration

The 18 MP3 files in this directory were generated on 2026-09-29 from the
localized `mission.*.intro` text in `translations/` using `edge-tts` 7.2.8.
Run `scripts/generate-mission-intros.py` to reproduce missing clips.

Voices:

- English: `en-GB-SoniaNeural`
- German: `de-DE-KatjaNeural`
- French: `fr-FR-DeniseNeural`

Generation settings use a 5% slower speaking rate and 5% increased volume.
Files are organized as `<mission_id>/<locale>.mp3` and selected using the
player's saved language, with English as a runtime fallback.
