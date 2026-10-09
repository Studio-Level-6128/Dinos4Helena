extends SceneTree

const IDS := ["tracks_in_snow", "whiteout", "singing_lake", "sleeping_giants", "snowplug", "last_avalanche"]
var game: Node
var event: Node
var progress_path := "user://frozen_pass_smoke.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("Localization").set_language("en", false)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.quest_progress_path = progress_path
	game.quest_progress.clear()
	game._dismiss_splash(true)
	game._show_quest_page("frozen_pass")
	assert(game.mission_config.get_value("quest", "mission_ids") == IDS)
	for index in IDS.size():
		var button: Button = game.find_child("Mission_" + IDS[index], true, false)
		assert(button != null and button.disabled == (index > 0), "Wrong initial ice mission lock")
		for key in ["image", "setup_script", "event_script"]:
			assert(ResourceLoader.exists(game.mission_config.get_value(IDS[index], key)), "Missing ice asset")
	for mid in IDS:
		await _start(mid)
		assert(game.selected_map_theme == "winter")
		assert(game.mission_intro_player.playing, "Ice introduction did not play")
		assert(game.mission_intro_player.stream.resource_path.ends_with("/%s/en.mp3" % mid))
		assert(game.generated_eggs.is_empty() and game.generated_tokens.is_empty())
		assert(event.checkpoints.size() == (4 if mid == "singing_lake" else (1 if mid == "snowplug" else 3)))
		_check_hazards(mid)
		_check_win(mid)
		assert(event.ended, "Ice mission did not complete: " + mid)
		assert(game.quest_progress.get_value("frozen_pass", mid, false), "Ice completion was not saved")
		assert(game.find_child("MissionResult", true, false) != null)
		await _leave()
	# Completion persists independently of the old campaigns.
	game.quest_progress.clear()
	assert(game.quest_progress.load(progress_path) == OK)
	for mid in IDS: assert(game.quest_progress.get_value("frozen_pass", mid, false))
	assert(not game.quest_progress.has_section("sand_land"))
	# Every mission has a terminal player-death outcome.
	for mid in IDS:
		await _start(mid)
		event._on_player_died()
		assert(event.ended and game.find_child("MissionResult", true, false) != null)
		await _leave()
	await _start("sleeping_giants")
	event.giants[0].take_damage(999, game.player)
	assert(event.ended)
	await _leave()
	await _start("sleeping_giants")
	event.giants[0].take_damage(1, game.player)
	event._process(0.1)
	assert(event.ended)
	await _leave()
	# All three languages use real strings and the matching narration file.
	for locale in ["de", "fr"]:
		root.get_node("Localization").set_language(locale, false)
		await _start("whiteout")
		assert(game.mission_intro_player.stream.resource_path.ends_with("/whiteout/%s.mp3" % locale))
		event._update_ui()
		assert(not game.mission_objective_label.text.begins_with("ice."))
		await _leave()
	root.get_node("Localization").set_language("en", false)
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(progress_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	print("Frozen Pass smoke passed: six wins, hazard recovery, death outcomes, progression, localized audio")
	quit()

func _start(mid: String) -> void:
	game._start_quest_mission("frozen_pass", mid)
	await process_frame
	await physics_frame
	event = game.active_mission_event
	assert(event != null and event.mode == mid, "Ice mission failed to start")
	event.set_process(false)
	game.player.set_physics_process(false)

func _leave() -> void:
	game._return_to_main_menu()
	await process_frame
	await process_frame

func _check_hazards(mid: String) -> void:
	match mid:
		"tracks_in_snow":
			game.player.global_position = Vector3(10, 0.1, 28)
			event._process(0.1)
			assert(event.stage == 0 and game.player.global_position == event.checkpoint)
		"whiteout":
			game.player.global_position = Vector3(0, 0.1, 17)
			event.clock = 10
			event.warmth = 5
			event._process(0.5)
			assert(event.warmth == 100 and game.player.global_position == event.checkpoint)
			event.warmth = 20
			event._process(1)
			assert(event.warmth > 20, "Shelter did not restore warmth")
		"singing_lake":
			game.player.global_position = Vector3(18, 0.1, 30)
			event._process(3)
			assert(game.player.global_position == event.checkpoint and event.stage == 0)
		"sleeping_giants":
			assert(event.giants.size() == 3)
			for giant in event.giants: assert(not giant.is_physics_processing())
			game.player.global_position = Vector3(0, 0.1, 24)
			game.player.velocity = Vector3(0, 0, 4.5)
			event._process(2.1)
			assert(game.player.global_position == event.checkpoint)
			game.player.global_position = Vector3(14, 0.1, 24)
			game.player.velocity = Vector3(0, 0, 4.5)
			event._process(1)
			assert(event.noise == 0, "Walking on soft snow woke a giant")
			game.player.global_position = Vector3(0, 0.1, 24)
			game.player.velocity = Vector3.ZERO
			event.noise = 1
			event._process(0.5)
			assert(event.noise < 1, "Stopping did not calm the giant")
		"snowplug":
			game.player.global_position = Vector3(0, 0.1, 72)
			event._process(0.1)
			assert(not event.ended, "Tunnel completed before channels were ready")
			assert(is_instance_valid(event.snow_gate))
		"last_avalanche":
			game.player.global_position = Vector3(0, 0.1, 17)
			event.clock = 10
			event._process(0.8)
			assert(game.player.global_position == event.checkpoint)
			assert(not event.ended)

func _check_win(mid: String) -> void:
	if mid == "snowplug":
		for index in 3:
			# Push from behind using actual proximity and movement, rather than
			# directly marking the channel complete.
			for step in 40:
				var rock: Node3D = event.boulders[index]
				game.player.global_position = Vector3(rock.position.x, 0.1, rock.position.z - 3)
				game.player.velocity = Vector3(0, 0, 4)
				event._process(0.15)
			assert(event.channel_ready[index], "Boulder did not reach its channel")
		game.player.global_position = event.checkpoints[0]
		event._process(0.1)
		return
	for point in event.checkpoints:
		game.player.global_position = point
		game.player.velocity = Vector3.ZERO
		event.clock = 0
		event._process(0.1)
	if mid == "last_avalanche":
		assert(not event.ended, "Finale completed before the warm valley")
		game.player.global_position = Vector3(0, 0.1, 100)
		event._process(0.1)
