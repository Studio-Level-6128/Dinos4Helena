extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player_dino.gd")
const MINIMAP_SCRIPT := preload("res://scripts/minimap.gd")
const DINO_IDS := ["trex", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]
const MAP_HALF_SIZE := 200.0

var player: CharacterBody3D
var status_label: Label
var world_root: Node3D
var game_hud: CanvasLayer
var menu_layer: CanvasLayer
var selected_dino_name := "T-Rex"
var selected_dino_id := "trex"
var dinosaur_config := ConfigFile.new()
var seed_input: LineEdit
var map_seed := 0
var generated_ponds: Array = []
var generated_hills: Array = []
var generated_trees: Array = []
var generated_rocks: Array = []


func _ready() -> void:
	var config_error := dinosaur_config.load("res://config/dinosaurs.cfg")
	assert(config_error == OK, "Could not load dinosaur configuration")
	_create_input_actions()
	_build_main_menu()


func _start_game(dino_id: String) -> void:
	_commit_world_seed()
	selected_dino_id = dino_id
	selected_dino_name = dinosaur_config.get_value(dino_id, "display_name", dino_id.capitalize())
	menu_layer.hide()
	world_root = Node3D.new()
	world_root.name = "PrehistoricWorld"
	add_child(world_root)
	_generate_world_layout()
	_build_environment()
	_build_ambient_audio()
	_build_landscape()
	_build_player(dino_id)
	_build_hud()


func _return_to_main_menu() -> void:
	if is_instance_valid(game_hud):
		game_hud.queue_free()
	if is_instance_valid(world_root):
		world_root.queue_free()
	player = null
	status_label = null
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

	var title := Label.new()
	title.text = "DINOS4HELENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-440, 34)
	title.size = Vector2(880, 78)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("fff2c2"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Helena's Dino game - made by dad"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-350, 108)
	subtitle.size = Vector2(700, 40)
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Color("f5dc9d"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(subtitle)

	var prompt := Label.new()
	prompt.text = "CHOOSE YOUR DINOSAUR"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.position = Vector2(-260, 169)
	prompt.size = Vector2(520, 42)
	prompt.add_theme_font_size_override("font_size", 21)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(prompt)

	var seed_row := HBoxContainer.new()
	seed_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	seed_row.position = Vector2(-225, 210)
	seed_row.size = Vector2(450, 40)
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 10)
	root.add_child(seed_row)

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

	var cards := HBoxContainer.new()
	cards.name = "DinosaurCards"
	cards.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cards.position = Vector2(-590, 258)
	cards.size = Vector2(1180, 360)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 12)
	root.add_child(cards)

	for dino_id in DINO_IDS:
		var display_name: String = dinosaur_config.get_value(dino_id, "display_name", dino_id.capitalize())
		cards.add_child(_create_dino_card(dino_id, display_name))

	var footer := Label.new()
	footer.text = "Select a dinosaur to begin your prehistoric adventure"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-350, -54)
	footer.size = Vector2(700, 32)
	footer.add_theme_font_size_override("font_size", 17)
	footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	root.add_child(footer)


