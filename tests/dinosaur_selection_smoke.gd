extends SceneTree

const DINO_IDS := ["trex", "spinosaurus", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	var config := ConfigFile.new()
	assert(config.load("res://config/dinosaurs.cfg") == OK, "Could not load dinosaur stats")
	root.add_child(app)
	await process_frame
	assert(is_instance_valid(app.splash_layer), "Startup splash is missing")
	assert(not app.menu_layer.visible, "Selection menu should wait behind the splash")
	app._dismiss_splash(true)
	assert(app.menu_layer.visible, "Main menu is not visible at startup")
	var landing_page := app.menu_layer.find_child("LandingPage", true, false) as Control
	var free_game_page := app.menu_layer.find_child("FreeGamePage", true, false) as Control
	var quests_tile := app.menu_layer.find_child("QuestsTile", true, false) as Button
	var free_game_tile := app.menu_layer.find_child("FreeGameTile", true, false) as Button
	assert(landing_page != null and landing_page.visible, "Landing page should be visible at startup")
	assert(free_game_page != null and not free_game_page.visible, "Free Game page should start hidden")
	assert(quests_tile != null and quests_tile.disabled, "Unavailable Quests tile is missing or enabled")
	assert(free_game_tile != null, "Free Game tile is missing")
	assert(ResourceLoader.exists("res://assets/ui/menu/quests-tile.png"), "Quests tile background is missing")
	assert(ResourceLoader.exists("res://assets/ui/menu/free-game-tile.png"), "Free Game tile background is missing")
	var mode_tiles: Node = app.menu_layer.find_child("GameModeTiles", true, false)
	assert(mode_tiles != null and mode_tiles.get_child_count() == 2, "Landing page should contain exactly two mode tiles")

	# Credits remain available from the clean landing page.
	var credits_button := app.menu_layer.find_child("CreditsButton", true, false) as Button
	assert(credits_button != null and credits_button.get_parent() == landing_page, "Credits button is missing from the landing page")
	assert(app.credits_overlay != null and not app.credits_overlay.visible, "Credits overlay should start hidden")
	credits_button.pressed.emit()
	assert(app.credits_overlay.visible, "Credits button did not open the credits page")
	var dedication := app.credits_overlay.find_child("Dedication", true, false) as Label
	var author := app.credits_overlay.find_child("AuthorCredit", true, false) as Label
	var license := app.credits_overlay.find_child("LicenseCredit", true, false) as Label
	var github := app.credits_overlay.find_child("GithubLink", true, false) as LinkButton
	assert(dedication.text == "For Helena - have fun. Dad.", "Credits dedication is incorrect")
	assert(author.text == "Open Souce Game by Janis Keuper.", "Credits author line is incorrect")
	assert(license.text == "License: GPL v3", "Credits license line is incorrect")
	assert(github.get_meta("uri") == "https://github.com/keuperj/Dinos4Helena", "Credits GitHub link is incorrect")
	app._close_credits()
	assert(not app.credits_overlay.visible, "Credits page did not close")

	free_game_tile.pressed.emit()
	assert(not landing_page.visible and free_game_page.visible, "Free Game tile did not open the setup page")
	var cards: Node = app.menu_layer.find_child("DinosaurCards", true, false)
	assert(cards != null and cards.get_child_count() == 2, "Dinosaur cards are not arranged in two rows")
	assert(cards.get_child(0).get_child_count() == 4, "First dinosaur-card row should contain four cards")
	assert(cards.get_child(1).get_child_count() == 3, "Second dinosaur-card row should contain three cards")
	var first_portrait := cards.get_child(0).get_child(0).find_child("Portrait", true, false) as TextureButton
	assert(first_portrait != null and first_portrait.stretch_mode == TextureButton.STRETCH_KEEP_ASPECT_CENTERED, "Dinosaur portraits should fit without cropping")
	assert(first_portrait.size.y >= 130.0, "Dinosaur portraits were not enlarged")
	var trex_card := cards.get_child(0).get_child(0) as PanelContainer
	assert((trex_card.find_child("SelectionShade", true, false) as ColorRect).visible, "Selected dinosaur portrait is not shaded")
	assert((trex_card.find_child("SelectedStats", true, false) as GridContainer).visible, "Selected dinosaur properties are not shown over its portrait")
	var spinosaurus_card := cards.get_child(0).get_child(1) as PanelContainer
	var spinosaurus_selector := spinosaurus_card.find_child("SelectButton", true, false) as Button
	assert(spinosaurus_selector != null, "Whole dinosaur card is not selectable")
	spinosaurus_selector.pressed.emit()
	assert(app.selected_dino_id == "spinosaurus", "Dinosaur card did not update the selection")
	assert((spinosaurus_card.find_child("SelectedMarker", true, false) as Label).visible, "Selected dinosaur has no visual marker")
	assert((spinosaurus_card.find_child("SelectionShade", true, false) as ColorRect).visible, "Newly selected portrait is not shaded")
	assert((spinosaurus_card.find_child("SelectedStats", true, false) as GridContainer).visible, "Newly selected dinosaur properties are not shown")
	assert(not (trex_card.find_child("SelectedStats", true, false) as GridContainer).visible, "Unselected dinosaur properties should be hidden")
	var trex_selector := cards.get_child(0).get_child(0).find_child("SelectButton", true, false) as Button
	trex_selector.pressed.emit()
	for candidate in cards.find_children("*", "Button", true, false):
		assert((candidate as Button).text != "PLAY", "Per-dinosaur Play buttons should be removed")
	for menu_label in free_game_page.find_children("*", "Label", true, false):
		assert((menu_label as Label).text != "CHOOSE YOUR MAP", "Obsolete map-selection heading is still visible")
	var theme_cards := app.menu_layer.find_child("MapThemeCards", true, false) as HBoxContainer
	assert(theme_cards != null and theme_cards.get_child_count() == 4, "Visual map-theme cards are incomplete")
	for theme_button in theme_cards.get_children():
		assert((theme_button as Button).get_theme_stylebox("normal") is StyleBoxTexture, "Map theme card has no preview image")
	var start_button := app.menu_layer.find_child("StartGameButton", true, false) as Button
	assert(start_button != null and "T-REX" in start_button.text, "Shared Start Game button is missing or stale")
	var back_button := app.menu_layer.find_child("BackToLandingButton", true, false) as Button
	assert(back_button != null, "Free Game back button is missing")
	back_button.pressed.emit()
	assert(landing_page.visible and not free_game_page.visible, "Back button did not return to the landing page")
	free_game_tile.pressed.emit()
	assert(ResourceLoader.exists("res://assets/models/spinosaurus/Spinosaurus.glb"), "Spinosaurus model is missing")
	assert(ResourceLoader.exists("res://assets/ui/menu/spinosaurus.png"), "Spinosaurus portrait is missing")

	for dino_id in DINO_IDS:
		app._start_game(dino_id)
		await process_frame
		await physics_frame
		var player := app.get_node("PrehistoricWorld/PlayerDinosaur")
		assert(player.dino_id == dino_id, "Wrong dinosaur selected: " + dino_id)
		for wild_dino in app.generated_dinosaurs:
			assert(wild_dino["species"] != "spinosaurus", "Player-only Spinosaurus appeared as wildlife")
		assert(player.animation_player != null, "Missing animations for: " + dino_id)
		var minimum_animation_count := 4 if dino_id == "spinosaurus" else 5
		assert(player.animation_player.get_animation_list().size() >= minimum_animation_count, "Incomplete animation set for: " + dino_id)
		if dino_id == "spinosaurus":
			var meshes: Array[Node] = player.model_root.find_children("*", "MeshInstance3D", true, false)
			assert(not meshes.is_empty(), "Spinosaurus render mesh is missing")
			var mesh_instance := meshes[0] as MeshInstance3D
			assert(mesh_instance.mesh.get_surface_count() == 1, "Spinosaurus should retain its single render surface")
			var skin := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			assert(skin != null, "Spinosaurus optimized material is missing")
			assert(skin.albedo_texture.resource_path.ends_with("spinosaurus_skin.png"), "Spinosaurus albedo is not species-specific")
			assert(skin.normal_enabled and skin.normal_texture.resource_path.ends_with("spinosaurus_skin_normal.png"), "Spinosaurus normal detail is missing")
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
		assert(not landing_page.visible and free_game_page.visible, "Gameplay should return to the Free Game selection page")

	print("Dinosaur selection smoke test passed for all 7 species")
	app.queue_free()
	await process_frame
	quit()
