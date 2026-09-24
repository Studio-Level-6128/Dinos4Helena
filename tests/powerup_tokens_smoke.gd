extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world.seed_input.text = "867530"
	world._start_game("triceratops")
	await physics_frame
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)

	var tokens := world.get_tree().get_nodes_in_group("powerup_token")
	assert(tokens.size() == 30, "Not all configured tokens were placed")
	var counts := {"health": 0, "speed": 0, "strength": 0}
	for token in tokens:
		counts[token.token_type] += 1
		assert(token.visual_root != null, "Token has no animated symbol")
	assert(counts == {"health": 14, "speed": 8, "strength": 8}, "Token type distribution is incorrect")

	var rotating_token = tokens[0]
	var rotation_before: float = rotating_token.visual_root.rotation.y
	for frame in 3:
		await process_frame
	assert(rotating_token.visual_root.rotation.y > rotation_before, "Token symbol is not rotating")

	var player = world.player
	player.health = player.max_health - 60
	player.health_changed.emit(player.health, player.max_health)
	var health_token = _find_token(world, "health")
	var health_count_before: int = counts["health"]
	player.apply_poison()
	assert(player.poisoned and world.poison_label.visible, "Poison state was not active before collecting the cure")
	player.global_position = health_token.global_position
	for frame in 20:
		await physics_frame
	assert(player.health == player.max_health - 20, "Health token did not restore the configured health")
	assert(not player.poisoned and not world.poison_label.visible, "Walking over a health token did not cure poison")
	assert(world.get_tree().get_nodes_in_group("powerup_token").size() == tokens.size() - 1, "Collected health token was not consumed")
	world._respawn_powerup_token("health")
	await process_frame
	var respawned_health_count := 0
	for token in world.get_tree().get_nodes_in_group("powerup_token"):
		if token.token_type == "health":
			respawned_health_count += 1
	assert(respawned_health_count == health_count_before, "Consumed token did not respawn as the same type")

	var base_speed: float = player.base_run_speed
	var speed_token = _find_token(world, "speed")
	player.global_position = speed_token.global_position
	for frame in 3:
		await physics_frame
	assert(is_equal_approx(player.run_speed, base_speed * 2.0), "Speed token did not double movement speed")
	assert("SPEED ×2" in world.bonus_label.text, "Speed bonus is not shown in the HUD")

	var base_strength: int = player.base_strength
	var strength_token = _find_token(world, "strength")
	player.global_position = strength_token.global_position
	for frame in 3:
		await physics_frame
	assert(player.strength == base_strength * 2, "Strength token did not double attack strength")
	assert("STRENGTH ×2" in world.bonus_label.text, "Strength bonus is not shown in the HUD")

	player.speed_bonus_time = 0.01
	player.strength_bonus_time = 0.01
	await physics_frame
	assert(is_equal_approx(player.run_speed, base_speed), "Expired speed bonus did not reset")
	assert(player.strength == base_strength, "Expired strength bonus did not reset")

	print("Power-up smoke test passed: placement, animation, healing, doubled stats, HUD, consumption, and respawn")
	world.queue_free()
	await process_frame
	quit()


func _find_token(world: Node, token_type: String) -> Area3D:
	for token in world.get_tree().get_nodes_in_group("powerup_token"):
		if token.token_type == token_type and not token.collected:
			return token as Area3D
	assert(false, "Missing token type: " + token_type)
	return null
