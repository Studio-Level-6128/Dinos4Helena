#!/usr/bin/env python3
"""Generate localized mission introductions with edge-tts.

Install the generator with `python3 -m pip install edge-tts`, then run this
script from anywhere inside the project. Existing audio is preserved unless
`--force` is supplied.
"""

import argparse
import asyncio
import json
from pathlib import Path

import edge_tts


PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSLATIONS = PROJECT_ROOT / "translations"
OUTPUT_ROOT = PROJECT_ROOT / "assets" / "audio" / "missions"
MISSIONS = (
    "dinner_time",
    "explore_the_world",
    "family",
    "breed",
    "hunt",
    "defense",
    "poison",
    "water",
    "prey",
    "kingpin",
    "lost_baby",
    "eat_the_baby",
    "tracks_in_snow",
    "whiteout",
    "singing_lake",
    "sleeping_giants",
    "snowplug",
    "last_avalanche",
)
VOICES = {
    "en": "en-GB-SoniaNeural",
    "de": "de-DE-KatjaNeural",
    "fr": "fr-FR-DeniseNeural",
}


async def generate(force: bool) -> None:
    for locale, voice in VOICES.items():
        catalog = json.loads((TRANSLATIONS / f"{locale}.json").read_text())
        for mission in MISSIONS:
            target = OUTPUT_ROOT / mission / f"{locale}.mp3"
            if target.exists() and target.stat().st_size > 0 and not force:
                print(f"Already generated: {target.relative_to(PROJECT_ROOT)}")
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            text = catalog[f"mission.{mission}.intro"]
            print(f"Generating: {target.relative_to(PROJECT_ROOT)}")
            speech = edge_tts.Communicate(text, voice, rate="-5%", volume="+5%")
            await speech.save(str(target))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace existing narration")
    args = parser.parse_args()
    asyncio.run(generate(args.force))


if __name__ == "__main__":
    main()
