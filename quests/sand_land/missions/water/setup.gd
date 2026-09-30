extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var pond: Dictionary = controller.generated_ponds[0]
	var water: Vector3 = pond["position"]
	var away := Vector3(-water.x, 0.0, -water.z).normalized()
	if away.length_squared() < 0.1:
		away = Vector3(0.0, 0.0, 1.0)
	var start := water + away * 125.0
	start.x = clampf(start.x, -178.0, 178.0)
	start.z = clampf(start.z, -178.0, 178.0)
	start.y = 0.1
	controller.mission_player_start = start
	controller.set_meta("sand_land_water_position", water)
	controller.set_meta("sand_land_water_size", pond["size"])
	var side := Vector3(-away.z, 0.0, away.x)
	for index in 5:
		controller.generated_dinosaurs.append({
			"species": "parasaurolophus",
			"position": start - away * (5.0 + index * 2.0) + side * (float(index) - 2.0) * 2.4,
			"pack_id": 1200, "pack_slot": index, "patrol_center": start,
			"rng_seed": controller.map_seed + 1200 + index, "texture_variant": index,
			"mission_role": "water_pack_leader" if index == 0 else "water_pack"
		})
	for index in 2:
		controller.generated_babies.append({
			"species": "parasaurolophus",
			"position": start - away * (11.0 + index * 2.0) + side * (-2.0 + index * 4.0),
			"parent_role": "water_pack_leader", "mission_role": "water_child",
			"texture_variant": index + 1
		})
	for index in 2:
		var hunter_position := start.lerp(water, 0.38 + float(index) * 0.25) + side * (-13.0 if index == 0 else 13.0)
		controller.generated_dinosaurs.append({
			"species": "trex", "position": hunter_position,
			"pack_id": -1, "pack_slot": -1, "patrol_center": hunter_position,
			"rng_seed": controller.map_seed + 1250 + index, "texture_variant": index,
			"mission_role": "water_hunter"
		})
