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
const MULTIPLAYER_CLIENT_SCRIPT := preload("res://scripts/multiplayer_client.gd")
const REMOTE_PLAYER_SCRIPT := preload("res://scripts/remote_player.gd")
const HUMAN_MARKER_SCRIPT := preload("res://scripts/human_marker.gd")
const VIRTUAL_JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const LAVA_STREAM_SCRIPT := preload("res://scripts/lava_stream.gd")
const SNOW_FOOTPRINTS_SCRIPT := preload("res://scripts/snow_footprints.gd")
# DINO_IDS is the player-selection roster. The two diet lists below are the
# deliberately smaller wildlife pools; Spinosaurus is player-only.
const DINO_IDS := ["trex", "spinosaurus", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]
const HERBIVORE_IDS := ["triceratops", "stegosaurus", "parasaurolophus", "apatosaurus"]
const CARNIVORE_IDS := ["trex", "velociraptor"]
const MAP_HALF_SIZE := 200.0
const MAP_THEMES := ["grassland", "desert", "winter", "volcano"]
const MAP_THEME_SEED_SALTS := {"grassland": 0, "desert": 0xD35E47, "winter": 0x71A7E2, "volcano": 0xB01CA0}
const QUEST_PROGRESS_PATH := "user://quest_progress.cfg"
const MULTIPLAYER_SETTINGS_PATH := "user://multiplayer.cfg"
const DEFAULT_SERVER_URL := "wss://92.205.18.100:8765/"
const DEFAULT_SERVER_HOST := "92.205.18.100"
const DEFAULT_SERVER_PORT := 8765
const PLAYER_COLORS := ["#ff6b6b", "#ffd166", "#7bd389", "#4ecdc4", "#6ea8fe", "#c792ea", "#ff9f68", "#f47ac2"]
const SCREAM_RESPONSE_RANGE := 72.0
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
var multiplayer_page: Control
var configuration_page: Control
var quest_overview_page: Control
var quest_detail_page: Control
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
var poison_label: Label
var selected_dino_name := ""
var selected_dino_id := "trex"
var selected_map_theme := "grassland"
var dino_cards: Dictionary = {}
var multiplayer_dino_cards: Dictionary = {}
var multiplayer_settings := ConfigFile.new()
var multiplayer_host_input: LineEdit
var multiplayer_port_input: LineEdit
var multiplayer_secure_checkbox: CheckBox
var multiplayer_self_signed_checkbox: CheckBox
var configuration_status_label: Label
var multiplayer_status_label: Label
var multiplayer_connect_button: Button
var multiplayer_name_input: LineEdit
var multiplayer_color_buttons: Dictionary = {}
var selected_player_color := "#6ea8fe"
var multiplayer_client: Node
var multiplayer_active := false
var multiplayer_id := 0
var remote_players: Dictionary = {}
var multiplayer_roster: Dictionary = {}
var multiplayer_roster_rows: VBoxContainer
var map_theme_buttons: Dictionary = {}
var start_game_button: Button
var dinosaur_config := ConfigFile.new()
var quest_config := ConfigFile.new()
var mission_config := ConfigFile.new()
var quest_progress := ConfigFile.new()
var quest_progress_path := QUEST_PROGRESS_PATH
var active_quest_id := ""
var active_mission_id := ""
var active_mission_event: Node
var mission_objective_label: Label
var mission_intro_player: AudioStreamPlayer
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
var generated_babies: Array = []
var generated_tokens: Array = []
var generated_eggs: Array = []
var mission_player_start := Vector3(0.0, 0.1, 5.0)
var generated_lava_streams: Array = []
var volcano_data: Dictionary = {}
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


func _t(key: String, values: Array = []) -> String:
	return Localization.text(key, values)


func _dino_name(dino_id: String) -> String:
	return _t(str(dinosaur_config.get_value(dino_id, "display_name_key", "dino." + dino_id)))


func _theme_name(theme_id: String) -> String:
	return _t("theme." + theme_id)


func _config_text(config: ConfigFile, section: String, field: String) -> String:
	return _t(str(config.get_value(section, field + "_key", section + "." + field)))


func _ready() -> void:
	add_to_group("world_controller")
	var config_error := dinosaur_config.load("res://config/dinosaurs.cfg")
	assert(config_error == OK, "Could not load dinosaur configuration")
	var quest_config_error := quest_config.load("res://config/quests.cfg")
	if quest_config_error != OK:
		push_error("Could not load quest configuration: %s" % error_string(quest_config_error))
	var progress_error := quest_progress.load(quest_progress_path)
	if progress_error != OK and progress_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load quest progress: %s" % error_string(progress_error))
	multiplayer_settings.load(MULTIPLAYER_SETTINGS_PATH)
	multiplayer_client = MULTIPLAYER_CLIENT_SCRIPT.new()
	multiplayer_client.name = "MultiplayerClient"
	add_child(multiplayer_client)
	multiplayer_client.welcome_received.connect(_on_multiplayer_welcome)
	multiplayer_client.message_received.connect(_on_multiplayer_message)
	multiplayer_client.connection_failed.connect(_on_multiplayer_failed)
	multiplayer_client.disconnected.connect(_on_multiplayer_disconnected)
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
	selected_dino_name = _dino_name(dino_id)
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
	_apply_mission_setup()
	_build_environment()
	_build_clouds()
	_build_ambient_audio()
	_build_landscape()
	if not multiplayer_active:
		_build_powerup_tokens()
	_build_player(dino_id)
	if not multiplayer_active:
		_build_egg_nests()
		_build_wild_dinosaurs()
		_build_mission_babies()
	_build_snow_footprints()
	_build_hud()
	_play_mission_intro()
	_start_mission_event()
	_reset_adaptive_performance()


func _return_to_main_menu() -> void:
	var return_to_quest := active_quest_id != ""
	var return_to_multiplayer := multiplayer_active
	if multiplayer_active:
		multiplayer_client.disconnect_from_server()
		multiplayer_active = false
		multiplayer_id = 0
		remote_players.clear()
		multiplayer_roster.clear()
	if is_instance_valid(active_mission_event):
		active_mission_event.queue_free()
	active_mission_event = null
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
	poison_label = null
	mission_objective_label = null
	mission_intro_player = null
	multiplayer_roster_rows = null
	companions_spawned = 0
	quality_geometry.clear()
	sun_light = null
	active_minimap = null
	get_viewport().scaling_3d_scale = 1.0
	if return_to_quest:
		_show_quest_page(active_quest_id)
	elif return_to_multiplayer:
		_show_multiplayer_page()
	else:
		_show_free_game_page()
	active_mission_id = ""
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
	multiplayer_page = Control.new()
	multiplayer_page.name = "MultiplayerPage"
	multiplayer_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(multiplayer_page)
	multiplayer_page.hide()
	configuration_page = Control.new()
	configuration_page.name = "ConfigurationPage"
	configuration_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(configuration_page)
	configuration_page.hide()

	var title := Label.new()
	title.text = _t("app.title")
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
	subtitle.text = _t("app.subtitle")
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

	var mode_tiles := Control.new()
	mode_tiles.name = "GameModeTiles"
	mode_tiles.set_anchors_preset(Control.PRESET_CENTER)
	mode_tiles.position = Vector2(-474, -105)
	mode_tiles.size = Vector2(948, 210)
	landing_page.add_child(mode_tiles)

	var quests_tile := Button.new()
	quests_tile.name = "QuestsTile"
	quests_tile.text = _t("menu.quests")
	quests_tile.custom_minimum_size = Vector2(304, 210)
	quests_tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quests_tile.position = Vector2(0, 0)
	quests_tile.size = Vector2(304, 210)
	quests_tile.focus_mode = Control.FOCUS_NONE
	quests_tile.tooltip_text = _t("menu.quests_tooltip")
	quests_tile.add_theme_font_size_override("font_size", 25)
	quests_tile.add_theme_color_override("font_color", Color("fff2c2"))
	quests_tile.add_theme_color_override("font_hover_color", Color.WHITE)
	quests_tile.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.015, 0.96))
	quests_tile.add_theme_constant_override("outline_size", 8)
	var quests_art: Texture2D = load("res://assets/ui/menu/quests-tile.png")
	quests_tile.add_theme_stylebox_override("normal", _tile_image_style(quests_art, Color(0.76, 0.76, 0.70, 1.0)))
	quests_tile.add_theme_stylebox_override("hover", _tile_image_style(quests_art, Color(0.95, 0.95, 0.88, 1.0)))
	quests_tile.add_theme_stylebox_override("pressed", _tile_image_style(quests_art, Color(0.58, 0.60, 0.54, 1.0)))
	quests_tile.pressed.connect(_show_quest_overview)
	_add_tile_rim(quests_tile)
	mode_tiles.add_child(quests_tile)

	var free_game_tile := Button.new()
	free_game_tile.name = "FreeGameTile"
	free_game_tile.text = _t("menu.free_game_tile")
	free_game_tile.custom_minimum_size = Vector2(304, 210)
	free_game_tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	free_game_tile.position = Vector2(322, 0)
	free_game_tile.size = Vector2(304, 210)
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
	_add_tile_rim(free_game_tile)
	mode_tiles.add_child(free_game_tile)

	var multiplayer_tile := Button.new()
	multiplayer_tile.name = "MultiplayerTile"
	multiplayer_tile.text = _t("menu.multiplayer_tile")
	multiplayer_tile.custom_minimum_size = Vector2(304, 210)
	multiplayer_tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	multiplayer_tile.position = Vector2(644, 0)
	multiplayer_tile.size = Vector2(304, 210)
	multiplayer_tile.focus_mode = Control.FOCUS_NONE
	multiplayer_tile.add_theme_font_size_override("font_size", 25)
	multiplayer_tile.add_theme_color_override("font_color", Color("fff2c2"))
	multiplayer_tile.add_theme_color_override("font_hover_color", Color.WHITE)
	multiplayer_tile.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.015, 0.96))
	multiplayer_tile.add_theme_constant_override("outline_size", 8)
	var multiplayer_art: Texture2D = load("res://assets/ui/menu/multiplayer-tile.png")
	multiplayer_tile.add_theme_stylebox_override("normal", _tile_image_style(multiplayer_art, Color(0.72, 0.72, 0.68)))
	multiplayer_tile.add_theme_stylebox_override("hover", _tile_image_style(multiplayer_art, Color(0.95, 0.95, 0.88)))
	multiplayer_tile.add_theme_stylebox_override("pressed", _tile_image_style(multiplayer_art, Color(0.58, 0.60, 0.54)))
	multiplayer_tile.pressed.connect(_show_multiplayer_page)
	_add_tile_rim(multiplayer_tile)
	mode_tiles.add_child(multiplayer_tile)

	var configuration_button := Button.new()
	configuration_button.name = "ConfigurationButton"
	configuration_button.text = _t("menu.configuration")
	configuration_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	configuration_button.position = Vector2(20, -66)
	configuration_button.size = Vector2(190, 44)
	configuration_button.focus_mode = Control.FOCUS_NONE
	configuration_button.add_theme_font_size_override("font_size", 16)
	configuration_button.add_theme_color_override("font_color", Color("f7f2d0"))
	configuration_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
	configuration_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
	configuration_button.pressed.connect(_show_configuration_page)
	landing_page.add_child(configuration_button)

	var free_game_title := Label.new()
	free_game_title.text = _t("menu.free_game")
	free_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	free_game_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	free_game_title.position = Vector2(-260, 8)
	free_game_title.size = Vector2(520, 38)
	free_game_title.add_theme_font_size_override("font_size", 29)
	free_game_title.add_theme_color_override("font_color", Color("fff2c2"))
	free_game_page.add_child(free_game_title)

	var back_button := Button.new()
	back_button.name = "BackToLandingButton"
	back_button.text = _t("menu.back")
	back_button.position = Vector2(20, 14)
	back_button.size = Vector2(126, 40)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
	back_button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
	back_button.pressed.connect(_show_landing_page)
	free_game_page.add_child(back_button)

	var prompt := Label.new()
	prompt.text = _t("menu.choose_dinosaur")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.position = Vector2(-260, 45)
	prompt.size = Vector2(520, 28)
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	free_game_page.add_child(prompt)

	dino_cards.clear()
	multiplayer_dino_cards.clear()
	var cards := VBoxContainer.new()
	cards.name = "DinosaurCards"
	cards.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cards.position = Vector2(-430, 72)
	cards.size = Vector2(860, 326)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
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
		var display_name: String = _dino_name(dino_id)
		card_rows[0 if dino_index < 4 else 1].add_child(_create_dino_card(dino_id, display_name))

	map_theme_buttons.clear()
	var theme_row := HBoxContainer.new()
	theme_row.name = "MapThemeCards"
	theme_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	theme_row.position = Vector2(-360, 404)
	theme_row.size = Vector2(720, 88)
	theme_row.alignment = BoxContainer.ALIGNMENT_CENTER
	theme_row.add_theme_constant_override("separation", 12)
	free_game_page.add_child(theme_row)
	for theme_index in MAP_THEMES.size():
		var theme_id: String = MAP_THEMES[theme_index]
		var theme_button := Button.new()
		theme_button.name = "MapTheme_%s" % theme_id
		theme_button.custom_minimum_size = Vector2(171, 86)
		theme_button.focus_mode = Control.FOCUS_NONE
		theme_button.add_theme_font_size_override("font_size", 16)
		theme_button.add_theme_color_override("font_color", Color("fff4d0"))
		theme_button.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.01, 0.98))
		theme_button.add_theme_constant_override("outline_size", 6)
		theme_button.tooltip_text = _t("theme.select_tooltip", [_theme_name(theme_id).capitalize()])
		theme_button.pressed.connect(_select_map_theme.bind(theme_id))
		theme_row.add_child(theme_button)
		var rim := Panel.new()
		rim.name = "ThemeRim"
		rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rim.add_theme_stylebox_override("panel", _theme_tile_rim_style(theme_id == selected_map_theme))
		theme_button.add_child(rim)
		map_theme_buttons[theme_id] = theme_button

	var seed_row := HBoxContainer.new()
	seed_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	seed_row.position = Vector2(-250, 528)
	seed_row.size = Vector2(500, 40)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 10)
	free_game_page.add_child(seed_row)

	var seed_label := Label.new()
	seed_label.text = _t("menu.world_seed")
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
	seed_input.tooltip_text = _t("menu.seed_tooltip")
	seed_input.text_changed.connect(_on_seed_text_changed)
	seed_row.add_child(seed_input)

	var random_seed_button := Button.new()
	random_seed_button.text = _t("menu.random_seed")
	random_seed_button.custom_minimum_size = Vector2(176, 36)
	random_seed_button.focus_mode = Control.FOCUS_NONE
	random_seed_button.add_theme_font_size_override("font_size", 14)
	random_seed_button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.25, 0.16, 0.92), Color(0.72, 0.83, 0.42, 0.8)))
	random_seed_button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.43, 0.22, 0.96), Color("f7f2d0")))
	random_seed_button.pressed.connect(_set_random_world_seed)
	seed_row.add_child(random_seed_button)
	if map_seed == 0:
		_set_random_world_seed()
	else:
		seed_input.text = "%06d" % map_seed

	start_game_button = Button.new()
	start_game_button.name = "StartGameButton"
	start_game_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	start_game_button.position = Vector2(-440, -74)
	start_game_button.size = Vector2(420, 54)
	start_game_button.focus_mode = Control.FOCUS_NONE
	start_game_button.add_theme_font_size_override("font_size", 20)
	start_game_button.add_theme_color_override("font_color", Color("fff7d6"))
	start_game_button.add_theme_stylebox_override("normal", _button_style(Color("376c32"), Color("efd56c")))
	start_game_button.add_theme_stylebox_override("hover", _button_style(Color("4f8a42"), Color("fff1a0")))
	start_game_button.add_theme_stylebox_override("pressed", _button_style(Color("294f28"), Color.WHITE))
	start_game_button.pressed.connect(_start_selected_game)
	free_game_page.add_child(start_game_button)

	var footer := Label.new()
	footer.text = _t("menu.footer")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	footer.position = Vector2(-350, 600)
	footer.size = Vector2(700, 28)
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	free_game_page.add_child(footer)
	_update_dino_card_selection()
	_update_map_theme_selection()
	_update_start_button()

	var credits_button := Button.new()
	credits_button.name = "CreditsButton"
	credits_button.text = _t("menu.credits")
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
	_build_language_selector(landing_page)

	var guide_button := Button.new()
	guide_button.name = "PlayGuideButton"
	guide_button.text = _t("menu.how_to_play")
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
	_build_quest_pages(root)
	_build_multiplayer_page()
	_build_configuration_page()


