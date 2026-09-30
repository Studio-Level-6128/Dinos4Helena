extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var baby_position := _search_position(controller)
	controller.generated_babies.append({
		"species": "apatosaurus", "position": baby_position,
		"mission_role": "hunted_baby", "texture_variant": 1
	})
	var start := baby_position + Vector3(-90.0, 0.0, 35.0)
	start.x = clampf(start.x, -175.0, 175.0)
	start.z = clampf(start.z, -175.0, 175.0)
	start.y = 0.1
	controller.mission_player_start = start
	for index in 3:
		controller.generated_dinosaurs.append({
			"species": "velociraptor",
			"position": start + Vector3(-3.0 + index * 3.0, 0.0, 5.0 + index * 2.0),
			"pack_id": 1500, "pack_slot": index, "patrol_center": start,
			"rng_seed": controller.map_seed + 1500 + index, "texture_variant": index,
			"mission_role": "baby_hunter_pack", "ignore_combat_odds": true
		})
	var herd_start := baby_position + Vector3(85.0, 0.0, -30.0)
	herd_start.x = clampf(herd_start.x, -175.0, 175.0)
	herd_start.z = clampf(herd_start.z, -175.0, 175.0)
	for index in 4:
		controller.generated_dinosaurs.append({
			"species": "apatosaurus",
			"position": herd_start + Vector3(index * 4.0, 0.0, index * 3.0),
			"pack_id": 1510, "pack_slot": index, "patrol_center": herd_start,
			"rng_seed": controller.map_seed + 1510 + index, "texture_variant": index,
			"mission_role": "baby_rescue_leader" if index == 0 else "baby_rescue_pack"
		})


func _search_position(controller: Node) -> Vector3:
	if not controller.generated_rocks.is_empty():
		var rock: Dictionary = controller.generated_rocks[controller.generated_rocks.size() - 1]
		return Vector3(rock["position"].x + 5.0, 0.1, rock["position"].z + 5.0)
	return Vector3(105.0, 0.1, -95.0)
