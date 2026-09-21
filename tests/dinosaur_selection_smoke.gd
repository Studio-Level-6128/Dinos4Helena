extends SceneTree

const DINO_IDS := ["trex", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	var config := ConfigFile.new()
	assert(config.load("res://config/dinosaurs.cfg") == OK, "Could not load dinosaur stats")
	root.add_child(app)
	await process_frame
	assert(app.menu_layer.visible, "Main menu is not visible at startup")

	for dino_id in DINO_IDS:
		app._start_game(dino_id)
		await process_frame
		await physics_frame
		var player := app.get_node("PrehistoricWorld/PlayerDinosaur")
		assert(player.dino_id == dino_id, "Wrong dinosaur selected: " + dino_id)
		assert(player.animation_player != null, "Missing animations for: " + dino_id)
		assert(player.animation_player.get_animation_list().size() >= 5, "Incomplete animation set for: " + dino_id)
		var death_animation: String = player._find_animation("death")
		assert(death_animation != "", "Missing death animation for: " + dino_id)
		assert(player.animation_player.get_animation(death_animation).loop_mode == Animation.LOOP_NONE, "Death animation loops for: " + dino_id)
		assert(player.audio_streams.size() == 7, "Incomplete sound set for: " + dino_id)
		assert(is_equal_approx(player.run_speed, float(config.get_value(dino_id, "run_speed"))), "Wrong speed for: " + dino_id)
		assert(player.strength == int(config.get_value(dino_id, "strength")), "Wrong strength for: " + dino_id)
		assert(player.max_health == int(config.get_value(dino_id, "max_health")), "Wrong health for: " + dino_id)
		assert(player.health == player.max_health, "Health did not start full for: " + dino_id)
		assert(is_equal_approx(player.energy, 100.0), "Energy did not start full for: " + dino_id)
		assert(player.diet == str(config.get_value(dino_id, "diet")), "Wrong diet for: " + dino_id)
		assert(player.can_jump == bool(config.get_value(dino_id, "can_jump")), "Wrong jump ability for: " + dino_id)
		if dino_id == "apatosaurus":
			assert(player.model_scale >= 0.38, "Apatosaurus is not scaled as a giant")
			assert(not player.can_jump, "Apatosaurus should not be able to jump")
		app._return_to_main_menu()
		await process_frame
		assert(app.menu_layer.visible, "Could not return to menu after: " + dino_id)

	print("Dinosaur selection smoke test passed for all 6 species")
	app.queue_free()
	await process_frame
	quit()
