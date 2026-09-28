extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var quest_config := ConfigFile.new()
	assert(quest_config.load("res://config/quests.cfg") == OK, "Quest catalog did not load")
	var quest_ids: Array = quest_config.get_value("quests", "quest_ids", [])
	assert(quest_ids == ["getting_started"], "Getting Started quest is missing from the catalog")
	assert(ResourceLoader.exists(str(quest_config.get_value("quests", "overview_background"))), "Quest overview background is missing")

	var missions := ConfigFile.new()
	assert(missions.load(str(quest_config.get_value("getting_started", "mission_config"))) == OK, "Mission config did not load")
	var mission_ids: Array = missions.get_value("quest", "mission_ids", [])
	assert(mission_ids.size() == 6, "Getting Started should contain six missions")
	var expected_dinosaurs := ["triceratops", "triceratops", "triceratops", "apatosaurus", "trex", "stegosaurus"]
	for index in mission_ids.size():
		var mission_id := str(mission_ids[index])
		assert(str(missions.get_value(mission_id, "map_theme")) == "grassland", "%s is not a grassland mission" % mission_id)
		assert(str(missions.get_value(mission_id, "dinosaur")) == expected_dinosaurs[index], "%s uses the wrong dinosaur" % mission_id)
		for key in ["image", "setup_script", "event_script"]:
			assert(ResourceLoader.exists(str(missions.get_value(mission_id, key))), "%s has a missing %s" % [mission_id, key])

	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var progress_path := "user://quest_progress_ui_smoke.cfg"
	var absolute_progress_path := ProjectSettings.globalize_path(progress_path)
	if FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	game.quest_progress_path = progress_path
	game.quest_progress.clear()
	game.call("_dismiss_splash", true)
	var quests_tile := game.find_child("QuestsTile", true, false) as Button
	assert(is_instance_valid(quests_tile) and not quests_tile.disabled, "Quests tile is not enabled")
	assert(is_instance_valid(quests_tile.get_node_or_null("TileRim")), "Landing quest tile has no rim")
	assert(is_instance_valid(game.find_child("FreeGameTile", true, false).get_node_or_null("TileRim")), "Landing Free Game tile has no rim")
	game.call("_show_quest_overview")
	assert(game.quest_overview_page.visible, "Quest overview did not open")
	var quest_button := game.find_child("Quest_getting_started", true, false) as Button
	assert(is_instance_valid(quest_button), "Getting Started tile is missing")
	assert(is_instance_valid(quest_button.get_node_or_null("TileRim")), "Quest overview tile has no rim")
	game.call("_show_quest_page", "getting_started")
	assert(game.quest_detail_page.visible, "Getting Started page did not open")
	for index in mission_ids.size():
		var mission_id := str(mission_ids[index])
		var mission_button := game.find_child("Mission_%s" % mission_id, true, false) as Button
		assert(is_instance_valid(mission_button), "Mission tile is missing: %s" % mission_id)
		assert(is_instance_valid(mission_button.get_node_or_null("TileRim")), "Mission tile has no rim: %s" % mission_id)
		assert(mission_button.disabled == (index > 0), "Initial mission lock state is wrong: %s" % mission_id)

	game.call("_mark_mission_completed", "getting_started", "dinner_time")
	var saved_progress := ConfigFile.new()
	assert(saved_progress.load(progress_path) == OK and bool(saved_progress.get_value("getting_started", "dinner_time", false)), "Mission completion was not persisted")
	game.call("_show_quest_page", "getting_started")
	var dinner_button := game.find_child("Mission_dinner_time", true, false) as Button
	var explore_button := game.find_child("Mission_explore_the_world", true, false) as Button
	var family_button := game.find_child("Mission_family", true, false) as Button
	assert("COMPLETED" in dinner_button.text and not dinner_button.disabled, "Completed mission is not marked")
	assert(not explore_button.disabled, "Completing mission 1 did not unlock mission 2")
	assert(family_button.disabled, "Mission 3 unlocked before mission 2 was completed")

	game.call("_start_quest_mission", "getting_started", "dinner_time")
	await process_frame
	await physics_frame
	assert(game.selected_dino_id == "triceratops", "Dinner Time did not select Triceratops")
	assert(game.selected_map_theme == "grassland", "Dinner Time did not select grassland")
	assert(is_instance_valid(game.player), "Mission player was not created")
	assert(is_instance_valid(game.active_mission_event), "Mission event loop was not created")
	assert(is_instance_valid(game.mission_objective_label), "Mission objective HUD is missing")
	assert(game.generated_vegetation.size() >= 2, "Dinner Time setup did not populate edible plants")

	print("Quest smoke test passed: catalog, pages, six missions, setup, event loop, and HUD")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	quit()
