extends RefCounted


func setup(controller: Node) -> void:
	var pack_id := 900
	var positions := [Vector3(-8.0, 0.1, 24.0), Vector3(0.0, 0.1, 28.0), Vector3(8.0, 0.1, 24.0), Vector3(0.0, 0.1, 36.0)]
	for index in positions.size():
		controller.generated_dinosaurs.append({
			"species": "triceratops", "position": positions[index],
			"pack_id": pack_id, "pack_slot": index,
			"patrol_center": Vector3(0.0, 0.0, 28.0),
			"rng_seed": controller.map_seed + 700 + index,
			"texture_variant": index, "mission_role": "family_pack"
		})

