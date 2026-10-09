extends "res://quests/mission_event.gd"

const MATERIALS = preload("res://scripts/generated_materials.gd")

const BLUE := Color("3e8faf")
const SNOW := Color("e0edf3")
const AMBER := Color("e9b44c")
const RED := Color("df665b")
const GREEN := Color("80ba77")
var mode := ""
var checkpoints: Array[Vector3] = []
var stage := 0
var checkpoint := Vector3(0, 0.1, 5)
var clock := 0.0
var warmth := 100.0
var exposure := 0.0
var noise := 0.0
var notice_time := 0.0
var notice := ""
var ui_time := 0.0
var markers: Array[MeshInstance3D] = []
var boulders: Array[Node3D] = []
var channels: Array[Vector3] = []
var channel_ready: Array[bool] = [false, false, false]
var streams: Array[MeshInstance3D] = []
var giants: Array[Node3D] = []
var giant_labels: Array[Label3D] = []
var snow_gate: StaticBody3D
var weather: Environment
var sound: AudioStreamPlayer
var hazard_sound: AudioStreamPlayer
var last_phase := -1
var avalanche_snow: MeshInstance3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	mode = str(objective.get("mission_mode", ""))
	controller.player.died.connect(_on_player_died)
	controller.player.rotation.y = PI
	if is_instance_valid(controller.status_label): controller.status_label.text = ""
	# Tall corridor walls prevent bypassing the lake and mountain tunnel.
	_box(Vector3(-24, 6, 55), Vector3(2, 12, 114), SNOW, true).visible = false
	_box(Vector3(24, 6, 55), Vector3(2, 12, 114), SNOW, true).visible = false
	_box(Vector3(0, 6, -3), Vector3(50, 12, 2), SNOW, true).visible = false
	for child in controller.world_root.get_children():
		if child is WorldEnvironment:
			weather = child.environment
			weather.fog_density = 0.002
	sound = AudioStreamPlayer.new()
	add_child(sound)
	hazard_sound = AudioStreamPlayer.new()
	hazard_sound.volume_db = -14
	add_child(hazard_sound)
	match mode:
		"tracks_in_snow": _build_tracks()
		"whiteout":
			checkpoints.assign([Vector3(-10, 0.1, 28), Vector3(10, 0.1, 53), Vector3(0, 0.1, 80)])
			_shelter(checkpoint)
			for point in checkpoints: _shelter(point)
		"singing_lake":
			checkpoints.assign([Vector3(-7, 0.1, 22), Vector3(7, 0.1, 39), Vector3(-7, 0.1, 56), Vector3(0, 0.1, 74)])
			_box(Vector3(0, 0.02, 42), Vector3(46, 0.025, 72), Color("bddae5"))
			_ice_island(checkpoint)
			for point in checkpoints: _ice_island(point)
			for z in range(10, 80, 6):
				var crack := _box(Vector3(0, 0.045, z), Vector3(30, 0.015, 0.08), BLUE)
				crack.rotation.y = 0.12 * (z % 5 - 2)
		"sleeping_giants": _build_giants()
		"snowplug": _build_channels()
		"last_avalanche":
			checkpoints.assign([Vector3(-12, 0.1, 30), Vector3(12, 0.1, 58), Vector3(-12, 0.1, 86)])
			_shelter(checkpoint)
			for point in checkpoints: _shelter(point)
			for index in 3:
				markers.append(_box(Vector3(0, 0.025, 17 + index * 28), Vector3(46, 0.03, 12), BLUE))
			avalanche_snow = _box(Vector3(0, 5, 17), Vector3(46, 1.5, 9), SNOW)
			avalanche_snow.visible = false
			_box(Vector3(0, 0.05, 100), Vector3(46, 0.1, 20), GREEN)
			_label(Vector3(0, 4, 102), "exit")
			for x in [-14, 14]:
				_box(Vector3(x, 0.08, 101), Vector3(7, 0.12, 5), BLUE)
				_box(Vector3(x, 1.4, 98), Vector3(1, 2.8, 1), Color("8c7055"))
	_update_ui()


