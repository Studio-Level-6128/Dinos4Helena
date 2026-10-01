extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world.seed_input.text = "424242"
	world._start_game("triceratops")
	await physics_frame

	var herbivores := world.get_tree().get_nodes_in_group("prey_dinosaur")
	var hunters := world.get_tree().get_nodes_in_group("hunter_dinosaur")
	assert(herbivores.size() >= 2 and not hunters.is_empty(), "Test world lacks wildlife")
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)

	var defender = herbivores[0]
	var packmate: Node3D
	for candidate in herbivores:
		if candidate != defender and candidate.pack_id == defender.pack_id and candidate.dino_id == defender.dino_id:
			packmate = candidate
			break
	assert(packmate != null, "Could not find two members of one herbivore pack")
	var hunter = hunters[0]
	var player = world.player

	# No dinosaur may injure or select a member of its own species.
	var packmate_health: int = packmate.health
	defender.attack_cooldown = 0.0
	defender._attack(packmate)
	assert(packmate.health == packmate_health, "Same-species NPC attack caused damage")
	player.dino_id = defender.dino_id
	var player_health: int = player.health
	player.take_damage(20, true, defender)
	assert(player.health == player_health, "Same-species NPC damaged the player")

	player.dino_id = hunter.dino_id
	hunter.forced_target = player
	player.global_position = hunter.global_position + Vector3(0.0, 0.0, 2.0)
	for prey in herbivores:
		prey.global_position = hunter.global_position + Vector3(120.0, 0.0, 120.0)
	assert(hunter._choose_prey() != player, "Carnivore selected a same-species player as prey")

	# A matching herbivore player is welcomed into the herd.
	player.dino_id = defender.dino_id
	player.diet = "herbivore"
	defender.global_position = Vector3(80.0, 0.1, 80.0)
	packmate.global_position = Vector3(82.0, 0.1, 80.0)
	player.global_position = Vector3(100.0, 0.1, 80.0)
	var welcome_direction: Vector3 = defender._pack_direction(0.1)
	assert(welcome_direction.dot(Vector3.RIGHT) > 0.8 and defender.state == "welcoming", "Pack did not welcome a matching herbivore player")

	# A herbivore scream calls every nearby same-species animal into a ring,
	# even when it belongs to another pack.
	player.last_attacker = null
	defender.global_position = player.global_position + Vector3(-24.0, 0.0, 0.0)
	packmate.global_position = player.global_position + Vector3(20.0, 0.0, 4.0)
	world._on_dino_screamed()
	assert(defender.rally_target == player and defender.rally_time > 0.0, "Herbivore scream did not call a nearby same-species dinosaur")
	assert(packmate.rally_target == player and packmate.rally_time > 0.0, "Herbivore scream did not call the whole nearby herd")
	assert(defender._rally_direction().dot((player.global_position - defender.global_position).normalized()) > 0.7, "Called herd member did not converge on the player")

	# When that player is attacked, nearby members converge and retaliate.
	hunter.global_position = player.global_position + Vector3(0.0, 0.0, 1.2)
	defender.global_position = player.global_position + Vector3(-1.2, 0.0, 0.0)
	packmate.global_position = player.global_position + Vector3(1.2, 0.0, 0.0)
	player.take_damage(5, true, hunter)
	assert(defender.ally_defense_target == hunter, "Pack ignored an attack on the matching player")
	assert(packmate.ally_defense_target == hunter, "Not all nearby pack members joined the defense")
	var hunter_health: int = hunter.health
	defender.attack_cooldown = 0.0
	defender.set_physics_process(true)
	for frame in 5:
		await physics_frame
	defender.set_physics_process(false)
	assert(hunter.health < hunter_health, "Pack defender did not fight the player's attacker")

	# A predator scream overrides formation and gives each prey animal an
	# independently jittered escape direction, breaking the pack apart.
	player.dino_id = hunter.dino_id
	player.diet = "carnivore"
	player.global_position = Vector3(40.0, 0.1, 40.0)
	defender.global_position = player.global_position + Vector3(-8.0, 0.0, 0.0)
	packmate.global_position = player.global_position + Vector3(-8.0, 0.0, 2.0)
	world._on_dino_screamed()
	assert(defender.panic_time > 0.0 and packmate.panic_time > 0.0, "Predator scream did not frighten nearby prey")
	assert(defender.panic_direction.dot(packmate.panic_direction) < 0.999, "Frightened pack members fled in a coordinated direction")
	defender.set_physics_process(true)
	packmate.set_physics_process(true)
	await physics_frame
	defender.set_physics_process(false)
	packmate.set_physics_process(false)
	assert(defender.state == "panicked" and packmate.state == "panicked", "Fear did not override normal pack behavior")

	print("Herd shelter smoke test passed: species peace, rally, pack defense, and predator fear")
	world.queue_free()
	await process_frame
	quit()
