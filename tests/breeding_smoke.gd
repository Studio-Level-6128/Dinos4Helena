extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world.seed_input.text = "654321"
	world._start_game("triceratops")
	await physics_frame

	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)
	var nests := world.get_tree().get_nodes_in_group("dinosaur_egg")
	assert(nests.size() == 6, "Configured egg nests were not spawned")
	var nest = nests[0]
	assert(nest is Area3D and nest.collision_layer == 0, "Egg nest incorrectly blocks dinosaur movement")
	assert(not nest.get_signal_connection_list("hatched").is_empty(), "Egg nest has no hatch handler")
	assert(nest.get_node_or_null("Egg") != null, "Nest has no visible 3D egg")
	nest.incubation_seconds = 0.25
	var hatch_events := [0]
	nest.hatched.connect(func(_parent: CharacterBody3D, _position: Vector3) -> void: hatch_events[0] += 1)

	var player = world.player
	player.global_position = nest.global_position + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	for frame in 3:
		await physics_frame
	assert(nest.nearby_player == player, "Walking onto an egg did not activate its nest")
	player.set_mobile_action("duck", true)
	for frame in 30:
		await physics_frame
	player.set_mobile_action("duck", false)
	assert(nest.hatching, "Holding duck over the egg did not complete breeding")
	assert(hatch_events[0] == 1, "Egg did not emit its hatch event")
	var babies := world.get_tree().get_nodes_in_group("baby_dinosaur")
	assert(babies.size() == 1, "Hatched egg created %d babies instead of one (main count: %d)" % [babies.size(), world.companions_spawned])
	var baby = babies[0]
	assert(baby.dino_id == player.dino_id, "Baby is not the same species as its parent")
	assert(baby.parent_dino == player, "Baby does not follow the player parent")
	assert(baby.model_scale < player.model_scale, "Baby model is not smaller than its parent")
	assert(baby.walk_speed < player.base_walk_speed and baby.run_speed < player.base_run_speed, "Baby is not slower than its parent")
	assert(baby.max_health > 0 and baby.health == baby.max_health, "Baby health was not initialized")
	assert(not _has_property(baby, "energy"), "Baby unexpectedly has an energy system")

	var initial_distance: float = baby.global_position.distance_to(player.global_position)
	player.global_position += Vector3(12.0, 0.0, 0.0)
	for frame in 100:
		await physics_frame
	assert(baby.global_position.distance_to(player.global_position) < initial_distance + 5.0, "Baby did not follow its moving parent")
	assert(baby.state in ["following", "catching_up", "beside_parent"], "Baby entered an invalid follow state")

	var hunters := world.get_tree().get_nodes_in_group("hunter_dinosaur")
	assert(not hunters.is_empty(), "Test world has no predator")
	var hunter = hunters[0]
	var baby_health_before: int = baby.health
	hunter.strength = 1
	hunter.attack_cooldown = 0.0
	hunter._attack(baby)
	assert(baby.health == baby_health_before - 3, "Predator could not damage the baby")
	baby.take_damage(10000, hunter)
	assert(baby.dead, "Baby could not be killed by a predator")
	assert(not baby.is_in_group("prey_dinosaur"), "Dead baby remained available as living prey")

	print("Breeding smoke test passed: nests, duck incubation, hatching, following, health, and predator damage")
	world.queue_free()
	await process_frame
	quit()


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false
