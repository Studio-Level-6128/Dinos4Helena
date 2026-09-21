extends CharacterBody3D

const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")

signal screamed
signal health_changed(current_health: int, maximum_health: int)
signal energy_changed(current_energy: float, maximum_energy: float)
signal bonuses_changed(speed_seconds: float, strength_seconds: float)
signal died
signal status_requested(message: String)

var dino_id := "trex"
var texture_variant := 0
var dino_config := ConfigFile.new()
var model_scale := 0.20
var walk_speed := 4.0
var run_speed := 8.0
var duck_speed := 2.2
var turn_speed := 2.4
var strength := 1
var base_walk_speed := 4.0
var base_run_speed := 8.0
var base_duck_speed := 2.2
var base_strength := 1
var speed_bonus_time := 0.0
var strength_bonus_time := 0.0
var token_bonus_duration := 30.0
var token_health_restore := 40
var can_jump := true
var jump_velocity := 7.0
var max_health := 100
var health := 100
var collision_radius := 0.95
var diet := "herbivore"
var max_energy := 100.0
var energy := 100.0
var walk_energy_cost := 0.18
var run_energy_cost := 0.70
var duck_energy_cost := 0.10
var jump_energy_cost := 5.0
var attack_energy_cost := 9.0
var scream_energy_cost := 3.0
var starvation_damage_per_second := 2.5
var plant_energy_per_second := 7.0
var meat_energy_per_second := 22.0
var food_reach := 4.5
var starvation_damage_accumulator := 0.0
var eating_target: Node3D
var eating_active := false
var eating_pose_time := 0.0
var dead := false
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
var eat_was_pressed := false


