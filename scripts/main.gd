extends Node3D

# Main application controller. This script owns the menu/HUD, seeded world
# generation, and the creation of runtime actors. Individual actor behavior
# lives in the smaller scripts preloaded below.
const PLAYER_SCRIPT := preload("res://scripts/player_dino.gd")
const NPC_DINO_SCRIPT := preload("res://scripts/npc_dino.gd")
const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")
const CLOUD_SCRIPT := preload("res://scripts/cloud.gd")
const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")
const POWERUP_TOKEN_SCRIPT := preload("res://scripts/powerup_token.gd")
const EGG_NEST_SCRIPT := preload("res://scripts/egg_nest.gd")
const BABY_DINO_SCRIPT := preload("res://scripts/baby_dino.gd")
const VIRTUAL_JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
# DINO_IDS is the player-selection roster. The two diet lists below are the
# deliberately smaller wildlife pools; Spinosaurus is player-only.
const DINO_IDS := ["trex", "spinosaurus", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]
const HERBIVORE_IDS := ["triceratops", "stegosaurus", "parasaurolophus", "apatosaurus"]
const CARNIVORE_IDS := ["trex", "velociraptor"]
const MAP_HALF_SIZE := 200.0
# Adaptive performance starts at full quality. It only reduces expensive
# rendering features after several sustained low-frame-rate samples, and uses
# a deliberately slower recovery threshold to avoid quality oscillation.
const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2
const PERFORMANCE_WARMUP_SECONDS := 8.0
const PERFORMANCE_SAMPLE_SECONDS := 2.0
const PERFORMANCE_DOWNGRADE_FPS := 42.0
const PERFORMANCE_UPGRADE_FPS := 56.0
const PERFORMANCE_CHANGE_COOLDOWN := 10.0
const PLAY_GUIDE_TEXT := """[b]MOVEMENT AND ACTIONS[/b]
Drag the right-hand movement wheel in any direction to combine forward/backward movement and steering. Use the left-hand buttons to jump, run, duck, attack, eat, or scream. Keyboard controls are WASD/arrows, Space, Shift, C/Ctrl, F, E, and R.

[b]HEALTH, ENERGY, AND FOOD[/b]
Every action costs energy; running, jumping, and fighting cost more. At zero energy, health starts to fall. Herbivores regain energy by holding EAT near plants. Carnivores eat meat left by defeated dinosaurs. Red tokens restore health; blue and orange tokens temporarily double speed or strength.

[b]WILDLIFE[/b]
Herbivores travel in moving packs. They flee hunters, but fight back and defend members of their own species. A matching herbivore player can shelter with a pack. Carnivores stalk prey, avoid fights they are unlikely to win, feed after a kill, and retreat when badly injured. Dinosaurs never attack their own species.

[b]EGGS AND BABIES[/b]
Egg nests are hidden throughout the valley. Stand over an egg and hold DUCK until it hatches. The baby matches your species, follows beside you, and has its own health. Protect it from predators.

[b]EXPLORING THE WORLD[/b]
Trees, rocks, fallen logs, hills, and raised ledges are solid. Rivers and lakes divide the forest and grassland areas. Invisible walls keep dinosaurs inside the valley. The minimap reveals terrain as you explore and marks meat from defeated dinosaurs.

[b]WORLD SEEDS[/b]
The six-digit seed on the selection screen controls the complete map layout. Reuse a seed to replay the same valley or generate a new random one."""
const ENVIRONMENT_MODEL_PATHS := {
	"tree": "res://assets/models/environment/araucaria_conifer.glb",
	"fern": "res://assets/models/environment/forest_fern.glb",
	"rock": "res://assets/models/environment/mossy_basalt_rock.glb",
	"cycad": "res://assets/models/environment/cycad.glb",
	"undergrowth": "res://assets/models/environment/forest_undergrowth.glb",
	"grass": "res://assets/models/environment/grass_cluster.glb",
	"tree_fern": "res://assets/models/environment/tree_fern.glb",
	"dead_tree": "res://assets/models/environment/dead_tree_snag.glb",
	"fallen_log": "res://assets/models/environment/fallen_rainforest_log.glb",
	"horsetail": "res://assets/models/environment/horsetail_colony.glb",
	"fiddlehead": "res://assets/models/environment/fiddlehead_cluster.glb"
}

var player: CharacterBody3D
var status_label: Label
var world_root: Node3D
var game_hud: CanvasLayer
var menu_layer: CanvasLayer
var landing_page: Control
var free_game_page: Control
var credits_overlay: Control
var play_guide_overlay: Control
var splash_layer: CanvasLayer
var splash_root: Control
var splash_dismissed := false
var health_bar: ProgressBar
var energy_bar: ProgressBar
var health_label: Label
var energy_label: Label
var bonus_label: Label
var selected_dino_name := "T-Rex"
var selected_dino_id := "trex"
var dinosaur_config := ConfigFile.new()
var seed_input: LineEdit
var map_seed := 0
var generated_ponds: Array = []
var generated_hills: Array = []
var generated_trees: Array = []
var generated_rocks: Array = []
var generated_rivers: Array = []
var generated_vegetation: Array = []
var generated_biomes: Array = []
var generated_clouds: Array = []
var generated_high_ground: Array = []
var generated_logs: Array = []
var generated_dinosaurs: Array = []
var generated_tokens: Array = []
var generated_eggs: Array = []
var environment_models: Dictionary = {}
var token_rng := RandomNumberGenerator.new()
var companions_spawned := 0
var performance_tier := QUALITY_HIGH
var performance_warmup := 0.0
var performance_sample_time := 0.0
var performance_sample_frames := 0
var performance_low_samples := 0
var performance_high_samples := 0
var performance_change_cooldown := 0.0
var quality_geometry: Array[GeometryInstance3D] = []
var sun_light: DirectionalLight3D
var active_minimap: Control


func _ready() -> void:
	add_to_group("world_controller")
	var config_error := dinosaur_config.load("res://config/dinosaurs.cfg")
	assert(config_error == OK, "Could not load dinosaur configuration")
	_create_input_actions()
	_build_main_menu()
	_build_splash_screen()


func _process(delta: float) -> void:
	# Startup generation is intentionally excluded: only sustained gameplay FPS
	# should decide whether this device needs a lower rendering tier.
	if not is_instance_valid(world_root) or not is_instance_valid(player):
		return
	performance_warmup = maxf(performance_warmup - delta, 0.0)
	performance_change_cooldown = maxf(performance_change_cooldown - delta, 0.0)
	if performance_warmup > 0.0:
		return
	performance_sample_time += delta
	performance_sample_frames += 1
	if performance_sample_time < PERFORMANCE_SAMPLE_SECONDS:
		return
	var measured_fps := float(performance_sample_frames) / maxf(performance_sample_time, 0.001)
	performance_sample_time = 0.0
	performance_sample_frames = 0
	if measured_fps < PERFORMANCE_DOWNGRADE_FPS:
		performance_low_samples += 1
		performance_high_samples = 0
	elif measured_fps > PERFORMANCE_UPGRADE_FPS:
		performance_high_samples += 1
		performance_low_samples = 0
	else:
		performance_low_samples = 0
		performance_high_samples = 0
	if performance_change_cooldown > 0.0:
		return
	if performance_low_samples >= 2 and performance_tier > QUALITY_LOW:
		_apply_performance_tier(performance_tier - 1)
	elif performance_high_samples >= 5 and performance_tier < QUALITY_HIGH:
		_apply_performance_tier(performance_tier + 1)


func _start_game(dino_id: String) -> void:
	# Tests and keyboard users may start directly, so make sure the splash can
	# never remain above a running world.
	_dismiss_splash(true)
	_commit_world_seed()
	selected_dino_id = dino_id
	selected_dino_name = dinosaur_config.get_value(dino_id, "display_name", dino_id.capitalize())
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	menu_layer.hide()
	world_root = Node3D.new()
	world_root.name = "PrehistoricWorld"
	add_child(world_root)
	quality_geometry.clear()
	sun_light = null
	active_minimap = null
	_generate_world_layout()
	_build_environment()
	_build_clouds()
	_build_ambient_audio()
	_build_landscape()
	_build_powerup_tokens()
	_build_player(dino_id)
	_build_egg_nests()
	_build_wild_dinosaurs()
	_build_hud()
	_reset_adaptive_performance()


func _return_to_main_menu() -> void:
	if is_instance_valid(game_hud):
		game_hud.queue_free()
	if is_instance_valid(world_root):
		world_root.queue_free()
	player = null
	status_label = null
	health_bar = null
	energy_bar = null
	health_label = null
	energy_label = null
	bonus_label = null
	companions_spawned = 0
	quality_geometry.clear()
	sun_light = null
	active_minimap = null
	get_viewport().scaling_3d_scale = 1.0
	_show_landing_page()
	menu_layer.show()


func _set_random_world_seed() -> void:
	var randomizer := RandomNumberGenerator.new()
	randomizer.randomize()
	var next_seed := randomizer.randi_range(100000, 999999)
	if next_seed == map_seed:
		next_seed = 100000 if next_seed == 999999 else next_seed + 1
	map_seed = next_seed
	if is_instance_valid(seed_input):
		seed_input.text = "%06d" % map_seed


