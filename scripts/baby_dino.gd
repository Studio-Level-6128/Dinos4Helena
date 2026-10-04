extends CharacterBody3D

# Lightweight companion controller. Babies deliberately reuse adult models and
# configuration at a reduced scale, but omit energy and combat objectives.
signal died(baby: CharacterBody3D)

const CONFIG_PATH := "res://config/dinosaurs.cfg"
const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")

var dino_id := "triceratops"
var texture_variant := 0
var companion_index := 0
var pack_id := -2
var pack_slot := -1
var parent_dino: CharacterBody3D
var diet := "herbivore"
var display_name := ""
var model_scale := 0.1
var run_animation_speed_scale := 1.0
var walk_speed := 2.5
var run_speed := 4.5
var turn_speed := 2.5
var strength := 2
var max_health := 50
var health := 50
var collision_radius := 0.4
var collision_height := 1.3
var dead := false
var state := "following"
var panic_source: Node3D
var panic_time := 0.0
var panic_turn_time := 0.0
var panic_direction := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var model_root: Node3D
var animation_player: AnimationPlayer
var collision_shape: CollisionShape3D
var health_label: Label3D
var current_animation := ""
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	var config := ConfigFile.new()
	var config_error := config.load(CONFIG_PATH)
	if config_error != OK:
		push_error("Could not load dinosaur configuration: %s" % error_string(config_error))
	diet = config.get_value(dino_id, "diet", "herbivore")
	display_name = Localization.text("dino.baby_named", [Localization.text(str(config.get_value(dino_id, "display_name_key", "dino." + dino_id)))])
	var baby_scale := float(config.get_value("breeding", "baby_scale", 0.42))
	var speed_factor := float(config.get_value("breeding", "baby_speed_factor", 0.84))
	model_scale = float(config.get_value(dino_id, "model_scale", 0.2)) * baby_scale
	run_animation_speed_scale = config.get_value(dino_id, "run_animation_speed_scale", 1.0)
	walk_speed = float(config.get_value(dino_id, "walk_speed", 3.0)) * speed_factor
	run_speed = float(config.get_value(dino_id, "run_speed", 6.0)) * speed_factor
	turn_speed = float(config.get_value(dino_id, "turn_speed", 2.0)) * 1.15
	strength = maxi(int(round(float(config.get_value(dino_id, "strength", 5)) * 0.45)), 1)
	max_health = maxi(int(round(float(config.get_value(dino_id, "max_health", 100)) * 0.55)), 1)
	health = max_health
	rng.seed = hash("%s:%d:%d" % [dino_id, companion_index, get_instance_id()])
	collision_radius = float(config.get_value(dino_id, "collision_radius", 0.8)) * baby_scale
	collision_height = float(config.get_value(dino_id, "collision_height", 2.8)) * baby_scale
	add_to_group("baby_dinosaur")
	add_to_group("npc_dinosaur")
	add_to_group("prey_dinosaur")
	_build_collision()
	_build_model(config.get_value(dino_id, "model_path", ""))
	_build_health_label()
	if is_instance_valid(parent_dino):
		add_collision_exception_with(parent_dino)
		parent_dino.add_collision_exception_with(self)
	var hatch_scale := model_root.scale
	model_root.scale = hatch_scale * 0.08
	create_tween().tween_property(model_root, "scale", hatch_scale, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	var direction := Vector3.ZERO
	var speed := walk_speed
	panic_time = maxf(panic_time - delta, 0.0)
	if panic_time > 0.0:
		panic_turn_time = maxf(panic_turn_time - delta, 0.0)
		if panic_turn_time <= 0.0:
			_choose_panic_direction()
		direction = panic_direction
		speed = run_speed
		state = "panicked"
		_face_direction(direction, delta)
	elif is_instance_valid(parent_dino) and parent_dino.get("dead") != true and parent_dino.get("eating_active") == true and is_instance_valid(parent_dino.get("eating_target")):
		var food := parent_dino.get("eating_target") as Node3D
		var angle := TAU * float(posmod(companion_index * 5 + 2, 13)) / 13.0
		var meal_radius := collision_radius + 0.9 + float(companion_index / 2) * 0.35
		var meal_position := food.global_position + Vector3(cos(angle), 0.0, sin(angle)) * meal_radius
		var meal_offset := meal_position - global_position
		meal_offset.y = 0.0
		if meal_offset.length() > 0.55:
			direction = meal_offset.normalized()
			speed = run_speed if meal_offset.length() > 5.0 else walk_speed
			state = "gathering_to_eat"
			_face_direction(direction, delta)
		else:
			state = "eating_with_parent"
			_face_direction(food.global_position - global_position, delta)
	elif is_instance_valid(parent_dino) and parent_dino.get("dead") != true:
		# Alternate companions left/right and place later babies slightly farther
		# back. A short catch-up boost prevents permanent loss behind obstacles.
		var side_sign := 1.0 if companion_index % 2 == 0 else -1.0
		var rank := float(companion_index / 2)
		var lateral_distance := float(parent_dino.get("collision_radius")) + collision_radius + 1.1 + rank * 1.4
		var target := parent_dino.global_position + parent_dino.global_transform.basis.x.normalized() * lateral_distance * side_sign
		target += parent_dino.global_transform.basis.z.normalized() * (0.5 + rank * 0.7)
		var offset := target - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance > 1.0:
			direction = Vector3(offset.x, 0.0, offset.z).normalized()
			speed = run_speed if distance > 4.5 else walk_speed
			if distance > 12.0:
				speed *= 1.35
			state = "catching_up" if distance > 4.5 else "following"
			_face_direction(direction, delta)
		else:
			state = "beside_parent"
	else:
		state = "orphaned"
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 6.0 * delta)
	move_and_slide()
	_update_animation(direction.length_squared() > 0.01, speed > walk_speed)
	if state == "eating_with_parent" and animation_player:
		animation_player.speed_scale = 0.58