func _build_language_selector(parent: Control) -> void:
	var selector := HBoxContainer.new()
	selector.name = "LanguageSelector"
	selector.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	selector.position = Vector2(-178, 18)
	selector.size = Vector2(158, 42)
	selector.alignment = BoxContainer.ALIGNMENT_END
	selector.add_theme_constant_override("separation", 8)
	parent.add_child(selector)
	var languages := [
		["en", "🇬🇧", "language.english"],
		["de", "🇩🇪", "language.german"],
		["fr", "🇫🇷", "language.french"]
	]
	for data in languages:
		var button := Button.new()
		button.name = "Language_" + str(data[0])
		button.text = str(data[1])
		button.tooltip_text = _t(str(data[2]))
		button.custom_minimum_size = Vector2(46, 40)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = Localization.language == str(data[0])
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42, 0.72)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.96), Color("f7f2d0")))
		button.pressed.connect(_select_language.bind(str(data[0])))
		selector.add_child(button)


func _select_language(locale: String) -> void:
	if locale == Localization.language:
		return
	Localization.set_language(locale)
	_rebuild_menu_for_language.call_deferred()


func _rebuild_menu_for_language() -> void:
	var menu_was_visible := is_instance_valid(menu_layer) and menu_layer.visible
	if is_instance_valid(menu_layer):
		menu_layer.free()
	_build_main_menu()
	if not splash_dismissed or not menu_was_visible:
		menu_layer.hide()


func _select_dino(dino_id: String) -> void:
	if dino_id not in DINO_IDS:
		return
	selected_dino_id = dino_id
	selected_dino_name = _dino_name(dino_id)
	_update_dino_card_selection()
	_update_start_button()


func _select_map_theme(theme_id: String) -> void:
	if theme_id not in MAP_THEMES:
		return
	selected_map_theme = theme_id
	_update_map_theme_selection()
	_update_start_button()


func _start_selected_game() -> void:
	_start_game(selected_dino_id)


func _update_dino_card_selection() -> void:
	for collection in [dino_cards, multiplayer_dino_cards]:
		for dino_id in collection:
			var panel := collection[dino_id] as PanelContainer
			_set_dino_card_selected(panel, str(dino_id) == selected_dino_id)


func _set_dino_card_selected(panel: PanelContainer, selected: bool) -> void:
	panel.add_theme_stylebox_override("panel", _card_style(selected))
	var marker := panel.find_child("SelectedMarker", true, false) as Label
	var shade := panel.find_child("SelectionShade", true, false) as ColorRect
	var stats := panel.find_child("SelectedStats", true, false) as GridContainer
	if marker:
		marker.visible = selected
	if shade:
		shade.visible = selected
	if stats:
		stats.visible = selected


func _build_multiplayer_page() -> void:
	var heading := Label.new()
	heading.name = "MultiplayerHeading"
	heading.text = _t("menu.multiplayer_title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.position = Vector2(-330, 10)
	heading.size = Vector2(660, 48)
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	multiplayer_page.add_child(heading)
	var back := Button.new()
	back.name = "MultiplayerBackButton"
	back.text = _t("menu.back")
	back.position = Vector2(20, 14)
	back.size = Vector2(126, 40)
	back.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42)))
	back.pressed.connect(_show_landing_page)
	multiplayer_page.add_child(back)
	var prompt := Label.new()
	prompt.text = _t("menu.choose_dinosaur")
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.position = Vector2(-300, 60)
	prompt.size = Vector2(600, 30)
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	multiplayer_page.add_child(prompt)
	multiplayer_dino_cards.clear()
	var cards := VBoxContainer.new()
	cards.name = "MultiplayerDinosaurCards"
	cards.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cards.position = Vector2(-430, 88)
	cards.size = Vector2(860, 326)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 6)
	multiplayer_page.add_child(cards)
	var rows: Array[HBoxContainer] = []
	for row_index in 2:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards.add_child(row)
		rows.append(row)
	for index in DINO_IDS.size():
		var dino_id: String = DINO_IDS[index]
		rows[0 if index < 4 else 1].add_child(_create_dino_card(dino_id, _dino_name(dino_id), true))
	var name_label := Label.new()
	name_label.text = _t("menu.player_name")
	name_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	name_label.position = Vector2(-430, 428)
	name_label.size = Vector2(125, 36)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color("fff2c2"))
	multiplayer_page.add_child(name_label)
	multiplayer_name_input = LineEdit.new()
	multiplayer_name_input.name = "MultiplayerPlayerName"
	multiplayer_name_input.max_length = 20
	multiplayer_name_input.placeholder_text = _t("menu.player_name_placeholder")
	multiplayer_name_input.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_name_input.position = Vector2(-300, 421)
	multiplayer_name_input.size = Vector2(300, 43)
	multiplayer_name_input.add_theme_font_size_override("font_size", 18)
	multiplayer_page.add_child(multiplayer_name_input)
	var color_label := Label.new()
	color_label.text = _t("menu.player_color")
	color_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	color_label.position = Vector2(-430, 476)
	color_label.size = Vector2(150, 36)
	color_label.add_theme_font_size_override("font_size", 18)
	color_label.add_theme_color_override("font_color", Color("fff2c2"))
	multiplayer_page.add_child(color_label)
	multiplayer_color_buttons.clear()
	for index in PLAYER_COLORS.size():
		var hex: String = PLAYER_COLORS[index]
		var swatch := Button.new()
		swatch.name = "PlayerColor_%d" % index
		swatch.tooltip_text = hex
		swatch.set_anchors_preset(Control.PRESET_CENTER_TOP)
		swatch.position = Vector2(-270 + index * 78, 470)
		swatch.size = Vector2(60, 42)
		swatch.add_theme_font_size_override("font_size", 24)
		swatch.add_theme_color_override("font_color", Color("132518"))
		swatch.pressed.connect(_select_player_color.bind(hex))
		multiplayer_page.add_child(swatch)
		multiplayer_color_buttons[hex] = swatch
	_update_player_color_buttons()
	multiplayer_connect_button = Button.new()
	multiplayer_connect_button.name = "ConnectToServerButton"
	multiplayer_connect_button.text = _t("menu.connect")
	multiplayer_connect_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_connect_button.position = Vector2(-190, 535)
	multiplayer_connect_button.size = Vector2(380, 54)
	multiplayer_connect_button.add_theme_font_size_override("font_size", 21)
	multiplayer_connect_button.add_theme_stylebox_override("normal", _button_style(Color("376c32"), Color("efd56c")))
	multiplayer_connect_button.pressed.connect(_connect_multiplayer)
	multiplayer_page.add_child(multiplayer_connect_button)
	multiplayer_status_label = Label.new()
	multiplayer_status_label.name = "MultiplayerStatus"
	multiplayer_status_label.text = _t("menu.multiplayer_hint")
	multiplayer_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiplayer_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_status_label.position = Vector2(-450, 605)
	multiplayer_status_label.size = Vector2(900, 42)
	multiplayer_status_label.add_theme_font_size_override("font_size", 16)
	multiplayer_status_label.add_theme_color_override("font_color", Color("fff2c2"))
	multiplayer_page.add_child(multiplayer_status_label)


