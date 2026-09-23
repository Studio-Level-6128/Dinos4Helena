# Dinos4Helena development guide

This guide explains how the project is organized, how its runtime systems fit together, and how to extend it safely. The game targets Godot 4.7 and Android, while remaining runnable from VS Code on the desktop.

## Quick start

Open the repository as a VS Code workspace and use `Terminal > Run Task`.

- `Godot: Open editor` opens the project in Godot.
- `Godot: Run game` launches the desktop build.
- `Android: Build debug APK` exports the signed debug APK.
- The individual `Godot: … test` tasks run headless smoke tests.

Equivalent terminal commands are:

```bash
./scripts/godot.sh --editor --path .
./scripts/godot.sh --path .
./scripts/build-android.sh
```

Run `./scripts/setup-dev.sh` if the ignored local Godot/Android toolchain under `.tools/` has been removed.

## Repository map

| Path | Responsibility |
| --- | --- |
| `scenes/main.tscn` | Minimal entry scene; most runtime nodes are built by code. |
| `scripts/main.gd` | Application flow, splash/menu/HUD, procedural layout, landscape and actor spawning. |
| `scripts/player_dino.gd` | Input, movement, camera, actions, audio, health, energy and player combat. |
| `scripts/npc_dino.gd` | Herbivore packs, carnivore strategy, wildlife movement and combat. |
| `scripts/egg_nest.gd` | Non-solid duck-to-incubate interaction and egg visuals. |
| `scripts/baby_dino.gd` | Baby companion following, health, death and meat drop. |
| `scripts/minimap.gd` | Runtime map drawing, fog of war and feast markers. |
| `scripts/powerup_token.gd` | Health, speed and strength collectibles. |
| `scripts/generated_materials.gd` | Shared textured-material construction. |
| `config/dinosaurs.cfg` | Species balance plus energy, token and breeding settings. |
| `tests/` | Headless integration/smoke tests. |
| `assets/` | Models, generated artwork/textures, audio and license metadata. |

## Runtime lifecycle

`main.gd` loads configuration and builds the selection menu, then places the startup splash above it. Dismissing the splash reveals the menu. Starting a game performs this sequence:

1. Validate and commit the six-digit seed.
2. Generate deterministic layout dictionaries.
3. Build lighting, weather, terrain, water and solid scenery.
4. Spawn tokens, the player, egg nests and wildlife.
5. Build the HUD and initialize the minimap.

Returning to the menu frees the world and HUD while retaining the already-built menu. Keep world-owned nodes below `world_root`; otherwise they may survive between sessions.

## Configuration and balancing

Use `config/dinosaurs.cfg` instead of hard-coding species balance. Each dinosaur section defines its model, diet, scale, speeds, strength, jump ability, health, collision and camera framing. Shared sections define energy costs, token behavior and breeding values.

Selection cards and runtime actors read the same file. When adding a setting, give code a sensible fallback and add a smoke-test assertion where practical.

### Adding a dinosaur

1. Add the model and its license/source information under `assets/models/`.
2. Add a complete species section to `config/dinosaurs.cfg`.
3. Add the identifier to `DINO_IDS` and to the correct diet list in `main.gd`.
4. Add its menu portrait and action sounds using the existing naming scheme.
5. Verify model facing, scale, collision, animation names and camera distance.
6. Run the dinosaur-selection, gameplay, wildlife and Android export tests.

## Procedural world generation

`_generate_world_layout()` uses a local `RandomNumberGenerator` seeded from the menu. It creates data only; `_build_landscape()` and the actor builders turn that data into nodes. Maintaining this separation keeps seed reproducibility testable.

Use `_find_world_position()` for solid objects and `_find_biome_position()` for biome-specific decoration. Add solid footprints to the local `occupied` list, and reject water positions with `_is_position_in_water()`. If a new generated collection affects the world identity, include it in `procedural_world_smoke.gd`'s layout signature.

## Adaptive mobile performance