func _build_tracks() -> void:
	checkpoints.assign([Vector3(-10, 0.1, 28), Vector3(10, 0.1, 52), Vector3(-8, 0.1, 76)])
	var previous := checkpoint
	for point in checkpoints:
		_footprints(previous, point, false)
		# Wrong branches visibly turn into a loop; only forward prints advance.
		var wrong := Vector3(-point.x, 0.1, point.z)
		_footprints(previous, wrong, true)
		previous = point
	_label(Vector3(-8, 4, 80), "camp")
	_shelter(checkpoints.back())


func _footprints(from: Vector3, to: Vector3, loop: bool) -> void:
	for step in 12:
		var position := from.lerp(to, float(step + 1) / 12.0)
		if loop:
			position.x += sin(float(step) * 0.5) * 3.0
		var direction := (to - from).normalized()
		if loop and step > 7: direction = -direction
		for side in [-1, 1]:
			var print_mesh := _box(Vector3(position.x + side * 0.5, 0.035, position.z), Vector3(0.32, 0.04, 0.65), Color("547184"))
			print_mesh.rotation.y = atan2(direction.x, direction.z)
			# Three toes give each footprint a clearly visible forward direction.
			for toe in [-1, 0, 1]:
				var offset := Vector3(toe * 0.13, 0, 0.45).rotated(Vector3.UP, print_mesh.rotation.y)
				_box(print_mesh.position + offset, Vector3(0.12, 0.04, 0.32), Color("547184"))


func _build_giants() -> void:
	checkpoints.assign([Vector3(14, 0.1, 36), Vector3(-14, 0.1, 60), Vector3(14, 0.1, 84)])
	for index in 3:
		var z := 24.0 + index * 24
		_box(Vector3(0, 0.03, z), Vector3(46, 0.03, 15), BLUE)
		var x := 14.0 if index % 2 == 0 else -14.0
		_box(Vector3(x, 0.06, z), Vector3(12, 0.04, 18), SNOW)
		_label(Vector3(x, 1.3, z - 8), "soft_snow")
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) != "sleeping_giant": continue
		giants.append(npc)
		npc.set_physics_process(false)
		npc.set_process(false)
		npc.call("_play_animation", "idle")
		npc.model_root.rotation.z = PI * 0.5
		npc.model_root.position.y = 1.4
		if npc.animation_player != null: npc.animation_player.pause()
		npc.died.connect(_on_giant_died)
		var label := _label(npc.global_position + Vector3(0, 6, 0), "")
		label.text = "Z z z"
		giant_labels.append(label)


func _build_channels() -> void:
	for index in 3:
		var x := -12.0 + index * 12
		var target := Vector3(x, 0.1, 40)
		channels.append(target)
		_box(Vector3(x, 0.035, 32), Vector3(4, 0.04, 20), BLUE)
		markers.append(_box(Vector3(x, 0.075, 40), Vector3(5, 0.05, 4), AMBER))
		var rock := _box(Vector3(x, 1.4, 23), Vector3(2.8, 2.8, 2.8), Color("73818d"), true).get_parent() as Node3D
		_decorate_rock(rock)
		boulders.append(rock)
		_label(Vector3(x, 4, 40), "channel")
		var stream := _box(Vector3(x, 0.1, 49), Vector3(2, 0.06, 18), BLUE)
		stream.visible = false
		streams.append(stream)
	_box(Vector3(-16, 3, 61), Vector3(16, 6, 4), Color("8295a4"), true)
	_box(Vector3(16, 3, 61), Vector3(16, 6, 4), Color("8295a4"), true)
	snow_gate = _box(Vector3(0, 3, 61), Vector3(16, 6, 4), SNOW, true).get_parent() as StaticBody3D
	checkpoints.assign([Vector3(0, 0.1, 72)])
	_label(Vector3(0, 4, 72), "camp")


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player): return
	if controller.player.dead: return
	clock += delta
	notice_time = maxf(0, notice_time - delta)
	var position: Vector3 = controller.player.global_position
	match mode:
		"tracks_in_snow":
			if stage < checkpoints.size():
				var wrong := Vector3(-checkpoints[stage].x, 0.1, checkpoints[stage].z)
				if _distance(position, wrong) < 4: _retry("wrong_trail")
			_advance(position)
		"whiteout": _storm(delta, position)
		"singing_lake": _lake(delta, position)
		"sleeping_giants": _stealth(delta, position)
		"snowplug": _push(delta, position)
		"last_avalanche": _avalanche(delta, position)
	ui_time -= delta
	if ui_time <= 0:
		ui_time = 0.2
		_update_ui()