func _on_seed_text_changed(new_text: String) -> void:
	var digits := ""
	for character in new_text:
		if character >= "0" and character <= "9":
			digits += character
	if digits != new_text:
		seed_input.text = digits.left(6)
		seed_input.caret_column = seed_input.text.length()


func _commit_world_seed() -> void:
	if not is_instance_valid(seed_input) or seed_input.text.length() != 6 or int(seed_input.text) < 100000:
		_set_random_world_seed()
	map_seed = int(seed_input.text)


func _build_main_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "MainMenu"
	add_child(menu_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/ui/menu/prehistoric-valley.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.04, 0.025, 0.46)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	# The menu has two distinct levels: a simple mode landing page and the
	# detailed Free Game setup page. Keeping both under the same CanvasLayer
	# makes transitions instant and retains the chosen seed between visits.
	landing_page = Control.new()
	landing_page.name = "LandingPage"
	landing_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(landing_page)

	free_game_page = Control.new()
	free_game_page.name = "FreeGamePage"
	free_game_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(free_game_page)
	free_game_page.hide()

	var title := Label.new()
	title.text = "DINOS4HELENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-440, 62)
	title.size = Vector2(880, 78)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("fff2c2"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	landing_page.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Helena's Dino game - made by dad"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-350, 136)
	subtitle.size = Vector2(700, 40)
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Color("f5dc9d"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	landing_page.add_child(subtitle)

	var mode_tiles := HBoxContainer.new()
	mode_tiles.name = "GameModeTiles"
	mode_tiles.set_anchors_preset(Control.PRESET_CENTER)
	mode_tiles.position = Vector2(-344, -110)
	mode_tiles.size = Vector2(688, 238)
	mode_tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_tiles.add_theme_constant_override("separation", 28)
	landing_page.add_child(mode_tiles)

	var quests_tile := Button.new()
	quests_tile.name = "QuestsTile"
	quests_tile.text = "QUESTS\nCOMING LATER"
	quests_tile.custom_minimum_size = Vector2(330, 220)
	quests_tile.disabled = true
	quests_tile.focus_mode = Control.FOCUS_NONE
	quests_tile.tooltip_text = "Quests will be added in a future update"
	quests_tile.add_theme_font_size_override("font_size", 25)
	quests_tile.add_theme_color_override("font_disabled_color", Color(0.92, 0.92, 0.82, 0.92))
	quests_tile.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.015, 0.96))
	quests_tile.add_theme_constant_override("outline_size", 8)
	quests_tile.add_theme_stylebox_override("disabled", _tile_image_style(load("res://assets/ui/menu/quests-tile.png"), Color(0.44, 0.47, 0.42, 1.0)))
	mode_tiles.add_child(quests_tile)

	var free_game_tile := Button.new()
	free_game_tile.name = "FreeGameTile"
	free_game_tile.text = "FREE GAME\nCHOOSE YOUR DINOSAUR"
	free_game_tile.custom_minimum_size = Vector2(330, 220)
	free_game_tile.focus_mode = Control.FOCUS_NONE
	free_game_tile.add_theme_font_size_override("font_size", 25)
	free_game_tile.add_theme_color_override("font_color", Color("fff2c2"))
	free_game_tile.add_theme_color_override("font_hover_color", Color.WHITE)
	free_game_tile.add_theme_color_override("font_pressed_color", Color.WHITE)
	free_game_tile.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.015, 0.96))
	free_game_tile.add_theme_constant_override("outline_size", 8)
	var free_game_art: Texture2D = load("res://assets/ui/menu/free-game-tile.png")
	free_game_tile.add_theme_stylebox_override("normal", _tile_image_style(free_game_art, Color(0.72, 0.72, 0.68, 1.0)))
	free_game_tile.add_theme_stylebox_override("hover", _tile_image_style(free_game_art, Color(0.92, 0.92, 0.86, 1.0)))
	free_game_tile.add_theme_stylebox_override("pressed", _tile_image_style(free_game_art, Color(0.58, 0.6, 0.54, 1.0)))
	free_game_tile.pressed.connect(_show_free_game_page)
	mode_tiles.add_child(free_game_tile)

	var free_game_title := Label.new()
	free_game_title.text = "FREE GAME"
	free_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	free_game_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	free_game_title.position = Vector2(-260, 12)
	free_game_title.size = Vector2(520, 44)
	free_game_title.add_theme_font_size_override("font_size", 32)
	free_game_title.add_theme_color_override("font_color", Color("fff2c2"))
	free_game_page.add_child(free_game_title)

	var back_button := Button.new()
	back_button.name = "BackToLandingButton"
	back_button.text = "← BACK"
	back_button.position = Vector2(20, 18)
	back_button.size = Vector2(126, 42)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
	back_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
	back_button.pressed.connect(_show_landing_page)
	free_game_page.add_child(back_button)

	var prompt := Label.new()
	prompt.text = "CHOOSE YOUR DINOSAUR"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.position = Vector2(-260, 55)
	prompt.size = Vector2(520, 42)
	prompt.add_theme_font_size_override("font_size", 21)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	free_game_page.add_child(prompt)

	var seed_row := HBoxContainer.new()
	seed_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	seed_row.position = Vector2(-225, 94)
	seed_row.size = Vector2(450, 40)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 10)
	free_game_page.add_child(seed_row)

	var seed_label := Label.new()
	seed_label.text = "WORLD SEED"
	seed_label.add_theme_font_size_override("font_size", 16)
	seed_label.add_theme_color_override("font_color", Color("fff2c2"))
	seed_row.add_child(seed_label)

	seed_input = LineEdit.new()
	seed_input.name = "WorldSeed"
	seed_input.custom_minimum_size = Vector2(112, 36)
	seed_input.max_length = 6
	seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_input.add_theme_font_size_override("font_size", 18)
	seed_input.tooltip_text = "Enter any six-digit number to replay the same world"
	seed_input.text_changed.connect(_on_seed_text_changed)
	seed_row.add_child(seed_input)

	var random_seed_button := Button.new()
	random_seed_button.text = "NEW RANDOM SEED"
	random_seed_button.custom_minimum_size = Vector2(176, 36)
	random_seed_button.focus_mode = Control.FOCUS_NONE
	random_seed_button.add_theme_font_size_override("font_size", 14)
	random_seed_button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.92), Color(0.72, 0.83, 0.42, 0.8)))
	random_seed_button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.43, 0.22, 0.96), Color("f7f2d0")))
	random_seed_button.pressed.connect(_set_random_world_seed)
	seed_row.add_child(random_seed_button)
	_set_random_world_seed()

	var cards := VBoxContainer.new()
	cards.name = "DinosaurCards"
	cards.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cards.position = Vector2(-430, 137)
	cards.size = Vector2(860, 496)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 8)
	free_game_page.add_child(cards)

	var card_rows: Array[HBoxContainer] = []
	for row_index in 2:
		var row := HBoxContainer.new()
		row.name = "DinosaurCardRow%d" % (row_index + 1)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards.add_child(row)
		card_rows.append(row)

	for dino_index in DINO_IDS.size():
		var dino_id: String = DINO_IDS[dino_index]
		var display_name: String = dinosaur_config.get_value(dino_id, "display_name", dino_id.capitalize())
		card_rows[0 if dino_index < 4 else 1].add_child(_create_dino_card(dino_id, display_name))

	var footer := Label.new()
	footer.text = "Select a dinosaur to begin your prehistoric adventure"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-350, -54)
	footer.size = Vector2(700, 32)
	footer.add_theme_font_size_override("font_size", 17)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	free_game_page.add_child(footer)

	var credits_button := Button.new()
	credits_button.name = "CreditsButton"
	credits_button.text = "CREDITS"
	credits_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits_button.position = Vector2(-170, -66)
	credits_button.size = Vector2(150, 44)
	credits_button.focus_mode = Control.FOCUS_NONE
	credits_button.add_theme_font_size_override("font_size", 16)
	credits_button.add_theme_color_override("font_color", Color("f7f2d0"))
	credits_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
	credits_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
	credits_button.pressed.connect(_open_credits)
	landing_page.add_child(credits_button)

	var guide_button := Button.new()
	guide_button.name = "PlayGuideButton"
	guide_button.text = "HOW TO PLAY"
	guide_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	guide_button.position = Vector2(20, -66)
	guide_button.size = Vector2(170, 44)
	guide_button.focus_mode = Control.FOCUS_NONE
	guide_button.add_theme_font_size_override("font_size", 16)
	guide_button.add_theme_color_override("font_color", Color("f7f2d0"))
	guide_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
	guide_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
	guide_button.pressed.connect(_open_play_guide)
	free_game_page.add_child(guide_button)
	_build_credits_overlay(root)
	_build_play_guide_overlay(root)


func _show_free_game_page() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	landing_page.hide()
	free_game_page.show()


func _show_landing_page() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	free_game_page.hide()
	landing_page.show()


