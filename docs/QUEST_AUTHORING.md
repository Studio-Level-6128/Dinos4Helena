# Quest and mission authoring guide

This guide explains how to add a quest, add or reorder missions, customize a
mission's generated world, implement win and loss conditions, persist
progress, add artwork, and test the result.

## Concepts and runtime order

A **quest** is an ordered campaign. A **mission** is one playable step in that
campaign. Mission order is significant:

1. The first mission is unlocked in normal progression.
2. Completing a mission unlocks the next mission in the configured list.
3. Completed missions remain replayable.
4. Completion is saved by quest ID and mission ID in
   `user://quest_progress.cfg`.

For debugging, `config/quests.cfg` currently enables `[debug]`
`unlock_all_missions=true`. Every quest mission is immediately available,
including the final boss, without changing saved completion. Set it to `false`
and restart the game to restore sequential unlocking. Omitting the setting
also uses normal progression.

When a mission starts, the game:

1. Generates the normal deterministic world-layout data.
2. Runs the mission's setup script, which may modify that data.
3. Builds the landscape, player, wildlife, eggs, tokens, HUD, and minimap.
4. Instantiates the mission's event script.
5. Saves completion when the event script calls `complete()`.

The setup script therefore changes what will be built. The event script
observes and controls the live game.

## Folder layout

Use lowercase `snake_case` for IDs and directories. A quest with two missions
should look like this:

```text
config/
└── quests.cfg
quests/
└── river_journey/
    ├── missions.cfg
    └── missions/
        ├── find_the_river/
        │   ├── setup.gd
        │   └── event.gd
        └── cross_the_river/
            ├── setup.gd
            └── event.gd
assets/ui/quests/
├── river-journey.png
├── find-the-river.png
└── cross-the-river.png
```

IDs become save-data keys. Do not rename a published quest or mission ID unless
you also implement a progress migration. Titles and descriptions can be
changed freely.

## Add a quest

### 1. Create its directory

Create `quests/<quest_id>/missions/`, then add one subdirectory per mission.
Each mission must have a `setup.gd` and `event.gd`.

### 2. Register the quest

Add the quest ID to `[quests].quest_ids` in `config/quests.cfg`. The array
controls the order on the quest overview.

```ini
[quests]
quest_ids=["getting_started", "river_journey"]
overview_background="res://assets/ui/quests/quest-overview-background.png"

[river_journey]
title="River Journey"
description="Follow the valley river and find a safe crossing."
image="res://assets/ui/quests/river-journey.png"
mission_config="res://quests/river_journey/missions.cfg"
```

Required quest fields:

| Field | Meaning |
| --- | --- |
| `title` | Display name shown on the quest tile and page. |
| `description` | Short overview-tile description. |
| `image` | Quest cover image loaded through a `res://` path. |
| `mission_config` | Path to this quest's mission configuration. |

No change to `main.gd` is required for an ordinary new quest.

### 3. Create the mission configuration

Create `quests/<quest_id>/missions.cfg`:

```ini
[quest]
mission_ids=["find_the_river", "cross_the_river"]

[find_the_river]
title="Find the River"
description="Reach the river bank."
dinosaur="parasaurolophus"
map_theme="grassland"
image="res://assets/ui/quests/find-the-river.png"
setup_script="res://quests/river_journey/missions/find_the_river/setup.gd"
event_script="res://quests/river_journey/missions/find_the_river/event.gd"
target_distance=8.0

[cross_the_river]
title="Cross the River"
description="Reach the far bank without losing all health."
dinosaur="spinosaurus"
map_theme="grassland"
image="res://assets/ui/quests/cross-the-river.png"
setup_script="res://quests/river_journey/missions/cross_the_river/setup.gd"
event_script="res://quests/river_journey/missions/cross_the_river/event.gd"
```

Required mission fields:

| Field | Meaning |
| --- | --- |
| `title` | Mission name shown on its tile and objective HUD. |
| `description` | Brief objective shown on the tile and initially in the HUD. |
| `dinosaur` | Player dinosaur ID from `config/dinosaurs.cfg`. |
| `map_theme` | One of `grassland`, `desert`, `winter`, or `volcano`. |
| `image` | Mission tile artwork. |
| `setup_script` | Script that modifies the generated layout before building. |
| `event_script` | Live objective and failure-condition script. |

Any additional fields are mission-specific objective data. The event script
receives the complete section as its `objective` dictionary. Prefer these
config values over hard-coded counts, distances, and durations.

Mission order in `mission_ids` controls progression. Inserting a mission
between two existing missions changes which prerequisite unlocks the later
mission but does not erase existing completion flags.

## Write a setup script

Every setup script extends `RefCounted` and exposes
`setup(controller: Node)`:

