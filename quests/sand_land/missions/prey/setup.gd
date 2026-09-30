extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var pond: Dictionary = controller.generated_ponds[0]
	var water: Vector3 = pond["position"]
	var away := Vector3(-water.x, 0.0, -water.z).normalized()
	if away.length_squared() < 0.1:
		away = Vector3(0.0, 0.0, 1.0)
	var herd_start := water + away * 120.0
	herd_start.x = clampf(herd_start.x, -175.0, 175.0)
	herd_start.z = clampf(herd_start.z, -175.0, 175.0)
	herd_start.y = 0.1
	var side := Vector3(-away.z, 0.0, away.x)
	controller.mission_player_start = herd_start - away * 24.0 + side * 18.0
	controller.set_meta("sand_land_water_position", water)
	controller.set_meta("sand_land_water_size", pond["size"])
	for index in 6:
		controller.generated_dinosaurs.append({
			"species": "parasaurolophus",
			"position": herd_start - away * float(index) * 2.7 + side * (float(index % 3) - 1.0) * 3.0,
			"pack_id": 1210, "pack_slot": index, "patrol_center": herd_start,
			"rng_seed": controller.map_seed + 1210 + index, "texture_variant": index,
			"mission_role": "prey_leader" if index == 0 else "prey_pack"
		})
	for index in 2:
		controller.generated_babies.append({
			"species": "parasaurolophus",
			"position": herd_start - away * (10.0 + index * 2.0) + side * (-2.5 + index * 5.0),
			"parent_role": "prey_leader", "mission_role": "prey_child",
			"texture_variant": index + 2
		})
