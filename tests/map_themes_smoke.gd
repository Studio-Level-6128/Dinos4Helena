extends SceneTree

const THEMES := ["grassland", "desert", "winter", "volcano"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	app._dismiss_splash(true)
	assert(app.map_theme_buttons.size() == THEMES.size(), "Free Game theme cards are incomplete")
	var desert_button := app.map_theme_buttons["desert"] as Button
	desert_button.pressed.emit()
	assert(app.selected_map_theme == "desert", "Theme card did not update the selected topic")
	assert(desert_button.text.begins_with("✓"), "Selected theme card has no visual marker")
	assert((desert_button.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.ends_with("theme-desert.png"), "Desert preview image is missing")

	await _start_theme(app, "desert")
	assert(app.generated_rivers.is_empty(), "Desert should contain water holes instead of rivers")
	assert(app.generated_ponds.size() >= 2, "Desert has too few water holes")
	assert(app.generated_trees.size() <= 34, "Desert vegetation is not sparse")
	assert(app.generated_vegetation.size() < 180, "Desert ground vegetation is too dense")
	assert(app.generated_biomes.any(func(biome: Dictionary) -> bool: return biome["type"] == "oasis"), "Desert has no oasis vegetation areas")
	_assert_ground_texture(app, "ground_desert_sand.png")
	await _close_theme(app)

	await _start_theme(app, "winter")
	_assert_ground_texture(app, "ground_winter_snow.png")
	assert(app.get_node_or_null("PrehistoricWorld/SnowFootprints") != null, "Winter footprint renderer is missing")
	var footprints := app.get_node("PrehistoricWorld/SnowFootprints")
	footprints.call("record_footprint", app.player)
	assert(footprints.get("footprint_count") == 1, "Snow footprint was not recorded")
	assert(app.call("_water_surface_material") is StandardMaterial3D, "Winter water is not frozen")
	var winter_plant: Node = app.world_root.get_node_or_null("Fern")
	if winter_plant == null:
		for candidate in app.get_tree().get_nodes_in_group("edible_plant"):
			winter_plant = candidate
			break
	assert(winter_plant != null, "Winter vegetation is missing")
	var winter_meshes: Array[Node] = winter_plant.find_children("*", "MeshInstance3D", true, false)
	assert(not winter_meshes.is_empty(), "Winter plant mesh is missing")
	var snow_material := (winter_meshes[0] as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	assert(snow_material != null and snow_material.albedo_texture.resource_path.ends_with("ground_winter_snow.png"), "Winter plants are not snow-covered")
	await _close_theme(app)

	await _start_theme(app, "volcano")
	_assert_ground_texture(app, "ground_volcanic_basalt.png")
	var volcano := app.get_node_or_null("PrehistoricWorld/CentralVolcano") as StaticBody3D
	assert(volcano != null, "Central volcano is missing")
	var shell := volcano.get_node_or_null("TexturedVolcanoShell") as MeshInstance3D
	assert(shell != null and shell.mesh is ArrayMesh, "Volcano does not use the complex cratered mesh")
	var shell_material := shell.material_override as StandardMaterial3D
	assert(shell_material != null and shell_material.albedo_texture.resource_path.ends_with("ground_volcanic_basalt.png"), "Volcano shell is missing its basalt texture")
	var crater_lava := volcano.get_node_or_null("CraterLava") as MeshInstance3D
	assert(crater_lava != null and crater_lava.position.y > 25.0, "Volcano crater is not filled with elevated lava")
	assert(volcano.find_children("*", "CollisionShape3D", true, false).size() >= 5, "Volcano does not have a solid layered collider")
	assert(app.generated_lava_streams.size() >= 4, "Volcano has too few lava streams")
	var lava_meshes: Array[Node] = (app.get_tree().get_nodes_in_group("lava_hazard")[0] as Area3D).find_children("*", "MeshInstance3D", true, false)
	var first_lava_mesh := lava_meshes[0] as MeshInstance3D
	var lava_bounds := first_lava_mesh.mesh.get_aabb()
	assert(lava_bounds.position.y + lava_bounds.size.y > 20.0, "Lava streams do not descend from the volcano slopes")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(60.0, 2.0, 0.0), Vector3(0.0, 2.0, 0.0), 1)
	var volcano_hit: Dictionary = app.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not volcano_hit.is_empty() and volcano_hit["collider"] == volcano, "Dinosaurs can still pass through the volcano footprint")
	var hazards := app.get_tree().get_nodes_in_group("lava_hazard")
	assert(hazards.size() == app.generated_lava_streams.size(), "Lava hazard geometry is incomplete")
	var health_before: int = app.player.health
	hazards[0].call("apply_damage_to", app.player)
	assert(app.player.health < health_before, "Lava did not hurt the player")
	var lava_point: Vector2 = app.generated_lava_streams[0]["points"][5]
	assert(app.call("_is_position_in_lava", lava_point, 0.5), "Lava avoidance query missed a stream")
	assert(app.player.global_position.distance_to(Vector3.ZERO) > 40.0, "Player spawned inside the volcano")
	await _close_theme(app)

	print("Map themes smoke test passed: selector, desert, winter footprints, frozen water, volcano, and lava damage")
	app.queue_free()
	await process_frame
	quit()


func _start_theme(app: Node, theme: String) -> void:
	app.selected_map_theme = theme
	app.seed_input.text = "314159"
	app._start_game("trex")
	await process_frame
	await physics_frame
	assert(app.selected_map_theme == theme, "Wrong theme started: " + theme)


func _close_theme(app: Node) -> void:
	app._return_to_main_menu()
	await process_frame
	await process_frame


func _assert_ground_texture(app: Node, texture_name: String) -> void:
	var ground_mesh := app.get_node("PrehistoricWorld/Ground").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := ground_mesh.material_override as StandardMaterial3D
	assert(material != null and material.albedo_texture.resource_path.ends_with(texture_name), "Wrong ground texture for " + app.selected_map_theme)