func receive_predator_roar(source: Node3D) -> void:
	if dead or diet != "herbivore" or not is_instance_valid(source) or str(source.get("dino_id")) == dino_id:
		return
	panic_source = source
	panic_time = rng.randf_range(4.5, 7.5)
	panic_turn_time = 0.0
	_choose_panic_direction()


func _choose_panic_direction() -> void:
	var away := Vector3.FORWARD
	if is_instance_valid(panic_source):
		away = global_position - panic_source.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			away = away.normalized()
	panic_direction = away.rotated(Vector3.UP, rng.randf_range(-1.35, 1.35)).normalized()
	panic_turn_time = rng.randf_range(0.4, 1.0)


func take_damage(amount: int, attacker: Node3D = null) -> void:
	if amount <= 0 or dead or (is_instance_valid(attacker) and str(attacker.get("dino_id")) == dino_id):
		return
	health = maxi(health - amount, 0)
	_update_health_label()
	health_label.visible = true
	if health <= 0:
		_die(attacker)


func _die(attacker: Node3D = null) -> void:
	if dead:
		return
	dead = true
	state = "dead"
	remove_from_group("prey_dinosaur")
	collision_shape.set_deferred("disabled", true)
	_play_animation("death", true)
	if animation_player:
		animation_player.speed_scale = 0.85
	var meat := _drop_meat()
	if is_instance_valid(attacker) and attacker.has_method("claim_meal"):
		attacker.call("claim_meal", meat)
	died.emit(self)
	get_tree().create_timer(12.0).timeout.connect(queue_free)


func _drop_meat() -> Node3D:
	var meat := Node3D.new()
	meat.name = "SmallMeat"
	meat.add_to_group("edible_meat")
	meat.set_meta("energy_remaining", 24.0)
	meat.set_meta("source_dinosaur", self)
	get_parent().add_child(meat)
	meat.global_position = global_position + Vector3(0.0, 0.2, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.48
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.4, 0.55, 0.85)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8f3028")
	material.roughness = 0.9
	mesh_instance.material_override = material
	meat.add_child(mesh_instance)
	return meat


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
	model_root.name = "BabyDinosaurModel"
	model_root.scale = Vector3.ONE * model_scale
	model_root.rotation.y = PI
	add_child(model_root)
	GENERATED_MATERIALS.apply_dino_skin(model_root, texture_variant, dino_id)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		for keyword in ["idle", "walk", "run"]:
			var animation_name := _find_animation(keyword)
			if animation_name != "":
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		_play_animation("idle", true)


func _build_health_label() -> void:
	health_label = Label3D.new()
	health_label.position.y = collision_height + 0.55
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.no_depth_test = true
	health_label.font_size = 28
	health_label.pixel_size = 0.011
	health_label.outline_size = 6
	health_label.modulate = Color("bdeaff")
	health_label.visible = false
	add_child(health_label)
	_update_health_label()


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = Localization.text("dino.health_label", [display_name, health, max_health])


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() <= 0.001:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-flat.x, -flat.y), turn_speed * delta)


func _update_animation(moving: bool, running: bool) -> void:
	if dead or animation_player == null:
		return
	_play_animation(("run" if running else "walk") if moving else "idle")
	animation_player.speed_scale = run_animation_speed_scale if moving and running else 1.0


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
	var search_terms: Array[String] = [keyword.to_lower()]
	match keyword.to_lower():
		"death":
			search_terms.append("dead")
		"run":
			search_terms.append("walk")
	for search_term in search_terms:
		for animation_name in animation_player.get_animation_list():
			if search_term in animation_name.to_lower():
				return animation_name
	return ""