func _select_player_color(hex: String) -> void:
	if hex not in PLAYER_COLORS:
		return
	selected_player_color = hex
	_update_player_color_buttons()


func _update_player_color_buttons() -> void:
	for hex in multiplayer_color_buttons:
		var button := multiplayer_color_buttons[hex] as Button
		var selected := str(hex) == selected_player_color
		var style := StyleBoxFlat.new()
		style.bg_color = Color(str(hex))
		style.border_color = Color.WHITE if selected else Color(0.05, 0.12, 0.06, 0.9)
		style.set_border_width_all(4 if selected else 2)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.text = "✓" if selected else ""


func _build_configuration_page() -> void:
	var heading := Label.new()
	heading.name = "ConfigurationHeading"
	heading.text = _t("menu.configuration_title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.position = Vector2(-360, 85)
	heading.size = Vector2(720, 56)
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(heading)
	var back := Button.new()
	back.name = "ConfigurationBackButton"
	back.text = _t("menu.back")
	back.position = Vector2(20, 14)
	back.size = Vector2(126, 40)
	back.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.88), Color(0.72, 0.83, 0.42)))
	back.pressed.connect(_show_landing_page)
	configuration_page.add_child(back)
	var description := Label.new()
	description.text = _t("menu.configuration_description")
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.set_anchors_preset(Control.PRESET_CENTER_TOP)
	description.position = Vector2(-400, 150)
	description.size = Vector2(800, 36)
	description.add_theme_font_size_override("font_size", 19)
	description.add_theme_color_override("font_color", Color("f5dc9d"))
	configuration_page.add_child(description)
	var connection := _saved_multiplayer_connection()
	var host_label := Label.new()
	host_label.text = _t("menu.server_host")
	host_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	host_label.position = Vector2(-390, 246)
	host_label.size = Vector2(200, 38)
	host_label.add_theme_font_size_override("font_size", 18)
	host_label.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(host_label)
	multiplayer_host_input = LineEdit.new()
	multiplayer_host_input.name = "ServerHost"
	multiplayer_host_input.text = str(connection["host"])
	multiplayer_host_input.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_host_input.position = Vector2(-185, 240)
	multiplayer_host_input.size = Vector2(440, 44)
	multiplayer_host_input.add_theme_font_size_override("font_size", 18)
	multiplayer_host_input.placeholder_text = _t("menu.server_host_placeholder")
	configuration_page.add_child(multiplayer_host_input)
	var port_label := Label.new()
	port_label.text = _t("menu.server_port")
	port_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	port_label.position = Vector2(-390, 310)
	port_label.size = Vector2(200, 38)
	port_label.add_theme_font_size_override("font_size", 18)
	port_label.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(port_label)
	multiplayer_port_input = LineEdit.new()
	multiplayer_port_input.name = "ServerPort"
	multiplayer_port_input.text = str(connection["port"])
	multiplayer_port_input.max_length = 5
	multiplayer_port_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	multiplayer_port_input.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_port_input.position = Vector2(-185, 304)
	multiplayer_port_input.size = Vector2(160, 44)
	multiplayer_port_input.add_theme_font_size_override("font_size", 18)
	configuration_page.add_child(multiplayer_port_input)
	multiplayer_secure_checkbox = CheckBox.new()
	multiplayer_secure_checkbox.name = "SecureConnection"
	multiplayer_secure_checkbox.text = _t("menu.server_secure")
	multiplayer_secure_checkbox.button_pressed = bool(connection["secure"])
	multiplayer_secure_checkbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_secure_checkbox.position = Vector2(-390, 377)
	multiplayer_secure_checkbox.size = Vector2(680, 40)
	multiplayer_secure_checkbox.add_theme_font_size_override("font_size", 18)
	multiplayer_secure_checkbox.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(multiplayer_secure_checkbox)
	multiplayer_self_signed_checkbox = CheckBox.new()
	multiplayer_self_signed_checkbox.name = "AllowSelfSignedCertificate"
	multiplayer_self_signed_checkbox.text = _t("menu.server_self_signed")
	multiplayer_self_signed_checkbox.button_pressed = bool(connection["allow_self_signed"])
	multiplayer_self_signed_checkbox.disabled = not multiplayer_secure_checkbox.button_pressed
	multiplayer_self_signed_checkbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	multiplayer_self_signed_checkbox.position = Vector2(-390, 422)
	multiplayer_self_signed_checkbox.size = Vector2(780, 40)
	multiplayer_self_signed_checkbox.add_theme_font_size_override("font_size", 17)
	multiplayer_self_signed_checkbox.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(multiplayer_self_signed_checkbox)
	multiplayer_secure_checkbox.toggled.connect(func(active: bool) -> void:
		multiplayer_self_signed_checkbox.disabled = not active
	)
	var save := Button.new()
	save.name = "SaveServerConfiguration"
	save.text = _t("menu.save_configuration")
	save.set_anchors_preset(Control.PRESET_CENTER_TOP)
	save.position = Vector2(-190, 508)
	save.size = Vector2(380, 54)
	save.add_theme_font_size_override("font_size", 21)
	save.add_theme_stylebox_override("normal", _button_style(Color("376c32"), Color("efd56c")))
	save.pressed.connect(_save_multiplayer_settings)
	configuration_page.add_child(save)
	configuration_status_label = Label.new()
	configuration_status_label.name = "ConfigurationStatus"
	configuration_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	configuration_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	configuration_status_label.position = Vector2(-420, 582)
	configuration_status_label.size = Vector2(840, 38)
	configuration_status_label.add_theme_font_size_override("font_size", 17)
	configuration_status_label.add_theme_color_override("font_color", Color("fff2c2"))
	configuration_page.add_child(configuration_status_label)


func _show_multiplayer_page() -> void:
	landing_page.hide()
	free_game_page.hide()
	configuration_page.hide()
	quest_overview_page.hide()
	quest_detail_page.hide()
	multiplayer_page.show()
	_update_dino_card_selection()
	if is_instance_valid(multiplayer_connect_button):
		multiplayer_connect_button.disabled = false


func _connect_multiplayer() -> void:
	var display_name := multiplayer_name_input.text.strip_edges()
	if display_name.is_empty() or display_name.length() > 20:
		multiplayer_status_label.text = _t("menu.player_name_required")
		return
	var connection := _saved_multiplayer_connection()
	var host := str(connection["host"]).strip_edges()
	var port_text := str(connection["port"])
	if host.is_empty() or host.contains(" ") or host.contains("/") or host.contains("@") or host.contains("?") or host.contains("#") or host.contains(":"):
		multiplayer_status_label.text = _t("menu.server_host_invalid")
		return
	if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		multiplayer_status_label.text = _t("menu.server_port_invalid")
		return
	var port := int(port_text)
	var secure := bool(connection["secure"])
	var allow_self_signed := secure and bool(connection["allow_self_signed"])
	var url := "%s://%s:%d/" % ["wss" if secure else "ws", host, port]
	multiplayer_connect_button.disabled = true
	multiplayer_status_label.text = _t("menu.connecting")
	var result: Error = multiplayer_client.connect_to_server(url, selected_dino_id, allow_self_signed, display_name, selected_player_color)
	if result != OK:
		_on_multiplayer_failed(error_string(result))


func _show_configuration_page() -> void:
	var connection := _saved_multiplayer_connection()
	multiplayer_host_input.text = str(connection["host"])
	multiplayer_port_input.text = str(connection["port"])
	multiplayer_secure_checkbox.button_pressed = bool(connection["secure"])
	multiplayer_self_signed_checkbox.button_pressed = bool(connection["allow_self_signed"])
	multiplayer_self_signed_checkbox.disabled = not multiplayer_secure_checkbox.button_pressed
	configuration_status_label.text = ""
	landing_page.hide()
	free_game_page.hide()
	multiplayer_page.hide()
	quest_overview_page.hide()
	quest_detail_page.hide()
	configuration_page.show()


func _save_multiplayer_settings() -> void:
	var host := multiplayer_host_input.text.strip_edges()
	var port_text := multiplayer_port_input.text.strip_edges()
	if host.is_empty() or host.contains(" ") or host.contains("/") or host.contains("@") or host.contains("?") or host.contains("#") or host.contains(":"):
		configuration_status_label.text = _t("menu.server_host_invalid")
		return
	if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		configuration_status_label.text = _t("menu.server_port_invalid")
		return
	var port := int(port_text)
	var secure := multiplayer_secure_checkbox.button_pressed
	var allow_self_signed := secure and multiplayer_self_signed_checkbox.button_pressed
	var url := "%s://%s:%d/" % ["wss" if secure else "ws", host, port]
	var pending_settings := ConfigFile.new()
	pending_settings.load(MULTIPLAYER_SETTINGS_PATH)
	pending_settings.set_value("server", "host", host)
	pending_settings.set_value("server", "port", port)
	pending_settings.set_value("server", "secure", secure)
	pending_settings.set_value("server", "allow_self_signed", allow_self_signed)
	pending_settings.set_value("server", "url", url)
	if pending_settings.save(MULTIPLAYER_SETTINGS_PATH) != OK:
		configuration_status_label.text = _t("menu.configuration_save_failed")
		return
	multiplayer_settings = pending_settings
	configuration_status_label.text = _t("menu.configuration_saved")


func _saved_multiplayer_connection() -> Dictionary:
	# Preserve addresses entered in versions that used one WebSocket URL field.
	var old_url := str(multiplayer_settings.get_value("server", "url", DEFAULT_SERVER_URL))
	var secure := bool(multiplayer_settings.get_value("server", "secure", old_url.begins_with("wss://")))
	var address := old_url.trim_prefix("wss://").trim_prefix("ws://").get_slice("/", 0)
	var old_host := address.get_slice(":", 0)
	var old_port := int(address.get_slice(":", 1)) if address.contains(":") else DEFAULT_SERVER_PORT
	return {
		"host": str(multiplayer_settings.get_value("server", "host", old_host if not old_host.is_empty() else DEFAULT_SERVER_HOST)),
		"port": int(multiplayer_settings.get_value("server", "port", old_port if old_port > 0 else DEFAULT_SERVER_PORT)),
		"secure": secure,
		"allow_self_signed": bool(multiplayer_settings.get_value("server", "allow_self_signed", true))
	}


func _on_multiplayer_welcome(message: Dictionary) -> void:
	var seed := int(message.get("seed", 0))
	if message.get("map") != "grassland" or seed < 100000 or seed > 999999 or not message.get("spawn") is Dictionary:
		_on_multiplayer_failed("protocol")
		multiplayer_client.disconnect_from_server()
		return
	active_quest_id = ""
	active_mission_id = ""
	multiplayer_active = true
	multiplayer_id = int(message.get("id", 0))
	multiplayer_roster.clear()
	selected_map_theme = "grassland"
	seed_input.text = "%06d" % seed
	map_seed = seed
	_start_game(selected_dino_id)
	var spawn: Dictionary = message["spawn"]
	player.global_position = Vector3(float(spawn.get("x", 0.0)), float(spawn.get("y", 0.1)), float(spawn.get("z", 0.0)))
	_remember_multiplayer_player(spawn)
	var marker: Node3D = HUMAN_MARKER_SCRIPT.new()
	marker.position.y = float(player.get("collision_height")) + 1.7
	player.add_child(marker)
	marker.call("set_color", str(spawn.get("color", selected_player_color)))
	for peer in message.get("players", []):
		if peer is Dictionary:
			_upsert_remote_player(peer, true)


