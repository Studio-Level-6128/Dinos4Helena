extends SceneTree

const IDS := ["echoes_of_warning", "leap_of_fire", "giants_balance", "black_wall", "return_to_sender", "ashfang"]
const SPECIES := ["parasaurolophus", "velociraptor", "apatosaurus", "triceratops", "stegosaurus", "spinosaurus"]
var game: Node
var event: Node
const SAVE := "user://volcano_quest_smoke.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Localization").set_language("en", false)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.quest_progress_path = SAVE
	game.quest_progress.clear()
	game._dismiss_splash(true)
	game._show_quest_page("heart_of_volcano")
	assert(game.mission_config.get_value("quest", "mission_ids") == IDS)
	for index in IDS.size():
		var button: Button = game.find_child("Mission_" + IDS[index], true, false)
		assert(button != null and button.disabled == (index > 0), "Wrong volcano mission lock")
		assert(game.mission_config.get_value(IDS[index], "dinosaur") == SPECIES[index])
	for index in IDS.size():
		await _start(IDS[index])
		assert(game.selected_dino_id == SPECIES[index] and game.selected_map_theme == "volcano")
		assert(game.mission_player_start == Vector3(0, 0.1, 72), "Volcano quest spawn was overridden")
		assert(game.mission_intro_player.stream.resource_path.ends_with("/%s/en.mp3" % IDS[index]))
		_check_wrong(IDS[index])
		await _check_win(IDS[index])
		assert(event.ended and game.quest_progress.get_value("heart_of_volcano", IDS[index], false))
		await _leave()
	game.quest_progress.clear()
	assert(game.quest_progress.load(SAVE) == OK)
	for mid in IDS: assert(game.quest_progress.get_value("heart_of_volcano", mid, false))
	assert(not game.quest_progress.has_section("sand_land"))
	for mid in IDS:
		await _start(mid)
		event._on_player_died()
		assert(event.ended)
		await _leave()
	for locale in ["de", "fr"]:
		root.get_node("Localization").set_language(locale, false)
		await _start("ashfang")
		assert(game.mission_intro_player.stream.resource_path.ends_with("/ashfang/%s.mp3" % locale))
		assert(not game.find_child("AshfangHealth", true, false).get_child(0).text.begins_with("lava."))
		await _leave()
	root.get_node("Localization").set_language("en", false)
	# The configurable volcano mission spawn must preserve the old free-play spawn.
	game.selected_map_theme = "volcano"
	game._generate_world_layout()
	assert(game.mission_player_start == Vector3(0, 0.1, 58))
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("Volcano quest smoke passed: six species, six wins, wrong actions, checkpoints, boss phases, locales")
	quit()

func _start(mid: String) -> void:
	game._start_quest_mission("heart_of_volcano", mid)
	await process_frame
	await physics_frame
	event = game.active_mission_event
	assert(event != null)
	event.set_process(false)
	event.set_physics_process(false)
	game.player.set_physics_process(false)
	if mid == "ashfang": event.boss.set_physics_process(false)

func _leave() -> void:
	game._return_to_main_menu()
	await process_frame
	await process_frame

func _check_wrong(mid: String) -> void:
	match mid:
		"echoes_of_warning":
			event._submit_roar(true)
			assert(event.stage == 0 and event.answer == 0)
		"leap_of_fire":
			game.player.global_position = Vector3(0, 0.1, 100)
			event._process(0.1)
			assert(event.stage == 0 and not event.rode_lift and game.player.global_position == event.checkpoint)
		"giants_balance":
			game.player.global_position = Vector3(12, 3, 108)
			event._physics_process(2)
			assert(event.stage == 0 and game.player.global_position == event.checkpoint)
		"black_wall":
			game.player.global_position = Vector3(-14, 0.1, 100)
			game.player.velocity = Vector3.ZERO
			event._on_attack()
			assert(event.stage == 0)
		"return_to_sender":
			game.player.global_position = event.landing
			event.flight_time = 0.5
			event._on_attack()
			assert(not event.returning and event.stage == 0)
			event._process(3)
			assert(game.player.global_position == event.checkpoint)
		"ashfang":
			var hp: int = event.phase_health
			event.hit_boss(999, game.player)
			assert(event.phase_health == hp and event.phase == 0, "Boss guard did not block damage")
			event.hit_boss(999, null)
			assert(event.phase_health == hp)
			game.player.global_position = Vector3(0, 0.1, 155)
			event._process(0.1)
			assert(not event.ended, "Boss crossing completed before victory")

func _check_win(mid: String) -> void:
	match mid:
		"echoes_of_warning":
			for pattern in event.PATTERNS:
				for value in pattern: event._submit_roar(value)
		"leap_of_fire":
			for index in 3:
				event.rode_lift = true
				game.player.global_position = event.ledges[index]
				game.player.velocity = Vector3.ZERO
				game.player.set_physics_process(true)
				for frame in 6: await physics_frame
				event._process(0.016)
				game.player.set_physics_process(false)
				assert(event.stage == index + 1, "Ledge did not save the jump checkpoint")
		"giants_balance":
			for point in event.points:
				game.player.global_position = point
				event.tilt = 0
				event._physics_process(2)
			assert(event.stage == 3 and not event.ended)
			game.player.global_position = Vector3(0, 0.1, 142)
			event._physics_process(0.1)
		"black_wall":
			for point in event.weak_points:
				game.player.global_position = point - Vector3(0, 0, 4)
				game.player.rotation.y = PI
				game.player.velocity = Vector3(0, 0, 6)
				game.player.mobile_actions["run"] = true
				event._on_attack()
			assert(event.stage == 3 and not event.ended)
			game.player.global_position = Vector3(0, 0.1, 114)
			event._process(0.1)
		"return_to_sender":
			for index in 5:
				game.player.global_position = event.landing
				event.flight_time = 2.4
				event._on_attack()
				assert(event.returning)
				event._process(0.8)
		"ashfang":
			for index in 3:
				event._recover()
				event.boss.take_damage(160, game.player)
				assert(event.phase == index + 1)
				if index < 2:
					event.phase_health = 40
					game.player.health = 1
					event._damage_player(25)
					assert(event.phase == index + 1 and event.phase_health == 160)
					assert(not game.player.dead and game.player.health == game.player.max_health)
			assert(not event.ended and event.state == "retreat")
			game.player.global_position = Vector3(0, 0.1, 150)
			event._process(0.1)
			assert("green valley" in game.find_child("MissionResult", true, false).get_child(0).get_child(1).text)

