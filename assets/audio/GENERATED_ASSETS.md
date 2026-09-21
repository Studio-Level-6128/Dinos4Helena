# Generated audio assets

The audio in this directory was generated for Dinos4Helena with ElevenLabs' `eleven_text_to_sound_v2` sound-effects model. Generation prompts and durations are preserved in `scripts/generate-sounds.sh` so the library is reproducible.

- Dinosaur one-shots: species-specific scream, walk, run, jump, duck, attack, and hurt sounds
- Ambience: seamless prehistoric jungle and distant-dinosaur loops
- Output: MP3, 44.1 kHz, 128 kbps

The dinosaur sounds are cinematic, plausible interpretations. There are no recordings of non-avian dinosaur vocalizations, so they should not be presented as scientifically established reconstructions.

Do not commit `.env` or an API key. The generator reads `ELEVENLABS_API_KEY` from the ignored project-root `.env` file and skips any audio file that already exists.