func _on_multiplayer_message(message: Dictionary) -> void:
	if not multiplayer_active or not is_instance_valid(world_root):
		return
	match str(message.get("type", "")):
		"joined":
			if message.get("player") is Dictionary:
				_upsert_remote_player(message["player"], true)
		"state":
			if message.get("player") is Dictionary:
				_upsert_remote_player(message["player"])
		"left":
			var peer_id := int(message.get("id", 0))
			if remote_players.has(peer_id):
				(remote_players[peer_id] as Node).queue_free()
				remote_players.erase(peer_id)
			multiplayer_roster.erase(peer_id)
			_refresh_multiplayer_roster()
		"hit":
			var target_id := int(message.get("target", 0))
			var remaining := maxi(int(message.get("health", 0)), 0)
			if target_id == multiplayer_id and is_instance_valid(player):
				if remaining < player.health:
					player.take_damage(player.health - remaining)
				elif remaining > player.health:
					player.restore_health(remaining - player.health)
			elif remote_players.has(target_id):
				remote_players[target_id].set_health(remaining)
		"scream":
			pass


func _upsert_remote_player(data: Dictionary, immediate := false) -> void:
	var peer_id := int(data.get("id", 0))
	if peer_id == 0 or peer_id == multiplayer_id:
		return
	_remember_multiplayer_player(data)
	var remote: Node3D = remote_players.get(peer_id)
	if not is_instance_valid(remote):
		remote = REMOTE_PLAYER_SCRIPT.new()
		remote.name = "RemotePlayer_%d" % peer_id
		remote.set("identifier", peer_id)
		remote.set("dino_id", str(data.get("dino", "triceratops")))
		world_root.add_child(remote)
		remote_players[peer_id] = remote
		_register_quality_geometry(remote, "actor")
		immediate = true
	remote.call("set_network_state", data, immediate)


func _remember_multiplayer_player(data: Dictionary) -> void:
	var peer_id := int(data.get("id", 0))
	if peer_id == 0:
		return
	var details := {
		"name": str(data.get("name", "Player")),
		"color": str(data.get("color", "#6ea8fe"))
	}
	if multiplayer_roster.get(peer_id, {}) == details:
		return
	multiplayer_roster[peer_id] = details
	_refresh_multiplayer_roster()


func _refresh_multiplayer_roster() -> void:
	if not is_instance_valid(multiplayer_roster_rows):
		return
	_clear_control(multiplayer_roster_rows)
	var ids: Array = multiplayer_roster.keys()
	ids.sort()
	for peer_id in ids:
		var details: Dictionary = multiplayer_roster[peer_id]
		var row := Label.new()
		row.name = "Player_%s" % peer_id
		row.text = "● %s%s" % [details["name"], " (%s)" % _t("hud.you") if peer_id == multiplayer_id else ""]
		row.clip_text = true
		row.custom_minimum_size = Vector2(240, 23)
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color(str(details["color"])))
		multiplayer_roster_rows.add_child(row)


func _on_multiplayer_failed(reason: String) -> void:
	if is_instance_valid(multiplayer_connect_button):
		multiplayer_connect_button.disabled = false
	if is_instance_valid(multiplayer_status_label):
		multiplayer_status_label.text = _t("menu.server_full") if reason == "full" else (_t("menu.server_unreachable") if reason in ["timeout", "unreachable"] else _t("menu.server_rejected"))


func _on_multiplayer_disconnected() -> void:
	if multiplayer_active:
		_return_to_main_menu()
	if is_instance_valid(multiplayer_status_label):
		multiplayer_status_label.text = _t("menu.server_disconnected")


func _on_player_attacked() -> void:
	if multiplayer_active:
		multiplayer_client.send_action("attack")


func _update_map_theme_selection() -> void:
	for theme_id in map_theme_buttons:
		var button := map_theme_buttons[theme_id] as Button
		var selected := str(theme_id) == selected_map_theme
		button.text = ("✓ " if selected else "") + _theme_name(str(theme_id))
		var art: Texture2D = load("res://assets/ui/menu/theme-%s.png" % theme_id)
		button.add_theme_stylebox_override("normal", _tile_image_style(art, Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.54, 0.56, 0.53, 1.0)))
		button.add_theme_stylebox_override("hover", _tile_image_style(art, Color(0.9, 0.92, 0.88, 1.0)))
		button.add_theme_stylebox_override("pressed", _tile_image_style(art, Color(0.72, 0.74, 0.68, 1.0)))
		var rim := button.find_child("ThemeRim", false, false) as Panel
		if rim:
			rim.add_theme_stylebox_override("panel", _theme_tile_rim_style(selected))


func _update_start_button() -> void:
	if not is_instance_valid(start_game_button):
		return
	var dino_name: String = _dino_name(selected_dino_id)
	start_game_button.text = _t("menu.start_as", [dino_name.to_upper(), _theme_name(selected_map_theme).to_upper()])


func _show_free_game_page() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	landing_page.hide()
	configuration_page.hide()
	quest_overview_page.hide()
	quest_detail_page.hide()
	multiplayer_page.hide()
	free_game_page.show()
	_update_dino_card_selection()
	_update_map_theme_selection()
	_update_start_button()


func _show_landing_page() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	free_game_page.hide()
	configuration_page.hide()
	multiplayer_page.hide()
	quest_overview_page.hide()
	quest_detail_page.hide()
	landing_page.show()


func _build_quest_pages(root: Control) -> void:
	quest_overview_page = Control.new()
	quest_overview_page.name = "QuestOverviewPage"
	quest_overview_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(quest_overview_page)
	quest_overview_page.hide()

	quest_detail_page = Control.new()
	quest_detail_page.name = "QuestDetailPage"
	quest_detail_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(quest_detail_page)
	quest_detail_page.hide()
	_populate_quest_overview()


func _add_quest_background(page: Control, texture_path: String) -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load(texture_path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.015, 0.52)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shade)


func _quest_back_button(parent: Control, callback: Callable) -> void:
	var button := Button.new()
	button.name = "QuestBackButton"
	button.text = _t("menu.back")
	button.position = Vector2(20, 18)
	button.size = Vector2(126, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.16, 0.1, 0.9), Color(0.72, 0.83, 0.42, 0.8)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.34, 0.2, 0.97), Color("f7f2d0")))
	button.pressed.connect(callback)
	parent.add_child(button)


func _populate_quest_overview() -> void:
	_add_quest_background(quest_overview_page, str(quest_config.get_value("quests", "overview_background")))
	_quest_back_button(quest_overview_page, _show_landing_page)
	var title := Label.new()
	title.text = _t("quest.heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-350, 34)
	title.size = Vector2(700, 58)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("fff2c2"))
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.94))
	title.add_theme_constant_override("outline_size", 8)
	quest_overview_page.add_child(title)

	var quest_grid := GridContainer.new()
	quest_grid.name = "QuestTiles"
	quest_grid.columns = 2
	quest_grid.set_anchors_preset(Control.PRESET_CENTER)
	quest_grid.position = Vector2(-390, -220)
	quest_grid.size = Vector2(780, 450)
	quest_grid.add_theme_constant_override("h_separation", 24)
	quest_grid.add_theme_constant_override("v_separation", 24)
	quest_overview_page.add_child(quest_grid)
	for quest_value in quest_config.get_value("quests", "quest_ids", []):
		var quest_id := str(quest_value)
		var button := Button.new()
		button.name = "Quest_%s" % quest_id
		button.text = "%s\n%s" % [_config_text(quest_config, quest_id, "title").to_upper(), _config_text(quest_config, quest_id, "description")]
		button.custom_minimum_size = Vector2(378, 245)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_color_override("font_color", Color("fff2c2"))
		button.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.96))
		button.add_theme_constant_override("outline_size", 7)
		var art: Texture2D = load(str(quest_config.get_value(quest_id, "image")))
		button.add_theme_stylebox_override("normal", _tile_image_style(art, Color(0.78, 0.78, 0.72, 1.0)))
		button.add_theme_stylebox_override("hover", _tile_image_style(art, Color(1.0, 1.0, 0.94, 1.0)))
		button.add_theme_stylebox_override("pressed", _tile_image_style(art, Color(0.62, 0.64, 0.58, 1.0)))
		button.pressed.connect(_show_quest_page.bind(quest_id))
		_add_tile_rim(button)
		quest_grid.add_child(button)


func _clear_control(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _show_quest_overview() -> void:
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()
	if is_instance_valid(play_guide_overlay):
		play_guide_overlay.hide()
	landing_page.hide()
	configuration_page.hide()
	free_game_page.hide()
	multiplayer_page.hide()
	quest_detail_page.hide()
	quest_overview_page.show()


func _show_quest_page(quest_id: String) -> void:
	var config_path := str(quest_config.get_value(quest_id, "mission_config", ""))
	if config_path.is_empty() or mission_config.load(config_path) != OK:
		push_error("Could not load missions for quest %s" % quest_id)
		return
	active_quest_id = quest_id
	_clear_control(quest_detail_page)
	_add_quest_background(quest_detail_page, str(quest_config.get_value(quest_id, "background", quest_config.get_value("quests", "overview_background"))))
	_quest_back_button(quest_detail_page, _show_quest_overview)
	var title := Label.new()
	title.text = _config_text(quest_config, quest_id, "title").to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-400, 22)
	title.size = Vector2(800, 50)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("fff2c2"))
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.96))
	title.add_theme_constant_override("outline_size", 7)
	quest_detail_page.add_child(title)

	var mission_grid := GridContainer.new()
	mission_grid.name = "MissionTiles"
	mission_grid.columns = 3
	mission_grid.set_anchors_preset(Control.PRESET_CENTER)
	mission_grid.position = Vector2(-465, -242)
	mission_grid.size = Vector2(930, 500)
	mission_grid.add_theme_constant_override("h_separation", 15)
	mission_grid.add_theme_constant_override("v_separation", 15)
	quest_detail_page.add_child(mission_grid)
	var mission_ids: Array = mission_config.get_value("quest", "mission_ids", [])
	for index in mission_ids.size():
		var mission_id := str(mission_ids[index])
		var completed := _is_mission_completed(quest_id, mission_id)
		var unlocked := _is_mission_unlocked(quest_id, mission_ids, index)
		var dino_id := str(mission_config.get_value(mission_id, "dinosaur"))
		var dino_name := str(_dino_name(dino_id))
		var button := Button.new()
		button.name = "Mission_%s" % mission_id
		var status_text := _t("mission.completed") if completed else (_t("mission.available") if unlocked else _t("mission.locked"))
		button.text = "%d. %s\n%s\n%s  •  %s" % [index + 1, _config_text(mission_config, mission_id, "title").to_upper(), _config_text(mission_config, mission_id, "description"), status_text, _t("mission.play_as", [dino_name])]
		button.custom_minimum_size = Vector2(300, 220)
		button.disabled = not unlocked
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("fff5d2"))
		button.add_theme_color_override("font_disabled_color", Color(0.72, 0.72, 0.69, 0.92))
		button.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.01, 0.98))
		button.add_theme_constant_override("outline_size", 6)
		var art: Texture2D = load(str(mission_config.get_value(mission_id, "image")))
		button.add_theme_stylebox_override("normal", _tile_image_style(art, Color(0.78, 0.84, 0.70, 1.0) if completed else Color(0.72, 0.72, 0.68, 1.0)))
		button.add_theme_stylebox_override("hover", _tile_image_style(art, Color(0.96, 0.96, 0.91, 1.0)))
		button.add_theme_stylebox_override("pressed", _tile_image_style(art, Color(0.58, 0.60, 0.54, 1.0)))
		button.add_theme_stylebox_override("disabled", _tile_image_style(art, Color(0.30, 0.30, 0.29, 1.0)))
		button.tooltip_text = _t("mission.replay_tooltip") if completed else (_t("mission.start_tooltip") if unlocked else _t("mission.unlock_tooltip", [index]))
		button.pressed.connect(_start_quest_mission.bind(quest_id, mission_id))
		_add_tile_rim(button, "completed" if completed else ("available" if unlocked else "locked"))
		mission_grid.add_child(button)
	landing_page.hide()
	free_game_page.hide()
	multiplayer_page.hide()
	quest_overview_page.hide()
	quest_detail_page.show()


