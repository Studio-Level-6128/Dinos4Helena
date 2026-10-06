extends Node3D

var energy_remaining := 55.0
var source_dinosaur: Node3D


func _ready() -> void:
	add_to_group("edible_meat")
	set_meta("energy_remaining", energy_remaining)
	set_meta("source_dinosaur", source_dinosaur)
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
	add_child(mesh_instance)
