# Dinos4Helena

A mobile-first 3D Android game built with Godot 4 and GDScript. The current playable prototype has seven selectable animated dinosaurs, a third-person follow camera, two-handed touch controls, species-specific sound design, and a procedural prehistoric valley.

See the [player guide](docs/PLAY_GUIDE.md) for the complete game rules and the [development guide](docs/DEVELOPMENT.md) for architecture, setup, extension points, testing, and Android builds.

The game opens with a generated cinematic dinosaur-fight splash, followed by a clean **DINOS4HELENA** landing page with `QUESTS`, `FREE GAME`, and `CREDITS`. `QUESTS` opens a config-driven campaign browser. Its first campaign, **Getting Started**, contains six grassland missions covering grazing, exploration, herd behavior, breeding, hunting, and pack defense. `FREE GAME` opens a separate setup page where the player chooses T-Rex, Spinosaurus, Triceratops, Stegosaurus, Velociraptor, Parasaurolophus, or Apatosaurus and sets the world seed. `HOW TO PLAY` is available there, and the top-right menu button returns from gameplay to the appropriate setup page.

## Play the prototype

The camera follows above and behind the player dinosaur. On Android, the action buttons are on the left and an analog movement wheel is on the right.

| Action | Touch control | Keyboard |
| --- | --- | --- |
| Move/steer | Drag the right-hand wheel; diagonal positions combine movement and steering | `WASD` or arrow keys |
| Jump | `JUMP` | `Space` |
| Run | Hold `RUN` while moving | Hold `Shift` |
| Duck | Hold `DUCK` | Hold `C` or `Ctrl` |
| Attack | `ATTACK` | `F` |
| Eat | `EAT` | `E` |
| Scream | `SCREAM` (roar pose, sound, and shockwave) | `R` |

Health and energy bars appear in the upper-left corner. Every dinosaur starts with its species-specific maximum health and 100% energy. Walking, running, ducking, jumping, attacking, and screaming consume energy at deliberately gradual rates. At zero energy, health silently falls without repeatedly playing the hurt sound; reaching zero health plays the species' death animation and ends the game.

Herbivores regain energy slowly by holding `EAT` near grass or another plant. While grazing, the dinosaur stops, lowers its body and head, and makes a repeated chewing motion. Glowing purple plants with bright red pods are poisonous: eating one triggers continuous silent health loss and a persistent purple HUD warning until a red health token cures the poisoning. Player-controlled T-Rex, Velociraptor, and Spinosaurus regain energy quickly by eating meat left after a hunt.

Thirty glowing tokens are distributed throughout each seeded world: 14 health tokens restore 40 health, while 8 speed and 8 strength tokens double the matching stat for 30 seconds. Active bonuses and their countdowns appear beneath the health and energy bars. Tokens bob and rotate, disappear when collected, and respawn at a new clear location as the same type after a random 6–12 second delay. Counts, healing, bonus duration, and respawn timing are configurable under `[tokens]` in `config/dinosaurs.cfg`.

The game creates a 400×400 procedural prehistoric world. Each six-digit world seed deterministically controls its forest and grassland biomes, lakes, winding river, hills, dense mixed forests, grounded rocks, fallen trees, prehistoric understory, cloud cover, and object variation. Enter a seed on the dinosaur-selection screen to replay a world, or press `NEW RANDOM SEED` for a new one. The central spawn area is kept clear, solid landmarks avoid water, and generated features are spaced to avoid obvious overlaps.

Trees, fallen logs, rocks, hills, and tiered high-ground formations have solid collision geometry, and four invisible perimeter walls keep every dinosaur inside the valley. The high-ground tiers rise in jump-sized steps to broad lookout platforms. The live minimap beneath the main-menu button shows the map boundary and the dinosaur's current position and facing direction. Its fog of war hides terrain and landmarks until the dinosaur explores the surrounding area; explored cells remain visible for the rest of that game. Living predators in explored cells use red markers, herbivores use green markers, and each herbivore pack is summarized by one marker.

The world uses animated shader water with earthy banks for seeded lakes and rivers, a visible directional sun with mobile-friendly shadows, and a seeded layer of slowly moving clouds. Dense Araucaria forests contain ferns, cycads, and undergrowth, while open grasslands contain lightweight grass clusters.

## Wildlife and combat