func _start_quest_mission(quest_id: String, mission_id: String) -> void:
	var mission_ids: Array = mission_config.get_value("quest", "mission_ids", [])
	var mission_index := mission_ids.find(mission_id)
	if mission_index < 0 or not _is_mission_unlocked(quest_id, mission_ids, mission_index):
		return
	active_quest_id = quest_id
	active_mission_id = mission_id
	selected_dino_id = str(mission_config.get_value(mission_id, "dinosaur"))
	selected_map_theme = str(mission_config.get_value(mission_id, "map_theme", "grassland"))
	_start_game(selected_dino_id)


func _is_mission_completed(quest_id: String, mission_id: String) -> bool:
	return bool(quest_progress.get_value(quest_id, mission_id, false))


func _is_mission_unlocked(quest_id: String, mission_ids: Array, mission_index: int) -> bool:
	return mission_index == 0 or _is_mission_completed(quest_id, str(mission_ids[mission_index - 1]))


func _mark_mission_completed(quest_id: String, mission_id: String) -> void:
	quest_progress.set_value(quest_id, mission_id, true)
	var save_error := quest_progress.save(quest_progress_path)
	if save_error != OK:
		push_error("Could not save quest progress: %s" % error_string(save_error))


func _mission_objective() -> Dictionary:
	var data := {}
	if active_mission_id.is_empty():
		return data
	for key in mission_config.get_section_keys(active_mission_id):
		data[key] = mission_config.get_value(active_mission_id, key)
	return data


func _apply_mission_setup() -> void:
	if active_mission_id.is_empty():
		return
	var setup_path := str(mission_config.get_value(active_mission_id, "setup_script", ""))
	var setup_script: Script = load(setup_path)
	assert(setup_script != null, "Could not load mission setup script: %s" % setup_path)
	var setup_instance = setup_script.new()
	setup_instance.call("setup", self)


func _play_mission_intro() -> void:
	if active_mission_id.is_empty() or not is_instance_valid(game_hud):
		return
	var locale := Localization.language
	var audio_path := "res://assets/audio/missions/%s/%s.mp3" % [active_mission_id, locale]
	if not ResourceLoader.exists(audio_path):
		audio_path = "res://assets/audio/missions/%s/en.mp3" % active_mission_id
	if not ResourceLoader.exists(audio_path):
		push_warning("Mission introduction audio is missing: %s" % audio_path)
		return
	mission_intro_player = AudioStreamPlayer.new()
	mission_intro_player.name = "MissionIntroduction"
	mission_intro_player.stream = load(audio_path) as AudioStream
	mission_intro_player.volume_db = 3.0
	game_hud.add_child(mission_intro_player)
	mission_intro_player.play()


func _start_mission_event() -> void:
	if active_mission_id.is_empty():
		return
	var event_path := str(mission_config.get_value(active_mission_id, "event_script", ""))
	var event_script: Script = load(event_path)
	assert(event_script != null, "Could not load mission event script: %s" % event_path)
	active_mission_event = event_script.new()
	active_mission_event.name = "ActiveMissionEvent"
	add_child(active_mission_event)
	active_mission_event.progress_changed.connect(_on_mission_progress)
	active_mission_event.mission_completed.connect(_on_mission_completed)
	active_mission_event.mission_failed.connect(_on_mission_failed)
	active_mission_event.call("setup", self, _mission_objective())


func _on_mission_progress(message: String) -> void:
	if is_instance_valid(mission_objective_label):
		mission_objective_label.text = message


func _on_mission_completed() -> void:
	_mark_mission_completed(active_quest_id, active_mission_id)
	_show_mission_result(true, _t("mission.complete_detail"))


func _on_mission_failed(reason: String) -> void:
	_show_mission_result(false, reason)


func _show_mission_result(success: bool, detail: String) -> void:
	if not is_instance_valid(game_hud) or game_hud.find_child("MissionResult", true, false):
		return
	var overlay := ColorRect.new()
	overlay.name = "MissionResult"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.02, 0.01, 0.82)
	game_hud.add_child(overlay)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -110)
	panel.size = Vector2(500, 220)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	overlay.add_child(panel)
	var heading := Label.new()
	heading.text = _t("mission.quest_complete") if success else _t("mission.failed")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 44)
	heading.add_theme_color_override("font_color", Color("bfe46a") if success else Color("ef6655"))
	panel.add_child(heading)
	var message := Label.new()
	message.text = detail
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 21)
	message.add_theme_color_override("font_color", Color("fff2c2"))
	panel.add_child(message)
	var return_button := Button.new()
	return_button.text = _t("mission.return")
	return_button.custom_minimum_size = Vector2(340, 52)
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.pressed.connect(_return_to_main_menu)
	panel.add_child(return_button)


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
	title.text = _t("app.title")
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
	subtitle.text = _t("splash.subtitle")
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
	continue_button.text = _t("splash.continue")
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
	heading.text = _t("menu.credits")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(heading)

	var dedication := Label.new()
	dedication.name = "Dedication"
	dedication.text = _t("credits.dedication")
	dedication.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dedication.add_theme_font_size_override("font_size", 23)
	dedication.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(dedication)

	var author := Label.new()
	author.name = "AuthorCredit"
	author.text = _t("credits.author")
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author.add_theme_font_size_override("font_size", 19)
	author.add_theme_color_override("font_color", Color("f5dc9d"))
	column.add_child(author)

	var license := Label.new()
	license.name = "LicenseCredit"
	license.text = _t("credits.license")
	license.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	license.add_theme_font_size_override("font_size", 18)
	license.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	column.add_child(license)

	var github := LinkButton.new()
	github.name = "GithubLink"
	github.text = _t("credits.github")
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
	close_button.text = _t("menu.back")
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
	heading.text = _t("menu.how_to_play")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(heading)

	var guide_text := RichTextLabel.new()
	guide_text.name = "PlayGuideText"
	guide_text.bbcode_enabled = true
	guide_text.text = _t("guide.text")
	guide_text.custom_minimum_size = Vector2(850, 430)
	guide_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_text.scroll_active = true
	guide_text.add_theme_font_size_override("normal_font_size", 16)
	guide_text.add_theme_font_size_override("bold_font_size", 18)
	guide_text.add_theme_color_override("default_color", Color("f4f0df"))
	column.add_child(guide_text)

	var close_button := Button.new()
	close_button.name = "ClosePlayGuideButton"
	close_button.text = _t("menu.back")
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


func _create_dino_card(dino_id: String, display_name: String, for_multiplayer := false) -> Control:
	var panel := PanelContainer.new()
	panel.name = "DinoCard_%s" % dino_id
	panel.custom_minimum_size = Vector2(202, 154)
	panel.set_meta("dino_id", dino_id)
	panel.add_theme_stylebox_override("panel", _card_style(dino_id == selected_dino_id))
	if for_multiplayer:
		multiplayer_dino_cards[dino_id] = panel
	else:
		dino_cards[dino_id] = panel

	# Cards stay image-first until selected. The chosen portrait is dimmed and
	# reveals its configured abilities in the same space.
	var content := Control.new()
	content.name = "CardContent"
	content.custom_minimum_size = Vector2(188, 140)
	panel.add_child(content)

	var portrait := TextureButton.new()
	portrait.name = "Portrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.texture_normal = load("res://assets/ui/menu/%s.png" % dino_id)
	portrait.ignore_texture_size = true
	portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)

	var shade := ColorRect.new()
	shade.name = "SelectionShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.015, 0.008, 0.70)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = dino_id == selected_dino_id
	content.add_child(shade)

	var name_label := Label.new()
	name_label.name = "DinoName"
	name_label.text = display_name.to_upper()
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 5.0
	name_label.offset_top = 4.0
	name_label.offset_right = -5.0
	name_label.offset_bottom = 30.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15 if display_name.length() < 13 else 13)
	name_label.add_theme_color_override("font_color", Color("fff2c2"))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.96))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var stats := GridContainer.new()
	stats.name = "SelectedStats"
	stats.columns = 2
	stats.set_anchors_preset(Control.PRESET_CENTER)
	stats.position = Vector2(-76, -31)
	stats.size = Vector2(152, 79)
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 3)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.visible = dino_id == selected_dino_id
	content.add_child(stats)
	_add_stat(stats, _t("stat.speed"), "%.1f" % float(dinosaur_config.get_value(dino_id, "run_speed", 0.0)))
	_add_stat(stats, _t("stat.strength"), "%d/10" % int(dinosaur_config.get_value(dino_id, "strength", 0)))
	_add_stat(stats, _t("stat.can_jump"), _t("common.yes") if dinosaur_config.get_value(dino_id, "can_jump", false) else _t("common.no"))
	_add_stat(stats, _t("stat.health"), str(int(dinosaur_config.get_value(dino_id, "max_health", 0))))

	var marker := Label.new()
	marker.name = "SelectedMarker"
	marker.text = "✓"
	marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	marker.position = Vector2(-31, 3)
	marker.size = Vector2(26, 26)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 21)
	marker.add_theme_color_override("font_color", Color("ffe778"))
	marker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	marker.add_theme_constant_override("shadow_offset_x", 2)
	marker.add_theme_constant_override("shadow_offset_y", 2)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.visible = dino_id == selected_dino_id
	content.add_child(marker)

	var selector := Button.new()
	selector.name = "SelectButton"
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector.flat = true
	selector.focus_mode = Control.FOCUS_NONE
	selector.tooltip_text = _t("menu.select_dinosaur", [display_name])
	selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		selector.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	selector.pressed.connect(_select_dino.bind(dino_id))
	content.add_child(selector)
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


func _card_style(selected := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.14, 0.075, 0.96) if selected else Color(0.025, 0.075, 0.045, 0.88)
	style.border_color = Color("ffe778") if selected else Color(0.82, 0.72, 0.35, 0.72)
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 7
	style.content_margin_bottom = 9
	return style