func _build_splash_screen() -> void:
	# CanvasLayer keeps the startup art above the menu while Godot finishes
	# importing and preparing the first interactive screen.
	splash_dismissed = false
	menu_layer.hide()
	splash_layer = CanvasLayer.new()
	splash_layer.name = "StartupSplash"
	splash_layer.layer = 20
	add_child(splash_layer)
	splash_root = Control.new()
	splash_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_layer.add_child(splash_root)

	var artwork := TextureRect.new()
	artwork.name = "DinoFightArtwork"
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.texture = load("res://assets/ui/menu/dino-fight-splash.png")
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_root.add_child(artwork)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.018, 0.012, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_root.add_child(shade)

	var title := Label.new()
	title.text = "DINOS4HELENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-480, 38)
	title.size = Vector2(960, 86)
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color("fff1bc"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	splash_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A PREHISTORIC ADVENTURE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-350, 116)
	subtitle.size = Vector2(700, 38)
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("f1d690"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	splash_root.add_child(subtitle)

	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "TAP TO CONTINUE"
	continue_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	continue_button.position = Vector2(-150, -78)
	continue_button.size = Vector2(300, 52)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_color_override("font_color", Color("fff2c2"))
	continue_button.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.075, 0.045, 0.86), Color(0.9, 0.76, 0.34, 0.9)))
	continue_button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.28, 0.13, 0.94), Color("fff2c2")))
	continue_button.pressed.connect(_dismiss_splash)
	splash_root.add_child(continue_button)
	get_tree().create_timer(4.0).timeout.connect(_dismiss_splash)


func _dismiss_splash(immediate := false) -> void:
	if splash_dismissed:
		return
	splash_dismissed = true
	if immediate or not is_instance_valid(splash_root):
		if is_instance_valid(splash_layer):
			splash_layer.queue_free()
		menu_layer.show()
		return
	var tween := create_tween()
	tween.tween_property(splash_root, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func() -> void:
		if is_instance_valid(splash_layer):
			splash_layer.queue_free()
		if is_instance_valid(menu_layer):
			menu_layer.show()
	)


func _build_credits_overlay(parent: Control) -> void:
	credits_overlay = Control.new()
	credits_overlay.name = "CreditsOverlay"
	credits_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(credits_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.01, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	credits_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -180)
	panel.size = Vector2(680, 360)
	panel.add_theme_stylebox_override("panel", _credits_style())
	credits_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "CREDITS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(heading)

	var dedication := Label.new()
	dedication.name = "Dedication"
	dedication.text = "For Helena - have fun. Dad."
	dedication.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dedication.add_theme_font_size_override("font_size", 23)
	dedication.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(dedication)

	var author := Label.new()
	author.name = "AuthorCredit"
	author.text = "Open Souce Game by Janis Keuper."
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author.add_theme_font_size_override("font_size", 19)
	author.add_theme_color_override("font_color", Color("f5dc9d"))
	column.add_child(author)

	var license := Label.new()
	license.name = "LicenseCredit"
	license.text = "License: GPL v3"
	license.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	license.add_theme_font_size_override("font_size", 18)
	license.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	column.add_child(license)

	var github := LinkButton.new()
	github.name = "GithubLink"
	github.text = "Github: https://github.com/keuperj/Dinos4Helena"
	github.set_meta("uri", "https://github.com/keuperj/Dinos4Helena")
	github.custom_minimum_size = Vector2(600, 34)
	github.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	github.add_theme_font_size_override("font_size", 18)
	github.add_theme_color_override("font_color", Color("77d7ff"))
	github.add_theme_color_override("font_hover_color", Color("bcecff"))
	github.pressed.connect(_open_credits_github)
	column.add_child(github)

	var close_button := Button.new()
	close_button.name = "CloseCreditsButton"
	close_button.text = "BACK"
	close_button.custom_minimum_size = Vector2(210, 48)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.95), Color(0.72, 0.83, 0.42, 0.8)))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.43, 0.22, 0.98), Color("f7f2d0")))
	close_button.pressed.connect(_close_credits)
	column.add_child(close_button)
	credits_overlay.hide()


func _open_credits() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.show()


func _close_credits() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()


func _build_play_guide_overlay(parent: Control) -> void:
	play_guide_overlay = Control.new()
	play_guide_overlay.name = "PlayGuideOverlay"
	play_guide_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_guide_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(play_guide_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.01, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	play_guide_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-470, -310)
	panel.size = Vector2(940, 620)
	panel.add_theme_stylebox_override("panel", _credits_style())
	play_guide_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "HOW TO PLAY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(heading)

	var guide_text := RichTextLabel.new()
	guide_text.name = "PlayGuideText"
	guide_text.bbcode_enabled = true
	guide_text.text = PLAY_GUIDE_TEXT
	guide_text.custom_minimum_size = Vector2(850, 430)
	guide_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_text.scroll_active = true
	guide_text.add_theme_font_size_override("normal_font_size", 16)
	guide_text.add_theme_font_size_override("bold_font_size", 18)
	guide_text.add_theme_color_override("default_color", Color("f4f0df"))
	column.add_child(guide_text)

	var close_button := Button.new()
	close_button.name = "ClosePlayGuideButton"
	close_button.text = "BACK"
	close_button.custom_minimum_size = Vector2(210, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.95), Color(0.72, 0.83, 0.42, 0.8)))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.43, 0.22, 0.98), Color("f7f2d0")))
	close_button.pressed.connect(_close_play_guide)
	column.add_child(close_button)
	play_guide_overlay.hide()


func _open_play_guide() -> void:
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.show()


func _close_play_guide() -> void:
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()


func _open_credits_github() -> void:
	OS.shell_open("https://github.com/keuperj/Dinos4Helena")


func _credits_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.045, 0.97)
	style.border_color = Color(0.82, 0.72, 0.35, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style


func _create_dino_card(dino_id: String, display_name: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(202, 238)
	panel.add_theme_stylebox_override("panel", _card_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)

	var portrait := TextureButton.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(186, 116)
	portrait.texture_normal = load("res://assets/ui/menu/%s.png" % dino_id)
	portrait.ignore_texture_size = true
	# Keep the complete dinosaur visible. The generated portraits have varying
	# aspect ratios, so cover mode would crop heads, tails, or feet.
	portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	portrait.tooltip_text = "Play as " + display_name
	portrait.pressed.connect(_start_game.bind(dino_id))
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15 if display_name.length() < 13 else 13)
	name_label.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(name_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 0)
	column.add_child(stats)
	_add_stat(stats, "SPEED", "%.1f" % float(dinosaur_config.get_value(dino_id, "run_speed", 0.0)))
	_add_stat(stats, "STRENGTH", "%d/10" % int(dinosaur_config.get_value(dino_id, "strength", 0)))
	_add_stat(stats, "CAN JUMP", "YES" if dinosaur_config.get_value(dino_id, "can_jump", false) else "NO")
	_add_stat(stats, "HEALTH", str(int(dinosaur_config.get_value(dino_id, "max_health", 0))))

	var play := Button.new()
	play.text = "PLAY"
	play.custom_minimum_size.y = 27
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_font_size_override("font_size", 14)
	play.add_theme_color_override("font_color", Color("f7f2d0"))
	play.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.92), Color(0.72, 0.83, 0.42, 0.8)))
	play.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.43, 0.22, 0.96), Color("f7f2d0")))
	play.add_theme_stylebox_override("pressed", _button_style(Color(0.52, 0.64, 0.24, 1.0), Color.WHITE))
	play.pressed.connect(_start_game.bind(dino_id))
	column.add_child(play)
	return panel


func _add_stat(parent: GridContainer, stat_name: String, stat_value: String) -> void:
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.68))
	parent.add_child(name_label)
	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", Color("f5dc9d"))
	parent.add_child(value_label)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.045, 0.88)
	style.border_color = Color(0.82, 0.72, 0.35, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	return style


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f95c7")
	sky_material.sky_horizon_color = Color("d6e6b5")
	sky_material.ground_bottom_color = Color("425b2e")
	sky_material.ground_horizon_color = Color("c7d39b")
	sky_material.sun_angle_max = 10.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("b9caa3")
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.45
	world_environment.environment = environment
	world_root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff1c4")
	sun.light_energy = 1.42
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	world_root.add_child(sun)
	sun_light = sun


func _build_clouds() -> void:
	var cloud_layer := Node3D.new()
	cloud_layer.name = "Clouds"
	world_root.add_child(cloud_layer)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.94, 0.97, 0.96, 0.72)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.roughness = 1.0
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 1.0
	puff_mesh.height = 2.0
	puff_mesh.radial_segments = 12
	puff_mesh.rings = 6
	for cloud_data in generated_clouds:
		var cloud := Node3D.new()
		cloud.name = "Cloud"
		cloud.set_script(CLOUD_SCRIPT)
		cloud.position = cloud_data["position"]
		cloud.call("setup", cloud_data["direction"], cloud_data["speed"], MAP_HALF_SIZE + 35.0)
		cloud_layer.add_child(cloud)
		var cloud_scale: float = cloud_data["scale"]
		for puff_index in 4:
			var puff := MeshInstance3D.new()
			puff.mesh = puff_mesh
			puff.material_override = cloud_material
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3((float(puff_index) - 1.5) * 2.3, sin(float(puff_index) * 1.7) * 0.45, cos(float(puff_index) * 1.3) * 0.8) * cloud_scale
			puff.scale = Vector3(2.4, 0.72, 1.45) * cloud_scale * (0.82 + float(puff_index % 2) * 0.22)
			cloud.add_child(puff)
			_register_quality_geometry(puff, "cloud")


