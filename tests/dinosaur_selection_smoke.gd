extends SceneTree

const DINO_IDS := ["trex", "triceratops", "stegosaurus", "velociraptor", "parasaurolophus", "apatosaurus"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
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
		app._return_to_main_menu()
		await process_frame
		assert(app.menu_layer.visible, "Could not return to menu after: " + dino_id)

	print("Dinosaur selection smoke test passed for all 6 species")
	app.queue_free()
	await process_frame
	quit()

