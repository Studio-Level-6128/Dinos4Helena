extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var pond: Dictionary = controller.generated_ponds[0]
	var water: Vector3 = pond["position"]
	var size: Vector2 = pond["size"]
	var radius := maxf(size.x, size.y) * 0.5 + 7.0
	controller.mission_player_start = water + Vector3(0.0, 0.1, radius)
	var rival_position := water + Vector3(0.0, 0.1, -radius)
	controller.generated_dinosaurs.append({
		"species": "trex", "position": rival_position,
		"pack_id": -1, "pack_slot": -1, "patrol_center": water,
		"rng_seed": controller.map_seed + 1300, "texture_variant": 3,
		"mission_role": "kingpin_rival", "can_retreat": false,
		"ignore_combat_odds": true, "allow_same_species_combat": true
	})
