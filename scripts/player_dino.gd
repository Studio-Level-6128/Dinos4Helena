extends CharacterBody3D

signal screamed
signal health_changed(current_health: int, maximum_health: int)

var dino_id := "trex"
var dino_config := ConfigFile.new()
var model_scale := 0.20
var walk_speed := 4.0
var run_speed := 8.0
var duck_speed := 2.2
var turn_speed := 2.4
var strength := 1
var can_jump := true
var jump_velocity := 7.0
var max_health := 100
var health := 100
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model_root: Node3D
var animation_player: AnimationPlayer
var action_audio: AudioStreamPlayer3D
var movement_audio: AudioStreamPlayer3D
var vocal_audio: AudioStreamPlayer3D
var audio_streams: Dictionary = {}
var current_animation := ""
var mobile_actions: Dictionary = {}
var attack_time := 0.0
var scream_time := 0.0
var footstep_time := 0.0
var jump_was_pressed := false
var duck_was_pressed := false


func _ready() -> void:
	var config_error := dino_config.load("res://config/dinosaurs.cfg")
	assert(config_error == OK, "Could not load dinosaur configuration")
	model_scale = dino_config.get_value(dino_id, "model_scale", 0.20)
	walk_speed = dino_config.get_value(dino_id, "walk_speed", 4.0)
	run_speed = dino_config.get_value(dino_id, "run_speed", 8.0)
	duck_speed = dino_config.get_value(dino_id, "duck_speed", 2.2)
	turn_speed = dino_config.get_value(dino_id, "turn_speed", 2.4)
	strength = dino_config.get_value(dino_id, "strength", 1)
	can_jump = dino_config.get_value(dino_id, "can_jump", true)
	jump_velocity = dino_config.get_value(dino_id, "jump_velocity", 7.0)
	max_health = dino_config.get_value(dino_id, "max_health", 100)
	health = max_health
	_build_collision()
	_build_model()
	_build_follow_camera()
	_build_audio()


func _physics_process(delta: float) -> void:
	attack_time = maxf(attack_time - delta, 0.0)
	scream_time = maxf(scream_time - delta, 0.0)
	footstep_time = maxf(footstep_time - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var wants_jump := _action_pressed("jump")
	if wants_jump and not jump_was_pressed and can_jump and is_on_floor() and attack_time <= 0.0:
		velocity.y = jump_velocity
		_play_action_sound("jump")
	jump_was_pressed = wants_jump

	if _action_just_pressed("attack") and attack_time <= 0.0:
		_start_attack()

	if _action_just_pressed("scream") and scream_time <= 0.0:
		_start_scream()

	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	throttle += _float_action("move_forward") - _float_action("move_back")
	throttle = clampf(throttle, -1.0, 1.0)
	var steering := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	steering += _float_action("move_left") - _float_action("move_right")
	steering = clampf(steering, -1.0, 1.0)

	var ducking := _action_pressed("duck")
	if ducking and not duck_was_pressed:
		_play_action_sound("duck")
	duck_was_pressed = ducking
	var running := _action_pressed("run") and not ducking
	var speed := duck_speed if ducking else (run_speed if running else walk_speed)

	if attack_time <= 0.0 and scream_time <= 0.0:
		rotation.y += steering * turn_speed * delta

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
	var moving := not is_zero_approx(throttle) and attack_time <= 0.0 and scream_time <= 0.0
	_update_footsteps(moving and is_on_floor(), running, ducking)
	_update_animation(moving, running, ducking)


func set_mobile_action(action: StringName, pressed: bool) -> void:
	var was_pressed: bool = mobile_actions.get(action, false)
	mobile_actions[action] = pressed
	if pressed and not was_pressed and action == "attack" and attack_time <= 0.0:
		_start_attack()
	if pressed and not was_pressed and action == "scream" and scream_time <= 0.0:
		_start_scream()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = dino_config.get_value(dino_id, "collision_radius", 0.95)
	shape.height = dino_config.get_value(dino_id, "collision_height", 3.8)
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	add_child(collision)


func _build_model() -> void:
	var model_path: String = dino_config.get_value(dino_id, "model_path", "res://assets/models/trex/Trex.fbx")
	var model_scene := load(model_path) as PackedScene
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
	pivot.position = Vector3(0.0, dino_config.get_value(dino_id, "camera_height", 3.4), 0.0)
	pivot.rotation_degrees.x = -16.0
	add_child(pivot)

	var spring_arm := SpringArm3D.new()
	spring_arm.spring_length = dino_config.get_value(dino_id, "camera_distance", 9.0)
	spring_arm.margin = 0.25
	spring_arm.collision_mask = 1
	pivot.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 64.0
	spring_arm.add_child(camera)


func _build_audio() -> void:
	for sound_name in ["scream", "walk", "run", "jump", "duck", "attack", "hurt"]:
		var path := "res://assets/audio/dinosaurs/%s/%s.mp3" % [dino_id, sound_name]
		if ResourceLoader.exists(path):
			audio_streams[sound_name] = load(path)

	action_audio = _create_audio_player("ActionAudio", 18.0, 55.0, -2.0)
	movement_audio = _create_audio_player("MovementAudio", 12.0, 45.0, -5.0)
	vocal_audio = _create_audio_player("VocalAudio", 24.0, 80.0, 0.0)


func _create_audio_player(player_name: String, unit_size: float, max_distance: float, volume_db: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = player_name
	audio.unit_size = unit_size
	audio.max_distance = max_distance
	audio.volume_db = volume_db
	add_child(audio)
	return audio


func _play_action_sound(sound_name: String) -> void:
	var stream: AudioStream = audio_streams.get(sound_name)
	if stream == null:
		return
	var audio := vocal_audio if sound_name in ["scream", "hurt"] else action_audio
	audio.stream = stream
	audio.play()


func _update_footsteps(moving: bool, running: bool, ducking: bool) -> void:
	if not moving:
		footstep_time = 0.0
		return
	if footstep_time > 0.0:
		return
	var sound_name := "run" if running and not ducking else "walk"
	var stream: AudioStream = audio_streams.get(sound_name)
	if stream:
		movement_audio.stream = stream
		movement_audio.play()
	var body_size_factor := clampf(model_scale / 0.20, 0.8, 1.65)
	var clip_duration := stream.get_length() if stream else 0.8
	var minimum_interval := 0.34 if running and not ducking else 0.58
	footstep_time = maxf(clip_duration * 0.92, minimum_interval) * body_size_factor


func _start_attack() -> void:
	attack_time = 0.85
	_play_animation("attack", true)
	_play_action_sound("attack")


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
	_play_action_sound("scream")
	_spawn_roar_wave()
	screamed.emit()


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	_play_action_sound("hurt")
	health_changed.emit(health, max_health)


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
