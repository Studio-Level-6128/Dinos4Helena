extends CharacterBody3D

signal died(npc: CharacterBody3D)

const CONFIG_PATH := "res://config/dinosaurs.cfg"
const HUNTER_SIGHT_RANGE := 58.0
const HERBIVORE_DANGER_RANGE := 34.0
const PACK_COHESION_RANGE := 11.0

var dino_id := "triceratops"
var pack_id := -1
var rng_seed := 1
var patrol_center := Vector3.ZERO
var diet := "herbivore"
var display_name := "Dinosaur"
var model_scale := 0.2
var walk_speed := 3.0
var run_speed := 6.0
var turn_speed := 2.0
var strength := 5
var max_health := 100
var health := 100
var collision_radius := 0.8
var collision_height := 2.8
var dead := false
var state := "wandering"
var attack_cooldown := 0.0
var wander_time := 0.0
var wander_target := Vector3.ZERO
var forced_target: Node3D
var model_root: Node3D
var animation_player: AnimationPlayer
var health_label: Label3D
var collision_shape: CollisionShape3D
var current_animation := ""
var rng := RandomNumberGenerator.new()
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var config := ConfigFile.new()
	assert(config.load(CONFIG_PATH) == OK, "Could not load dinosaur configuration")
	diet = config.get_value(dino_id, "diet", "herbivore")
	display_name = config.get_value(dino_id, "display_name", dino_id.capitalize())
	model_scale = config.get_value(dino_id, "model_scale", 0.2)
	walk_speed = config.get_value(dino_id, "walk_speed", 3.0)
	run_speed = config.get_value(dino_id, "run_speed", 6.0)
	turn_speed = config.get_value(dino_id, "turn_speed", 2.0)
	strength = config.get_value(dino_id, "strength", 5)
	max_health = config.get_value(dino_id, "max_health", 100)
	health = max_health
	collision_radius = config.get_value(dino_id, "collision_radius", 0.8)
	collision_height = config.get_value(dino_id, "collision_height", 2.8)
	rng.seed = rng_seed
	add_to_group("npc_dinosaur")
	if diet == "carnivore":
		add_to_group("hunter_dinosaur")
	else:
		add_to_group("prey_dinosaur")
	_build_collision()
	_build_model(config.get_value(dino_id, "model_path", ""))
	_build_health_label()
	_choose_wander_target()


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move_direction := Vector3.ZERO
	var move_speed := walk_speed
	if diet == "carnivore":
		var prey := _choose_prey()
		if is_instance_valid(prey):
			var offset := prey.global_position - global_position
			var distance := Vector2(offset.x, offset.z).length()
			_face_direction(offset, delta)
			if distance <= collision_radius + _body_radius(prey) + 1.6:
				state = "attacking"
				_attack(prey)
			else:
				state = "hunting"
				move_direction = Vector3(offset.x, 0.0, offset.z).normalized()
				move_speed = run_speed
		else:
			state = "wandering"
			move_direction = _wander_direction(delta)
	else:
		var hunter := _nearest_hunter()
		if is_instance_valid(hunter):
			state = "fleeing"
			var escape := global_position - hunter.global_position
			move_direction = Vector3(escape.x, 0.0, escape.z).normalized()
			move_speed = run_speed
		else:
			state = "packing"
			move_direction = _pack_direction(delta)
	_apply_movement(move_direction, move_speed, delta)


func _choose_prey() -> Node3D:
	if is_instance_valid(forced_target) and not bool(forced_target.get("dead")):
		if global_position.distance_to(forced_target.global_position) <= HUNTER_SIGHT_RANGE * 1.35:
			return forced_target
	forced_target = null
	var nearest: Node3D
	var nearest_distance := HUNTER_SIGHT_RANGE
	var candidates := get_tree().get_nodes_in_group("prey_dinosaur") + get_tree().get_nodes_in_group("player_dinosaur")
	for candidate in candidates:
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate_node
			nearest_distance = distance
	return nearest


func _pack_direction(delta: float) -> Vector3:
	var center := Vector3.ZERO
	var members := 0
	for candidate in get_tree().get_nodes_in_group("prey_dinosaur"):
		if candidate is CharacterBody3D and candidate.get("pack_id") == pack_id and not bool(candidate.get("dead")):
			center += candidate.global_position
			members += 1
	if members > 0:
		center /= float(members)
		var to_pack := center - global_position
		if Vector2(to_pack.x, to_pack.z).length() > PACK_COHESION_RANGE:
			return Vector3(to_pack.x, 0.0, to_pack.z).normalized()
	return _wander_direction(delta)


func _wander_direction(delta: float) -> Vector3:
	wander_time -= delta
	if wander_time <= 0.0 or global_position.distance_to(wander_target) < 2.5:
		_choose_wander_target()
	var offset := wander_target - global_position
	return Vector3(offset.x, 0.0, offset.z).normalized()