```gdscript
extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_vegetation.append({
		"type": "grass",
		"position": Vector3(0.0, 0.015, 18.0),
		"scale": 1.2,
		"rotation": 0.0
	})
```

Setup runs after normal procedural generation. Use `append()` to add
mission-specific objects while keeping the normal world, or `clear()` /
replacement assignment when the mission requires a controlled scenario.

### Useful controller data

| Property | Purpose |
| --- | --- |
| `map_seed` | Current deterministic world seed. Use it when deriving NPC RNG seeds. |
| `selected_map_theme` | Active theme selected from the mission config. |
| `generated_vegetation` | Plants that will be built. |
| `generated_eggs` | Egg nests that will be built. |
| `generated_dinosaurs` | Wildlife that will be spawned. |
| `generated_tokens` | Power-up tokens that will be spawned. |
| `generated_ponds`, `generated_rivers` | Generated water layout. |
| `generated_hills`, `generated_trees`, `generated_rocks`, `generated_logs` | Solid world features. |

### Vegetation entry

```gdscript
{
	"type": "grass", # grass, poisonous, cycad, horsetail, fiddlehead, etc.
	"position": Vector3(0.0, 0.015, 18.0),
	"scale": 1.2,
	"rotation": 0.0
}
```

`grass` and other safe plant types join the `edible_plant` group when
built. `poisonous` plants are also tagged `poisonous_plant`.

### Egg entry

```gdscript
{
	"position": Vector3(-6.0, 0.1, 20.0),
	"rotation": 1.4
}
```

To require an exact number of nests, replace the existing array:

```gdscript
controller.generated_eggs = [
	{"position": Vector3(-6.0, 0.1, 20.0), "rotation": 0.4},
	{"position": Vector3(6.0, 0.1, 24.0), "rotation": 2.0}
]
```

### Wildlife entry

```gdscript
controller.generated_dinosaurs.append({
	"species": "triceratops",
	"position": Vector3(0.0, 0.1, 30.0),
	"pack_id": 1000,
	"pack_slot": 0,
	"patrol_center": Vector3(0.0, 0.0, 30.0),
	"rng_seed": controller.map_seed + 1000,
	"texture_variant": 0,
	"mission_role": "river_guide"
})
```

Required wildlife fields are `species`, `position`, `pack_id`,
`pack_slot`, `patrol_center`, and `rng_seed`. `texture_variant` is
optional.

`mission_role` is optional metadata and is the preferred way for the event
script to find mission-specific actors without depending on generated node
names. Mission carnivores may also set:

- `can_retreat=false` to disable injury retreat.
- `ignore_combat_odds=true` to make a forced target ignore normal risk checks.

Use unique positive `pack_id` values for separate herbivore packs. Use `-1`
for solitary hunters. Avoid placing actors inside water, lava, or solid
landmarks. The central spawn area is near `Vector3(0, 0.1, 5)` on normal
themes.

## Write an event script

Every event script extends the shared base:

```gdscript
extends "res://quests/mission_event.gd"
```

The base provides:

| Member | Purpose |
| --- | --- |
| `controller` | The live `main.gd` world controller. |
| `objective` | Dictionary containing every value from the mission's config section. |
| `ended` | Becomes `true` after completion or failure. |
| `set_progress(message)` | Updates the mission objective HUD. |
| `complete()` | Ends successfully, saves completion, and unlocks the next mission. |
| `fail(reason)` | Ends unsuccessfully and shows the supplied reason. |

When overriding `setup()`, call `super.setup()` first:

```gdscript
extends "res://quests/mission_event.gd"

var collected := 0


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.food_consumed.connect(_on_food_consumed)
	set_progress("Food: 0 / %d" % int(objective.get("target_count", 3)))


func _on_food_consumed(food_kind: String) -> void:
	if ended or food_kind != "plant":
		return
	collected += 1
	var target := int(objective.get("target_count", 3))
	set_progress("Food: %d / %d" % [collected, target])
	if collected >= target:
		complete()
```

For continuous conditions, use `_process(delta)`, guard against invalid
objects, and throttle UI updates:

```gdscript
extends "res://quests/mission_event.gd"

var elapsed := 0.0
var update_time := 0.0


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player):
		return
	elapsed += delta
	update_time -= delta
	if update_time <= 0.0:
		update_time = 0.5
		set_progress("Survive: %d seconds" % int(elapsed))
	if elapsed >= float(objective.get("target_seconds", 60.0)):
		complete()
```

### Useful live objects, groups, and signals

