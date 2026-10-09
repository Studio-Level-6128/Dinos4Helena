extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Main scene is missing")
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var quest_grid := game.find_child("QuestTiles", true, false) as GridContainer
	if quest_grid == null or quest_grid.get_child_count() != 3:
		_fail("Quest overview must have three tiles; check quest config loading in release builds")
		return
	for quest_id in ["getting_started", "sand_land", "frozen_pass"]:
		game.call("_show_quest_page", quest_id)
		var mission_grid := game.find_child("MissionTiles", true, false) as GridContainer
		if mission_grid == null or mission_grid.get_child_count() != 6:
			_fail("%s must have six mission tiles in the packaged build" % quest_id)
			return
		for mission_id in game.mission_config.get_value("quest", "mission_ids", []):
			for key in ["image", "setup_script", "event_script"]:
				if not ResourceLoader.exists(str(game.mission_config.get_value(mission_id, key))):
					_fail("Missing packaged mission asset: %s / %s" % [mission_id, key])
					return
			for locale in ["en", "de", "fr"]:
				var audio_path := "res://assets/audio/missions/%s/%s.mp3" % [mission_id, locale]
				if not ResourceLoader.exists(audio_path):
					_fail("Missing packaged mission narration: " + audio_path)
					return
	game.quest_progress_path = "user://quest_release_smoke.cfg"
	game.quest_progress.clear()
	game.call("_dismiss_splash", true)
	game.call("_show_quest_page", "frozen_pass")
	game.call("_start_quest_mission", "frozen_pass", "tracks_in_snow")
	await process_frame
	await physics_frame
	if game.active_mission_event == null or game.active_mission_event.get("checkpoints").size() != 3:
		_fail("Frozen Pass did not boot correctly in the packaged build")
		return
	game.call("_return_to_main_menu")
	await process_frame
	print("Release quest smoke test passed: three quest tiles and six missions each")
	game.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