Every seeded world also contains AI-controlled dinosaurs. Herbivores spawn in small same-species packs whose leader selects a distant destination, keeps pursuing it around obstacles, and chooses another only after arrival. Other members keep staggered side and trail positions, steer apart locally, and cannot physically deadlock one another. One animal periodically lags behind the moving herd, briefly creating an isolated hunting opportunity before it regroups. Packs welcome nearby herbivore players of their own species into the herd. If one of those players or another pack member is attacked, nearby herd members converge on the attacker and fight in its defense. T-Rex and Velociraptor hunters spawn alone and weigh their health, energy, strength, and size against a potential target plus its nearby same-species defenders. Healthy hunters strongly prefer babies and accept riskier baby attacks, while still accounting for nearby parents and defenders. They stalk marginal adult prey, avoid overpowering packs, feed after a kill, and retreat from opponents once their health falls below 50%.

Wild dinosaurs use the same configured health, strength, speed, scale, collision, and animation data as their playable counterparts. Spinosaurus is deliberately player-only and never appears in the procedural wildlife pool. Dinosaurs never hunt, target, or damage their own species. The player's `ATTACK` action works while walking, running or jumping and can hit a different-species dinosaur in front of it. Hunters likewise keep pursuing through their strikes. Hunters can damage both wildlife and the player, and damaged NPCs briefly show their health. Carnivores spend energy while walking, pursuing, and attacking; after a kill they claim the dropped meat, feed to recover energy, and only then resume hunting. A defeated wild dinosaur plays its native death animation and leaves edible meat, whose explored location remains marked on the minimap until the meat is consumed.

Six egg nests are hidden at deterministic clear locations in every seeded world. Stand over an egg and hold `DUCK` for four seconds to hatch a baby of the player's species. The smaller, slightly slower baby follows beside its parent, has independent health but no energy meter, and can be hunted and killed by different-species predators. Breeding counts, incubation time, baby scale, and speed are configurable in `config/dinosaurs.cfg`.

## Environment model library

Eleven locally stored GLB assets provide multiple living and dead tree forms, ferns, cycads, horsetails, fiddleheads, undergrowth, grass, fallen logs, and mossy basalt rocks. They are CC0 models from 3DAssets.dev; exact source pages, dimensions, licensing, and conversion notes are recorded in `assets/models/environment/SOURCE.md`.

The checked-in models need no network connection at runtime. To restore missing source assets, run `scripts/download-environment-assets.sh` or the `Assets: Download environment models` VS Code task. The script downloads and dequantizes them into the format supported by this Godot build.

Every dinosaur has its own scream, walking, running, jumping, ducking, attacking, and hurt sounds. Movement audio follows the dinosaur's pace, while action and vocal effects use independent 3D channels so important sounds are not cut off by footsteps.

## Sound library

The checked-in MP3 assets under `assets/audio/` were generated with ElevenLabs' sound-effects model. The exact prompts, durations, and output format are recorded in `scripts/generate-sounds.sh`; provenance and scientific caveats are in `assets/audio/GENERATED_ASSETS.md`.

To regenerate missing clips, create a local `.env` from the safe template and run:

```bash
cp .env.example .env
# Add ELEVENLABS_API_KEY to .env, then:
./scripts/generate-sounds.sh
```

`.env` and `.env.*` are ignored by Git, while `.env.example` remains tracked. The generator is resumable and skips existing clips to avoid duplicate API charges.

## Dinosaur balancing

All species characteristics and physical presentation values are centralized in `config/dinosaurs.cfg`. Each section controls:

- Walking, running, ducking, and turning speed
- Strength rating
- Whether the species can jump and its jump velocity
- Maximum health
- Herbivore or carnivore diet
- Model scale, collision size, and follow-camera framing

The same configuration file contains the maximum energy, action costs, starvation damage, eating rates, and food-interaction distance under its `[energy]` section.

The Free Game selection cards read directly from this file, so displayed speed, strength, jump capability, and health always match the gameplay values. Their portraits use an uncropped fit mode so the complete dinosaur remains visible. Heavy adult dinosaurs cannot jump; Velociraptor is currently the agile jumping species. Apatosaurus is deliberately much larger, slower, and healthier than the other playable dinosaurs.

## Installed development stack

- Godot 4.7.2 (standard/GDScript edition)
- Godot export templates matching the editor version
- Eclipse Temurin JDK 17
- Android SDK Platform 36, Build Tools 36.1.0, Platform Tools, NDK 29, and CMake 3.22.1
- VS Code Godot Tools extension

