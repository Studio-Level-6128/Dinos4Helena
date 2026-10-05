extends CharacterBody3D

signal damage_requested(player_id: int, npc_id: int, damage: int)

const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")
const HUMAN_MARKER_SCRIPT := preload("res://scripts/human_marker.gd")

var dino_id := "triceratops"
var identifier := 0
var target_position := Vector3.ZERO
var target_yaw := 0.0
var animation_player: AnimationPlayer
var current_animation := ""
var health_label: Label3D
var current_health := 100
var player_name := "Player"
var player_color := "#6ea8fe"
var identity_marker: Node3D
var diet := "herbivore"
var health := 100
var max_health := 100
var strength := 5
var collision_radius := 0.8
var collision_height := 2.8
var dead := false
var ai_target := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://config/dinosaurs.cfg") != OK:
		return
	diet = str(config.get_value(dino_id, "diet", "herbivore"))
	max_health = int(config.get_value(dino_id, "max_health", 100))
	strength = int(config.get_value(dino_id, "strength", 5))
	collision_radius = float(config.get_value(dino_id, "collision_radius", 0.8))
	collision_height = float(config.get_value(dino_id, "collision_height", 2.8))
	var scene := load(str(config.get_value(dino_id, "model_path", ""))) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	model.name = "RemoteModel"
	model.scale = Vector3.ONE * float(config.get_value(dino_id, "model_scale", 0.2))
	model.rotation.y = PI
	add_child(model)
	GENERATED_MATERIALS.apply_dino_skin(model, posmod(identifier, GENERATED_MATERIALS.dino_variant_count()), dino_id)
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var label := Label3D.new()
	label.name = "RemoteName"
	label.text = Localization.text(str(config.get_value(dino_id, "display_name_key", "dino." + dino_id)))
	label.position.y = float(config.get_value(dino_id, "collision_height", 2.8)) + 1.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 26
	label.pixel_size = 0.01
	label.outline_size = 6
	label.modulate = Color("fff2c2")
	add_child(label)
	health_label = label
	identity_marker = HUMAN_MARKER_SCRIPT.new()
	identity_marker.position.y = float(config.get_value(dino_id, "collision_height", 2.8)) + 1.7
	add_child(identity_marker)
	_play_motion("idle")


func set_network_state(data: Dictionary, immediate := false) -> void:
	player_name = str(data.get("name", player_name))
	var incoming_color := str(data.get("color", player_color))
	if incoming_color != player_color:
		player_color = incoming_color
		identity_marker.call("set_color", player_color)
	if is_instance_valid(health_label):
		health_label.modulate = Color(player_color)
	target_position = Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.1)), float(data.get("z", 0.0)))
	target_yaw = float(data.get("yaw", 0.0))
	if immediate:
		global_position = target_position
		rotation.y = target_yaw
	_play_motion(str(data.get("animation", "idle")))
	if is_instance_valid(health_label):
		set_health(int(data.get("health", current_health)))


func set_health(value: int) -> void:
	current_health = value
	health = value
	dead = value <= 0
	if is_instance_valid(health_label):
		health_label.text = "%s  %d" % [player_name, current_health]


func _process(delta: float) -> void:
	velocity = (target_position - global_position) / maxf(delta, 0.001)
	global_position = global_position.lerp(target_position, minf(delta * 11.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 11.0, 1.0))


func set_ai_target(enabled: bool) -> void:
	ai_target = enabled
	if enabled:
		add_to_group("player_dinosaur")
		if diet == "carnivore":
			add_to_group("player_hunter")
	else:
		remove_from_group("player_dinosaur")
		remove_from_group("player_hunter")


func take_damage(amount: int, _from_npc := false, attacker: Node3D = null) -> void:
	if ai_target and amount > 0 and is_instance_valid(attacker):
		damage_requested.emit(identifier, int(attacker.get("multiplayer_npc_id")), amount)


func _play_motion(motion: String) -> void:
	if animation_player == null:
		return
	var wanted := "idle" if motion in ["eat", "scream"] else motion
	for animation_name in animation_player.get_animation_list():
		if wanted in animation_name.to_lower():
			if current_animation != animation_name:
				current_animation = animation_name
				animation_player.play(animation_name, 0.16)
			animation_player.speed_scale = 0.58 if motion == "eat" else 1.0
			return
