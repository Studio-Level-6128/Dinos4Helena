extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var baby_position := _search_position(controller)
	controller.generated_babies.append({
		"species": "apatosaurus", "position": baby_position,
		"mission_role": "lost_baby", "texture_variant": 2
	})
	for index in 4:
		var angle := TAU * float(index) / 4.0
		var position := baby_position + Vector3(cos(angle), 0.0, sin(angle)) * 48.0
		controller.generated_dinosaurs.append({
			"species": "velociraptor", "position": position,
			"pack_id": 1400, "pack_slot": index, "patrol_center": baby_position,
			"rng_seed": controller.map_seed + 1400 + index, "texture_variant": index,
			"mission_role": "lost_baby_hunter", "ignore_combat_odds": true
		})


func _search_position(controller: Node) -> Vector3:
	if not controller.generated_rocks.is_empty():
		var rock: Dictionary = controller.generated_rocks[controller.generated_rocks.size() - 1]
		return Vector3(rock["position"].x + 5.0, 0.1, rock["position"].z + 5.0)
	return Vector3(125.0, 0.1, -110.0)
