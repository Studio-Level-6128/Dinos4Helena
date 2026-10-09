extends SceneTree

var game: Node
var event: Node
const IDS := ["tracks_in_snow", "whiteout", "singing_lake", "sleeping_giants", "snowplug", "last_avalanche"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.quest_progress_path = "user://frozen_pass_routes_smoke.cfg"
	game.quest_progress.clear()
	game._dismiss_splash(true)
	game._show_quest_page("frozen_pass")
	for mid in IDS: game.quest_progress.set_value("frozen_pass", mid, true)
	for mid in IDS:
		game._start_quest_mission("frozen_pass", mid)
		await process_frame
		await physics_frame
		event = game.active_mission_event
		assert(is_equal_approx(absf(game.player.rotation.y), PI), "Player must face the trail")
		match mid:
			"sleeping_giants":
				await _walk(Vector3(14, 0.1, 5))
				await _walk(Vector3(14, 0.1, 36))
				await _walk(Vector3(-14, 0.1, 36))
				await _walk(Vector3(-14, 0.1, 60))
				await _walk(Vector3(14, 0.1, 60))
				await _walk(Vector3(14, 0.1, 84))
			"snowplug":
				for index in 3:
					await _walk(Vector3(-12 + index * 12, 0.1, 15))
					await _walk(Vector3(-12 + index * 12, 0.1, 37))
					assert(event.channel_ready[index], "Physical boulder pushing failed")
					await _walk(Vector3(-12 + index * 12, 0.1, 15))
				await _walk(Vector3(6, 0.1, 15))
				await _walk(Vector3(6, 0.1, 48))
				await _walk(Vector3(0, 0.1, 72))
			_:
				for point in event.checkpoints:
					if mid == "whiteout" or mid == "last_avalanche": event.clock = 0
					await _walk(point)
				if mid == "last_avalanche": await _walk(Vector3(0, 0.1, 100))
		assert(event.ended, "Physical route did not finish: " + mid)
		assert(game.player.energy > 0, "Physical route exhausted the player's energy")
		print("Physical route passed: " + mid)
		game._return_to_main_menu()
		await process_frame
		await process_frame
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frozen_pass_routes_smoke.cfg"))
	print("Frozen Pass physical routes passed")
	quit()

func _walk(target: Vector3) -> void:
	for frame in 1600:
		if event.ended: return
		var offset: Vector3 = target - game.player.global_position
		offset.y = 0
		if offset.length() < 0.8:
			game.player.mobile_actions.clear()
			await physics_frame
			return
		game.player.rotation.y = atan2(-offset.x, -offset.z)
		game.player.mobile_actions["move_forward"] = true
		await physics_frame
	assert(false, "Unreachable physical waypoint: %s at %s in %s" % [target, game.player.global_position, event.mode])
