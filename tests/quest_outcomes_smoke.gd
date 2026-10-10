extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.quest_progress_path = "user://quest_outcomes_smoke.cfg"
	game.quest_progress.clear()
	for quest_id in ["getting_started", "sand_land"]:
		game.call("_show_quest_page", quest_id)
		for mission_id in game.mission_config.get_value("quest", "mission_ids", []):
			game.quest_progress.set_value(quest_id, str(mission_id), true)
	for quest_id in ["getting_started", "sand_land"]:
		game.call("_show_quest_page", quest_id)
		var mission_ids: Array = game.mission_config.get_value("quest", "mission_ids", [])
		for mission_id_value in mission_ids:
			var mission_id := str(mission_id_value)
			await _start(game, quest_id, mission_id)
			_check_win(game, quest_id, mission_id)
			assert(game.active_mission_event.ended, "%s did not complete" % mission_id)
			assert(game.find_child("MissionResult", true, false) != null, "%s showed no result" % mission_id)
			await _leave(game)
	for scenario in [
		["getting_started", "family"], ["getting_started", "breed"],
		["getting_started", "hunt"], ["getting_started", "defense"],
		["sand_land", "water"], ["sand_land", "prey"], ["sand_land", "lost_baby"],
		["sand_land", "eat_the_baby"]
	]:
		await _start(game, scenario[0], scenario[1])
		_check_loss(game, scenario[1])
		assert(game.active_mission_event.ended, "%s did not fail" % scenario[1])
		assert(game.find_child("MissionResult", true, false) != null, "%s showed no failure" % scenario[1])
		await _leave(game)
	for scenario in [["getting_started", "hunt", "hunt_prey"], ["sand_land", "eat_the_baby", "hunted_baby"]]:
		await _start(game, scenario[0], scenario[1])
		var target := _role(scenario[2])
		target.take_damage(999, game.player)
		for meat in get_nodes_in_group("edible_meat"):
			if meat.get_meta("source_dinosaur", null) == target:
				meat.queue_free()
		await process_frame
		game.active_mission_event.call("_process", 0.1)
		assert(game.active_mission_event.ended, "%s did not fail after its meat was lost" % scenario[1])
		await _leave(game)
	print("Quest outcome smoke test passed: all twelve wins and ten mission-specific failures")
	game.queue_free()
	await process_frame
	var path := ProjectSettings.globalize_path("user://quest_outcomes_smoke.cfg")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	quit()


func _start(game: Node, quest_id: String, mission_id: String) -> void:
	game.call("_show_quest_page", quest_id)
	game.call("_start_quest_mission", quest_id, mission_id)
	await process_frame
	await physics_frame
	assert(game.active_mission_id == mission_id, "%s did not start" % mission_id)
	assert(is_instance_valid(game.active_mission_event), "%s has no event" % mission_id)


func _leave(game: Node) -> void:
	game.call("_return_to_main_menu")
	await process_frame
	await process_frame


func _role(role: String) -> CharacterBody3D:
	for npc in get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == role:
			return npc
	return null


