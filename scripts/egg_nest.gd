extends Area3D

signal hatched(parent_dino: CharacterBody3D, hatch_position: Vector3)
signal status_changed(message: String)

var incubation_seconds := 4.0
var incubation_progress := 0.0
var hatching := false
var nearby_player: CharacterBody3D
var egg_root: Node3D
var instruction_label: Label3D
var last_second_shown := -1


func _ready() -> void:
	name = "DinosaurEggNest"
	add_to_group("dinosaur_egg")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_build_detection_area()
	_build_nest()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if hatching or not is_instance_valid(nearby_player):
		return
	var ducking := nearby_player.has_method("is_ducking") and bool(nearby_player.call("is_ducking"))
	if not ducking:
		if incubation_progress > 0.0:
			incubation_progress = 0.0
			last_second_shown = -1
			_update_instruction("DUCK TO HATCH")
		return
	incubation_progress = minf(incubation_progress + delta, incubation_seconds)
	var seconds_left := maxi(int(ceil(incubation_seconds - incubation_progress)), 0)
	if seconds_left != last_second_shown:
		last_second_shown = seconds_left
		_update_instruction("HATCHING… %d" % seconds_left)
		status_changed.emit("Keep ducking — the egg is hatching!" if seconds_left > 0 else "A baby dinosaur is hatching!")
	if incubation_progress >= incubation_seconds:
		_hatch()


func _build_detection_area() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.4
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)


func _build_nest() -> void:
	var nest_material := StandardMaterial3D.new()
	nest_material.albedo_color = Color("5d3b20")
	nest_material.roughness = 1.0
	for twig_index in 12:
		var angle := TAU * float(twig_index) / 12.0
		var twig := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.09
		mesh.bottom_radius = 0.12
		mesh.height = 1.25
		mesh.radial_segments = 6
		twig.mesh = mesh
		twig.position = Vector3(cos(angle) * 0.82, 0.12 + sin(float(twig_index) * 2.1) * 0.035, sin(angle) * 0.82)
		twig.rotation = Vector3(PI * 0.5, angle, angle)
		twig.material_override = nest_material
		add_child(twig)

	egg_root = Node3D.new()
	egg_root.name = "Egg"
	egg_root.position.y = 0.58
	add_child(egg_root)
	var egg := MeshInstance3D.new()
	var egg_mesh := SphereMesh.new()
	egg_mesh.radius = 0.48
	egg_mesh.height = 1.15
	egg_mesh.radial_segments = 24
	egg_mesh.rings = 12
	egg.mesh = egg_mesh
	egg.scale = Vector3(0.82, 1.08, 0.82)
	var egg_material := StandardMaterial3D.new()
	egg_material.albedo_color = Color("e9dfbd")
	egg_material.roughness = 0.72
	egg.material_override = egg_material
	egg_root.add_child(egg)
	for spot_index in 7:
		var spot := MeshInstance3D.new()
		var spot_mesh := SphereMesh.new()
		spot_mesh.radius = 0.055
		spot_mesh.height = 0.09
		spot_mesh.radial_segments = 8
		spot_mesh.rings = 4
		spot.mesh = spot_mesh
		var spot_angle := TAU * float(spot_index) / 7.0
		spot.position = Vector3(cos(spot_angle) * 0.39, -0.28 + float(spot_index % 3) * 0.27, sin(spot_angle) * 0.39)
		var spot_material := StandardMaterial3D.new()
		spot_material.albedo_color = Color("718052")
		spot.material_override = spot_material
		egg_root.add_child(spot)

	instruction_label = Label3D.new()
	instruction_label.text = "DUCK TO HATCH"
	instruction_label.position = Vector3(0.0, 1.65, 0.0)
	instruction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instruction_label.no_depth_test = true
	instruction_label.font_size = 30
	instruction_label.pixel_size = 0.012
	instruction_label.outline_size = 7
	instruction_label.modulate = Color("fff0b0")
	instruction_label.visible = false
	add_child(instruction_label)


func _on_body_entered(body: Node3D) -> void:
	if hatching or not body.is_in_group("player_dinosaur"):
		return
	nearby_player = body as CharacterBody3D
	_update_instruction("DUCK TO HATCH")
	status_changed.emit("You found a dinosaur egg — stand over it and hold DUCK")


func _on_body_exited(body: Node3D) -> void:
	if body != nearby_player:
		return
	nearby_player = null
	incubation_progress = 0.0
	last_second_shown = -1
	if is_instance_valid(instruction_label):
		instruction_label.visible = false


func _update_instruction(message: String) -> void:
	if is_instance_valid(instruction_label):
		instruction_label.text = message
		instruction_label.visible = true


func _hatch() -> void:
	if hatching or not is_instance_valid(nearby_player):
		return
	# Disabling monitoring emits body_exited immediately, so preserve the
	# parent before the callback clears nearby_player.
	var hatching_parent := nearby_player
	hatching = true
	monitoring = false
	instruction_label.visible = false
	hatched.emit(hatching_parent, global_position)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(egg_root, "scale", Vector3(1.35, 0.15, 1.35), 0.38).set_trans(Tween.TRANS_BACK)
	tween.tween_property(egg_root, "position:y", 0.16, 0.38)
	tween.finished.connect(egg_root.queue_free)


func get_incubation_fraction() -> float:
	return clampf(incubation_progress / maxf(incubation_seconds, 0.01), 0.0, 1.0)