Gameplay starts in the high-quality tier at native 3D resolution. After an eight-second warm-up, `main.gd` samples delivered frame rate in two-second windows. Two sustained samples below 42 FPS lower the tier; five samples above 56 FPS restore one tier. A cooldown prevents rapid oscillation.

- High preserves native resolution, original draw ranges, shadows and minimap refresh.
- Medium uses 86% 3D resolution, shorter shadow/draw distances and cheaper distant LODs.
- Low uses 72% 3D resolution, disables the world shadow and shortens scenery/camera ranges further.
- UI remains at native resolution in every tier.

Register new environment or actor renderables through `_register_quality_geometry()` with the closest existing category. Collision and AI remain active outside visual culling range. Update `performance_scaling_smoke.gd` when changing tier values.

## Wildlife AI

The wildlife controller uses explicit states rather than a behavior-tree plugin.

- Carnivores prioritize injury retreat, feeding, risk assessment, stalking and attacking in that order. Injury retreat begins below 50% health.
- Combat odds combine current/max health, strength, size and energy, plus partial power from nearby defenders.
- Herbivores prioritize pack defense, direct retaliation/fleeing and formation movement.
- Every pack has a slot-zero leader. It retains a 55–105 unit world goal until arrival and uses temporary collision-tangent steering rather than discarding a blocked goal. Followers use staggered formation targets and local separation.
- Same-pack collision exceptions prevent physical deadlocks. Slot one periodically trails beyond the pack-support radius, then regroups.
- Same-species checks exist both during target selection and damage application; preserve both layers.
- Pack and same-species membership are cached after spawning; use those caches for frequent AI queries and reserve whole-tree group scans for dynamic targets such as babies.

Babies join the prey and NPC groups so predators can target them, but use a separate script with no energy or hunting logic. Hunters give baby targets a strong selection bonus and use lower stalking/strike odds (0.55/0.68 instead of 0.78/1.0), while the combat-risk calculation still counts the nearby parent and herd before permitting an attack.

## UI and controls

The project uses a 1280×720 reference canvas with `canvas_items` stretching. Anchor controls before applying offsets so layouts scale correctly on Android. Touch buttons call `player.set_mobile_action()` and share the same action names as `InputMap` keyboard controls.

The splash and menu artwork are project assets under `assets/ui/menu/`. Keep generated-asset prompts and dates in `GENERATED_ASSETS.md`. Overlay important text in Godot rather than baking it into images.

## Tests

Every smoke test is a standalone `SceneTree` script. Tests instantiate the real main scene, exercise a focused behavior, free it and quit. Add new tests to `.vscode/tasks.json`.

Run all smoke tests from a shell with:

```bash
for test in tests/*_smoke.gd; do
  ./scripts/godot.sh --headless --path . --script "res://$test" || exit 1
done
```

Before handing off a change, also run:

```bash
./scripts/godot.sh --headless --editor --path . --quit
git diff --check
jq empty .vscode/tasks.json
./scripts/build-android.sh
```

Headless Godot may print resource-leak cleanup warnings after a successful test. Treat script errors, assertion failures, nonzero exits, or failed export verification as failures.

## Android debugging and release

The debug APK is written to `build/android/Dinos4Helena-debug.apk`. Install it with:

```bash
.tools/android-sdk/platform-tools/adb install -r build/android/Dinos4Helena-debug.apk
```

For a Play Store release, use a package ID you own, create an external release keystore, enable the Gradle build template, export an AAB, and test through Play's internal track. Never commit signing secrets or `.env` files.

## Coding conventions

- Use typed GDScript values where inference from `Variant` would be ambiguous.
- Prefer small actor scripts and keep global orchestration in `main.gd`.
- Explain intent, priority, or non-obvious engine behavior in comments; do not restate straightforward assignments.
- Preserve deterministic RNG by using the seeded generator passed through world layout code.
- Keep mobile costs predictable: reuse materials/models and avoid creating nodes every frame.
- Add a focused smoke test for every gameplay regression.