| API | Notes |
| --- | --- |
| `controller.player` | Player `CharacterBody3D`. |
| `controller.world_root` | Parent of the live generated world. |
| `controller.active_minimap.get_explored_fraction()` | Returns explored map fraction from `0.0` to `1.0`. |
| Player signal `food_consumed(food_kind)` | Emits `"plant"` or `"meat"` after food is fully consumed. |
| Player signal `died` | Use when player death needs a mission-specific result. |
| NPC signal `died(npc)` | Emitted by wildlife on death. |
| Baby signal `died(baby)` | Emitted by baby dinosaurs on death. |
| Group `npc_dinosaur` | All living or dying wildlife and babies. |
| Group `hunter_dinosaur` | Living carnivore NPCs. |
| Group `prey_dinosaur` | Living herbivore NPCs and babies. |
| Group `baby_dinosaur` | Hatched children. |
| Group `dinosaur_egg` | Unhatched egg nests. |
| Groups `edible_plant`, `edible_meat` | Current food nodes. |

NPCs record their most recent attacker in `last_attacker`. This lets a hunt
mission distinguish a player kill from a kill caused by other wildlife.

### Actor-specific win and loss example

Use `mission_role` rather than names:

```gdscript
extends "res://quests/mission_event.gd"


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		match str(npc.get_meta("mission_role", "")):
			"target":
				npc.died.connect(_on_target_died)
			"protected":
				npc.died.connect(_on_protected_died)
	set_progress("Defeat the target and protect your ally")


func _on_target_died(_npc: CharacterBody3D) -> void:
	complete()


func _on_protected_died(_npc: CharacterBody3D) -> void:
	fail("Your ally was killed")
```

Always guard callbacks and `_process()` with `ended` if they perform work
beyond calling `complete()` or `fail()`. The base methods themselves ignore
duplicate endings.

## Artwork

Store quest artwork under `assets/ui/quests/`:

- Overview background: 1280×720, wide 16:9.
- Quest covers: 768×512, wide 3:2.
- Mission tiles: 768×512, wide 3:2.

Keep important subjects readable at thumbnail size. Do not bake titles,
progress marks, locks, or borders into the image; Godot renders those elements.
For generated artwork, record the date, prompts or prompt summary, and any
scientific caveats in `assets/ui/quests/GENERATED_ASSETS.md`.

After adding or replacing images, force an import validation:

```bash
./scripts/godot.sh --headless --path . --editor --quit
```

## Progress and local testing

Progress is saved in `user://quest_progress.cfg`, using this shape:

```ini
[river_journey]
find_the_river=true
cross_the_river=true
```

During automated tests, override `game.quest_progress_path` with a
test-specific `user://` filename and clear `game.quest_progress`. Never let
tests write to the real player-progress path.

If you need to test a later mission directly, either complete its prerequisite
through `_mark_mission_completed()` using an isolated test file or start from
a prepared test-only `ConfigFile`.

## Testing checklist

For every new quest or mission, verify:

- Every `res://` image and script path exists.
- Quest and mission IDs are unique and stable.
- The configured dinosaur exists in `config/dinosaurs.cfg`.
- The setup script creates a reachable, winnable world.
- The event script has an explicit completion condition.
- Intended failure conditions call `fail()`.
- Mission 1 is available and later missions are initially locked.
- Completing each mission unlocks exactly the next mission.
- Completed missions are marked and replayable after restarting the game.
- Tile art has the correct species and no embedded UI text.
- The mission remains practical on a 1280×720 touch layout.

Run:

```bash
./scripts/godot.sh --headless --path . --script res://tests/quests_smoke.gd
./scripts/godot.sh --headless --path . --script res://tests/quest_missions_smoke.gd
./scripts/godot.sh --headless --path . --script res://tests/quest_outcomes_smoke.gd
./scripts/godot.sh --headless --path . --script res://tests/quest_release_smoke.gd
./scripts/godot.sh --headless --path . --editor --quit
git diff --check
./scripts/build-android.sh
```

The release smoke check uses explicit runtime checks rather than `assert()`,
which is omitted from release builds. To test the exported code and data before
installing on a device, export a pack and run it outside the project directory:

```bash
./scripts/godot.sh --headless --path . --export-pack "Android Release" /tmp/dinos4helena-quests.zip
cd /tmp
/path/to/Dinos4Helena/scripts/godot.sh --headless --main-pack /tmp/dinos4helena-quests.zip --script res://tests/quest_release_smoke.gd
```

Never put required setup or configuration loads inside `assert()`: Godot does
not evaluate those expressions in release builds.

Extend `tests/quests_smoke.gd` when adding catalog or progression behavior.
Extend `tests/quest_missions_smoke.gd` with assertions for the new mission's
setup data and important actor roles. Add a focused test for complex objective
logic rather than relying only on the generic boot test.
Extend `tests/quest_outcomes_smoke.gd` with at least one win and each explicit
loss condition so missions cannot remain active after their goal becomes impossible.