func _check_win(game: Node, quest_id: String, mission_id: String) -> void:
	var event: Node = game.active_mission_event
	match mission_id:
		"dinner_time":
			game.player.food_consumed.emit("meat")
			game.player.food_consumed.emit("plant")
			assert(not event.ended, "Dinner Time completed after only one plant")
			game.player.food_consumed.emit("plant")
		"explore_the_world":
			game.active_minimap.discovered.fill(1)
			event.call("_process", 1.0)
		"family":
			var nearby := 0
			for npc in get_nodes_in_group("npc_dinosaur"):
				if str(npc.get_meta("mission_role", "")) == "family_pack" and nearby < 3:
					npc.global_position = game.player.global_position + Vector3(nearby * 2.0, 0.0, 0.0)
					nearby += 1
			event.call("_process", 179.0)
			assert(not event.ended, "Family completed before three minutes")
			event.call("_process", 1.1)
		"breed":
			var first := Node.new()
			var second := Node.new()
			event.tracked_babies.append(first)
			event.call("_process", 0.0)
			assert(not event.ended, "Breed completed after one child")
			event.tracked_babies.append(second)
			event.call("_process", 0.0)
			first.free()
			second.free()
		"hunt":
			var prey := _role("hunt_prey")
			assert(is_instance_valid(prey), "Hunt prey is missing")
			game.player.food_source_consumed.emit(prey)
			assert(not event.ended, "Hunt completed without killing the marked prey")
			prey.take_damage(999, game.player)
			game.player.food_source_consumed.emit(game.player)
			assert(not event.ended, "Hunt accepted unrelated meat")
			_eat_source(game.player, prey)
		"defense":
			var attacker := _role("defense_attacker")
			attacker.died.emit(attacker)
		"poison":
			game.player.poisoning_changed.emit(false)
			assert(not event.ended, "Poison completed before poisoning")
			game.player.poisoning_changed.emit(true)
			assert(not event.ended, "Poison completed before the cure")
			game.player.poisoning_changed.emit(false)
		"water":
			var water: Vector3 = game.get_meta("sand_land_water_position")
			game.player.set_mobile_action("eat", true)
			game.player.global_position = water + Vector3(0.0, 0.1, 4.0)
			event.call("_process", 2.1)
			assert(not event.ended, "Water completed without the herd")
			var leader := _role("water_pack_leader")
			var toward_player: Vector3 = (game.player.global_position - leader.global_position).normalized()
			var rally_direction: Vector3 = leader.call("_rally_direction")
			assert(rally_direction.dot(toward_player) > 0.5, "Water herd leader does not move toward the player")
			var nearby := 0
			for npc in get_nodes_in_group("npc_dinosaur"):
				if str(npc.get_meta("mission_role", "")) in ["water_pack_leader", "water_pack"]:
					assert(npc.rally_target == game.player, "Water herd is not following the player")
					if nearby < 4:
						npc.global_position = water + Vector3(float(nearby) * 2.0, 0.1, 4.0)
						nearby += 1
			for npc in get_nodes_in_group("baby_dinosaur"):
				if str(npc.get_meta("mission_role", "")) == "water_child":
					assert(npc.parent_dino == leader, "Water child does not follow the herd leader")
			event.call("_process", 1.0)
			assert(not event.ended, "Water completed before drinking long enough")
			event.call("_process", 1.1)
			game.player.set_mobile_action("eat", false)
		"prey":
			var leader := _role("prey_leader")
			leader.last_attacker = game.player
			leader.died.emit(leader)
		"kingpin":
			var rival := _role("kingpin_rival")
			rival.died.emit(rival)
		"lost_baby":
			var baby := _role("lost_baby")
			game.player.global_position = baby.global_position
			event.call("_process", 0.1)
		"eat_the_baby":
			var baby := _role("hunted_baby")
			var hunter := _role("baby_hunter_pack")
			baby.take_damage(999, hunter)
			var meal: Node3D
			for meat in get_nodes_in_group("edible_meat"):
				if meat.get_meta("source_dinosaur", null) == baby: meal = meat
			assert(is_instance_valid(meal) and meal.get_meta("player_only", false), "Mission meat was not reserved")
			assert(hunter.food_target != meal, "Pack killer claimed the mission meat")
			assert(hunter._nearest_meat(meal.global_position, 1.0) == null, "Hungry pack can still find reserved meat")
			var remaining: float = meal.get_meta("energy_remaining")
			var energy: float = hunter.energy
			hunter.food_target = meal
			hunter._eat_meat(100.0)
			assert(hunter.food_target == null and hunter.energy == energy and meal.get_meta("energy_remaining") == remaining, "Pack consumed reserved meat")
			# Simulate the normal 12-second corpse cleanup, then eat much later.
			baby._expire_corpse()
			assert(is_instance_valid(baby) and not baby.is_queued_for_deletion() and not baby.visible, "Corpse cleanup lost the mission food source")
			event._process(0.1)
			assert(not event.ended, "Mission failed while its reserved meat was available")
			game.player.food_source_consumed.emit(game.player)
			assert(not event.ended, "Eat the Baby accepted unrelated meat")
			_eat_source(game.player, baby)
		_:
			assert(false, "Missing outcome check for %s/%s" % [quest_id, mission_id])


func _eat_source(player: CharacterBody3D, source: Node3D) -> void:
	for meat in get_nodes_in_group("edible_meat"):
		if meat.get_meta("source_dinosaur", null) == source:
			player.global_position = meat.global_position
			player.energy = 0.0
			player.eating_target = meat
			player.call("_update_eating", 3.0, true)
			return
	assert(false, "Marked target dropped no identifiable meat")


func _check_loss(game: Node, mission_id: String) -> void:
	var event: Node = game.active_mission_event
	match mission_id:
		"family":
			var lost := 0
			for npc in get_nodes_in_group("npc_dinosaur"):
				if str(npc.get_meta("mission_role", "")) == "family_pack" and lost < 2:
					npc.dead = true
					lost += 1
			event.call("_process", 0.1)
		"breed":
			event.call("_on_baby_died", null)
		"hunt":
			var prey := _role("hunt_prey")
			prey.died.emit(prey)
		"defense":
			var defender := _role("defense_pack")
			defender.died.emit(defender)
		"water":
			var lost := 0
			for npc in get_nodes_in_group("npc_dinosaur"):
				if str(npc.get_meta("mission_role", "")) in ["water_pack_leader", "water_pack", "water_child"] and lost < 4:
					npc.dead = true
					lost += 1
			event.call("_process", 0.1)
		"prey":
			var leader := _role("prey_leader")
			leader.global_position = game.get_meta("sand_land_water_position")
			event.call("_process", 0.1)
		"lost_baby":
			var baby := _role("lost_baby")
			baby.died.emit(baby)
		"eat_the_baby":
			var baby := _role("hunted_baby")
			var rescuer := _role("baby_rescue_leader")
			rescuer.global_position = baby.global_position
			event.call("_process", 0.1)