func _choose_wander_target() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(7.0, 20.0)
	wander_target = patrol_center + Vector3(cos(angle), 0.0, sin(angle)) * distance
	wander_time = rng.randf_range(4.0, 9.0)


func _nearest_group_member(group_name: StringName, maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := maximum_distance
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate_node
			nearest_distance = distance
	return nearest


func _nearest_hunter() -> Node3D:
	var nearest := _nearest_group_member("hunter_dinosaur", HERBIVORE_DANGER_RANGE)
	var player_hunter := _nearest_group_member("player_hunter", HERBIVORE_DANGER_RANGE)
	if not is_instance_valid(nearest):
		return player_hunter
	if is_instance_valid(player_hunter) and global_position.distance_to(player_hunter.global_position) < global_position.distance_to(nearest.global_position):
		return player_hunter
	return nearest


func _apply_movement(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() > 0.01 and state != "attacking":
		_face_direction(direction, delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 8.0 * delta)
	move_and_slide()
	if get_slide_collision_count() > 0 and state in ["wandering", "packing"]:
		wander_time = 0.0
	_update_animation(direction.length_squared() > 0.01 and state != "attacking", is_equal_approx(speed, run_speed))


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() <= 0.001:
		return
	var target_rotation := atan2(-flat.x, -flat.y)
	rotation.y = rotate_toward(rotation.y, target_rotation, turn_speed * delta)


func _attack(target: Node3D) -> void:
	if attack_cooldown > 0.0 or not is_instance_valid(target):
		return
	attack_cooldown = 1.35
	_play_animation("attack", true)
	var damage := maxi(strength * 3, 1)
	if target.is_in_group("player_dinosaur"):
		target.call("take_damage", damage)
	else:
		target.call("take_damage", damage, self)


func take_damage(amount: int, attacker: Node3D = null) -> void:
	if amount <= 0 or dead:
		return
	health = maxi(health - amount, 0)
	_show_health()
	if is_instance_valid(attacker) and diet == "carnivore":
		forced_target = attacker
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	remove_from_group("hunter_dinosaur")
	remove_from_group("prey_dinosaur")
	collision_shape.set_deferred("disabled", true)
	_play_animation("death", true)
	if animation_player:
		animation_player.speed_scale = 0.85
	_drop_meat()
	died.emit(self)
	get_tree().create_timer(14.0).timeout.connect(queue_free)


func _drop_meat() -> void:
	var meat := Node3D.new()
	meat.name = "Meat"
	meat.add_to_group("edible_meat")
	meat.set_meta("energy_remaining", 55.0)
	get_parent().add_child(meat)
	meat.global_position = global_position + Vector3(0.0, 0.28, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 0.8
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.5, 0.55, 0.9)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8f3028")
	material.roughness = 0.9
	mesh_instance.material_override = material
	meat.add_child(mesh_instance)


func _build_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = collision_radius
	shape.height = collision_height
	collision_shape.shape = shape
	collision_shape.position.y = collision_height * 0.5
	add_child(collision_shape)


func _build_model(model_path: String) -> void:
	var model_scene := load(model_path) as PackedScene
	model_root = model_scene.instantiate()
	model_root.name = "DinosaurModel"
	model_root.scale = Vector3.ONE * model_scale
	model_root.rotation.y = PI
	add_child(model_root)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		for keyword in ["idle", "walk", "run"]:
			var animation_name := _find_animation(keyword)
			if animation_name != "":
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		var death_animation := _find_animation("death")
		if death_animation != "":
			animation_player.get_animation(death_animation).loop_mode = Animation.LOOP_NONE
		_play_animation("idle", true)


func _build_health_label() -> void:
	health_label = Label3D.new()
	health_label.position.y = collision_height + 0.8
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 34
	health_label.pixel_size = 0.012
	health_label.outline_size = 6
	health_label.modulate = Color("ffd7a1")
	health_label.no_depth_test = true
	health_label.visible = false
	add_child(health_label)
	_update_health_label()


func _show_health() -> void:
	_update_health_label()
	health_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(health_label) and not dead:
			health_label.visible = false
	)


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "%s  %d/%d" % [display_name, health, max_health]


func _update_animation(moving: bool, running: bool) -> void:
	if dead or animation_player == null or attack_cooldown > 0.9:
		return
	_play_animation(("run" if running else "walk") if moving else "idle")


func _play_animation(keyword: String, force := false) -> void:
	if animation_player == null:
		return
	var animation_name := _find_animation(keyword)
	if animation_name == "" or (animation_name == current_animation and not force):
		return
	current_animation = animation_name
	animation_player.play(animation_name, 0.15)


func _find_animation(keyword: String) -> String:
	if animation_player == null:
		return ""
	for animation_name in animation_player.get_animation_list():
		if keyword.to_lower() in animation_name.to_lower():
			return animation_name
	return ""


func _body_radius(body: Node) -> float:
	var value = body.get("collision_radius")
	return float(value) if value != null else 0.8
