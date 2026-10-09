extends RefCounted

func setup(controller: Node) -> void:
	# Keep the volcano itself, but reserve a deterministic route north of it.
	for property in ["generated_dinosaurs", "generated_babies", "generated_eggs", "generated_tokens", "generated_vegetation", "generated_ponds", "generated_rivers", "generated_hills", "generated_high_ground", "generated_trees", "generated_rocks", "generated_logs", "generated_biomes", "generated_lava_streams"]:
		controller.get(property).clear()
	controller.mission_player_start = Vector3(0, 0.1, 72)
	for z in range(70, 170, 14):
		for x in [-31.0, 31.0]:
			controller.generated_rocks.append({"position": Vector3(x, 0, z), "scale": 7.0 + sin(z)})
	# Scenic flowing lava stays outside the required route.
	for x in [-45.0, 45.0]:
		controller.generated_lava_streams.append({"points": PackedVector2Array([Vector2(x, 65), Vector2(x, 165)]), "width": 8.0, "damage_per_second": 12})
