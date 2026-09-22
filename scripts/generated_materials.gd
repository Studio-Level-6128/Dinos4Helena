extends RefCounted

# Central material factory for generated textures. Triplanar projection lets a
# small texture library cover unrelated source meshes without editing their UVs.
const DINO_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/generated/dino_skin_olive.png"),
	preload("res://assets/textures/generated/dino_skin_russet.png"),
	preload("res://assets/textures/generated/dino_skin_sand.png")
]
const BARK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/generated/bark_dark_moss.png"),
	preload("res://assets/textures/generated/bark_pale_lichen.png")
]
const ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/generated/rock_basalt_moss.png"),
	preload("res://assets/textures/generated/rock_sandstone.png")
]
const GROUND_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/generated/ground_forest_loam.png"),
	preload("res://assets/textures/generated/ground_grassland.png"),
	preload("res://assets/textures/generated/ground_floodplain.png")
]


static func dino_variant_count() -> int:
	return DINO_TEXTURES.size()


static func apply_dino_skin(model_root: Node, variant: int) -> void:
	var material := _triplanar_material(DINO_TEXTURES[posmod(variant, DINO_TEXTURES.size())], 0.94, 1.45)
	# The first surface is the hide on all six source models. Leaving the other
	# surfaces untouched preserves eyes, teeth, claws, horns, and markings.
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			mesh_instance.set_surface_override_material(0, material)


static func apply_bark(model_root: Node, variant: int) -> void:
	_apply_first_mesh_surface(model_root, _triplanar_material(BARK_TEXTURES[posmod(variant, BARK_TEXTURES.size())], 1.0, 0.72))


static func apply_rock(model_root: Node, variant: int) -> void:
	_apply_first_mesh_surface(model_root, rock_material(variant, 0.62))


static func rock_material(variant: int, texture_scale := 0.62) -> StandardMaterial3D:
	return _triplanar_material(ROCK_TEXTURES[posmod(variant, ROCK_TEXTURES.size())], 0.98, texture_scale)


static func ground_material(variant: int, texture_scale := 0.075) -> StandardMaterial3D:
	return _triplanar_material(GROUND_TEXTURES[posmod(variant, GROUND_TEXTURES.size())], 1.0, texture_scale)


static func _apply_first_mesh_surface(model_root: Node, material: Material) -> void:
	var meshes := model_root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.set_surface_override_material(0, material)


static func _triplanar_material(texture: Texture2D, roughness: float, texture_scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3.ONE * texture_scale
	return material
