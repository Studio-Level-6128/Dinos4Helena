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
	if quest_grid == null or quest_grid.get_child_count() != 2:
		_fail("Quest overview must have two tiles; check quest config loading in release builds")
		return
	for quest_id in ["getting_started", "sand_land"]:
		game.call("_show_quest_page", quest_id)
		var mission_grid := game.find_child("MissionTiles", true, false) as GridContainer
		if mission_grid == null or mission_grid.get_child_count() != 6:
			_fail("%s must have six mission tiles in the packaged build" % quest_id)
			return
	print("Release quest smoke test passed: two quest tiles and six missions each")
	game.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
