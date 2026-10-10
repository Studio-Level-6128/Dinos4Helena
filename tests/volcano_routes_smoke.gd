extends SceneTree

const IDS := ["echoes_of_warning", "leap_of_fire", "giants_balance", "black_wall", "return_to_sender", "ashfang"]
var game: Node
var event: Node
var failed := false
var mission_won := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.quest_progress_path = "user://volcano_routes_smoke.cfg"
	game.quest_progress.clear()
	game._dismiss_splash(true)
	game._show_quest_page("heart_of_volcano")
	for mid in IDS: game.quest_progress.set_value("heart_of_volcano", mid, true)
	for mid in IDS:
		game._start_quest_mission("heart_of_volcano", mid)
		await process_frame
		for frame in 6: await physics_frame
		event = game.active_mission_event
		mission_won = false
		event.mission_completed.connect(_on_mission_won)
		match mid:
			"echoes_of_warning":
				for pattern in event.PATTERNS:
					for long_roar in pattern:
						while game.player.scream_time > 0: await physics_frame
						game.player.set_mobile_action("scream", true)
						for frame in (72 if long_roar else 12): await physics_frame
						game.player.set_mobile_action("scream", false)
						for frame in 3: await physics_frame
			"leap_of_fire":
				await _walk(Vector3(0, 0.1, 76))
				for index in 3:
					await _jump_to(event.lifts[index].position)
					if failed: return
					if not event.rode_lift:
						_fail("Moving lift did not register contact at stage %d, player %s" % [index, game.player.global_position])
						return
					while event.lifts[index].position.y + 0.5 < 2.0: await physics_frame
					await _jump_to(event.ledges[index])
					if failed: return
					if event.stage != index + 1:
						_fail("Jump did not reach ledge %d: %s" % [index, game.player.global_position])
						return
			"giants_balance":
				for point in event.points:
					await _walk(point)
					var expected: int = event.stage + 1
					for frame in 300:
						if event.stage >= expected: break
						await physics_frame
				await _walk(Vector3(0, 0.1, 142))
			"black_wall":
				for index in event.weak_points.size():
					var point: Vector3 = event.weak_points[index]
					var approach_x := point.x + (2.0 if index == 2 else 0.0)
					await _walk(Vector3(approach_x, 0.1, 96))
					game.player.rotation.y = PI
					game.player.mobile_actions["move_forward"] = true
					game.player.mobile_actions["run"] = true
					if index == 0:
						while game.player.global_position.z < 99: await physics_frame
					else:
						# Press at contact, when collision has already stopped the body.
						for frame in 180:
							await physics_frame
							if game.player.global_position.z > 102 and absf(game.player.velocity.z) < 0.1: break
						assert(game.player.global_position.z > 102 and absf(game.player.velocity.z) < 0.1, "Charge did not reach wall contact")
					game.player.set_mobile_action("attack", true)
					for frame in 25: await physics_frame
					assert(event.broken[index], "Real horn impact did not break wall section %d" % index)
					game.player.set_mobile_action("attack", false)
					game.player.mobile_actions.clear()
					await _walk(Vector3(point.x, 0.1, 96))
				await _walk(Vector3(0, 0.1, 115))
			"return_to_sender":
				await _walk(event.landing)
				for index in 5:
					for frame in 500:
						if not event.returning and event.flight_time >= 2.25 and event.flight_time < 2.45: break
						await physics_frame
					game.player.set_mobile_action("attack", true)
					for frame in 4: await physics_frame
					game.player.set_mobile_action("attack", false)
					for frame in 100:
						if event.stage > index: break
						await physics_frame
			"ashfang": await _fight_boss()
		if failed: return
		if not mission_won:
			_fail("Physical controls did not complete " + mid + " at stage " + str(event.stage))
			return
		print("Volcano physical controls passed: " + mid)
		game._return_to_main_menu()
		await process_frame
		await process_frame
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://volcano_routes_smoke.cfg"))
	print("Volcano physical routes passed: actual roar, jump, balance, charge, deflection, and boss attacks")
	quit()

func _walk(target: Vector3, run := false) -> void:
	for frame in 1800:
		if event.ended or failed: return
		var offset: Vector3 = target - game.player.global_position
		offset.y = 0
		if offset.length() < 0.6:
			game.player.mobile_actions.clear()
			for step in 3: await physics_frame
			return
		game.player.rotation.y = atan2(-offset.x, -offset.z)
		game.player.mobile_actions["move_forward"] = true
		game.player.mobile_actions["run"] = run
		await physics_frame
	_fail("Unreachable physical point %s, player %s, mission %s" % [target, game.player.global_position, game.active_mission_id])

func _jump_to(target: Vector3) -> void:
	var offset: Vector3 = target - game.player.global_position
	offset.y = 0
	game.player.rotation.y = atan2(-offset.x, -offset.z)
	game.player.mobile_actions["move_forward"] = true
	game.player.set_mobile_action("jump", true)
	for frame in 3: await physics_frame
	game.player.set_mobile_action("jump", false)
	for frame in 240:
		if _flat_distance(game.player.global_position, target) < 0.8: game.player.mobile_actions["move_forward"] = false
		if frame > 6 and game.player.is_on_floor():
			game.player.mobile_actions.clear()
			for step in 3: await physics_frame
			return
		await physics_frame
	_fail("Jump did not land: " + str(game.player.global_position))

func _fight_boss() -> void:
	for attempt in 30:
		if event.phase == 3: break
		var before: int = event.phase
		# Stay outside both the locked center charge and the sweep radius.
		await _walk(Vector3(17, 0.1, 112), true)
		for frame in 700:
			if event.state == "recover": break
			await physics_frame
		for frame in 400:
			if event.phase != before or event.state != "recover": break
			var offset: Vector3 = event.boss.position - game.player.global_position
			offset.y = 0
			game.player.rotation.y = atan2(-offset.x, -offset.z)
			if offset.length() > 4.5:
				game.player.mobile_actions["move_forward"] = true
				game.player.mobile_actions["run"] = true
			else:
				game.player.mobile_actions.clear()
				if game.player.attack_time <= 0: game.player.set_mobile_action("attack", true)
				else: game.player.set_mobile_action("attack", false)
			await physics_frame
		game.player.mobile_actions.clear()
	if event.phase != 3:
		_fail("Boss could not be defeated through actual player attacks")
		return
	await _walk(Vector3(0, 0.1, 151), true)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)

func _on_mission_won() -> void:
	mission_won = true