func _theme_tile_rim_style(selected := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("ffe778") if selected else Color(0.82, 0.72, 0.35, 0.72)
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(10)
	return style


func _add_tile_rim(button: Button, state := "available") -> void:
	var rim := Panel.new()
	rim.name = "TileRim"
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.add_theme_stylebox_override("panel", _tile_rim_style(state))
	button.add_child(rim)


func _tile_rim_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	match state:
		"completed":
			style.border_color = Color("9be36d")
			style.set_border_width_all(4)
		"locked":
			style.border_color = Color(0.55, 0.56, 0.54, 0.82)
			style.set_border_width_all(3)
		_:
			style.border_color = Color(0.82, 0.72, 0.35, 0.82)
			style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	match selected_map_theme:
		"desert":
			sky_material.sky_top_color = Color("4c91c6")
			sky_material.sky_horizon_color = Color("efd39b")
			sky_material.ground_bottom_color = Color("8c5f2f")
			sky_material.ground_horizon_color = Color("d7ad6d")
			environment.fog_light_color = Color("d8b77c")
			environment.fog_density = 0.003
		"winter":
			sky_material.sky_top_color = Color("252d3a")
			sky_material.sky_horizon_color = Color("697583")
			sky_material.ground_bottom_color = Color("8c99a4")
			sky_material.ground_horizon_color = Color("c5ced3")
			environment.fog_light_color = Color("788794")
			environment.fog_density = 0.012
		"volcano":
			sky_material.sky_top_color = Color("352e32")
			sky_material.sky_horizon_color = Color("9a6651")
			sky_material.ground_bottom_color = Color("27211f")
			sky_material.ground_horizon_color = Color("5e4b3e")
			environment.fog_light_color = Color("76594c")
			environment.fog_density = 0.009
		_:
			sky_material.sky_top_color = Color("4f95c7")
			sky_material.sky_horizon_color = Color("d6e6b5")
			sky_material.ground_bottom_color = Color("425b2e")
			sky_material.ground_horizon_color = Color("c7d39b")
			environment.fog_light_color = Color("b9caa3")
			environment.fog_density = 0.006
	sky_material.sun_angle_max = 10.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.52 if selected_map_theme in ["winter", "volcano"] else 0.72
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.65 if selected_map_theme == "winter" else 0.45
	world_environment.environment = environment
	world_root.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("cbd5df") if selected_map_theme == "winter" else (Color("ffd2a1") if selected_map_theme == "volcano" else Color("fff1c4"))
	sun.light_energy = 0.72 if selected_map_theme == "winter" else (1.08 if selected_map_theme == "volcano" else 1.42)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	world_root.add_child(sun)
	sun_light = sun


func _build_clouds() -> void:
	var cloud_layer := Node3D.new()
	cloud_layer.name = "Clouds"
	world_root.add_child(cloud_layer)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.31, 0.34, 0.39, 0.92) if selected_map_theme == "winter" else (Color(0.36, 0.31, 0.31, 0.82) if selected_map_theme == "volcano" else Color(0.94, 0.97, 0.96, 0.72))
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
	generated_babies.clear()
	generated_tokens.clear()
	generated_eggs.clear()
	mission_player_start = Vector3(0.0, 0.1, 5.0)
	generated_lava_streams.clear()
	volcano_data.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ int(MAP_THEME_SEED_SALTS[selected_map_theme])
	var occupied: Array = []
	if selected_map_theme == "volcano":
		_generate_volcano_layout(rng)
		occupied.append({"position": Vector2.ZERO, "radius": 43.0})

	var forest_biome := "oasis" if selected_map_theme == "desert" else "forest"
	var open_biome := "desert" if selected_map_theme == "desert" else "grassland"
	var forest_biome_count := rng.randi_range(2, 3) if selected_map_theme == "desert" else rng.randi_range(3, 5)
	for index in forest_biome_count:
		generated_biomes.append({
			"type": forest_biome,
			"position": _random_clear_position(rng, 45.0),
			"radius": rng.randf_range(22.0, 34.0) if selected_map_theme == "desert" else rng.randf_range(42.0, 64.0)
		})
	for index in rng.randi_range(3, 5) if selected_map_theme == "desert" else rng.randi_range(2, 4):
		generated_biomes.append({
			"type": open_biome,
			"position": _random_clear_position(rng, 38.0),
			"radius": rng.randf_range(46.0, 68.0) if selected_map_theme == "desert" else rng.randf_range(38.0, 58.0)
		})

	var pond_count := rng.randi_range(2, 3) if selected_map_theme == "desert" else rng.randi_range(3, 5)
	for index in pond_count:
		var pond_size := Vector2(rng.randf_range(22.0, 44.0), rng.randf_range(16.0, 34.0))
		var pond_radius := maxf(pond_size.x, pond_size.y) * 0.6
		var pond_position := _find_world_position(rng, pond_radius, occupied, 8.0)
		generated_ponds.append({"position": Vector3(pond_position.x, 0.025, pond_position.y), "size": pond_size})
		occupied.append({"position": pond_position, "radius": pond_radius})

	if selected_map_theme == "desert":
		var oasis_index := 0
		for biome in generated_biomes:
			if biome["type"] != "oasis":
				continue
			var water_hole: Dictionary = generated_ponds[oasis_index % generated_ponds.size()]
			var water_position: Vector3 = water_hole["position"]
			biome["position"] = Vector2(water_position.x, water_position.z)
			biome["radius"] = maxf(float(water_hole["size"].x), float(water_hole["size"].y)) * 0.5 + 14.0
			oasis_index += 1

	if selected_map_theme != "desert":
		_generate_river_layout(rng)

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

	var tree_count := rng.randi_range(22, 34) if selected_map_theme == "desert" else rng.randi_range(118, 152)
	for index in tree_count:
		var tree_scale := rng.randf_range(1.0, 2.15)
		var tree_position := _find_biome_position(rng, forest_biome, 1.55 * tree_scale, occupied, 1.7)
		var tree_roll := rng.randf()
		var tree_type := ("dead_tree" if tree_roll < 0.34 else "tree_fern") if selected_map_theme == "desert" else ("tree" if tree_roll < 0.72 else ("tree_fern" if tree_roll < 0.92 else "dead_tree"))
		generated_trees.append({"type": tree_type, "position": Vector3(tree_position.x, 0.0, tree_position.y), "scale": tree_scale, "rotation": rng.randf_range(0.0, TAU)})
		occupied.append({"position": tree_position, "radius": 0.58 * tree_scale})

	for index in rng.randi_range(52, 72):
		var rock_scale := rng.randf_range(0.65, 1.65)
		var rock_position := _find_world_position(rng, 1.1 * rock_scale, occupied, 1.5)
		generated_rocks.append({"position": Vector3(rock_position.x, 0.0, rock_position.y), "scale": rock_scale})
		occupied.append({"position": rock_position, "radius": 0.9 * rock_scale})

	var log_count := rng.randi_range(3, 6) if selected_map_theme == "desert" else rng.randi_range(18, 28)
	for index in log_count:
		var log_scale := rng.randf_range(0.8, 1.35)
		var log_position := _find_biome_position(rng, forest_biome, 3.5 * log_scale, occupied, 1.2)
		generated_logs.append({"position": Vector3(log_position.x, 0.0, log_position.y), "scale": log_scale, "rotation": rng.randf_range(0.0, TAU)})
		occupied.append({"position": log_position, "radius": 3.5 * log_scale})

	var plant_count := rng.randi_range(55, 85) if selected_map_theme == "desert" else rng.randi_range(220, 285)
	for index in plant_count:
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
		var plant_position := _find_biome_position(rng, forest_biome, 0.7 * plant_scale, [], 0.0)
		generated_vegetation.append({"type": plant_type, "position": Vector3(plant_position.x, 0.02, plant_position.y), "scale": plant_scale, "rotation": rng.randf_range(0.0, TAU)})

	# Use a separate deterministic stream so adding poisonous plants never
	# changes the established terrain, wildlife, token, or egg layout for a seed.
	var poison_rng := RandomNumberGenerator.new()
	poison_rng.seed = map_seed ^ 0x70A150
	var poison_count := 6 if selected_map_theme == "desert" else int(dinosaur_config.get_value("poison", "plant_count", 16))
	for index in poison_count:
		var poison_scale := poison_rng.randf_range(0.9, 1.35)
		var poison_position := _find_biome_position(poison_rng, forest_biome, 0.8 * poison_scale, [], 0.0)
		generated_vegetation.append({"type": "poisonous", "position": Vector3(poison_position.x, 0.02, poison_position.y), "scale": poison_scale, "rotation": poison_rng.randf_range(0.0, TAU)})

	var grass_count := rng.randi_range(45, 75) if selected_map_theme == "desert" else rng.randi_range(360, 460)
	for index in grass_count:
		var grass_scale := rng.randf_range(0.7, 1.4)
		var grass_position := _find_biome_position(rng, forest_biome if selected_map_theme == "desert" else "grassland", 0.45 * grass_scale, [], 0.0)
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

	var cloud_count := rng.randi_range(13, 18) if selected_map_theme == "winter" else (rng.randi_range(5, 8) if selected_map_theme == "desert" else rng.randi_range(8, 13))
	for index in cloud_count:
		var wind_angle := rng.randf_range(-0.25, 0.25)
		generated_clouds.append({
			"position": Vector3(rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE), rng.randf_range(34.0, 52.0), rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)),
			"scale": rng.randf_range(1.4, 2.8),
			"direction": Vector3(cos(wind_angle), 0.0, sin(wind_angle)),
			"speed": rng.randf_range(0.7, 1.6)
		})


func _generate_river_layout(rng: RandomNumberGenerator) -> void:
	var river_points := PackedVector2Array()
	var horizontal_river := rng.randf() > 0.5
	var river_offset := rng.randf_range(52.0, 105.0) * (-1.0 if rng.randf() < 0.5 else 1.0)
	var river_phase := rng.randf_range(0.0, TAU)
	for point_index in 21:
		var along := lerpf(-MAP_HALF_SIZE - 8.0, MAP_HALF_SIZE + 8.0, float(point_index) / 20.0)
		var across := river_offset + sin(float(point_index) * 0.62 + river_phase) * rng.randf_range(12.0, 25.0)
		river_points.append(Vector2(along, across) if horizontal_river else Vector2(across, along))
	generated_rivers.append({"points": river_points, "width": rng.randf_range(8.0, 13.0)})


func _generate_volcano_layout(rng: RandomNumberGenerator) -> void:
	volcano_data = {"position": Vector3.ZERO, "radius": 46.0, "height": 31.0, "crater_radius": 10.5}
	var stream_count := rng.randi_range(4, 5)
	for stream_index in stream_count:
		var points := PackedVector2Array()
		var angle := TAU * float(stream_index) / float(stream_count) + rng.randf_range(-0.34, 0.34)
		var bend := rng.randf_range(-0.18, 0.18)
		for point_index in 12:
			var progress := float(point_index) / 11.0
			var radius := lerpf(9.0, 180.0, progress)
			var point_angle := angle + sin(progress * PI) * bend + sin(progress * 8.0 + float(stream_index)) * 0.035
			points.append(Vector2(cos(point_angle), sin(point_angle)) * radius)
		generated_lava_streams.append({"points": points, "width": rng.randf_range(6.0, 9.0), "damage_per_second": 12})


func _random_clear_position(rng: RandomNumberGenerator, edge_padding: float) -> Vector2:
	for attempt in 100:
		var candidate := Vector2(
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding),
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding)
		)
		if candidate.length() > (50.0 if selected_map_theme == "volcano" else 35.0):
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
		if candidate.length() < (46.0 if selected_map_theme == "volcano" else 28.0) + radius or _is_position_in_water(candidate, radius) or _is_position_in_lava(candidate, radius):
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
		if candidate.length() < (46.0 if selected_map_theme == "volcano" else 28.0) + radius or _is_position_in_water(candidate, radius) or _is_position_in_lava(candidate, radius):
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


func _is_position_in_lava(candidate: Vector2, radius: float) -> bool:
	for stream in generated_lava_streams:
		var points: PackedVector2Array = stream["points"]
		var lava_radius := float(stream["width"]) * 0.5 + radius
		for point_index in points.size() - 1:
			if Geometry2D.get_closest_point_to_segment(candidate, points[point_index], points[point_index + 1]).distance_to(candidate) <= lava_radius:
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
	ground_mesh.material_override = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, 1 + map_seed % 2, 0.055)
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
	if selected_map_theme == "volcano":
		_create_volcano()
		for stream in generated_lava_streams:
			_create_lava_stream(stream)
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
	var patch_material: StandardMaterial3D = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, texture_variant, 0.09)
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
	player.position = Vector3(0.0, 0.1, 58.0) if selected_map_theme == "volcano" else mission_player_start
	world_root.add_child(player)
	player.screamed.connect(_on_dino_screamed)
	player.attacked.connect(_on_player_attacked)
	player.health_changed.connect(_on_health_changed)
	player.energy_changed.connect(_on_energy_changed)
	player.bonuses_changed.connect(_on_bonuses_changed)
	player.poisoning_changed.connect(_on_poisoning_changed)
	player.died.connect(_on_player_died)
	player.status_requested.connect(_show_status_message)
	if multiplayer_active:
		multiplayer_client.player = player


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
		npc.set("can_retreat", data.get("can_retreat", true))
		npc.set("ignore_combat_odds", data.get("ignore_combat_odds", false))
		npc.set("allow_same_species_combat", data.get("allow_same_species_combat", false))
		if data.has("mission_role"):
			npc.set_meta("mission_role", data["mission_role"])
		npc.position = data["position"]
		wildlife.add_child(npc)
		_register_quality_geometry(npc.get("model_root"), "actor")