func _create_dino_card(dino_id: String, display_name: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(184, 338)
	panel.add_theme_stylebox_override("panel", _card_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var portrait := TextureButton.new()
	portrait.custom_minimum_size = Vector2(168, 158)
	portrait.texture_normal = load("res://assets/ui/menu/%s.png" % dino_id)
	portrait.ignore_texture_size = true
	portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	portrait.tooltip_text = "Play as " + display_name
	portrait.pressed.connect(_start_game.bind(dino_id))
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.text = display_name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17 if display_name.length() < 13 else 14)
	name_label.add_theme_color_override("font_color", Color("fff2c2"))
	column.add_child(name_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 2)
	column.add_child(stats)
	_add_stat(stats, "SPEED", "%.1f" % float(dinosaur_config.get_value(dino_id, "run_speed", 0.0)))
	_add_stat(stats, "STRENGTH", "%d/10" % int(dinosaur_config.get_value(dino_id, "strength", 0)))
	_add_stat(stats, "CAN JUMP", "YES" if dinosaur_config.get_value(dino_id, "can_jump", false) else "NO")
	_add_stat(stats, "HEALTH", str(int(dinosaur_config.get_value(dino_id, "max_health", 0))))

	var play := Button.new()
	play.text = "PLAY"
	play.focus_mode = Control.FOCUS_NONE
	play.add_theme_font_size_override("font_size", 16)
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
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.68))
	parent.add_child(name_label)
	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 12)
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
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("fff1c4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	world_root.add_child(sun)


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
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var occupied: Array = []

	for index in rng.randi_range(4, 7):
		var pond_size := Vector2(rng.randf_range(14.0, 30.0), rng.randf_range(10.0, 22.0))
		var pond_radius := maxf(pond_size.x, pond_size.y) * 0.6
		var pond_position := _find_world_position(rng, pond_radius, occupied, 8.0)
		generated_ponds.append({"position": Vector3(pond_position.x, 0.025, pond_position.y), "size": pond_size})
		occupied.append({"position": pond_position, "radius": pond_radius})

	for index in rng.randi_range(9, 14):
		var hill_scale := Vector3(rng.randf_range(9.0, 20.0), rng.randf_range(3.5, 8.0), rng.randf_range(8.0, 18.0))
		var hill_radius := maxf(hill_scale.x, hill_scale.z) * 0.82
		var hill_position := _find_world_position(rng, hill_radius, occupied, 7.0)
		generated_hills.append({"position": Vector3(hill_position.x, hill_scale.y * 0.48, hill_position.y), "scale": hill_scale})
		occupied.append({"position": hill_position, "radius": hill_radius})

	for index in rng.randi_range(75, 105):
		var tree_scale := rng.randf_range(0.75, 1.45)
		var tree_position := _find_world_position(rng, 1.6 * tree_scale, occupied, 2.5)
		generated_trees.append({"position": Vector3(tree_position.x, 0.0, tree_position.y), "scale": tree_scale})
		occupied.append({"position": tree_position, "radius": 0.55 * tree_scale})

	for index in rng.randi_range(28, 45):
		var rock_scale := rng.randf_range(0.65, 1.65)
		var rock_position := _find_world_position(rng, 1.1 * rock_scale, occupied, 1.5)
		generated_rocks.append({"position": Vector3(rock_position.x, 0.0, rock_position.y), "scale": rock_scale})
		occupied.append({"position": rock_position, "radius": 0.9 * rock_scale})


func _find_world_position(rng: RandomNumberGenerator, radius: float, occupied: Array, spacing: float) -> Vector2:
	var edge_padding := radius + 8.0
	for attempt in 100:
		var candidate := Vector2(
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding),
			rng.randf_range(-MAP_HALF_SIZE + edge_padding, MAP_HALF_SIZE - edge_padding)
		)
		if candidate.length() < 28.0 + radius:
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


