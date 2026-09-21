extends Node3D

var dino: Node3D


func _ready() -> void:
	_build_world()


func _process(delta: float) -> void:
	if dino:
		dino.rotate_y(delta * 0.6)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("76b7d8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.1, 7.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0))
	add_child(camera)

	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(12.0, 0.25, 12.0)
	ground.mesh = ground_mesh
	ground.position.y = -0.125
	ground.material_override = _material(Color("75a95a"))
	add_child(ground)

	dino = Node3D.new()
	dino.name = "DinoPlaceholder"
	add_child(dino)

	_add_part(dino, "Body", Vector3(0.0, 1.15, 0.0), Vector3(1.65, 0.9, 0.75), Color("52a85f"))
	_add_part(dino, "Head", Vector3(0.85, 1.75, 0.0), Vector3(0.8, 0.7, 0.65), Color("62bd6d"))
	_add_part(dino, "Tail", Vector3(-1.05, 1.25, 0.0), Vector3(1.2, 0.35, 0.35), Color("4c9d59"), -18.0)
	_add_part(dino, "LeftLeg", Vector3(0.45, 0.45, 0.35), Vector3(0.3, 0.9, 0.3), Color("438f50"))
	_add_part(dino, "RightLeg", Vector3(0.45, 0.45, -0.35), Vector3(0.3, 0.9, 0.3), Color("438f50"))


func _add_part(parent: Node3D, part_name: String, part_position: Vector3, size: Vector3, color: Color, rotation_z := 0.0) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.name = part_name
	part.mesh = mesh
	part.position = part_position
	part.rotation_degrees.z = rotation_z
	part.material_override = _material(color)
	parent.add_child(part)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