func _build_ambient_audio() -> void:
	var ambient_layers := [
		["prehistoric_jungle", -16.0],
		["distant_dinosaurs", -23.0]
	]
	for layer in ambient_layers:
		var path := "res://assets/audio/ambient/%s.mp3" % layer[0]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path)
		if stream is AudioStreamMP3:
			stream.loop = true
		var audio := AudioStreamPlayer.new()
		audio.name = str(layer[0]).to_pascal_case()
		audio.stream = stream
		audio.volume_db = layer[1]
		world_root.add_child(audio)
		audio.play()


func _generate_world_layout() -> void:
	generated_ponds.clear()
	generated_hills.clear()
	generated_trees.clear()
	generated_rocks.clear()
	generated_rivers.clear()
	generated_vegetation.clear()
	generated_biomes.clear()
	generated_clouds.clear()
	generated_high_ground.clear()
	generated_logs.clear()
	generated_dinosaurs.clear()
	generated_tokens.clear()
	generated_eggs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var occupied: Array = []

	for index in rng.randi_range(3, 5):
		generated_biomes.append({
			"type": "forest",
			"position": _random_clear_position(rng, 45.0),
			"radius": rng.randf_range(42.0, 64.0)
		})
	for index in rng.randi_range(2, 4):
		generated_biomes.append({
			"type": "grassland",
			"position": _random_clear_position(rng, 38.0),
			"radius": rng.randf_range(38.0, 58.0)
		})

	for index in rng.randi_range(3, 5):
		var pond_size := Vector2(rng.randf_range(22.0, 44.0), rng.randf_range(16.0, 34.0))
		var pond_radius := maxf(pond_size.x, pond_size.y) * 0.6
		var pond_position := _find_world_position(rng, pond_radius, occupied, 8.0)
		generated_ponds.append({"position": Vector3(pond_position.x, 0.025, pond_position.y), "size": pond_size})
		occupied.append({"position": pond_position, "radius": pond_radius})

	var river_points := PackedVector2Array()
	var horizontal_river := rng.randf() > 0.5
	var river_offset := rng.randf_range(52.0, 105.0) * (-1.0 if rng.randf() < 0.5 else 1.0)
	var river_phase := rng.randf_range(0.0, TAU)
	for point_index in 21:
		var along := lerpf(-MAP_HALF_SIZE - 8.0, MAP_HALF_SIZE + 8.0, float(point_index) / 20.0)
		var across := river_offset + sin(float(point_index) * 0.62 + river_phase) * rng.randf_range(12.0, 25.0)
		river_points.append(Vector2(along, across) if horizontal_river else Vector2(across, along))
	generated_rivers.append({"points": river_points, "width": rng.randf_range(8.0, 13.0)})

	for index in rng.randi_range(10, 15):
		var hill_scale := Vector3(rng.randf_range(9.0, 20.0), rng.randf_range(3.5, 8.0), rng.randf_range(8.0, 18.0))
		var hill_radius := maxf(hill_scale.x, hill_scale.z) * 0.82
		var hill_position := _find_world_position(rng, hill_radius, occupied, 7.0)
		generated_hills.append({"position": Vector3(hill_position.x, hill_scale.y * 0.48, hill_position.y), "scale": hill_scale})
		occupied.append({"position": hill_position, "radius": hill_radius})

	for index in rng.randi_range(10, 14):
		var formation_position := _find_world_position(rng, 7.5, occupied, 5.0)
		generated_high_ground.append({
			"position": Vector3(formation_position.x, 0.0, formation_position.y),
			"rotation": rng.randf_range(0.0, TAU),
			"scale": rng.randf_range(0.9, 1.3)
		})
		occupied.append({"position": formation_position, "radius": 7.5})

	for index in rng.randi_range(118, 152):
		var tree_scale := rng.randf_range(1.0, 2.15)
		var tree_position := _find_biome_position(rng, "forest", 1.55 * tree_scale, occupied, 1.7)
		var tree_roll := rng.randf()
		var tree_type := "tree" if tree_roll < 0.72 else ("tree_fern" if tree_roll < 0.92 else "dead_tree")
		generated_trees.append({"type": tree_type, "position": Vector3(tree_position.x, 0.0, tree_position.y), "scale": tree_scale, "rotation": rng.randf_range(0.0, TAU)})
		occupied.append({"position": tree_position, "radius": 0.58 * tree_scale})

	for index in rng.randi_range(52, 72):
		var rock_scale := rng.randf_range(0.65, 1.65)
		var rock_position := _find_world_position(rng, 1.1 * rock_scale, occupied, 1.5)
		generated_rocks.append({"position": Vector3(rock_position.x, 0.0, rock_position.y), "scale": rock_scale})
		occupied.append({"position": rock_position, "radius": 0.9 * rock_scale})

	for index in rng.randi_range(18, 28):
		var log_scale := rng.randf_range(0.8, 1.35)
		var log_position := _find_biome_position(rng, "forest", 3.5 * log_scale, occupied, 1.2)
		generated_logs.append({"position": Vector3(log_position.x, 0.0, log_position.y), "scale": log_scale, "rotation": rng.randf_range(0.0, TAU)})
		occupied.append({"position": log_position, "radius": 3.5 * log_scale})

	for index in rng.randi_range(220, 285):
		var plant_roll := rng.randf()
		var plant_type := "fern"
		if plant_roll < 0.24:
			plant_type = "undergrowth"
		elif plant_roll < 0.40:
			plant_type = "cycad"
		elif plant_roll < 0.63:
			plant_type = "horsetail"
		elif plant_roll < 0.82:
			plant_type = "fiddlehead"
		var plant_scale := rng.randf_range(0.75, 1.5)
		var plant_position := _find_biome_position(rng, "forest", 0.7 * plant_scale, [], 0.0)
		generated_vegetation.append({"type": plant_type, "position": Vector3(plant_position.x, 0.02, plant_position.y), "scale": plant_scale, "rotation": rng.randf_range(0.0, TAU)})

	for index in rng.randi_range(360, 460):
		var grass_scale := rng.randf_range(0.7, 1.4)
		var grass_position := _find_biome_position(rng, "grassland", 0.45 * grass_scale, [], 0.0)
		generated_vegetation.append({"type": "grass", "position": Vector3(grass_position.x, 0.015, grass_position.y), "scale": grass_scale, "rotation": rng.randf_range(0.0, TAU)})

	for pack_index in rng.randi_range(6, 9):
		var species: String = HERBIVORE_IDS[rng.randi_range(0, HERBIVORE_IDS.size() - 1)]
		var member_count := rng.randi_range(2, 4) if species == "apatosaurus" else rng.randi_range(4, 6)
		var pack_radius := 10.0 if species == "apatosaurus" else 7.0
		var pack_center := _find_world_position(rng, pack_radius, occupied, 5.0)
		occupied.append({"position": pack_center, "radius": pack_radius})
		for member_index in member_count:
			var angle := TAU * float(member_index) / float(member_count) + rng.randf_range(-0.35, 0.35)
			var distance := rng.randf_range(1.8, pack_radius * 0.55)
			var member_position := pack_center + Vector2(cos(angle), sin(angle)) * distance
			generated_dinosaurs.append({
				"species": species,
				"position": Vector3(member_position.x, 0.1, member_position.y),
				"pack_id": pack_index,
				"pack_slot": member_index,
				"patrol_center": Vector3(pack_center.x, 0.0, pack_center.y),
				"rng_seed": rng.randi(),
				"texture_variant": rng.randi_range(0, GENERATED_MATERIALS.dino_variant_count() - 1)
			})

	for hunter_index in rng.randi_range(4, 6):
		var hunter_species: String = CARNIVORE_IDS[rng.randi_range(0, CARNIVORE_IDS.size() - 1)]
		var hunter_position := _find_world_position(rng, 4.0, occupied, 12.0)
		occupied.append({"position": hunter_position, "radius": 4.0})
		generated_dinosaurs.append({
			"species": hunter_species,
			"position": Vector3(hunter_position.x, 0.1, hunter_position.y),
			"pack_id": -1,
			"pack_slot": -1,
			"patrol_center": Vector3(hunter_position.x, 0.0, hunter_position.y),
			"rng_seed": rng.randi(),
			"texture_variant": rng.randi_range(0, GENERATED_MATERIALS.dino_variant_count() - 1)
		})

	var token_counts := {
		"health": int(dinosaur_config.get_value("tokens", "health_count", 14)),
		"speed": int(dinosaur_config.get_value("tokens", "speed_count", 8)),
		"strength": int(dinosaur_config.get_value("tokens", "strength_count", 8))
	}
	for token_type in token_counts:
		for token_index in int(token_counts[token_type]):
			var token_position := _find_world_position(rng, 1.4, occupied, 2.5)
			generated_tokens.append({"type": token_type, "position": Vector3(token_position.x, 0.0, token_position.y)})
			occupied.append({"position": token_position, "radius": 1.4})

	var egg_count := int(dinosaur_config.get_value("breeding", "egg_nest_count", 6))
	for egg_index in egg_count:
		var egg_position := _find_world_position(rng, 2.0, occupied, 4.0)
		generated_eggs.append({
			"position": Vector3(egg_position.x, 0.0, egg_position.y),
			"rotation": rng.randf_range(0.0, TAU)
		})
		occupied.append({"position": egg_position, "radius": 2.0})

	for index in rng.randi_range(8, 13):
		var wind_angle := rng.randf_range(-0.25, 0.25)
		generated_clouds.append({
			"position": Vector3(rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE), rng.randf_range(34.0, 52.0), rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)),
			"scale": rng.randf_range(1.4, 2.8),
			"direction": Vector3(cos(wind_angle), 0.0, sin(wind_angle)),
			"speed": rng.randf_range(0.7, 1.6)
		})


