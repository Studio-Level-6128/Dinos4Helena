extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var localization := root.get_node("Localization")
	var expected_keys: Array = []
	for locale in ["en", "de", "fr"]:
		var file := FileAccess.open("res://translations/%s.json" % locale, FileAccess.READ)
		assert(file != null, "Translation catalog is missing: %s" % locale)
		var catalog = JSON.parse_string(file.get_as_text())
		assert(catalog is Dictionary, "Translation catalog is invalid: %s" % locale)
		var keys: Array = catalog.keys()
		keys.sort()
		if expected_keys.is_empty():
			expected_keys = keys
		else:
			assert(keys == expected_keys, "Translation keys differ for: %s" % locale)

	for mission in ["dinner_time", "explore_the_world", "family", "breed", "hunt", "defense", "poison", "water", "prey", "kingpin", "lost_baby", "eat_the_baby", "tracks_in_snow", "whiteout", "singing_lake", "sleeping_giants", "snowplug", "last_avalanche"]:
		for locale in ["en", "de", "fr"]:
			var audio_path := "res://assets/audio/missions/%s/%s.mp3" % [mission, locale]
			assert(ResourceLoader.exists(audio_path), "Mission narration is missing: %s" % audio_path)
			var stream := load(audio_path) as AudioStream
			assert(stream != null and stream.get_length() > 2.0, "Mission narration is invalid: %s" % audio_path)

	localization.call("set_language", "en", false)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	app._dismiss_splash(true)
	var selector := app.find_child("LanguageSelector", true, false) as HBoxContainer
	assert(selector != null and selector.get_child_count() == 3, "Language flag selector is incomplete")
	assert((app.find_child("FreeGameTile", true, false) as Button).text.begins_with("FREE GAME"), "English menu text is missing")

	var french_button := app.find_child("Language_fr", true, false) as Button
	assert(french_button != null and french_button.text == "🇫🇷", "French flag button is missing")
	french_button.pressed.emit()
	await process_frame
	await process_frame
	assert(localization.get("language") == "fr", "Language selector did not switch to French")
	assert((app.find_child("FreeGameTile", true, false) as Button).text.begins_with("JEU LIBRE"), "French menu text was not applied")
	assert((app.find_child("Language_fr", true, false) as Button).disabled, "Active language is not indicated")
	app.active_mission_id = "dinner_time"
	app.game_hud = CanvasLayer.new()
	app.add_child(app.game_hud)
	app._play_mission_intro()
	assert(app.mission_intro_player.stream.resource_path.ends_with("/dinner_time/fr.mp3"), "Mission narration did not follow the selected language")

	localization.call("set_language", "en")
	print("Localization smoke test passed for English, German, and French")
	app.queue_free()
	await process_frame
	quit()
