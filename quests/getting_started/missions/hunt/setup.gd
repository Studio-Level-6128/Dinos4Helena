extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.append({
		"species": "parasaurolophus", "position": Vector3(0.0, 0.1, 34.0),
		"pack_id": 910, "pack_slot": 0, "patrol_center": Vector3(0.0, 0.0, 34.0),
		"rng_seed": controller.map_seed + 910, "texture_variant": 1,
		"mission_role": "hunt_prey"
	})