func _random_clear_position(rng: RandomNumberGenerator, edge_padding: float) -> Vector2:
	for attempt in 100:
		var candidate := Vector2(
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding),
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding)
		)
		if candidate.length() > 35.0:
			return candidate
	return Vector2(80.0, 80.0)


func _find_biome_position(rng: RandomNumberGenerator, biome_type: String, radius: float, occupied: Array, spacing: float) -> Vector2:
	var matching_biomes: Array = generated_biomes.filter(func(biome: Dictionary) -> bool: return biome["type"] == biome_type)
	for attempt in 240:
		var biome: Dictionary = matching_biomes[rng.randi_range(0, matching_biomes.size() - 1)]
		var angle := rng.randf_range(0.0, TAU)
		var distance := sqrt(rng.randf()) * float(biome["radius"])
		var candidate: Vector2 = biome["position"] + Vector2(cos(angle), sin(angle)) * distance
		if absf(candidate.x) > MAP_HALF_SIZE - radius - 6.0 or absf(candidate.y) > MAP_HALF_SIZE - radius - 6.0:
			continue
		if candidate.length() < 28.0 + radius or _is_position_in_water(candidate, radius):
			continue
		var available := true
		for item in occupied:
			if candidate.distance_to(item["position"]) < radius + float(item["radius"]) + spacing:
				available = false
				break
		if available:
			return candidate
	return _find_world_position(rng, radius, occupied, spacing)


func _find_world_position(rng: RandomNumberGenerator, radius: float, occupied: Array, spacing: float) -> Vector2:
	var edge_padding := radius + 8.0
	for attempt in 300:
		var candidate := Vector2(
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding),
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding)
		)
		if candidate.length() < 28.0 + radius or _is_position_in_water(candidate, radius):
			continue
		var available := true
		for item in occupied:
			if candidate.distance_to(item["position"]) < radius + float(item["radius"]) + spacing:
				available = false
				break
		if available:
			return candidate
	return Vector2(
		rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding),
		rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding)
	)


func _is_position_in_water(candidate: Vector2, radius: float) -> bool:
	for pond in generated_ponds:
		var pond_position: Vector3 = pond["position"]
		var pond_size: Vector2 = pond["size"]
		var relative := candidate - Vector2(pond_position.x, pond_position.z)
		var expanded_half_size := pond_size * 0.5 + Vector2.ONE * radius
		if Vector2(relative.x / expanded_half_size.x, relative.y / expanded_half_size.y).length_squared() <= 1.0:
			return true
	for river in generated_rivers:
		var points: PackedVector2Array = river["points"]
		var river_radius := float(river["width"]) * 0.5 + radius
		for point_index in points.size() - 1:
			if Geometry2D.get_closest_point_to_segment(candidate, points[point_index], points[point_index + 1]).distance_to(candidate) <= river_radius:
				return true
	return false


