extends RefCounted

# Central material factory for generated textures. Triplanar projection lets a
# small texture library cover unrelated source meshes without editing their UVs.
const DINO_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/generated/dino_skin_olive.png"),
	preload("res://assets/textures/generated/dino_skin_russet.png"),
	preload("res://assets/textures/generated/dino_skin_sand.png")
]
# Spinosaurus keeps the single-surface, single-draw-call layout of the CC0
# source model, but uses a dedicated high-detail hide and normal map. Tinting
# one neutral texture supplies the three visual variants without loading three
# separate albedo maps on memory-constrained phones.
const SPINOSAURUS_SKIN: Texture2D = preload("res://assets/textures/generated/spinosaurus_skin.png")
const SPINOSAURUS_NORMAL: Texture2D = preload("res://assets/textures/generated/spinosaurus_skin_normal.png")
const SPINOSAURUS_TINTS: Array[Color] = [
	Color("9aaa82"),
	Color("bd856f"),
	Color("c8b68f")
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
const THEME_GROUND_TEXTURES := {
	"desert": preload("res://assets/textures/generated/ground_desert_sand.png"),
	"winter": preload("res://assets/textures/generated/ground_winter_snow.png"),
	"volcano": preload("res://assets/textures/generated/ground_volcanic_basalt.png")
}


static func dino_variant_count() -> int:
	return DINO_TEXTURES.size()


static func apply_dino_skin(model_root: Node, variant: int, species_id := "") -> void:
	var material: StandardMaterial3D
	if species_id == "spinosaurus":
		material = _spinosaurus_material(variant)
	else:
		material = _triplanar_material(DINO_TEXTURES[posmod(variant, DINO_TEXTURES.size())], 0.94, 1.45)
	# The first surface is the hide on all seven source models. Leaving the other
	# surfaces untouched preserves eyes, teeth, claws, horns, and markings.
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			mesh_instance.set_surface_override_material(0, material)


static func _spinosaurus_material(variant: int) -> StandardMaterial3D:
	var material := _triplanar_material(SPINOSAURUS_SKIN, 0.82, 1.7)
	material.albedo_color = SPINOSAURUS_TINTS[posmod(variant, SPINOSAURUS_TINTS.size())]
	material.normal_enabled = true
	material.normal_texture = SPINOSAURUS_NORMAL
	material.normal_scale = 0.58
	# A small specular response makes the scales readable in sunlight without
	# giving the animal a wet or plastic appearance.
	material.metallic_specular = 0.32
	return material


static func apply_bark(model_root: Node, variant: int) -> void:
	_apply_first_mesh_surface(model_root, _triplanar_material(BARK_TEXTURES[posmod(variant, BARK_TEXTURES.size())], 1.0, 0.72))


static func apply_rock(model_root: Node, variant: int) -> void:
	_apply_first_mesh_surface(model_root, rock_material(variant, 0.62))


static func rock_material(variant: int, texture_scale := 0.62) -> StandardMaterial3D:
	return _triplanar_material(ROCK_TEXTURES[posmod(variant, ROCK_TEXTURES.size())], 0.98, texture_scale)


static func ground_material(variant: int, texture_scale := 0.075) -> StandardMaterial3D:
	return _triplanar_material(GROUND_TEXTURES[posmod(variant, GROUND_TEXTURES.size())], 1.0, texture_scale)


static func theme_ground_material(theme: String, variant: int, texture_scale := 0.075) -> StandardMaterial3D:
	if theme == "grassland" or not THEME_GROUND_TEXTURES.has(theme):
		return ground_material(variant, texture_scale)
	var roughness := 0.96
	if theme == "winter":
		roughness = 0.78
	elif theme == "volcano":
		roughness = 0.90
	var material := _triplanar_material(THEME_GROUND_TEXTURES[theme], roughness, texture_scale)
	material.albedo_color = [Color("fffaf0"), Color("f0f6fa"), Color("e4edf2")][posmod(variant, 3)] if theme == "winter" else Color.WHITE
	material.metallic_specular = 0.38 if theme == "winter" else 0.22
	return material


static func tint_environment(model_root: Node, theme: String, kind: String) -> void:
	if theme == "grassland" or (theme == "volcano" and kind != "rock"):
		return
	if theme == "winter":
		_override_all_mesh_surfaces(model_root, _triplanar_material(THEME_GROUND_TEXTURES["winter"], 0.78, 1.25))
		return
	var tint := Color("a8a56f") if theme == "desert" else Color("4b4541")
	_tint_all_mesh_surfaces(model_root, tint, 0.92)


static func _apply_first_mesh_surface(model_root: Node, material: Material) -> void:
	var meshes := model_root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		return
	var mesh_instance := meshes[0] as MeshInstance3D
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		mesh_instance.set_surface_override_material(0, material)


static func _override_all_mesh_surfaces(model_root: Node, material: Material) -> void:
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface_index, material)


static func _tint_all_mesh_surfaces(model_root: Node, tint: Color, roughness: float) -> void:
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var tinted := source.duplicate() as StandardMaterial3D
				tinted.albedo_color *= tint
				tinted.roughness = roughness
				mesh_instance.set_surface_override_material(surface_index, tinted)
			elif source == null:
				var fallback := StandardMaterial3D.new()
				fallback.albedo_color = tint
				fallback.roughness = roughness
				mesh_instance.set_surface_override_material(surface_index, fallback)


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
