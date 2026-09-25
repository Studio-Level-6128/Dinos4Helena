extends MultiMeshInstance3D

# All dinosaurs share one capped MultiMesh footprint ring. Even a busy winter
# map therefore renders every visible track with one draw call and fixed memory.
const MAX_FOOTPRINTS := 256
const SAMPLE_INTERVAL := 0.16

var sample_time := 0.0
var next_instance := 0
var footprint_count := 0
var last_positions: Dictionary = {}


func _ready() -> void:
	name = "SnowFootprints"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var footprint_material := StandardMaterial3D.new()
	footprint_material.albedo_color = Color(0.20, 0.29, 0.36, 0.42)
	footprint_material.roughness = 1.0
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var footprint_mesh := _build_footprint_mesh()
	footprint_mesh.surface_set_material(0, footprint_material)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.instance_count = MAX_FOOTPRINTS
	instances.visible_instance_count = 0
	instances.mesh = footprint_mesh
	multimesh = instances


func _process(delta: float) -> void:
	sample_time -= delta
	if sample_time > 0.0:
		return
	sample_time = SAMPLE_INTERVAL
	var actors: Array[Node] = []
	actors.append_array(get_tree().get_nodes_in_group("player_dinosaur"))
	actors.append_array(get_tree().get_nodes_in_group("npc_dinosaur"))
	for candidate in actors:
		if not candidate is CharacterBody3D or bool(candidate.get("dead")):
			continue
		var actor := candidate as CharacterBody3D
		if not actor.is_on_floor():
			continue
		var actor_id := actor.get_instance_id()
		var flat_position := Vector2(actor.global_position.x, actor.global_position.z)
		if not last_positions.has(actor_id):
			last_positions[actor_id] = flat_position
			continue
		var stride := maxf(float(actor.get("collision_radius")) * 1.65, 1.15)
		if flat_position.distance_to(last_positions[actor_id]) < stride:
			continue
		last_positions[actor_id] = flat_position
		record_footprint(actor)


func record_footprint(actor: Node3D) -> void:
	if multimesh == null:
		return
	var radius := clampf(float(actor.get("collision_radius")), 0.45, 2.0)
	var basis := Basis(Vector3.UP, actor.global_rotation.y).scaled(Vector3.ONE * radius)
	var footprint_transform := Transform3D(basis, Vector3(actor.global_position.x, 0.022, actor.global_position.z))
	multimesh.set_instance_transform(next_instance, footprint_transform)
	next_instance = (next_instance + 1) % MAX_FOOTPRINTS
	footprint_count = mini(footprint_count + 1, MAX_FOOTPRINTS)
	multimesh.visible_instance_count = footprint_count


func _build_footprint_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for side in [-0.32, 0.32]:
		var palm_center := Vector3(side, 0.0, 0.08)
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([
			palm_center + Vector3(-0.20, 0.0, 0.19),
			palm_center + Vector3(0.20, 0.0, 0.19),
			palm_center + Vector3(0.0, 0.0, -0.25)
		]))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
		for toe in [-0.18, 0.0, 0.18]:
			base = vertices.size()
			vertices.append_array(PackedVector3Array([
				Vector3(side + toe - 0.075, 0.0, -0.15),
				Vector3(side + toe + 0.075, 0.0, -0.15),
				Vector3(side + toe * 1.28, 0.0, -0.52)
			]))
			indices.append_array(PackedInt32Array([base, base + 1, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
