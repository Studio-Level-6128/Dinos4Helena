extends RefCounted

# Keep the route clear and deterministic on every seed. Scenic mountains remain
# outside the playable corridor; objective props are built by the event script.
func setup(controller: Node) -> void:
	for property in ["generated_dinosaurs", "generated_babies", "generated_eggs", "generated_tokens", "generated_vegetation", "generated_ponds", "generated_rivers", "generated_hills", "generated_high_ground", "generated_trees", "generated_rocks", "generated_logs", "generated_biomes"]:
		controller.get(property).clear()
	for z in range(0, 115, 14):
		for x in [-31.0, 31.0]:
			controller.generated_rocks.append({"position": Vector3(x + sin(z) * 2, 0, z), "scale": 8.0 + cos(z) * 1.5})
	if controller.active_mission_id == "sleeping_giants":
		for index in 3:
			var position := Vector3(0, 0.1, 24 + index * 24)
			controller.generated_dinosaurs.append({
				"species": "apatosaurus", "position": position,
				"pack_id": 1800 + index, "pack_slot": 0,
				"patrol_center": position, "rng_seed": controller.map_seed + 1800 + index,
				"texture_variant": index, "mission_role": "sleeping_giant"
			})