func _build_landscape() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)

	var ground_mesh := MeshInstance3D.new()
	var ground_box := BoxMesh.new()
	ground_box.size = Vector3(MAP_HALF_SIZE * 2.0, 1.0, MAP_HALF_SIZE * 2.0)
	ground_mesh.mesh = ground_box
	ground_mesh.position.y = -0.5
	ground_mesh.material_override = _material(Color("668b49"), 0.95)
	ground.add_child(ground_mesh)

	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(MAP_HALF_SIZE * 2.0, 1.0, MAP_HALF_SIZE * 2.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.5
	ground.add_child(ground_collision)
	_build_map_boundary()

	for pond in generated_ponds:
		_create_pond(pond["position"], pond["size"])
	for hill in generated_hills:
		_create_hill(hill["position"], hill["scale"])
	for tree in generated_trees:
		_create_tree(tree["position"], tree["scale"])
	for rock in generated_rocks:
		_create_rock(rock["position"], rock["scale"])


func _build_player(dino_id: String) -> void:
	player = CharacterBody3D.new()
	player.name = "PlayerDinosaur"
	player.set_script(PLAYER_SCRIPT)
	player.set("dino_id", dino_id)
	player.position = Vector3(0.0, 0.1, 5.0)
	world_root.add_child(player)
	player.screamed.connect(_on_dino_screamed)


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
	_add_action_button(left_panel, "ATTACK", "attack", Vector2(46, 118), Vector2(110, 54))
	_add_action_button(left_panel, "SCREAM", "scream", Vector2(162, 118), Vector2(110, 54))

	var action_hint := Label.new()
	action_hint.text = "LEFT HAND • ACTIONS"
	action_hint.position = Vector2(4, 18)
	action_hint.add_theme_font_size_override("font_size", 14)
	action_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	left_panel.add_child(action_hint)

	var right_panel := Control.new()
	right_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_panel.position = Vector2(-286, -222)
	right_panel.size = Vector2(268, 204)
	root.add_child(right_panel)
	_add_action_button(right_panel, "", "move_forward", Vector2(94, 42), Vector2(72, 58))
	_add_action_button(right_panel, "", "move_left", Vector2(18, 104), Vector2(72, 58))
	_add_action_button(right_panel, "", "move_back", Vector2(94, 104), Vector2(72, 58))
	_add_action_button(right_panel, "", "move_right", Vector2(170, 104), Vector2(72, 58))

	var move_hint := Label.new()
	move_hint.text = "RIGHT HAND • MOVE"
	move_hint.position = Vector2(59, 8)
	move_hint.add_theme_font_size_override("font_size", 14)
	move_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	right_panel.add_child(move_hint)

	var keyboard_hint := Label.new()
	keyboard_hint.text = "Keyboard: WASD / arrows • Space jump • Shift run • C duck • F attack • R scream"
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
	minimap.call("setup", player, MAP_HALF_SIZE, {
		"ponds": generated_ponds,
		"hills": generated_hills,
		"trees": generated_trees,
		"rocks": generated_rocks
	})


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
		"jump": "jump", "run": "run", "duck": "duck", "attack": "attack", "scream": "scream"
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


func _create_pond(pond_position: Vector3, pond_size: Vector2) -> void:
	var pond := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = pond_size
	pond.mesh = mesh
	pond.position = pond_position
	var water := _material(Color(0.16, 0.49, 0.66, 0.78), 0.2)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.1
	pond.material_override = water
	world_root.add_child(pond)


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
	hill.material_override = _material(Color("58763e"), 1.0)
	hill_body.add_child(hill)

	var collision := CollisionShape3D.new()
	collision.shape = _ellipsoid_shape(hill_scale)
	hill_body.add_child(collision)


func _create_tree(tree_position: Vector3, tree_scale: float) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = tree_position
	tree.scale = Vector3.ONE * tree_scale
	world_root.add_child(tree)

	var tree_body := StaticBody3D.new()
	tree_body.name = "TreeObstacle"
	tree_body.add_to_group("world_obstacle")
	tree.add_child(tree_body)
	var tree_collision := CollisionShape3D.new()
	var tree_shape := CylinderShape3D.new()
	tree_shape.radius = 0.43
	tree_shape.height = 3.8
	tree_collision.shape = tree_shape
	tree_collision.position.y = 1.9
	tree_body.add_child(tree_collision)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.43
	trunk_mesh.height = 3.8
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.9
	trunk.material_override = _material(Color("6a4c2f"), 1.0)
	tree.add_child(trunk)

	for layer_index in 3:
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = 2.0 - float(layer_index) * 0.28
		crown_mesh.height = 2.4
		crown.mesh = crown_mesh
		crown.position.y = 3.7 + float(layer_index) * 1.15
		crown.material_override = _material(Color("315f38").lightened(float(layer_index) * 0.06), 1.0)
		tree.add_child(crown)


func _create_rock(rock_position: Vector3, rock_scale: float) -> void:
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockObstacle"
	rock_body.position = rock_position + Vector3(0, 0.35 * rock_scale, 0)
	rock_body.rotation_degrees.y = rock_position.x * 7.0
	rock_body.add_to_group("world_obstacle")
	world_root.add_child(rock_body)

	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.2
	mesh.radial_segments = 10
	mesh.rings = 6
	rock.mesh = mesh
	var rock_visual_scale := Vector3(1.25, 0.65, 0.9) * rock_scale
	rock.scale = rock_visual_scale
	rock.material_override = _material(Color("77796e"), 1.0)
	rock_body.add_child(rock)

	var collision := CollisionShape3D.new()
	collision.shape = _ellipsoid_shape(Vector3(0.8 * rock_visual_scale.x, 0.6 * rock_visual_scale.y, 0.8 * rock_visual_scale.z))
	rock_body.add_child(collision)


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


func _create_input_actions() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("run", [KEY_SHIFT])
	_add_key_action("duck", [KEY_C, KEY_CTRL])
	_add_key_action("attack", [KEY_F])
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
	status_label.text = "R O A R !"
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: status_label.text = "Explore the valley")
