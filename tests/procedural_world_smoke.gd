extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	assert(app.seed_input.text.length() == 6 and int(app.seed_input.text) >= 100000, "Automatic seed is not six digits")

	app.seed_input.text = "246810"
	app._start_game("trex")
	await physics_frame
	assert(app.map_seed == 246810, "Manual seed was not applied")
	var first_signature := _layout_signature(app)
	assert(app.generated_ponds.size() >= 3, "Procedural world has too few lakes")
	assert(app.generated_rivers.size() >= 1, "Procedural world has no river")
	assert(app.generated_biomes.size() >= 5, "Procedural world has too few biomes")
	assert(app.generated_trees.size() >= 118, "Procedural world has too few trees")
	assert(app.generated_rocks.size() >= 52, "Procedural world has too few grounded rocks")
	assert(app.generated_vegetation.size() >= 580, "Procedural world has too little ground vegetation")
	var poison_layout_count := 0
	for vegetation in app.generated_vegetation:
		if vegetation["type"] == "poisonous":
			poison_layout_count += 1
	assert(poison_layout_count == 16, "Seeded world has the wrong number of poisonous plants")
	assert(app.generated_logs.size() >= 18, "Procedural world has too few fallen logs")
	assert(app.generated_high_ground.size() >= 10, "Procedural world has too little jumpable high ground")
	assert(app.generated_dinosaurs.size() >= 16, "Procedural world has too little wildlife")
	assert(app.generated_tokens.size() == 30, "Procedural world has the wrong number of power-up tokens")
	assert(app.generated_eggs.size() == 6, "Procedural world has the wrong number of hidden egg nests")
	var texture_variants := {}
	for dinosaur in app.generated_dinosaurs:
		texture_variants[dinosaur["texture_variant"]] = true
	assert(texture_variants.size() >= 2, "Wildlife does not use varied generated skins")
	assert(app.generated_clouds.size() >= 8, "Procedural world has too few clouds")
	assert(app.environment_models.size() == 11, "CC0 environment model library did not load")
	assert(app.get_node_or_null("PrehistoricWorld/Sun") != null, "World has no sun")
	assert(app.get_node_or_null("PrehistoricWorld/Clouds") != null, "World has no cloud layer")
	assert(app.get_node_or_null("PrehistoricWorld/River") != null, "River geometry was not created")
	assert(app.get_node_or_null("PrehistoricWorld/Lake") != null, "Lake geometry was not created")
	assert(app.get_node_or_null("PrehistoricWorld/JumpableHighGround") != null, "Jumpable high ground was not created")
	assert(app.get_node_or_null("PrehistoricWorld/FallenLogObstacle") != null, "Fallen logs were not created")
	var first_rock: StaticBody3D = app.get_node("PrehistoricWorld/RockObstacle")
	assert(is_zero_approx(first_rock.position.y), "Rock model is floating above the ground")
	var rock_collision: CollisionShape3D = first_rock.find_children("*", "CollisionShape3D", true, false)[0]
	assert(rock_collision.position.y > 0.0, "Rock collision is not seated above ground level")
	var ground_mesh := app.get_node("PrehistoricWorld/Ground").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var ground_material := ground_mesh.material_override as StandardMaterial3D
	assert(ground_material != null and ground_material.albedo_texture != null, "Generated ground texture was not applied")
	var player_mesh := app.player.model_root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin_material := player_mesh.get_surface_override_material(0) as StandardMaterial3D
	assert(skin_material != null and skin_material.albedo_texture != null, "Generated dinosaur skin was not applied")
	app._return_to_main_menu()
	await process_frame

	app.seed_input.text = "246810"
	app._start_game("apatosaurus")
	await physics_frame
	assert(_layout_signature(app) == first_signature, "The same seed did not reproduce the same world")
	app._return_to_main_menu()
	await process_frame

	app.seed_input.text = "975310"
	app._start_game("trex")
	await physics_frame
	assert(_layout_signature(app) != first_signature, "Different seeds generated the same world")

	print("Procedural world smoke test passed: six-digit seeds are deterministic and varied")
	app.queue_free()
	await process_frame
	quit()


func _layout_signature(app: Node) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(app.generated_ponds),
		str(app.generated_rivers),
		str(app.generated_biomes),
		str(app.generated_hills),
		str(app.generated_high_ground),
		str(app.generated_trees),
		str(app.generated_rocks),
		str(app.generated_logs),
		str(app.generated_vegetation),
		str(app.generated_dinosaurs),
		str(app.generated_tokens),
		str(app.generated_eggs),
		str(app.generated_clouds)
	]