func _build_snow_footprints() -> void:
	if selected_map_theme != "winter":
		return
	var footprints := MultiMeshInstance3D.new()
	footprints.set_script(SNOW_FOOTPRINTS_SCRIPT)
	world_root.add_child(footprints)
	_register_quality_geometry(footprints, "small")


func _build_mission_babies() -> void:
	for index in generated_babies.size():
		var data: Dictionary = generated_babies[index]
		var baby := CharacterBody3D.new()
		baby.name = "MissionBaby_%02d_%s" % [index, data.get("species", "apatosaurus")]
		baby.set_script(BABY_DINO_SCRIPT)
		baby.set("dino_id", data.get("species", "apatosaurus"))
		baby.set("companion_index", index)
		baby.set("texture_variant", data.get("texture_variant", index))
		var parent_role := str(data.get("parent_role", ""))
		if not parent_role.is_empty():
			for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
				if str(npc.get_meta("mission_role", "")) == parent_role:
					baby.set("parent_dino", npc)
					break
		if data.has("mission_role"):
			baby.set_meta("mission_role", data["mission_role"])
		baby.position = data["position"]
		world_root.add_child(baby)
		_register_quality_geometry(baby.get("model_root"), "actor")


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
	_show_status_message(_t("egg.hatched", [selected_dino_name]))


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
	return not _is_position_in_water(candidate, 4.0) and not _is_position_in_lava(candidate, 4.0) and _is_token_position_clear(candidate)


func _build_hud() -> void:
	game_hud = CanvasLayer.new()
	game_hud.name = "TouchControls"
	add_child(game_hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_hud.add_child(root)

	var title := Label.new()
	title.text = _t("hud.title", [selected_dino_name.to_upper(), _theme_name(selected_map_theme).to_upper(), map_seed])
	title.position = Vector2(18, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f4f0cf"))
	root.add_child(title)
	_build_vital_bars(root)
	if multiplayer_active:
		var roster_panel := PanelContainer.new()
		roster_panel.name = "MultiplayerRoster"
		roster_panel.position = Vector2(18, 150)
		roster_panel.custom_minimum_size = Vector2(260, 0)
		roster_panel.add_theme_stylebox_override("panel", _button_style(Color(0.02, 0.07, 0.04, 0.78), Color(0.72, 0.83, 0.42, 0.7)))
		root.add_child(roster_panel)
		var roster_content := VBoxContainer.new()
		roster_content.add_theme_constant_override("separation", 3)
		roster_panel.add_child(roster_content)
		var roster_title := Label.new()
		roster_title.text = _t("hud.players")
		roster_title.add_theme_font_size_override("font_size", 17)
		roster_title.add_theme_color_override("font_color", Color("fff2c2"))
		roster_content.add_child(roster_title)
		multiplayer_roster_rows = VBoxContainer.new()
		multiplayer_roster_rows.name = "MultiplayerRosterRows"
		roster_content.add_child(multiplayer_roster_rows)

	status_label = Label.new()
	status_label.text = _t("hud.explore")
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
	var jump_button := _add_action_button(left_panel, _t("action.jump"), "jump", Vector2(0, 58), Vector2(92, 54))
	jump_button.disabled = not bool(dinosaur_config.get_value(selected_dino_id, "can_jump", false))
	if jump_button.disabled:
		jump_button.tooltip_text = _t("action.cannot_jump", [selected_dino_name])
	_add_action_button(left_panel, _t("action.run"), "run", Vector2(98, 58), Vector2(84, 54))
	_add_action_button(left_panel, _t("action.duck"), "duck", Vector2(188, 58), Vector2(84, 54))
	_add_action_button(left_panel, _t("action.attack"), "attack", Vector2(0, 118), Vector2(110, 54))
	_add_action_button(left_panel, _t("action.eat"), "eat", Vector2(116, 118), Vector2(92, 54))
	_add_action_button(left_panel, _t("action.scream"), "scream", Vector2(214, 118), Vector2(116, 54))

	var action_hint := Label.new()
	action_hint.text = _t("hud.left_actions")
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
	move_hint.text = _t("hud.right_move")
	move_hint.position = Vector2(22, 2)
	move_hint.size = Vector2(200, 22)
	move_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_hint.add_theme_font_size_override("font_size", 14)
	move_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	right_panel.add_child(move_hint)

	var keyboard_hint := Label.new()
	keyboard_hint.text = _t("hud.keyboard")
	keyboard_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	keyboard_hint.position = Vector2(-350, -30)
	keyboard_hint.size = Vector2(700, 24)
	keyboard_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_hint.add_theme_font_size_override("font_size", 13)
	keyboard_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.68))
	root.add_child(keyboard_hint)

	var menu_button := Button.new()
	menu_button.name = "ReturnToMissionButton" if not active_mission_id.is_empty() else "ReturnToFreeGameButton"
	menu_button.text = _t("hud.return_missions") if not active_mission_id.is_empty() else (_t("hud.return_multiplayer") if multiplayer_active else _t("hud.return_free_game"))
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

	if not active_mission_id.is_empty():
		var mission_title := Label.new()
		mission_title.name = "MissionTitle"
		mission_title.text = _config_text(mission_config, active_mission_id, "title").to_upper()
		mission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
		mission_title.position = Vector2(-300, 56)
		mission_title.size = Vector2(600, 26)
		mission_title.add_theme_font_size_override("font_size", 19)
		mission_title.add_theme_color_override("font_color", Color("d8ed7b"))
		mission_title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.95))
		mission_title.add_theme_constant_override("outline_size", 5)
		root.add_child(mission_title)
		mission_objective_label = Label.new()
		mission_objective_label.name = "MissionObjective"
		mission_objective_label.text = _config_text(mission_config, active_mission_id, "description")
		mission_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		mission_objective_label.position = Vector2(-350, 82)
		mission_objective_label.size = Vector2(700, 26)
		mission_objective_label.add_theme_font_size_override("font_size", 16)
		mission_objective_label.add_theme_color_override("font_color", Color("fff2c2"))
		mission_objective_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.01, 0.95))
		mission_objective_label.add_theme_constant_override("outline_size", 4)
		root.add_child(mission_objective_label)

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
		"logs": generated_logs,
		"theme": selected_map_theme,
		"lava_streams": generated_lava_streams,
		"volcano": volcano_data
	})
	_on_health_changed(player.health, player.max_health)
	_on_energy_changed(player.energy, player.max_energy)
	_on_bonuses_changed(player.speed_bonus_time, player.strength_bonus_time)
	_on_poisoning_changed(player.poisoned)


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
	poison_label = Label.new()
	poison_label.name = "PoisonWarning"
	poison_label.text = _t("hud.poison_warning")
	poison_label.position = Vector2(18, 116)
	poison_label.size = Vector2(430, 26)
	poison_label.add_theme_font_size_override("font_size", 15)
	poison_label.add_theme_color_override("font_color", Color("f46cff"))
	poison_label.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.09, 0.95))
	poison_label.add_theme_constant_override("outline_size", 5)
	poison_label.hide()
	parent.add_child(poison_label)


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
	bank.material_override = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, 2, 0.12)
	lake.add_child(bank)
	_register_quality_geometry(bank, "landmark")
	var water := MeshInstance3D.new()
	water.mesh = _round_water_mesh()
	water.scale = Vector3(pond_size.x * 0.5, 1.0, pond_size.y * 0.5)
	water.position.y = 0.035
	water.material_override = _water_surface_material()
	lake.add_child(water)
	_register_quality_geometry(water, "landmark")


func _create_river(points: PackedVector2Array, width: float) -> void:
	var river := Node3D.new()
	river.name = "River"
	world_root.add_child(river)
	var bank := MeshInstance3D.new()
	bank.mesh = _river_ribbon_mesh(points, width + 5.0, 0.012)
	bank.material_override = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, 2, 0.12)
	river.add_child(bank)
	var water := MeshInstance3D.new()
	water.mesh = _river_ribbon_mesh(points, width, 0.035)
	water.material_override = _water_surface_material()
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


func _water_surface_material() -> Material:
	if selected_map_theme == "winter":
		var ice := StandardMaterial3D.new()
		ice.albedo_color = Color("b8dae6")
		ice.roughness = 0.28
		ice.metallic_specular = 0.72
		ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice.albedo_color.a = 0.92
		return ice
	return _water_material()


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