The large tools are stored in ignored `.tools/`, `.local/`, and `.cache/` directories. This keeps the machine-wide Java and Android configuration untouched.

## Work in VS Code

Open this repository as the workspace. VS Code should activate the Godot Tools extension automatically.

Use `Terminal > Run Task`:

- `Godot: Open editor` opens the visual scene/asset editor.
- `Godot: Run game` runs the game on the desktop.
- `Godot: Gameplay smoke test` verifies movement and actions without opening a window.
- `Godot: Procedural world test` verifies six-digit seed reproducibility and variation.
- `Godot: Health and energy test` verifies energy drain, starvation damage, grazing, HUD updates, and game over.
- `Godot: Wildlife AI test` verifies packs, fleeing, pursuit, NPC/player combat, death, and meat drops.
- `Godot: Predator strategy test` verifies stalking, pack-risk avoidance, favorable attacks, and injury retreat.
- `Godot: Breeding test` verifies egg placement, non-blocking nests, duck incubation, same-species hatching, following, baby health, and predator damage.
- `Godot: Pack movement test` verifies roaming leaders, staggered formations, trailing individuals, collision exceptions, and deadlock recovery.
- `Godot: Herd shelter test` verifies same-species peace, welcoming behavior, ally alerts, and defense of the player.
- `Godot: Power-up token test` verifies placement, animation, healing, doubled stats, HUD timers, consumption, and same-type respawning.
- `Godot: Quest UI test` verifies the catalog, overview, Getting Started page, six mission cards, and a complete mission launch.
- `Godot: Quest missions test` boots every Getting Started setup/event pair and checks its mission-specific world additions.
- `Audio: Generate missing sounds` uses the local ElevenLabs key to fill any missing audio assets.
- `Assets: Download environment models` restores the CC0 environment model library if needed.
- `Android: Build debug APK` creates `build/android/Dinos4Helena-debug.apk`.
- `Android: Connected devices` lists USB-connected Android devices.

`Ctrl+Shift+B` builds the APK. Use `Terminal > Run Task > Godot: Run game` to launch the desktop game. Scripts live under `scripts/`; scenes and assets are edited visually in Godot while GDScript is edited in VS Code.

Equivalent terminal commands are:

```bash
./scripts/godot.sh --editor --path .
./scripts/godot.sh --path .
./scripts/build-android.sh
```

If the ignored local toolchain is ever removed, recreate it with:

```bash
./scripts/setup-dev.sh
```

## Run on an Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it over USB and accept the debugging prompt.
3. Run the `Android: Connected devices` task.
4. Build the APK, then install it:

```bash
.tools/android-sdk/platform-tools/adb install -r build/android/Dinos4Helena-debug.apk
```

You can also select the phone from Godot's play/deploy controls after opening the editor.

## Prepare a Google Play release later

The checked-in preset intentionally creates a debug APK only. Before publishing:

1. Change `package/unique_name` in `export_presets.cfg` from `org.dinos4helena.game` to a package ID you own. A published package ID cannot be changed later.
2. In Godot, use `Project > Install Android Build Template`, then add a separate Android release preset with Gradle Build enabled and export format set to AAB.
3. Create a release keystore and keep both the file and passwords outside Git. Never reuse the generated debug key for a Play release.
4. Export a signed, non-debug `.aab`, test it on a Play internal-testing track, then complete the store listing and policy declarations.

Google Play requires Android App Bundles for new apps. Keep release signing credentials backed up securely; losing them can complicate future updates.

## Project choices

The game uses Godot's Compatibility renderer for broad Android GPU support. All six playable models come from Quaternius' [Animated Dinosaur Pack](https://quaternius.com/packs/animateddinosaurs.html), are dedicated to the public domain under CC0 1.0, and include idle, walk, run, jump, and attack animations. The original license and precise provenance are stored in `assets/models/dinosaurs/`.

The photorealistic menu background and portraits were generated specifically for this game. Their prompt provenance is recorded in `assets/ui/menu/GENERATED_ASSETS.md`.

The seeded landscape combines inexpensive procedural terrain, water, lighting, clouds, and biome overlays with a small reusable CC0 environment-model library. Repeated assets share imported meshes and materials to keep the expanded world practical on mobile hardware.
