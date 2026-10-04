extends Node3D

# A bright, non-colliding token above every human-controlled dinosaur.
var token_material: StandardMaterial3D


func _ready() -> void:
	name = "HumanPlayerMarker"
	var token := MeshInstance3D.new()
	token.name = "ColorToken"
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	token.mesh = sphere
	token_material = StandardMaterial3D.new()
	token_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	token_material.emission_enabled = true
	token_material.emission_energy_multiplier = 2.0
	token.material_override = token_material
	add_child(token)
	set_color("#6ea8fe")


func set_color(hex: String) -> void:
	if token_material == null:
		return
	var tint := Color(hex)
	token_material.albedo_color = tint
	token_material.emission = tint
