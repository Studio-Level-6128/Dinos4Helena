extends "res://quests/mission_event.gd"

const MATERIALS = preload("res://scripts/generated_materials.gd")
const BASALT := Color("49444e")
const AMBER := Color("f0b84e")
const RED := Color("f45c32")
const GREEN := Color("8bd77b")
const BLUE := Color("67bdcc")
var stage := 0
var checkpoint := Vector3(0, 0.1, 72)
var clock := 0.0
var notice := ""
var notice_time := 0.0
var ui_time := 0.0
var sound: AudioStreamPlayer

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.rotation.y = PI
	checkpoint = controller.mission_player_start
	controller.player.died.connect(_on_player_died)
	if is_instance_valid(controller.status_label): controller.status_label.text = ""
	for child in controller.world_root.get_children():
		if child is WorldEnvironment: child.environment.fog_density = 0.002
	_box(Vector3(-24, 6, 117), Vector3(2, 12, 100), BASALT, true).visible = false
	_box(Vector3(24, 6, 117), Vector3(2, 12, 100), BASALT, true).visible = false
	sound = AudioStreamPlayer.new()
	sound.volume_db = -12
	add_child(sound)

func _tick(delta: float) -> void:
	clock += delta
	notice_time = maxf(0, notice_time - delta)
	ui_time -= delta

func _progress(key: String, values: Array = []) -> void:
	if ended: return
	if notice_time > 0: set_progress(notice)
	else: set_progress(Localization.text("lava." + key, values))

func _message(key: String) -> void:
	notice = Localization.text("lava." + key)
	notice_time = 2.5

func _retry(key: String) -> void:
	controller.player.global_position = checkpoint
	controller.player.velocity = Vector3.ZERO
	_restore_player()
	_message(key)
	_play("retry")

func _restore_player() -> void:
	controller.player.restore_energy(controller.player.max_energy)
	controller.player.restore_health(controller.player.max_health)

func _saved(point: Vector3) -> void:
	checkpoint = point
	_restore_player()
	_play("checkpoint")

func _on_player_died() -> void:
	fail(Localization.text("game_over.fallen"))

func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _play(clip: String) -> void:
	if ended: return
	sound.stream = load("res://assets/audio/heart_of_volcano/%s.wav" % clip)
	sound.play()

func _box(position: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	_color(visual, color)
	if solid:
		var body := StaticBody3D.new()
		body.position = position
		add_child(body)
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	else:
		visual.position = position
		add_child(visual)
	return visual

func _color(visual: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color == BASALT:
		material = MATERIALS.theme_ground_material("volcano", 0, 0.16)
	elif color in [AMBER, RED, GREEN, BLUE]:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.4
	visual.material_override = material

func _disk(position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 32
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = position
	_color(visual, color)
	add_child(visual)
	return visual

func _label(position: Vector3, key: String) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.text = Localization.text("lava." + key)
	label.font_size = 42
	label.pixel_size = 0.018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return label

func _lava(position: Vector3, size: Vector3) -> MeshInstance3D:
	var visual := _box(position, size, RED)
	visual.material_override = controller.call("_lava_material")
	return visual
