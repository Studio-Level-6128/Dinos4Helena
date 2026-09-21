extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dino_id := args[0] if not args.is_empty() else "trex"
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	app._start_game(dino_id)
	for frame in 3:
		await process_frame
	print("Previewing selected dinosaur: " + dino_id)

