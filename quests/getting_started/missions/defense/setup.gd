extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	var pack_positions := [Vector3(-7.0, 0.1, 9.0), Vector3(7.0, 0.1, 10.0), Vector3(0.0, 0.1, 17.0)]
	for index in pack_positions.size():
		controller.generated_dinosaurs.append({
			"species": "stegosaurus", "position": pack_positions[index],
			"pack_id": 920, "pack_slot": index, "patrol_center": Vector3(0.0, 0.0, 12.0),
			"rng_seed": controller.map_seed + 920 + index, "texture_variant": index,
			"mission_role": "defense_pack"
		})
	controller.generated_dinosaurs.append({
		"species": "velociraptor", "position": Vector3(0.0, 0.1, 34.0),
		"pack_id": -1, "pack_slot": -1, "patrol_center": Vector3(0.0, 0.0, 28.0),
		"rng_seed": controller.map_seed + 999, "texture_variant": 2,
		"mission_role": "defense_attacker", "can_retreat": false, "ignore_combat_odds": true
	})