func _volcano_shell_mesh() -> ArrayMesh:
	# Concentric irregular rings form a natural mountain silhouette and descend
	# into the crater instead of capping the volcano with a flat cylinder.
	var radii := [46.0, 40.5, 33.0, 25.0, 17.0, 10.5, 8.3]
	var heights := [0.15, 5.8, 12.8, 20.0, 26.3, 30.2, 27.3]
	var segments := 48
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring_index in radii.size():
		for segment_index in segments:
			var angle := TAU * float(segment_index) / float(segments)
			var edge_noise := sin(angle * 3.0 + ring_index * 0.83) * 0.055 + sin(angle * 7.0 - ring_index * 0.41) * 0.025
			var radius: float = radii[ring_index] * (1.0 + edge_noise)
			var height: float = heights[ring_index]
			if ring_index > 0 and ring_index < radii.size() - 1:
				height += sin(angle * 5.0 + ring_index) * 0.45
			vertices.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
			var normal := Vector3(cos(angle), 0.7, sin(angle)).normalized()
			if ring_index == radii.size() - 1:
				normal = Vector3(-cos(angle), 0.28, -sin(angle)).normalized()
			normals.append(normal)
			uvs.append(Vector2(float(segment_index) / float(segments), float(ring_index) * 0.58))
	for ring_index in radii.size() - 1:
		for segment_index in segments:
			var next_segment := (segment_index + 1) % segments
			var current := ring_index * segments + segment_index
			var next := ring_index * segments + next_segment
			var inner := (ring_index + 1) * segments + segment_index
			var inner_next := (ring_index + 1) * segments + next_segment
			indices.append_array(PackedInt32Array([current, inner, next, next, inner, inner_next]))
	# Seal the underside as well. It normally sits below the ground plane, but a
	# closed mesh avoids holes when cameras use low angles or aggressive clipping.
	var base_center := vertices.size()
	vertices.append(Vector3(0.0, -0.35, 0.0))
	normals.append(Vector3.DOWN)
	uvs.append(Vector2(0.5, 0.5))
	for segment_index in segments:
		var next_segment := (segment_index + 1) % segments
		indices.append_array(PackedInt32Array([base_center, next_segment, segment_index]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_volcano() -> void:
	var volcano := StaticBody3D.new()
	volcano.name = "CentralVolcano"
	volcano.collision_layer = 1
	volcano.collision_mask = 1
	volcano.add_to_group("world_obstacle")
	world_root.add_child(volcano)

	var mountain := MeshInstance3D.new()
	mountain.name = "TexturedVolcanoShell"
	mountain.mesh = _volcano_shell_mesh()
	var volcano_material := GENERATED_MATERIALS.theme_ground_material("volcano", 0, 0.085)
	volcano_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountain.material_override = volcano_material
	volcano.add_child(mountain)
	_register_quality_geometry(mountain, "landmark")

	# Overlapping collision tiers fill the complete mountain footprint. Their
	# radii follow the visible slope, preventing dinosaurs from entering the
	# shell while keeping physics far cheaper than a moving concave collider.
	_add_volcano_collision_tier(volcano, "BaseCollision", 45.0, 6.5)
	_add_volcano_collision_tier(volcano, "LowerSlopeCollision", 39.5, 12.0)
	_add_volcano_collision_tier(volcano, "MiddleSlopeCollision", 31.5, 19.0)
	_add_volcano_collision_tier(volcano, "UpperSlopeCollision", 23.0, 25.5)
	_add_volcano_collision_tier(volcano, "CraterCollision", 14.5, 30.0)

	var crater := MeshInstance3D.new()
	crater.name = "CraterLava"
	var crater_mesh := CylinderMesh.new()
	crater_mesh.top_radius = 8.25
	crater_mesh.bottom_radius = 8.25
	crater_mesh.height = 0.55
	crater_mesh.radial_segments = 48
	crater.mesh = crater_mesh
	crater.position.y = 27.5
	crater.material_override = _lava_material()
	volcano.add_child(crater)
	_register_quality_geometry(crater, "landmark")

	var eruption := GPUParticles3D.new()
	eruption.name = "LavaEruption"
	eruption.add_to_group("quality_particles")
	eruption.position.y = 29.0
	eruption.amount = 28
	eruption.lifetime = 2.8
	eruption.randomness = 0.7
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 4.5
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 8.0
	process.initial_velocity_max = 16.0
	process.gravity = Vector3(0.0, -7.5, 0.0)
	process.scale_min = 0.18
	process.scale_max = 0.55
	eruption.process_material = process
	var chunk := SphereMesh.new()
	chunk.radius = 0.24
	chunk.height = 0.48
	chunk.radial_segments = 6
	chunk.rings = 4
	chunk.material = _lava_material()
	eruption.draw_pass_1 = chunk
	volcano.add_child(eruption)


func _add_volcano_collision_tier(parent: StaticBody3D, tier_name: String, radius: float, height: float) -> void:
	var collision := CollisionShape3D.new()
	collision.name = tier_name
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position.y = height * 0.5
	parent.add_child(collision)


func _volcano_surface_height(point: Vector2) -> float:
	var distance := point.length()
	if distance <= 10.5:
		return 27.85
	var profile_radii := [10.5, 17.0, 25.0, 33.0, 40.5, 46.0]
	var profile_heights := [29.7, 26.3, 20.0, 12.8, 5.8, 0.08]
	for profile_index in profile_radii.size() - 1:
		if distance <= profile_radii[profile_index + 1]:
			var progress := inverse_lerp(profile_radii[profile_index], profile_radii[profile_index + 1], distance)
			return lerpf(profile_heights[profile_index], profile_heights[profile_index + 1], progress)
	return 0.08


func _volcano_lava_ribbon_mesh(points: PackedVector2Array, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for point_index in points.size():
		var previous := points[maxi(point_index - 1, 0)]
		var following := points[mini(point_index + 1, points.size() - 1)]
		var direction := (following - previous).normalized()
		var progress := float(point_index) / float(maxi(points.size() - 1, 1))
		var local_width := width * lerpf(0.46, 1.0, progress)
		var side := Vector2(-direction.y, direction.x) * local_width * 0.5
		var height := _volcano_surface_height(points[point_index]) + 0.16
		vertices.append(Vector3(points[point_index].x + side.x, height, points[point_index].y + side.y))
		vertices.append(Vector3(points[point_index].x - side.x, height, points[point_index].y - side.y))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, progress * 14.0))
		uvs.append(Vector2(1.0, progress * 14.0))
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


func _create_lava_stream(stream: Dictionary) -> void:
	var area := Area3D.new()
	area.name = "LavaStream"
	area.set_script(LAVA_STREAM_SCRIPT)
	area.set("damage_per_second", int(stream.get("damage_per_second", 12)))
	area.collision_layer = 0
	area.collision_mask = 1
	world_root.add_child(area)
	var points: PackedVector2Array = stream["points"]
	var width: float = stream["width"]
	var lava := MeshInstance3D.new()
	lava.mesh = _volcano_lava_ribbon_mesh(points, width)
	lava.material_override = _lava_material()
	area.add_child(lava)
	_register_quality_geometry(lava, "landmark")
	for point_index in points.size() - 1:
		var start := points[point_index]
		var finish := points[point_index + 1]
		var direction := finish - start
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(direction.length(), 0.8, width)
		collision.shape = shape
		var midpoint := (start + finish) * 0.5
		collision.position = Vector3(midpoint.x, 0.25, midpoint.y)
		collision.rotation.y = -direction.angle()
		area.add_child(collision)


func _lava_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

void fragment() {
	float flow = sin(UV.y * 38.0 - TIME * 3.2 + sin(UV.x * 15.0)) * 0.5 + 0.5;
	vec3 crust = vec3(0.10, 0.045, 0.025);
	vec3 hot = vec3(1.0, 0.18, 0.015);
	ALBEDO = mix(crust, hot, smoothstep(0.42, 0.72, flow));
	EMISSION = hot * (0.9 + flow * 1.8);
	ROUGHNESS = 0.62;
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
	hill.material_override = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, 0 if int(hill_position.x) % 2 == 0 else 1, 0.11)
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
		mesh_instance.material_override = GENERATED_MATERIALS.theme_ground_material(selected_map_theme, tier_index + int(formation["position"].x), 0.48) if selected_map_theme != "grassland" else GENERATED_MATERIALS.rock_material(tier_index + int(formation["position"].x), 0.48)
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
	GENERATED_MATERIALS.tint_environment(model, selected_map_theme, "plant")
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
	GENERATED_MATERIALS.tint_environment(rock, selected_map_theme, "rock")
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
	GENERATED_MATERIALS.tint_environment(model, selected_map_theme, "plant")
	_register_quality_geometry(model, "medium")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 1.2, 1.45)
	collision.shape = shape
	collision.position.y = 0.6
	log_body.add_child(collision)


func _create_vegetation(vegetation: Dictionary) -> void:
	var plant_type: String = vegetation["type"]
	var model_type := "fiddlehead" if plant_type == "poisonous" else plant_type
	var plant: Node3D = (environment_models[model_type] as PackedScene).instantiate()
	plant.name = "PoisonousPlant" if plant_type == "poisonous" else plant_type.capitalize()
	plant.position = vegetation["position"]
	plant.rotation.y = vegetation["rotation"]
	plant.scale = Vector3.ONE * float(vegetation["scale"])
	plant.add_to_group("edible_plant")
	plant.set_meta("energy_remaining", 18.0)
	if plant_type == "poisonous":
		plant.add_to_group("poisonous_plant")
		plant.set_meta("poisonous", true)
		_decorate_poisonous_plant(plant)
	world_root.add_child(plant)
	if plant_type != "poisonous":
		GENERATED_MATERIALS.tint_environment(plant, selected_map_theme, "plant")
	_register_quality_geometry(plant, "small")


func _decorate_poisonous_plant(plant: Node3D) -> void:
	# Purple foliage and luminous red toxin pods make the dangerous plant easy
	# to learn at a distance without adding another large model to the build.
	var foliage_material := StandardMaterial3D.new()
	foliage_material.albedo_color = Color("702878")
	foliage_material.roughness = 0.72
	foliage_material.emission_enabled = true
	foliage_material.emission = Color("5e1768")
	foliage_material.emission_energy_multiplier = 0.55
	for child in plant.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface_index, foliage_material)
	var pod_material := StandardMaterial3D.new()
	pod_material.albedo_color = Color("ff315f")
	pod_material.roughness = 0.28
	pod_material.emission_enabled = true
	pod_material.emission = Color("d81b62")
	pod_material.emission_energy_multiplier = 2.1
	for pod_index in 5:
		var pod := MeshInstance3D.new()
		pod.name = "ToxicPod_%d" % pod_index
		var pod_mesh := SphereMesh.new()
		pod_mesh.radius = 0.13 + float(pod_index % 2) * 0.035
		pod_mesh.height = pod_mesh.radius * 2.0
		pod_mesh.radial_segments = 10
		pod_mesh.rings = 6
		pod.mesh = pod_mesh
		var angle := TAU * float(pod_index) / 5.0
		pod.position = Vector3(cos(angle) * 0.46, 0.72 + float(pod_index % 3) * 0.22, sin(angle) * 0.46)
		pod.material_override = pod_material
		plant.add_child(pod)


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
	for item in get_tree().get_nodes_in_group("quality_particles"):
		if item is GPUParticles3D:
			(item as GPUParticles3D).amount = [8, 14, 22][performance_tier]


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
	if not is_instance_valid(player):
		return
	if multiplayer_active:
		multiplayer_client.send_action("scream")
	if str(player.get("diet")) == "herbivore":
		_show_status_message(_t("status.call_for_help"))
		var attacker = player.get("last_attacker")
		if not attacker is Node3D or not is_instance_valid(attacker) or bool(attacker.get("dead")) or player.global_position.distance_to(attacker.global_position) > SCREAM_RESPONSE_RANGE:
			attacker = null
		for candidate in get_tree().get_nodes_in_group("prey_dinosaur"):
			if not candidate is Node3D or candidate == player or not candidate.has_method("receive_help_call"):
				continue
			if str(candidate.get("dino_id")) != str(player.get("dino_id")):
				continue
			if player.global_position.distance_to(candidate.global_position) <= SCREAM_RESPONSE_RANGE:
				candidate.call("receive_help_call", player, attacker)
	else:
		_show_status_message(_t("status.fear_roar"))
		for candidate in get_tree().get_nodes_in_group("prey_dinosaur"):
			if not candidate is Node3D or candidate == player or not candidate.has_method("receive_predator_roar"):
				continue
			if player.global_position.distance_to(candidate.global_position) <= SCREAM_RESPONSE_RANGE:
				candidate.call("receive_predator_roar", player)


func _show_status_message(message: String) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = message
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(status_label) and status_label.text == message:
			status_label.text = _t("hud.poison_short") if is_instance_valid(player) and bool(player.get("poisoned")) else _t("hud.explore")
	)


func _on_poisoning_changed(active: bool) -> void:
	if is_instance_valid(poison_label):
		poison_label.visible = active
	if is_instance_valid(status_label):
		status_label.text = _t("hud.poison_short") if active else _t("hud.explore")


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if not is_instance_valid(health_bar):
		return
	health_bar.max_value = maximum_health
	health_bar.value = current_health
	health_label.text = _t("hud.health", [current_health, maximum_health])


func _on_energy_changed(current_energy: float, maximum_energy: float) -> void:
	if not is_instance_valid(energy_bar):
		return
	energy_bar.max_value = maximum_energy
	energy_bar.value = current_energy
	energy_label.text = _t("hud.energy", [int(round(current_energy / maximum_energy * 100.0))])


func _on_bonuses_changed(speed_seconds: float, strength_seconds: float) -> void:
	if not is_instance_valid(bonus_label):
		return
	var bonuses: Array[String] = []
	if speed_seconds > 0.0:
		bonuses.append(_t("hud.speed_bonus", [int(ceil(speed_seconds))]))
	if strength_seconds > 0.0:
		bonuses.append(_t("hud.strength_bonus", [int(ceil(strength_seconds))]))
	bonus_label.text = "   •   ".join(bonuses)


func _on_player_died() -> void:
	if multiplayer_active:
		multiplayer_client.disconnect_from_server()
	_show_status_message(_t("game_over.fallen"))
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
	heading.text = _t("game_over.heading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", Color("ef6655"))
	panel.add_child(heading)
	var detail := Label.new()
	detail.text = _t("game_over.detail", [selected_dino_name])
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", Color("fff2c2"))
	panel.add_child(detail)
	var return_button := Button.new()
	return_button.text = _t("game_over.return")
	return_button.custom_minimum_size = Vector2(340, 52)
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.pressed.connect(_return_to_main_menu)
	panel.add_child(return_button)
