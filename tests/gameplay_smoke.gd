extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame

	var player := world.get_node("PlayerT-Rex") as CharacterBody3D
	var initial_z := player.position.z
	player.set_mobile_action("move_forward", true)
	player.set_mobile_action("run", true)
	for frame in 30:
		await physics_frame
	player.set_mobile_action("move_forward", false)
	player.set_mobile_action("run", false)
	assert(player.position.z < initial_z - 1.0, "T-Rex did not move forward")
	assert(is_equal_approx(player.model_root.rotation.y, PI), "T-Rex model is not facing gameplay-forward")

	var position_before_turn: Vector3 = player.position
	var rotation_before_turn: float = player.rotation.y
	player.set_mobile_action("move_left", true)
	for frame in 12:
		await physics_frame
	player.set_mobile_action("move_left", false)
	assert(player.rotation.y > rotation_before_turn + 0.2, "Left steering did not turn smoothly")
	assert(player.position.distance_to(position_before_turn) < 1.0, "Steering caused an unexpected position jump")

	var standing_scale: float = player.model_root.scale.y
	player.set_mobile_action("duck", true)
	for frame in 10:
		await physics_frame
	player.set_mobile_action("duck", false)
	assert(player.model_root.scale.y < standing_scale, "T-Rex did not duck")

	player.set_mobile_action("jump", true)
	await physics_frame
	player.set_mobile_action("jump", false)
	assert(player.velocity.y > 0.0, "T-Rex did not jump")

	player.set_mobile_action("attack", true)
	player.set_mobile_action("attack", false)
	assert(player.attack_time > 0.0, "T-Rex attack did not trigger")

	var scream_count := [0]
	player.screamed.connect(func() -> void: scream_count[0] += 1)
	player.set_mobile_action("scream", true)
	player.set_mobile_action("scream", false)
	assert(scream_count[0] == 1, "T-Rex scream did not trigger")
	assert("idle" in player.current_animation.to_lower(), "Scream incorrectly reused the attack animation")

	print("Gameplay smoke test passed: movement, run, duck, jump, attack, and scream")
	world.queue_free()
	await process_frame
	quit()
