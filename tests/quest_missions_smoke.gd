extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var progress_path := "user://quest_progress_missions_smoke.cfg"
	var absolute_progress_path := ProjectSettings.globalize_path(progress_path)
	if FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	game.quest_progress_path = progress_path
	game.quest_progress.clear()
	game.call("_dismiss_splash", true)
	game.call("_show_quest_page", "getting_started")
	var mission_ids: Array = game.mission_config.get_value("quest", "mission_ids", [])

	for index in mission_ids.size():
		var mission_id := str(mission_ids[index])
		if index > 0:
			game.call("_mark_mission_completed", "getting_started", str(mission_ids[index - 1]))
		game.call("_start_quest_mission", "getting_started", mission_id)
		await process_frame
		await physics_frame
		assert(game.active_mission_id == mission_id, "%s did not become active" % mission_id)
		assert(game.selected_map_theme == "grassland", "%s did not use grassland" % mission_id)
		assert(is_instance_valid(game.player), "%s did not create its player" % mission_id)
		assert(is_instance_valid(game.active_mission_event), "%s did not create its event loop" % mission_id)
		match mission_id:
			"family":
				assert(_role_count("family_pack") == 4, "Family did not create its Triceratops pack")
			"breed":
				assert(game.generated_eggs.size() == 2, "Breed did not create exactly two eggs")
			"hunt":
				assert(_role_count("hunt_prey") == 1, "Hunt did not create its marked prey")
			"defense":
				assert(_role_count("defense_pack") == 3, "Defense did not create its pack")
				var attackers := get_nodes_in_group("npc_dinosaur").filter(func(npc: Node) -> bool: return str(npc.get_meta("mission_role", "")) == "defense_attacker")
				assert(attackers.size() == 1, "Defense did not create one attacker")
				assert(not bool(attackers[0].get("can_retreat")) and bool(attackers[0].get("ignore_combat_odds")), "Defense attacker can still avoid the fight")
		game.call("_return_to_main_menu")
		await process_frame
		await process_frame

	print("Quest mission smoke test passed: all six setup and event scripts boot correctly")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(absolute_progress_path)
	quit()


func _role_count(role: String) -> int:
	var count := 0
	for npc in get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == role:
			count += 1
	return count
