extends CharacterBody3D

signal screamed

const WALK_SPEED := 4.0
const RUN_SPEED := 8.0
const DUCK_SPEED := 2.2
const JUMP_VELOCITY := 7.0
const TURN_SPEED := 2.4
const DINO_CONFIGS := {
	"trex": {
		"path": "res://assets/models/trex/Trex.fbx", "scale": 0.20,
		"radius": 0.95, "height": 3.8, "camera_y": 3.4, "camera_length": 9.0, "speed": 1.0
	},
	"triceratops": {
		"path": "res://assets/models/dinosaurs/Triceratops.fbx", "scale": 0.20,
		"radius": 1.0, "height": 2.8, "camera_y": 2.8, "camera_length": 9.0, "speed": 0.9
	},
	"stegosaurus": {
		"path": "res://assets/models/dinosaurs/Stegosaurus.fbx", "scale": 0.20,
		"radius": 1.0, "height": 2.8, "camera_y": 2.9, "camera_length": 9.5, "speed": 0.86
	},
	"velociraptor": {
		"path": "res://assets/models/dinosaurs/Velociraptor.fbx", "scale": 0.22,
		"radius": 0.55, "height": 2.2, "camera_y": 2.3, "camera_length": 7.0, "speed": 1.28
	},
	"parasaurolophus": {
		"path": "res://assets/models/dinosaurs/Parasaurolophus.fbx", "scale": 0.20,
		"radius": 0.8, "height": 3.2, "camera_y": 3.1, "camera_length": 8.5, "speed": 1.0
	},
	"apatosaurus": {
		"path": "res://assets/models/dinosaurs/Apatosaurus.fbx", "scale": 0.14,
		"radius": 1.25, "height": 5.0, "camera_y": 4.8, "camera_length": 12.0, "speed": 0.72
	}
}

var dino_id := "trex"
var dino_config: Dictionary
var model_scale := 0.20
var movement_scale := 1.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model_root: Node3D
var animation_player: AnimationPlayer
var roar_audio: AudioStreamPlayer3D
var current_animation := ""
var mobile_actions: Dictionary = {}
var attack_time := 0.0
var scream_time := 0.0
var jump_was_pressed := false


func _ready() -> void:
	dino_config = DINO_CONFIGS.get(dino_id, DINO_CONFIGS.trex)
	model_scale = dino_config.scale
	movement_scale = dino_config.speed
	_build_collision()
	_build_model()
	_build_follow_camera()
	_build_roar_audio()


func _physics_process(delta: float) -> void:
	attack_time = maxf(attack_time - delta, 0.0)
	scream_time = maxf(scream_time - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var wants_jump := _action_pressed("jump")
	if wants_jump and not jump_was_pressed and is_on_floor() and attack_time <= 0.0:
		velocity.y = JUMP_VELOCITY
	jump_was_pressed = wants_jump

	if _action_just_pressed("attack") and attack_time <= 0.0:
		attack_time = 0.85
		_play_animation("attack", true)

	if _action_just_pressed("scream") and scream_time <= 0.0:
		_start_scream()

	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	throttle += _float_action("move_forward") - _float_action("move_back")
	throttle = clampf(throttle, -1.0, 1.0)
	var steering := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	steering += _float_action("move_left") - _float_action("move_right")
	steering = clampf(steering, -1.0, 1.0)

	var ducking := _action_pressed("duck")
	var running := _action_pressed("run") and not ducking
	var speed := (DUCK_SPEED if ducking else (RUN_SPEED if running else WALK_SPEED)) * movement_scale

	if attack_time <= 0.0 and scream_time <= 0.0:
		rotation.y += steering * TURN_SPEED * delta

	if not is_zero_approx(throttle) and attack_time <= 0.0 and scream_time <= 0.0:
		var forward := -global_transform.basis.z.normalized()
		var reverse_factor := 0.62 if throttle < 0.0 else 1.0
		velocity.x = forward.x * throttle * speed * reverse_factor
		velocity.z = forward.z * throttle * speed * reverse_factor
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 14.0 * delta)

	var target_y_scale := model_scale * (0.68 if ducking else 1.0)
	model_root.scale.y = lerpf(model_root.scale.y, target_y_scale, 10.0 * delta)
	var roar_tilt := deg_to_rad(-10.0 + sin(scream_time * 20.0) * 2.0) if scream_time > 0.0 else 0.0
	model_root.rotation.x = lerpf(model_root.rotation.x, roar_tilt, 9.0 * delta)
	model_root.position.y = lerpf(model_root.position.y, 0.18 if scream_time > 0.0 else 0.0, 8.0 * delta)
	move_and_slide()
	_update_animation(not is_zero_approx(throttle), running, ducking)


