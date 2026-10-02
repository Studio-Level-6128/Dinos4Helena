extends Node3D

const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")

var dino_id := "triceratops"
var identifier := 0
var target_position := Vector3.ZERO
var target_yaw := 0.0
var animation_player: AnimationPlayer
var current_animation := ""
var health_label: Label3D
var current_health := 100


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://config/dinosaurs.cfg") != OK:
		return
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
	_play_motion("idle")


func set_network_state(data: Dictionary, immediate := false) -> void:
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
	if is_instance_valid(health_label):
		health_label.text = "%s  %d" % [Localization.text("dino." + dino_id), current_health]


func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, minf(delta * 11.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 11.0, 1.0))


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