func _advance(position: Vector3, finish := true) -> void:
	if stage >= checkpoints.size(): return
	if _distance(position, checkpoints[stage]) <= float(objective.get("checkpoint_radius", 4.5)):
		checkpoint = checkpoints[stage]
		stage += 1
		_play("checkpoint")
		if finish and stage == checkpoints.size(): complete()


func _storm(delta: float, position: Vector3) -> void:
	var windy := fmod(clock, float(objective.get("weather_cycle", 16.0))) >= float(objective.get("calm_seconds", 9.0))
	var sheltered := _near_shelter(position)
	warmth = clampf(warmth + delta * (35 if sheltered else (-20 if windy else -2)), 0, 100)
	if weather != null: weather.fog_density = 0.025 if windy else 0.003
	_phase_sound(1 if windy else 0, "wind")
	if warmth <= 0:
		_retry("retry_cold")
		warmth = 100
		return
	_advance(position)


func _lake(delta: float, position: Vector3) -> void:
	var safe := _distance(position, Vector3(0, 0.1, 5)) < 6
	for point in checkpoints:
		if _distance(position, point) < float(objective.get("ice_radius", 6.0)): safe = true
	if position.z > 79: safe = true
	exposure = 0 if safe else exposure + delta
	if exposure > 0.65: _phase_sound(1, "ice_crack")
	else: last_phase = 0
	if exposure >= float(objective.get("ice_break_seconds", 2.5)):
		_retry("retry_ice")
		return
	_advance(position)


func _stealth(delta: float, position: Vector3) -> void:
	var nearest := -1
	for index in giants.size():
		if not is_instance_valid(giants[index]) or giants[index].health < giants[index].max_health:
			fail(Localization.text("ice.giant_hurt"))
			return
		if absf(position.z - giants[index].global_position.z) < 10: nearest = index
	var moving_speed := Vector2(controller.player.velocity.x, controller.player.velocity.z).length()
	var noisy := false
	if nearest >= 0:
		var soft_x := 14.0 if nearest % 2 == 0 else -14.0
		var on_snow := absf(position.x - soft_x) <= 6
		noisy = moving_speed > (4.5 if on_snow else 0.5) or controller.player.attack_time > 0.1 or controller.player.scream_time > 0.1
	noise = clampf(noise + delta * (1.2 if noisy else -1.8), 0, 3)
	for index in giant_labels.size():
		giant_labels[index].text = "!" if nearest == index and noise > 0.4 else "Z z z"
	if noise >= float(objective.get("wake_noise", 2.4)):
		_retry("retry_noise")
		return
	_advance(position)


func _push(delta: float, position: Vector3) -> void:
	for index in boulders.size():
		if channel_ready[index]: continue
		var rock := boulders[index]
		var velocity: Vector3 = controller.player.velocity
		if _distance(position, rock.position) < 4.0 and position.z < rock.position.z and velocity.z > 0.4:
			rock.position.z = minf(channels[index].z, rock.position.z + minf(velocity.z, 5) * delta)
		if absf(rock.position.z - channels[index].z) < 0.8:
			channel_ready[index] = true
			_color(markers[index], GREEN)
			streams[index].visible = true
			_play("checkpoint")
	if channel_ready.count(true) == 3:
		if is_instance_valid(snow_gate): snow_gate.queue_free()
		_advance(position)


func _avalanche(delta: float, position: Vector3) -> void:
	var cycle := fmod(clock, float(objective.get("slide_cycle", 12.0)))
	var phase := 0 if cycle < 6 else (1 if cycle < 9 else 2)
	for marker in markers: _color(marker, [BLUE, AMBER, RED][phase])
	avalanche_snow.visible = phase == 2
	if stage < 3:
		avalanche_snow.position = Vector3(0, (12 - cycle) * 2, 17 + stage * 28)
	_phase_sound(phase, "avalanche")
	var in_slide := false
	for index in 3:
		if absf(position.z - (17 + index * 28)) < 7: in_slide = true
	exposure = exposure + delta if phase == 2 and in_slide and not _near_shelter(position) else 0
	if exposure >= float(objective.get("slide_exposure_seconds", 0.65)):
		_retry("retry_slide")
		return
	_advance(position, false)
	if stage == 3 and position.z >= 97:
		set_progress(Localization.text("ice.valley"))
		complete()


