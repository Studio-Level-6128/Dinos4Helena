extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_dinosaurs.clear()
	controller.generated_babies.clear()
	var baby_position := _search_position(controller)
	var minimum_distance := float(controller.mission_config.get_value("lost_baby", "hunter_min_distance", 200.0))
	var player_distance := float(controller.mission_config.get_value("lost_baby", "player_start_distance", 45.0))
	var toward_center := Vector3(-baby_position.x, 0.0, -baby_position.z).normalized()
	if toward_center.length_squared() < 0.1:
		toward_center = Vector3.BACK
	controller.mission_player_start = baby_position + toward_center * player_distance
	controller.generated_babies.append({
		"species": "apatosaurus", "position": baby_position,
		"mission_role": "lost_baby", "texture_variant": 2
	})
	# Use only in-bounds points on the distant ring. Clamping individual points
	# to the map edge could silently reduce their distance from the baby.
	var positions: Array[Vector3] = []
	for step in 64:
		var angle := TAU * float(step) / 64.0
		var candidate := baby_position + Vector3(cos(angle), 0.0, sin(angle)) * minimum_distance
		if absf(candidate.x) <= 184.0 and absf(candidate.z) <= 184.0:
			positions.append(candidate)
	for index in 4:
		var position := positions[index * positions.size() / 4]
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