## Common mistakes

- **A later mission stays locked:** its immediate predecessor has not called
  `complete()`, or an ID was changed after progress was saved.
- **A mission can be opened out of order:** start it through
  `_start_quest_mission()`; do not bypass its unlock guard.
- **The event cannot find an actor:** add a unique `mission_role` in the setup
  data and query that metadata after actors are built.
- **The event receives no config value:** check the key's spelling in that
  mission's section and use `objective.get("key", fallback)`.
- **A setup object does not appear:** setup scripts change generated data, not
  live nodes. Use the expected dictionary fields and a valid `res://` script.
- **An objective fires multiple times:** guard callbacks with `ended`; the
  base class also protects `complete()` and `fail()`.
- **A mission is impossible on some seeds:** place required objects in known
  clear locations or replace the relevant generated array with a controlled
  layout.

## Frozen Pass environmental missions

`quests/frozen_pass/setup.gd` creates a deterministic, clear winter corridor.
Each mission has its own setup/event entry point inheriting the shared quest
scripts. The `mission_mode` configuration selects footprints, weather, ice,
stealth, boulder channels, or avalanche logic in `quests/frozen_pass/event.gd`.
All objective props, collisions, and effect players belong to that event node
and are freed when the player leaves or starts another mission. Existing free play
and other quests do not use these environmental rules.

Weather/ice/stealth/avalanche timing is configurable in `missions.cfg`.
Checkpoints advance in order; recoverable hazards reset position and motion,
while player death and harm to a sleeping giant produce mission failure.
English, German, and French strings live in the existing translation catalogs.
The mission introduction generator includes this quest; synthesized effect
sources are in `scripts/generate-frozen-pass-sounds.py`.

Additional checks for this quest:

```bash
./scripts/godot.sh --headless --path . --script res://tests/frozen_pass_smoke.gd
./scripts/godot.sh --headless --path . --fixed-fps 60 --script res://tests/frozen_pass_routes_smoke.gd
```

The first covers outcomes, recoverable hazards, progress persistence, and
language selection. The second moves real player bodies along each route and
pushes the boulders through normal movement, checking physical reachability.

## Heart of the Volcano

`quests/heart_of_volcano/setup.gd` reserves a deterministic route north of the
normal volcano and moves scenic lava away from required paths. Volcano free
play still starts at its original `(0, 0.1, 58)` position, while quest setup can
now supply `mission_player_start` just as on other themes.

Each mission has its own event script inheriting the shared geometry, sound,
localization, and checkpoint helpers in `quests/heart_of_volcano/event.gd`.
The six species are Parasaurolophus, Velociraptor, Apatosaurus, Triceratops,
Stegosaurus, and Spinosaurus. Gameplay uses the existing touch and keyboard
controls, including held Scream durations and the delayed Attack impact signal.
The script recognizes actual platform and ledge landings, balance holds,
aligned running attacks, and timed projectile deflections. Environmental retries
restore health and energy without clearing completed steps.

Black Wall remembers forward running for `charge_grace_seconds` (0.6 seconds)
so wall collision cannot cancel the delayed horn impact. Facing is checked
against the wall normal; `charge_alignment_tolerance` allows a three-unit
sideways offset from each crack. The player must keep Run held for the hit;
standing attacks, reverse movement, sideways hits, and expired charges fail.

Ashfang uses `quests/heart_of_volcano/boss.gd`, a mission-specific subclass of
normal wildlife. It keeps model, collision, animations, and normal player
attack targeting, while the event controls health, guard/recovery windows,
telegraphs, charges, sweeps, lava, phase retries, and retreat. The boss remains
alive and retreats after defeat; completion requires reaching the final
crossing. Phase checkpoints last for the current attempt; replay starts at
phase one. Settings are in `missions.cfg`. The optional `completion_detail_key`
provides the translated finale message without changing other quest results.

New asset prompts and audio provenance are recorded in their respective
`GENERATED_ASSETS.md` files. The existing narration generator includes all six
new mission IDs; effects can be reproduced with `scripts/generate-volcano-sounds.py`.

Additional checks:

```bash
./scripts/godot.sh --headless --path . --script res://tests/volcano_quest_smoke.gd
./scripts/godot.sh --headless --path . --fixed-fps 60 --script res://tests/volcano_routes_smoke.gd
```

The first checks species, objectives, wrong actions, recovery, persistence,
translations, voice selection, and all boss phases. The second completes every
mission using actual player movement and touch inputs, including real attack
hits against the boss. The packaged release smoke check also boots Ashfang and
verifies his phase HUD and all 24 missions' scripts, tile images, and narration.