func _build_landscape() -> void:
	_load_environment_models()
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)

	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(MAP_HALF_SIZE * 2.0, 1.0, MAP_HALF_SIZE * 2.0)
	ground_mesh.mesh = ground_box
	ground_mesh.position.y = -0.5
	ground_mesh.material_override = GENERATED_MATERIALS.ground_material(1 + map_seed % 2, 0.055)
	ground.add_child(ground_mesh)

	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(MAP_HALF_SIZE * 2.0, 1.0, MAP_HALF_SIZE * 2.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.5
	ground.add_child(ground_collision)
	_build_map_boundary()

	for biome in generated_biomes:
		_create_biome_ground(biome)
	for pond in generated_ponds:
		_create_pond(pond["position"], pond["size"])
	for river in generated_rivers:
		_create_river(river["points"], river["width"])
	for hill in generated_hills:
		_create_hill(hill["position"], hill["scale"])
	for formation in generated_high_ground:
		_create_high_ground(formation)
	for tree in generated_trees:
		_create_tree(tree)
	for rock in generated_rocks:
		_create_rock(rock["position"], rock["scale"])
	for log_data in generated_logs:
		_create_fallen_log(log_data)
	for vegetation in generated_vegetation:
		_create_vegetation(vegetation)


func _load_environment_models() -> void:
	environment_models.clear()
	for model_name in ENVIRONMENT_MODEL_PATHS:
		var scene := load(ENVIRONMENT_MODEL_PATHS[model_name]) as PackedScene
		assert(scene != null, "Missing environment model: " + model_name)
		environment_models[model_name] = scene


func _create_biome_ground(biome: Dictionary) -> void:
	var patch_group := Node3D.new()
	patch_group.name = str(biome["type"]).capitalize() + "Ground"
	world_root.add_child(patch_group)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.012
	mesh.radial_segments = 36
	var center: Vector2 = biome["position"]
	var radius: float = biome["radius"]
	var texture_variant: int = 0 if biome["type"] == "forest" else (1 + abs(int(center.x + center.y)) % 2)
	var patch_material: StandardMaterial3D = GENERATED_MATERIALS.ground_material(texture_variant, 0.09)
	for patch_index in 6:
		var patch := MeshInstance3D.new()
		patch.mesh = mesh
		var angle := float(patch_index) * TAU / 5.0 + center.x * 0.013
		var patch_radius := radius if patch_index == 0 else radius * (0.38 + 0.07 * sin(center.y + float(patch_index)))
		var offset := Vector2.ZERO if patch_index == 0 else Vector2(cos(angle), sin(angle)) * radius * 0.43
		patch.position = Vector3(center.x + offset.x, 0.006 + float(patch_index) * 0.0002, center.y + offset.y)
		patch.scale = Vector3(patch_radius, 1.0, patch_radius * (0.76 + 0.08 * float(patch_index % 3)))
		patch.material_override = patch_material
		patch_group.add_child(patch)


func _build_player(dino_id: String) -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerDinosaur"
	player.set_script(PLAYER_SCRIPT)
	player.set("dino_id", dino_id)
	player.set("texture_variant", posmod(map_seed + DINO_IDS.find(dino_id), GENERATED_MATERIALS.dino_variant_count()))
	player.position = Vector3(0.0, 0.1, 5.0)
	world_root.add_child(player)
	player.screamed.connect(_on_dino_screamed)
	player.health_changed.connect(_on_health_changed)
	player.energy_changed.connect(_on_energy_changed)
	player.bonuses_changed.connect(_on_bonuses_changed)
	player.died.connect(_on_player_died)
	player.status_requested.connect(_show_status_message)


func _build_wild_dinosaurs() -> void:
	var wildlife := Node3D.new()
	wildlife.name = "WildDinosaurs"
	world_root.add_child(wildlife)
	for index in generated_dinosaurs.size():
		var data: Dictionary = generated_dinosaurs[index]
		var npc := CharacterBody3D.new()
		npc.name = "WildDino_%02d_%s" % [index, data["species"]]
		npc.set_script(NPC_DINO_SCRIPT)
		npc.set("dino_id", data["species"])
		npc.set("pack_id", data["pack_id"])
		npc.set("pack_slot", data.get("pack_slot", -1))
		npc.set("patrol_center", data["patrol_center"])
		npc.set("rng_seed", data["rng_seed"])
		npc.set("texture_variant", data.get("texture_variant", index))
		npc.position = data["position"]
		wildlife.add_child(npc)
		_register_quality_geometry(npc.get("model_root"), "actor")


func _build_powerup_tokens() -> void:
	token_rng.seed = map_seed ^ 0x51C0FFEE
	for token_data in generated_tokens:
		_spawn_powerup_token(token_data["type"], token_data["position"])


func _build_egg_nests() -> void:
	for index in generated_eggs.size():
		var egg_data: Dictionary = generated_eggs[index]
		var nest := Area3D.new()
		nest.set_script(EGG_NEST_SCRIPT)
		nest.set("incubation_seconds", float(dinosaur_config.get_value("breeding", "incubation_seconds", 4.0)))
		nest.position = egg_data["position"]
		nest.rotation.y = egg_data["rotation"]
		nest.connect("hatched", _on_egg_hatched)
		nest.connect("status_changed", _show_status_message)
		world_root.add_child(nest)


func _on_egg_hatched(parent_dino: CharacterBody3D, hatch_position: Vector3) -> void:
	if not is_instance_valid(world_root) or not is_instance_valid(parent_dino) or not parent_dino.is_in_group("player_dinosaur"):
		return
	var baby := CharacterBody3D.new()
	baby.name = "BabyDinosaur_%02d" % companions_spawned
	baby.set_script(BABY_DINO_SCRIPT)
	baby.set("dino_id", str(parent_dino.get("dino_id")))
	baby.set("parent_dino", parent_dino)
	baby.set("companion_index", companions_spawned)
	baby.set("texture_variant", posmod(map_seed + companions_spawned + 1, GENERATED_MATERIALS.dino_variant_count()))
	baby.position = hatch_position + Vector3(0.0, 0.1, 0.0)
	world_root.add_child(baby)
	_register_quality_geometry(baby.get("model_root"), "actor")
	companions_spawned += 1
	_show_status_message("A baby %s hatched and joined you!" % selected_dino_name)


func _spawn_powerup_token(token_type: String, token_position: Vector3) -> void:
	if not is_instance_valid(world_root):
		return
	var token := Area3D.new()
	token.set_script(POWERUP_TOKEN_SCRIPT)
	token.set("token_type", token_type)
	token.position = token_position
	token.connect("consumed", _on_powerup_consumed)
	world_root.add_child(token)


func _on_powerup_consumed(token_type: String) -> void:
	var minimum := float(dinosaur_config.get_value("tokens", "respawn_min_seconds", 6.0))
	var maximum := float(dinosaur_config.get_value("tokens", "respawn_max_seconds", 12.0))
	get_tree().create_timer(token_rng.randf_range(minimum, maximum)).timeout.connect(_respawn_powerup_token.bind(token_type))


func _respawn_powerup_token(token_type: String) -> void:
	if not is_instance_valid(world_root) or not is_instance_valid(player):
		return
	_spawn_powerup_token(token_type, _random_clear_token_position())


func _random_clear_token_position() -> Vector3:
	for attempt in 120:
		var candidate := _find_world_position(token_rng, 1.4, [], 0.0)
		if _is_token_position_clear(candidate):
			return Vector3(candidate.x, 0.0, candidate.y)
	return Vector3(35.0, 0.0, 35.0)


func _is_token_position_clear(candidate: Vector2) -> bool:
	for hill in generated_hills:
		var hill_position: Vector3 = hill["position"]
		var hill_scale: Vector3 = hill["scale"]
		if candidate.distance_to(Vector2(hill_position.x, hill_position.z)) < maxf(hill_scale.x, hill_scale.z) + 2.0:
			return false
	for tree in generated_trees:
		var tree_position: Vector3 = tree["position"]
		if candidate.distance_to(Vector2(tree_position.x, tree_position.z)) < 2.5:
			return false
	for rock in generated_rocks:
		var rock_position: Vector3 = rock["position"]
		if candidate.distance_to(Vector2(rock_position.x, rock_position.z)) < 3.0:
			return false
	for log_data in generated_logs:
		var log_position: Vector3 = log_data["position"]
		if candidate.distance_to(Vector2(log_position.x, log_position.z)) < 5.0:
			return false
	for formation in generated_high_ground:
		var formation_position: Vector3 = formation["position"]
		if candidate.distance_to(Vector2(formation_position.x, formation_position.z)) < 11.0:
			return false
	return true


func is_pack_destination_clear(destination: Vector3) -> bool:
	# Pack leaders choose goals at runtime rather than during layout generation.
	# Reuse the generated layout data so those goals never land in water or
	# inside a solid landmark that the leader could not actually reach.
	var candidate := Vector2(destination.x, destination.z)
	return not _is_position_in_water(candidate, 4.0) and _is_token_position_clear(candidate)


func _build_hud() -> void:
	game_hud = CanvasLayer.new()
	game_hud.name = "TouchControls"
	add_child(game_hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_hud.add_child(root)

	var title := Label.new()
	title.text = "DINOS4HELENA  •  %s  •  WORLD %06d" % [selected_dino_name.to_upper(), map_seed]
	title.position = Vector2(18, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f4f0cf"))
	root.add_child(title)
	_build_vital_bars(root)

	status_label = Label.new()
	status_label.text = "Explore the valley"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-150, 18)
	status_label.size = Vector2(300, 36)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("fff3b0"))
	root.add_child(status_label)

	var left_panel := Control.new()
	left_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_panel.position = Vector2(18, -208)
	left_panel.size = Vector2(370, 190)
	root.add_child(left_panel)
	var jump_button := _add_action_button(left_panel, "JUMP", "jump", Vector2(0, 58), Vector2(92, 54))
	jump_button.disabled = not bool(dinosaur_config.get_value(selected_dino_id, "can_jump", false))
	if jump_button.disabled:
		jump_button.tooltip_text = selected_dino_name + " cannot jump"
	_add_action_button(left_panel, "RUN", "run", Vector2(98, 58), Vector2(84, 54))
	_add_action_button(left_panel, "DUCK", "duck", Vector2(188, 58), Vector2(84, 54))
	_add_action_button(left_panel, "ATTACK", "attack", Vector2(0, 118), Vector2(110, 54))
	_add_action_button(left_panel, "EAT", "eat", Vector2(116, 118), Vector2(92, 54))
	_add_action_button(left_panel, "SCREAM", "scream", Vector2(214, 118), Vector2(116, 54))

	var action_hint := Label.new()
	action_hint.text = "LEFT HAND • ACTIONS"
	action_hint.position = Vector2(4, 18)
	action_hint.add_theme_font_size_override("font_size", 14)
	action_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	left_panel.add_child(action_hint)

	var right_panel := Control.new()
	right_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_panel.position = Vector2(-258, -258)
	right_panel.size = Vector2(240, 240)
	root.add_child(right_panel)
	var movement_wheel: Control = VIRTUAL_JOYSTICK_SCRIPT.new()
	movement_wheel.name = "MovementWheel"
	movement_wheel.position = Vector2(8, 24)
	movement_wheel.size = Vector2(224, 208)
	movement_wheel.connect("movement_changed", player.set_mobile_movement)
	right_panel.add_child(movement_wheel)

	var move_hint := Label.new()
	move_hint.text = "RIGHT HAND • MOVE + STEER"
	move_hint.position = Vector2(22, 2)
	move_hint.size = Vector2(200, 22)
	move_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_hint.add_theme_font_size_override("font_size", 14)
	move_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	right_panel.add_child(move_hint)

	var keyboard_hint := Label.new()
	keyboard_hint.text = "Keyboard: WASD / arrows • Space jump • Shift run • C duck • F attack • E eat • R scream"
	keyboard_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	keyboard_hint.position = Vector2(-350, -30)
	keyboard_hint.size = Vector2(700, 24)
	keyboard_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_hint.add_theme_font_size_override("font_size", 13)
	keyboard_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.68))
	root.add_child(keyboard_hint)

	var menu_button := Button.new()
	menu_button.text = "←  MAIN MENU"
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.position = Vector2(-190, 16)
	menu_button.size = Vector2(170, 46)
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.add_theme_font_size_override("font_size", 16)
	menu_button.add_theme_color_override("font_color", Color("f7f2d0"))
	menu_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.84), Color(0.72, 0.83, 0.42, 0.72)))
	menu_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.94), Color("f7f2d0")))
	menu_button.add_theme_stylebox_override("pressed", _button_style(Color(0.48, 0.6, 0.24, 1.0), Color.WHITE))
	menu_button.pressed.connect(_return_to_main_menu)
	root.add_child(menu_button)

	var minimap: Control = MINIMAP_SCRIPT.new()
	minimap.name = "MiniMap"
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-204, 72)
	minimap.size = Vector2(184, 184)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.clip_contents = true
	root.add_child(minimap)
	active_minimap = minimap
	minimap.call("setup", player, MAP_HALF_SIZE, {
		"biomes": generated_biomes,
		"ponds": generated_ponds,
		"rivers": generated_rivers,
		"hills": generated_hills,
		"high_ground": generated_high_ground,
		"trees": generated_trees,
		"rocks": generated_rocks,
		"logs": generated_logs
	})
	_on_health_changed(player.health, player.max_health)
	_on_energy_changed(player.energy, player.max_energy)
	_on_bonuses_changed(player.speed_bonus_time, player.strength_bonus_time)


func _build_vital_bars(parent: Control) -> void:
	health_bar = _create_vital_bar(parent, "HealthBar", Vector2(18, 43), Color("d7473f"))
	energy_bar = _create_vital_bar(parent, "EnergyBar", Vector2(18, 69), Color("e4b83f"))
	health_label = health_bar.get_node("Label") as Label
	energy_label = energy_bar.get_node("Label") as Label
	bonus_label = Label.new()
	bonus_label.name = "ActiveBonuses"
	bonus_label.position = Vector2(18, 94)
	bonus_label.size = Vector2(360, 24)
	bonus_label.add_theme_font_size_override("font_size", 14)
	bonus_label.add_theme_color_override("font_color", Color("77e6f5"))
	bonus_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bonus_label.add_theme_constant_override("shadow_offset_x", 1)
	bonus_label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(bonus_label)


func _create_vital_bar(parent: Control, bar_name: String, bar_position: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = bar_name
	bar.position = bar_position
	bar.size = Vector2(278, 20)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.04, 0.03, 0.88)
	background.border_color = Color(0.88, 0.85, 0.68, 0.68)
	background.set_border_width_all(1)
	background.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(label)
	return bar