func set_mobile_action(action: StringName, pressed: bool) -> void:
	var was_pressed: bool = mobile_actions.get(action, false)
	mobile_actions[action] = pressed
	if pressed and not was_pressed and action == "attack":
		attack_time = 0.85
		_play_animation("attack", true)
	if pressed and not was_pressed and action == "scream" and scream_time <= 0.0:
		_start_scream()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = dino_config.radius
	shape.height = dino_config.height
	collision.shape = shape
	collision.position.y = float(dino_config.height) * 0.5
	add_child(collision)


func _build_model() -> void:
	var model_scene := load(dino_config.path) as PackedScene
	model_root = model_scene.instantiate()
	model_root.name = "DinosaurModel"
	model_root.scale = Vector3.ONE * model_scale
	# The source FBX faces +Z. Godot gameplay convention uses -Z as forward.
	model_root.rotation.y = PI
	add_child(model_root)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		for key in ["idle", "walk", "run"]:
			var animation_name := _find_animation(key)
			if animation_name != "":
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		_play_animation("idle", true)


func _build_follow_camera() -> void:
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = Vector3(0.0, dino_config.camera_y, 0.0)
	pivot.rotation_degrees.x = -16.0
	add_child(pivot)

	var spring_arm := SpringArm3D.new()
	spring_arm.spring_length = dino_config.camera_length
	spring_arm.margin = 0.25
	spring_arm.collision_mask = 1
	pivot.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 64.0
	spring_arm.add_child(camera)


func _build_roar_audio() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var duration := 1.15
	var sample_count := int(stream.mix_rate * duration)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(stream.mix_rate)
		var envelope := sin(PI * time / duration)
		var frequency := 54.0 + sin(time * 17.0) * 9.0
		var growl := sin(TAU * frequency * time) + 0.45 * sin(TAU * frequency * 1.91 * time)
		growl += 0.18 * sin(TAU * 31.0 * time + sin(time * 43.0))
		var sample := int(clampf(growl * envelope * 10500.0, -32767.0, 32767.0))
		samples.encode_s16(index * 2, sample)
	stream.data = samples
	roar_audio = AudioStreamPlayer3D.new()
	roar_audio.stream = stream
	roar_audio.unit_size = 18.0
	roar_audio.max_distance = 60.0
	add_child(roar_audio)


func _update_animation(moving: bool, running: bool, ducking: bool) -> void:
	if animation_player == null or attack_time > 0.0 or scream_time > 0.0:
		return
	if not is_on_floor():
		_play_animation("jump")
	elif moving:
		_play_animation("walk" if ducking else ("run" if running else "walk"))
	else:
		_play_animation("idle")
	animation_player.speed_scale = 0.65 if ducking else (0.75 if scream_time > 0.0 else 1.0)


func _start_scream() -> void:
	scream_time = 1.2
	_play_animation("idle", true)
	if roar_audio:
		roar_audio.play()
	_spawn_roar_wave()
	screamed.emit()


func _spawn_roar_wave() -> void:
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 20
	mesh.ring_segments = 8
	wave.mesh = mesh
	wave.position = Vector3(0.0, 2.7, -1.1)
	wave.rotation_degrees.x = 90.0
	wave.scale = Vector3.ONE * 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.82, 0.3, 0.85)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.42, 0.08)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = material
	add_child(wave)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * 4.0, 0.9).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(wave, "transparency", 1.0, 0.9)
	tween.chain().tween_callback(wave.queue_free)


func _play_animation(keyword: String, force := false) -> void:
	if animation_player == null:
		return
	var animation_name := _find_animation(keyword)
	if animation_name == "" or (animation_name == current_animation and not force):
		return
	current_animation = animation_name
	animation_player.play(animation_name, 0.18)


func _find_animation(keyword: String) -> String:
	if animation_player == null:
		return ""
	for animation_name in animation_player.get_animation_list():
		if keyword.to_lower() in animation_name.to_lower():
			return animation_name
	return ""


func _action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action) or mobile_actions.get(action, false)


func _action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func _float_action(action: StringName) -> float:
	return 1.0 if mobile_actions.get(action, false) else 0.0
