extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	assert(app.seed_input.text.length() == 6 and int(app.seed_input.text) >= 100000, "Automatic seed is not six digits")

	app.seed_input.text = "246810"
	app._start_game("trex")
	await physics_frame
	assert(app.map_seed == 246810, "Manual seed was not applied")
	var first_signature := _layout_signature(app)
	assert(app.generated_ponds.size() >= 4, "Procedural world has too few ponds")
	assert(app.generated_trees.size() >= 75, "Procedural world has too few trees")
	app._return_to_main_menu()
	await process_frame

	app.seed_input.text = "246810"
	app._start_game("apatosaurus")
	await physics_frame
	assert(_layout_signature(app) == first_signature, "The same seed did not reproduce the same world")
	app._return_to_main_menu()
	await process_frame

	app.seed_input.text = "975310"
	app._start_game("trex")
	await physics_frame
	assert(_layout_signature(app) != first_signature, "Different seeds generated the same world")

	print("Procedural world smoke test passed: six-digit seeds are deterministic and varied")
	app.queue_free()
	await process_frame
	quit()


func _layout_signature(app: Node) -> String:
	return "%s|%s|%s|%s" % [
		str(app.generated_ponds),
		str(app.generated_hills),
		str(app.generated_trees),
		str(app.generated_rocks)
	]