func _ready() -> void:
	var config_error := dino_config.load("res://config/dinosaurs.cfg")
	assert(config_error == OK, "Could not load dinosaur configuration")
	model_scale = dino_config.get_value(dino_id, "model_scale", 0.20)
	walk_speed = dino_config.get_value(dino_id, "walk_speed", 4.0)
	run_speed = dino_config.get_value(dino_id, "run_speed", 8.0)
	duck_speed = dino_config.get_value(dino_id, "duck_speed", 2.2)
	turn_speed = dino_config.get_value(dino_id, "turn_speed", 2.4)
	strength = dino_config.get_value(dino_id, "strength", 1)
	base_walk_speed = walk_speed
	base_run_speed = run_speed
	base_duck_speed = duck_speed
	base_strength = strength
	token_bonus_duration = dino_config.get_value("tokens", "bonus_duration_seconds", 30.0)
	token_health_restore = dino_config.get_value("tokens", "health_restore", 40)
	can_jump = dino_config.get_value(dino_id, "can_jump", true)
	jump_velocity = dino_config.get_value(dino_id, "jump_velocity", 7.0)
	max_health = dino_config.get_value(dino_id, "max_health", 100)
	health = max_health
	diet = dino_config.get_value(dino_id, "diet", "herbivore")
	if diet == "carnivore":
		add_to_group("player_hunter")
	max_energy = dino_config.get_value("energy", "max_energy", 100.0)
	energy = max_energy
	walk_energy_cost = dino_config.get_value("energy", "walk_cost_per_second", 0.18)
	run_energy_cost = dino_config.get_value("energy", "run_cost_per_second", 0.70)
	duck_energy_cost = dino_config.get_value("energy", "duck_cost_per_second", 0.10)
	jump_energy_cost = dino_config.get_value("energy", "jump_cost", 5.0)
	attack_energy_cost = dino_config.get_value("energy", "attack_cost", 9.0)
	scream_energy_cost = dino_config.get_value("energy", "scream_cost", 3.0)
	starvation_damage_per_second = dino_config.get_value("energy", "starvation_damage_per_second", 2.5)
	plant_energy_per_second = dino_config.get_value("energy", "plant_energy_per_second", 7.0)
	meat_energy_per_second = dino_config.get_value("energy", "meat_energy_per_second", 22.0)
	food_reach = dino_config.get_value("energy", "food_reach", 4.5)
	collision_radius = dino_config.get_value(dino_id, "collision_radius", 0.95)
	add_to_group("player_dinosaur")
	_build_collision()
	_build_model()
	_build_follow_camera()
	_build_audio()


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	_update_powerups(delta)
	attack_time = maxf(attack_time - delta, 0.0)
	scream_time = maxf(scream_time - delta, 0.0)
	footstep_time = maxf(footstep_time - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta

	var wants_jump := _action_pressed("jump")
	if wants_jump and not jump_was_pressed and can_jump and is_on_floor() and attack_time <= 0.0:
		velocity.y = jump_velocity
		_spend_energy(jump_energy_cost)
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
	var wants_eat := _action_pressed("eat")
	_update_eating(delta, wants_eat)
	eat_was_pressed = wants_eat
	if eating_active:
		throttle = 0.0
		eating_pose_time += delta
	else:
		eating_pose_time = 0.0

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

	var target_y_scale := model_scale * (0.68 if ducking else (0.88 if eating_active else 1.0))
	model_root.scale.y = lerpf(model_root.scale.y, target_y_scale, 10.0 * delta)
	var pose_tilt := 0.0
	var pose_height := 0.0
	if scream_time > 0.0:
		pose_tilt = deg_to_rad(-10.0 + sin(scream_time * 20.0) * 2.0)
		pose_height = 0.18
	elif eating_active:
		pose_tilt = deg_to_rad(-18.0 + sin(eating_pose_time * 8.0) * 3.5)
		pose_height = -0.08 + sin(eating_pose_time * 8.0) * 0.025
	model_root.rotation.x = lerpf(model_root.rotation.x, pose_tilt, 9.0 * delta)
	model_root.position.y = lerpf(model_root.position.y, pose_height, 8.0 * delta)
	move_and_slide()
	var moving := not is_zero_approx(throttle) and attack_time <= 0.0 and scream_time <= 0.0
	_update_energy(delta, moving, running, ducking)
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
	shape.radius = collision_radius
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
	GENERATED_MATERIALS.apply_dino_skin(model_root, texture_variant)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		for key in ["idle", "walk", "run"]:
			var animation_name := _find_animation(key)
			if animation_name != "":
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		var death_animation := _find_animation("death")
		if death_animation != "":
			animation_player.get_animation(death_animation).loop_mode = Animation.LOOP_NONE
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
	_spend_energy(attack_energy_cost)
	_play_animation("attack", true)
	_play_action_sound("attack")
	get_tree().create_timer(0.24).timeout.connect(_perform_attack_hit)


func _perform_attack_hit() -> void:
	if dead:
		return
	var forward := -global_transform.basis.z.normalized()
	var closest_target: Node3D
	var closest_distance := collision_radius + 3.8
	for candidate in get_tree().get_nodes_in_group("npc_dinosaur"):
		if not candidate is Node3D or bool(candidate.get("dead")):
			continue
		var target := candidate as Node3D
		var offset := target.global_position - global_position
		var flat_offset := Vector3(offset.x, 0.0, offset.z)
		var distance := flat_offset.length()
		if distance <= 0.001 or distance > closest_distance:
			continue
		if forward.dot(flat_offset.normalized()) < 0.2:
			continue
		closest_target = target
		closest_distance = distance
	if is_instance_valid(closest_target):
		closest_target.call("take_damage", maxi(strength * 4, 1), self)


func _update_animation(moving: bool, running: bool, ducking: bool) -> void:
	if animation_player == null or attack_time > 0.0 or scream_time > 0.0:
		return
	if eating_active:
		_play_animation("idle")
	elif not is_on_floor():
		_play_animation("jump")
	elif moving:
		_play_animation("walk" if ducking else ("run" if running else "walk"))
	else:
		_play_animation("idle")
	animation_player.speed_scale = 0.58 if eating_active else (0.65 if ducking else (0.75 if scream_time > 0.0 else 1.0))


func _start_scream() -> void:
	scream_time = 1.2
	_spend_energy(scream_energy_cost)
	_play_animation("idle", true)
	_play_action_sound("scream")
	_spawn_roar_wave()
	screamed.emit()


func take_damage(amount: int, play_hurt_sound := true) -> void:
	if amount <= 0 or health <= 0 or dead:
		return
	health = maxi(health - amount, 0)
	if play_hurt_sound:
		_play_action_sound("hurt")
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()


func _update_energy(delta: float, moving: bool, running: bool, ducking: bool) -> void:
	if moving:
		_spend_energy((run_energy_cost if running else walk_energy_cost) * delta)
	if ducking:
		_spend_energy(duck_energy_cost * delta)
	if energy <= 0.0:
		starvation_damage_accumulator += starvation_damage_per_second * delta
		var damage := int(floor(starvation_damage_accumulator))
		if damage > 0:
			starvation_damage_accumulator -= float(damage)
			take_damage(damage, false)
	else:
		starvation_damage_accumulator = 0.0


func _spend_energy(amount: float) -> void:
	if amount <= 0.0 or dead:
		return
	var previous := energy
	energy = maxf(energy - amount, 0.0)
	if not is_equal_approx(previous, energy):
		energy_changed.emit(energy, max_energy)


func restore_energy(amount: float) -> void:
	if amount <= 0.0 or dead:
		return
	var previous := energy
	energy = minf(energy + amount, max_energy)
	if not is_equal_approx(previous, energy):
		energy_changed.emit(energy, max_energy)


func restore_health(amount: int) -> void:
	if amount <= 0 or dead:
		return
	var previous := health
	health = mini(health + amount, max_health)
	if health != previous:
		health_changed.emit(health, max_health)


func collect_token(token_type: String) -> void:
	match token_type:
		"health":
			var restored := mini(token_health_restore, max_health - health)
			restore_health(token_health_restore)
			status_requested.emit("Health token: +%d health" % restored if restored > 0 else "Health is already full")
		"speed":
			speed_bonus_time = token_bonus_duration
			walk_speed = base_walk_speed * 2.0
			run_speed = base_run_speed * 2.0
			duck_speed = base_duck_speed * 2.0
			status_requested.emit("Speed doubled for %d seconds" % int(token_bonus_duration))
		"strength":
			strength_bonus_time = token_bonus_duration
			strength = base_strength * 2
			status_requested.emit("Strength doubled for %d seconds" % int(token_bonus_duration))
	bonuses_changed.emit(speed_bonus_time, strength_bonus_time)


func _update_powerups(delta: float) -> void:
	var previous_speed_time := speed_bonus_time
	var previous_strength_time := strength_bonus_time
	if speed_bonus_time > 0.0:
		speed_bonus_time = maxf(speed_bonus_time - delta, 0.0)
		if speed_bonus_time <= 0.0:
			walk_speed = base_walk_speed
			run_speed = base_run_speed
			duck_speed = base_duck_speed
	if strength_bonus_time > 0.0:
		strength_bonus_time = maxf(strength_bonus_time - delta, 0.0)
		if strength_bonus_time <= 0.0:
			strength = base_strength
	if int(ceil(previous_speed_time)) != int(ceil(speed_bonus_time)) or int(ceil(previous_strength_time)) != int(ceil(strength_bonus_time)):
		bonuses_changed.emit(speed_bonus_time, strength_bonus_time)


func _update_eating(delta: float, wants_eat: bool) -> void:
	eating_active = false
	if not wants_eat:
		eating_target = null
		return
	if energy >= max_energy:
		if not eat_was_pressed:
			status_requested.emit("Energy is already full")
		return
	var food_group := "edible_plant" if diet == "herbivore" else "edible_meat"
	if not is_instance_valid(eating_target) or not eating_target.is_in_group(food_group) or global_position.distance_to(eating_target.global_position) > food_reach:
		eating_target = _nearest_food(food_group)
	if not is_instance_valid(eating_target):
		if not eat_was_pressed:
			status_requested.emit("Find a nearby plant to graze" if diet == "herbivore" else "Hunt prey for meat — coming later")
		return
	eating_active = true
	var rate := plant_energy_per_second if diet == "herbivore" else meat_energy_per_second
	restore_energy(rate * delta)
	var food_remaining: float = eating_target.get_meta("energy_remaining", 18.0)
	food_remaining -= rate * delta
	eating_target.set_meta("energy_remaining", food_remaining)
	if not eat_was_pressed:
		status_requested.emit("Grazing..." if diet == "herbivore" else "Eating meat...")
	if food_remaining <= 0.0:
		eating_target.queue_free()
		eating_target = null
		eating_active = false


func _nearest_food(food_group: StringName) -> Node3D:
	var nearest: Node3D
	var nearest_distance := food_reach
	for candidate in get_tree().get_nodes_in_group(food_group):
		if not candidate is Node3D:
			continue
		var candidate_node := candidate as Node3D
		var candidate_distance := global_position.distance_to(candidate_node.global_position)
		if candidate_distance <= nearest_distance:
			nearest = candidate_node
			nearest_distance = candidate_distance
	return nearest


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector3.ZERO
	eating_active = false
	var death_animation := _find_animation("death")
	if death_animation != "":
		current_animation = death_animation
		animation_player.speed_scale = 0.85
		animation_player.play(death_animation, 0.12)
		var visible_duration := minf(animation_player.get_animation(death_animation).length / animation_player.speed_scale, 2.4)
		get_tree().create_timer(maxf(visible_duration, 1.0)).timeout.connect(died.emit)
	else:
		var tween := create_tween()
		tween.tween_property(model_root, "rotation:z", deg_to_rad(82.0), 0.9).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(died.emit)


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