func _add_action_button(parent: Control, caption: String, action: StringName, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = button_position
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f7f2d0"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.icon = load(_icon_path(action)) as Texture2D
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30 if caption != "" else 34)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.78), Color(0.65, 0.78, 0.43, 0.7)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.36, 0.22, 0.9), Color(0.78, 0.9, 0.55, 0.9)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.45, 0.62, 0.25, 0.95), Color("f7f2d0")))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.09, 0.1, 0.09, 0.58), Color(0.42, 0.44, 0.38, 0.55)))
	button.button_down.connect(player.set_mobile_action.bind(action, true))
	button.button_up.connect(player.set_mobile_action.bind(action, false))
	parent.add_child(button)
	return button


func _icon_path(action: StringName) -> String:
	var names := {
		"move_forward": "up", "move_back": "down", "move_left": "left", "move_right": "right",
		"jump": "jump", "run": "run", "duck": "duck", "attack": "attack", "eat": "eat", "scream": "scream"
	}
	return "res://assets/ui/icons/%s.svg" % names.get(action, "up")


func _button_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _tile_image_style(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	# A texture style keeps the Button semantics and accessible hit target while
	# letting the generated scene fill the complete 3:2 tile behind its label.
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _create_pond(pond_position: Vector3, pond_size: Vector2) -> void:
	var lake := Node3D.new()
	lake.name = "Lake"
	lake.position = pond_position
	world_root.add_child(lake)
	var bank := MeshInstance3D.new()
	bank.mesh = _round_water_mesh()
	bank.scale = Vector3(pond_size.x * 0.5 + 2.6, 1.0, pond_size.y * 0.5 + 2.6)
	bank.position.y = 0.008
	bank.material_override = _material(Color("756843"), 1.0)
	lake.add_child(bank)
	_register_quality_geometry(bank, "landmark")
	var water := MeshInstance3D.new()
	water.mesh = _round_water_mesh()
	water.scale = Vector3(pond_size.x * 0.5, 1.0, pond_size.y * 0.5)
	water.position.y = 0.035
	water.material_override = _water_material()
	lake.add_child(water)
	_register_quality_geometry(water, "landmark")


func _create_river(points: PackedVector2Array, width: float) -> void:
	var river := Node3D.new()
	river.name = "River"
	world_root.add_child(river)
	var bank := MeshInstance3D.new()
	bank.mesh = _river_ribbon_mesh(points, width + 5.0, 0.012)
	bank.material_override = _material(Color("756843"), 1.0)
	river.add_child(bank)
	var water := MeshInstance3D.new()
	water.mesh = _river_ribbon_mesh(points, width, 0.035)
	water.material_override = _water_material()
	river.add_child(water)


func _round_water_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.035
	mesh.radial_segments = 48
	mesh.rings = 1
	return mesh


func _river_ribbon_mesh(points: PackedVector2Array, width: float, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for point_index in points.size():
		var previous := points[maxi(point_index - 1, 0)]
		var following := points[mini(point_index + 1, points.size() - 1)]
		var direction := (following - previous).normalized()
		var side := Vector2(-direction.y, direction.x) * width * 0.5
		vertices.append(Vector3(points[point_index].x + side.x, height, points[point_index].y + side.y))
		vertices.append(Vector3(points[point_index].x - side.x, height, points[point_index].y - side.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		var progress := float(point_index) / float(maxi(points.size() - 1, 1))
		uvs.append(Vector2(0.0, progress * 12.0))
		uvs.append(Vector2(1.0, progress * 12.0))
		if point_index < points.size() - 1:
			var base := point_index * 2
			indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.24 + TIME * 1.2) * 0.035;
	VERTEX.y += cos(VERTEX.z * 0.19 - TIME * 0.85) * 0.025;
}

void fragment() {
	float ripple = sin((UV.x + UV.y) * 24.0 + TIME * 1.5) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.045, 0.25, 0.31), vec3(0.12, 0.48, 0.55), ripple * 0.28);
	ROUGHNESS = 0.16;
	METALLIC = 0.08;
	SPECULAR = 0.85;
	ALPHA = 0.82;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _create_hill(hill_position: Vector3, hill_scale: Vector3) -> void:
	var hill_body := StaticBody3D.new()
	hill_body.name = "HillObstacle"
	hill_body.position = hill_position
	hill_body.add_to_group("world_obstacle")
	world_root.add_child(hill_body)

	var hill := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	hill.mesh = mesh
	hill.scale = hill_scale
	hill.material_override = GENERATED_MATERIALS.ground_material(0 if int(hill_position.x) % 2 == 0 else 1, 0.11)
	hill_body.add_child(hill)
	_register_quality_geometry(hill, "large")

	var collision := CollisionShape3D.new()
	collision.shape = _ellipsoid_shape(hill_scale)
	hill_body.add_child(collision)


func _create_high_ground(formation: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "JumpableHighGround"
	root.position = formation["position"]
	root.rotation.y = formation["rotation"]
	root.scale = Vector3.ONE * float(formation["scale"])
	world_root.add_child(root)
	var tiers := [
		Vector2(2.9, 0.55),
		Vector2(2.65, 1.05),
		Vector2(2.9, 1.55),
		Vector2(3.75, 2.15)
	]
	for tier_index in tiers.size():
		var tier_data: Vector2 = tiers[tier_index]
		var tier_radius := tier_data.x
		var tier_height := tier_data.y
		var tier := StaticBody3D.new()
		tier.name = "HighGroundTier"
		tier.position = Vector3((float(tier_index) - 1.5) * 4.15, tier_height * 0.5, sin(float(tier_index) * 1.9) * 0.55)
		tier.add_to_group("world_obstacle")
		root.add_child(tier)
		var mesh_instance := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = tier_radius * 0.92
		mesh.bottom_radius = tier_radius
		mesh.height = tier_height
		mesh.radial_segments = 9
		mesh.rings = 2
		mesh_instance.mesh = mesh
		mesh_instance.material_override = GENERATED_MATERIALS.rock_material(tier_index + int(formation["position"].x), 0.48)
		tier.add_child(mesh_instance)
		_register_quality_geometry(mesh_instance, "landmark")
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = tier_radius * 0.94
		shape.height = tier_height
		collision.shape = shape
		tier.add_child(collision)


func _create_tree(tree_data: Dictionary) -> void:
	var tree_position: Vector3 = tree_data["position"]
	var tree_scale: float = tree_data["scale"]
	var tree_rotation: float = tree_data["rotation"]
	var tree_type: String = tree_data.get("type", "tree")
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = tree_position
	tree.rotation.y = tree_rotation
	tree.scale = Vector3.ONE * tree_scale
	world_root.add_child(tree)

	var tree_body := StaticBody3D.new()
	tree_body.name = "TreeObstacle"
	tree_body.add_to_group("world_obstacle")
	tree.add_child(tree_body)
	var tree_collision := CollisionShape3D.new()
	var dimensions := {
		"tree": Vector2(0.48, 5.5),
		"tree_fern": Vector2(0.36, 2.35),
		"dead_tree": Vector2(0.42, 3.5)
	}
	var collision_size: Vector2 = dimensions.get(tree_type, dimensions["tree"])
	var tree_shape := CylinderShape3D.new()
	tree_shape.radius = collision_size.x
	tree_shape.height = collision_size.y
	tree_collision.shape = tree_shape
	tree_collision.position.y = collision_size.y * 0.5
	tree_body.add_child(tree_collision)

	var model: Node3D = (environment_models[tree_type] as PackedScene).instantiate()
	model.name = tree_type.to_pascal_case()
	tree.add_child(model)
	GENERATED_MATERIALS.apply_bark(model, abs(int(tree_position.x * 13.0 + tree_position.z * 7.0)))
	_register_quality_geometry(model, "large")


func _create_rock(rock_position: Vector3, rock_scale: float) -> void:
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockObstacle"
	rock_body.position = rock_position
	rock_body.rotation_degrees.y = rock_position.x * 7.0
	rock_body.scale = Vector3.ONE * rock_scale
	rock_body.add_to_group("world_obstacle")
	world_root.add_child(rock_body)

	var rock: Node3D = (environment_models["rock"] as PackedScene).instantiate()
	rock.name = "MossyBasaltRock"
	rock_body.add_child(rock)
	GENERATED_MATERIALS.apply_rock(rock, abs(int(rock_position.x * 11.0 + rock_position.z * 17.0)))
	_register_quality_geometry(rock, "medium")

	var collision := CollisionShape3D.new()
	collision.shape = _ellipsoid_shape(Vector3(1.1, 0.78, 0.86))
	collision.position.y = 0.78
	rock_body.add_child(collision)


func _create_fallen_log(log_data: Dictionary) -> void:
	var log_body := StaticBody3D.new()
	log_body.name = "FallenLogObstacle"
	log_body.position = log_data["position"]
	log_body.rotation.y = log_data["rotation"]
	log_body.scale = Vector3.ONE * float(log_data["scale"])
	log_body.add_to_group("world_obstacle")
	world_root.add_child(log_body)
	var model: Node3D = (environment_models["fallen_log"] as PackedScene).instantiate()
	model.name = "FallenRainforestLog"
	log_body.add_child(model)
	var log_position: Vector3 = log_data["position"]
	GENERATED_MATERIALS.apply_bark(model, abs(int(log_position.x * 5.0 + log_position.z * 3.0)))
	_register_quality_geometry(model, "medium")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 1.2, 1.45)
	collision.shape = shape
	collision.position.y = 0.6
	log_body.add_child(collision)


func _create_vegetation(vegetation: Dictionary) -> void:
	var plant_type: String = vegetation["type"]
	var plant: Node3D = (environment_models[plant_type] as PackedScene).instantiate()
	plant.name = plant_type.capitalize()
	plant.position = vegetation["position"]
	plant.rotation.y = vegetation["rotation"]
	plant.scale = Vector3.ONE * float(vegetation["scale"])
	plant.add_to_group("edible_plant")
	plant.set_meta("energy_remaining", 18.0)
	world_root.add_child(plant)
	_register_quality_geometry(plant, "small")


func _build_map_boundary() -> void:
	var boundary := StaticBody3D.new()
	boundary.name = "MapBoundary"
	world_root.add_child(boundary)
	var wall_height := 20.0
	var wall_thickness := 2.0
	var wall_length := MAP_HALF_SIZE * 2.0 + wall_thickness * 2.0
	_add_boundary_wall(boundary, Vector3(0, wall_height * 0.5, -MAP_HALF_SIZE - wall_thickness * 0.5), Vector3(wall_length, wall_height, wall_thickness))
	_add_boundary_wall(boundary, Vector3(0, wall_height * 0.5, MAP_HALF_SIZE + wall_thickness * 0.5), Vector3(wall_length, wall_height, wall_thickness))
	_add_boundary_wall(boundary, Vector3(-MAP_HALF_SIZE - wall_thickness * 0.5, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, wall_length))
	_add_boundary_wall(boundary, Vector3(MAP_HALF_SIZE + wall_thickness * 0.5, wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, wall_length))


func _add_boundary_wall(parent: StaticBody3D, wall_position: Vector3, wall_size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wall_size
	collision.shape = shape
	collision.position = wall_position
	parent.add_child(collision)


func _ellipsoid_shape(radii: Vector3) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	var rings := 8
	var segments := 16
	for ring_index in rings + 1:
		var latitude := -PI * 0.5 + PI * float(ring_index) / float(rings)
		var ring_radius := cos(latitude)
		for segment_index in segments:
			var longitude := TAU * float(segment_index) / float(segments)
			points.append(Vector3(
				cos(longitude) * ring_radius * radii.x,
				sin(latitude) * radii.y,
				sin(longitude) * ring_radius * radii.z
			))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _register_quality_geometry(root: Node, category: String) -> void:
	# Imported GLBs often contain several MeshInstance3D children. Register each
	# renderable once while preserving its full-quality settings for recovery.
	if not is_instance_valid(root):
		return
	var renderables: Array[Node] = []
	if root is GeometryInstance3D:
		renderables.append(root)
	renderables.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	for item in renderables:
		var geometry := item as GeometryInstance3D
		if not is_instance_valid(geometry) or geometry.has_meta("_quality_category"):
			continue
		geometry.set_meta("_quality_category", category)
		geometry.set_meta("_quality_original_range", geometry.visibility_range_end)
		geometry.set_meta("_quality_original_margin", geometry.visibility_range_end_margin)
		geometry.set_meta("_quality_original_lod_bias", geometry.lod_bias)
		geometry.set_meta("_quality_original_shadow", int(geometry.cast_shadow))
		quality_geometry.append(geometry)
		_apply_geometry_quality(geometry)


func _reset_adaptive_performance() -> void:
	performance_warmup = PERFORMANCE_WARMUP_SECONDS
	performance_sample_time = 0.0
	performance_sample_frames = 0
	performance_low_samples = 0
	performance_high_samples = 0
	performance_change_cooldown = 0.0
	_apply_performance_tier(QUALITY_HIGH)


func _apply_performance_tier(next_tier: int) -> void:
	performance_tier = clampi(next_tier, QUALITY_LOW, QUALITY_HIGH)
	performance_low_samples = 0
	performance_high_samples = 0
	performance_change_cooldown = PERFORMANCE_CHANGE_COOLDOWN
	for index in range(quality_geometry.size() - 1, -1, -1):
		var geometry := quality_geometry[index]
		if not is_instance_valid(geometry):
			quality_geometry.remove_at(index)
			continue
		_apply_geometry_quality(geometry)

	var viewport := get_viewport()
	viewport.scaling_3d_scale = [0.72, 0.86, 1.0][performance_tier]
	if is_instance_valid(sun_light):
		sun_light.shadow_enabled = performance_tier > QUALITY_LOW
		sun_light.directional_shadow_max_distance = [42.0, 62.0, 90.0][performance_tier]
	if is_instance_valid(player):
		var cameras: Array[Node] = player.find_children("*", "Camera3D", true, false)
		if not cameras.is_empty():
			(cameras[0] as Camera3D).far = [170.0, 240.0, 360.0][performance_tier]
	if is_instance_valid(active_minimap) and active_minimap.has_method("set_performance_tier"):
		active_minimap.call("set_performance_tier", performance_tier)


func _apply_geometry_quality(geometry: GeometryInstance3D) -> void:
	var category := str(geometry.get_meta("_quality_category", "medium"))
	if performance_tier == QUALITY_HIGH:
		geometry.visibility_range_end = float(geometry.get_meta("_quality_original_range", 0.0))
		geometry.visibility_range_end_margin = float(geometry.get_meta("_quality_original_margin", 0.0))
		geometry.lod_bias = float(geometry.get_meta("_quality_original_lod_bias", 1.0))
		geometry.cast_shadow = int(geometry.get_meta("_quality_original_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
		return

	var medium_ranges := {
		"small": 95.0,
		"medium": 145.0,
		"large": 175.0,
		"landmark": 230.0,
		"actor": 190.0,
		"cloud": 260.0
	}
	var low_ranges := {
		"small": 62.0,
		"medium": 100.0,
		"large": 120.0,
		"landmark": 165.0,
		"actor": 135.0,
		"cloud": 175.0
	}
	var ranges: Dictionary = medium_ranges if performance_tier == QUALITY_MEDIUM else low_ranges
	var cull_distance := float(ranges.get(category, 130.0))
	geometry.visibility_range_end = cull_distance
	geometry.visibility_range_end_margin = minf(cull_distance * 0.12, 14.0)
	geometry.lod_bias = 0.72 if performance_tier == QUALITY_MEDIUM else 0.48
	var keeps_shadow := category in ["actor", "landmark", "large"] and performance_tier == QUALITY_MEDIUM
	geometry.cast_shadow = int(geometry.get_meta("_quality_original_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)) if keeps_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func get_performance_tier_name() -> String:
	return ["low", "medium", "high"][performance_tier]


func _create_input_actions() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("run", [KEY_SHIFT])
	_add_key_action("duck", [KEY_C, KEY_CTRL])
	_add_key_action("attack", [KEY_F])
	_add_key_action("eat", [KEY_E])
	_add_key_action("scream", [KEY_R])


func _add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _on_dino_screamed() -> void:
	_show_status_message("R O A R !")


func _show_status_message(message: String) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(status_label) and status_label.text == message:
			status_label.text = "Explore the valley"
	)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if not is_instance_valid(health_bar):
		return
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_label.text = "HEALTH  %d / %d" % [current_health, maximum_health]


func _on_energy_changed(current_energy: float, maximum_energy: float) -> void:
	if not is_instance_valid(energy_bar):
		return
	energy_bar.max_value = maximum_energy
	energy_bar.value = current_energy
	energy_label.text = "ENERGY  %d%%" % int(round(current_energy / maximum_energy * 100.0))


func _on_bonuses_changed(speed_seconds: float, strength_seconds: float) -> void:
	if not is_instance_valid(bonus_label):
		return
	var bonuses: Array[String] = []
	if speed_seconds > 0.0:
		bonuses.append("SPEED ×2  %ds" % int(ceil(speed_seconds)))
	if strength_seconds > 0.0:
		bonuses.append("STRENGTH ×2  %ds" % int(ceil(strength_seconds)))
	bonus_label.text = "   •   ".join(bonuses)


func _on_player_died() -> void:
	_show_status_message("Your dinosaur has fallen")
	var overlay := ColorRect.new()
	overlay.name = "GameOver"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.01, 0.005, 0.78)
	game_hud.add_child(overlay)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -100)
	panel.size = Vector2(420, 200)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 20)
	overlay.add_child(panel)
	var heading := Label.new()
	heading.text = "GAME OVER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", Color("ef6655"))
	panel.add_child(heading)
	var detail := Label.new()
	detail.text = "%s ran out of health" % selected_dino_name
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", Color("fff2c2"))
	panel.add_child(detail)
	var return_button := Button.new()
	return_button.text = "RETURN TO DINOSAUR SELECTION"
	return_button.custom_minimum_size = Vector2(340, 52)
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.pressed.connect(_return_to_main_menu)
	panel.add_child(return_button)