func _near_shelter(position: Vector3) -> bool:
	if _distance(position, Vector3(0, 0.1, 5)) <= 6: return true
	for point in checkpoints:
		if _distance(position, point) <= 6: return true
	return false


func _retry(key: String) -> void:
	controller.player.global_position = checkpoint
	controller.player.velocity = Vector3.ZERO
	exposure = 0
	noise = 0
	notice = Localization.text("ice." + key)
	notice_time = 3
	_play("retry")


func _update_ui() -> void:
	if ended: return
	if notice_time > 0:
		set_progress(notice)
		return
	match mode:
		"tracks_in_snow": set_progress(Localization.text("ice.tracks", [stage, 3]))
		"whiteout":
			var windy := fmod(clock, float(objective.get("weather_cycle", 16.0))) >= float(objective.get("calm_seconds", 9.0))
			set_progress(Localization.text("ice.storm" if windy else "ice.calm", [int(warmth), stage]))
		"singing_lake": set_progress(Localization.text("ice.cracking") if exposure > 0.65 else Localization.text("ice.ice", [stage]))
		"sleeping_giants": set_progress(Localization.text("ice.stirring") if noise > 0.4 else Localization.text("ice.quiet", [stage]))
		"snowplug": set_progress(Localization.text("ice.tunnel") if channel_ready.count(true) == 3 else Localization.text("ice.boulders", [channel_ready.count(true)]))
		"last_avalanche":
			var cycle := fmod(clock, float(objective.get("slide_cycle", 12.0)))
			set_progress(Localization.text("ice.clear" if cycle < 6 else ("ice.warning" if cycle < 9 else "ice.slide"), [stage]))


func _phase_sound(phase: int, clip: String) -> void:
	if phase == last_phase: return
	last_phase = phase
	if phase > 0:
		hazard_sound.stream = load("res://assets/audio/frozen_pass/%s.wav" % clip)
		hazard_sound.play()


func _play(clip: String) -> void:
	sound.stream = load("res://assets/audio/frozen_pass/%s.wav" % clip)
	sound.volume_db = -10
	sound.play()


func _on_player_died() -> void:
	fail(Localization.text("game_over.fallen"))


func _on_giant_died(_giant: Node3D) -> void:
	fail(Localization.text("ice.giant_hurt"))


func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _shelter(point: Vector3) -> void:
	_box(point + Vector3(-5.5, 2, 0), Vector3(1.5, 4, 8), Color("8295a4"), true)
	_box(point + Vector3(5.5, 2, 0), Vector3(1.5, 4, 8), Color("8295a4"), true)
	_box(point + Vector3(0, 6, 0), Vector3(13, 1.5, 9), SNOW, true)
	_box(point + Vector3(0, -0.02, 0), Vector3(9, 0.04, 8), GREEN)
	_label(point + Vector3(0, 3.5, 0), "shelter")


func _ice_island(point: Vector3) -> void:
	var island := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(objective.get("ice_radius", 6.0))
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.06
	island.mesh = mesh
	island.position = Vector3(point.x, 0.055, point.z)
	_color(island, BLUE)
	add_child(island)
	_label(point + Vector3(0, 1.5, 0), "island")


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
	material.roughness = 0.85
	if color == SNOW:
		material = MATERIALS.theme_ground_material("winter", 0, 0.18)
	elif color == Color("8295a4"):
		material.albedo_texture = MATERIALS.ROCK_TEXTURES[0]
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.2
	visual.material_override = material


func _label(position: Vector3, key: String) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.text = Localization.text("ice." + key) if not key.is_empty() else ""
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.018
	label.no_depth_test = false
	add_child(label)
	return label


func _decorate_rock(body: Node3D) -> void:
	for child in body.get_children():
		if child is MeshInstance3D: child.visible = false
	var model: Node3D = controller.environment_models["rock"].instantiate()
	model.position.y = -1.4
	model.scale = Vector3.ONE * 1.5
	body.add_child(model)
	MATERIALS.apply_rock(model, 0)
	MATERIALS.tint_environment(model, "winter", "rock")
