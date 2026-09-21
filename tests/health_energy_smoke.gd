extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame

	world.seed_input.text = "314159"
	world._start_game("velociraptor")
	await physics_frame
	var carnivore = world.player
	assert(carnivore.diet == "carnivore", "Velociraptor diet is not configured as carnivore")
	assert(carnivore.health == carnivore.max_health, "Health did not start at the species maximum")
	assert(is_equal_approx(carnivore.energy, 100.0), "Energy did not start at 100 percent")
	assert(world.health_bar != null and world.energy_bar != null, "Health and energy bars were not created")
	assert(is_equal_approx(world.health_bar.value, float(carnivore.max_health)), "Health bar has the wrong initial value")
	assert(is_equal_approx(world.energy_bar.value, 100.0), "Energy bar has the wrong initial value")

	var energy_before_running: float = carnivore.energy
	carnivore.set_mobile_action("move_forward", true)
	carnivore.set_mobile_action("run", true)
	for frame in 30:
		await physics_frame
	carnivore.set_mobile_action("move_forward", false)
	carnivore.set_mobile_action("run", false)
	assert(carnivore.energy < energy_before_running, "Running did not consume energy")
	var energy_before_attack: float = carnivore.energy
	carnivore.set_mobile_action("attack", true)
	carnivore.set_mobile_action("attack", false)
	assert(carnivore.energy <= energy_before_attack - carnivore.attack_energy_cost, "Attacking did not consume its configured energy cost")
	carnivore.attack_time = 0.0

	carnivore.energy = 50.0
	carnivore.set_mobile_action("eat", true)
	for frame in 10:
		await physics_frame
	carnivore.set_mobile_action("eat", false)
	assert(is_equal_approx(carnivore.energy, 50.0), "Carnivore gained energy without meat")

	carnivore.energy = 0.0
	carnivore.vocal_audio.stop()
	var health_before_starvation: int = carnivore.health
	for frame in 35:
		await physics_frame
	assert(carnivore.health < health_before_starvation, "Zero energy did not gradually reduce health")
	assert(not carnivore.vocal_audio.playing, "Starvation damage incorrectly played the hurt warning sound")
	carnivore.take_damage(1000)
	assert(carnivore.dead, "Dinosaur did not die at zero health")
	assert("death" in carnivore.current_animation.to_lower(), "Native death animation did not start")
	await carnivore.died
	await process_frame
	assert(world.game_hud.get_node_or_null("GameOver") != null, "Game-over overlay was not shown")

	world._return_to_main_menu()
	await process_frame
	world.seed_input.text = "314159"
	world._start_game("triceratops")
	await physics_frame
	var herbivore = world.player
	assert(herbivore.diet == "herbivore", "Triceratops diet is not configured as herbivore")
	var plants := world.get_tree().get_nodes_in_group("edible_plant")
	assert(not plants.is_empty(), "No edible plants were generated")
	var plant := plants[0] as Node3D
	herbivore.global_position = plant.global_position + Vector3(0.0, 0.1, 1.0)
	herbivore.energy = 40.0
	herbivore.set_mobile_action("eat", true)
	for frame in 20:
		await physics_frame
	assert(herbivore.eating_active, "Eating pose did not activate")
	assert(absf(herbivore.model_root.rotation.x) > 0.05, "Eating did not lower the dinosaur into a grazing pose")
	for frame in 50:
		await physics_frame
	herbivore.set_mobile_action("eat", false)
	assert(herbivore.energy > 45.0, "Herbivore did not regain energy by grazing")
	assert(world.energy_bar.value > 45.0, "Energy bar did not update after eating")

	print("Health and energy smoke test passed: drain, starvation, food, HUD, and game over")
	world.queue_free()
	await process_frame
	quit()
