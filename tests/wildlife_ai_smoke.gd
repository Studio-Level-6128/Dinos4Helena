extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world.seed_input.text = "424242"
	world._start_game("velociraptor")
	await physics_frame

	var herbivores := world.get_tree().get_nodes_in_group("prey_dinosaur")
	var hunters := world.get_tree().get_nodes_in_group("hunter_dinosaur")
	assert(herbivores.size() >= 12, "Too few pack herbivores spawned")
	assert(hunters.size() >= 4, "Too few solitary hunters spawned")
	var pack_sizes := {}
	for herbivore in herbivores:
		assert(herbivore.pack_id >= 0, "Herbivore spawned without a pack")
		pack_sizes[herbivore.pack_id] = int(pack_sizes.get(herbivore.pack_id, 0)) + 1
	for count in pack_sizes.values():
		assert(count >= 2, "A herbivore pack has fewer than two members")
		assert(count <= 6, "A herbivore pack is too large")
	assert(pack_sizes.size() >= 6, "Too few separate herbivore packs spawned")
	for hunter in hunters:
		assert(hunter.pack_id == -1, "Carnivore incorrectly spawned in a pack")

	var prey = herbivores[0]
	var hunter = hunters[0]
	# Isolate one encounter so this general combat test is not intentionally
	# rejected by the hunter's pack-risk assessment.
	var parked_index := 0
	for herbivore in herbivores:
		if herbivore == prey:
			continue
		herbivore.set_physics_process(false)
		herbivore.global_position = Vector3(-180.0 + parked_index * 3.0, 0.1, -180.0)
		parked_index += 1
	hunter.max_health = 250
	hunter.health = hunter.max_health
	hunter.strength = 18
	prey.global_position = Vector3(90.0, 0.1, 90.0)
	hunter.global_position = Vector3(90.0, 0.1, 108.0)
	var hunter_energy_before_chase: float = hunter.energy
	await physics_frame
	assert(prey.state == "fleeing", "Herbivore did not flee from a nearby hunter")
	assert(hunter.energy < hunter_energy_before_chase, "Hunting carnivore did not use energy")

	prey.global_position = Vector3(90.0, 0.1, 90.0)
	hunter.global_position = Vector3(90.0, 0.1, 91.2)
	hunter.forced_target = prey
	hunter.attack_cooldown = 0.0
	var prey_health_before: int = prey.health
	var hunter_health_before_defence: int = hunter.health
	for frame in 4:
		await physics_frame
	assert(prey.health < prey_health_before, "Hunter did not attack another dinosaur")
	assert(prey.retaliation_target == hunter, "Attacked herbivore did not target its attacker")
	for frame in 12:
		await physics_frame
	assert(hunter.health < hunter_health_before_defence, "Attacked herbivore did not fight back")

	var meal_prey = herbivores[2]
	meal_prey.set_physics_process(false)
	meal_prey.global_position = Vector3(115.0, 0.1, 115.0)
	hunter.global_position = Vector3(115.0, 0.1, 116.0)
	hunter.energy = 30.0
	hunter.attack_cooldown = 0.0
	meal_prey.health = 1
	hunter._attack(meal_prey)
	await physics_frame
	assert(meal_prey.dead and is_instance_valid(hunter.food_target), "Hunter did not claim meat from its prey")
	var energy_before_feeding: float = hunter.energy
	for frame in 24:
		await physics_frame
	assert(hunter.energy > energy_before_feeding, "Carnivore did not feed before hunting again")

	var player = world.player
	# Use a different carnivore species so the non-aggression rule does not
	# intentionally prevent this cross-species player combat check.
	player.dino_id = "trex" if hunter.dino_id == "velociraptor" else "velociraptor"
	var player_health_before: int = player.health
	hunter.food_target = null
	hunter.energy = hunter.max_energy
	hunter.global_position = player.global_position + Vector3(0.0, 0.0, -1.2)
	hunter.forced_target = player
	hunter.attack_cooldown = 0.0
	for frame in 4:
		await physics_frame
	assert(player.health < player_health_before, "Hunter did not attack the nearby player")

	hunter.global_position = Vector3(150.0, 0.1, 150.0)
	prey.set_physics_process(false)
	prey.global_position = player.global_position + Vector3(0.0, 0.0, -2.0)
	prey.health = prey.max_health
	player.rotation.y = 0.0
	var health_before_player_attack: int = prey.health
	player.set_mobile_action("attack", true)
	player.set_mobile_action("attack", false)
	for frame in 20:
		await physics_frame
	assert(prey.health < health_before_player_attack, "Player attack did not damage a nearby dinosaur")

	var meat_before := world.get_tree().get_nodes_in_group("edible_meat").size()
	prey.take_damage(10000, player)
	await process_frame
	assert(prey.dead, "Defeated wildlife did not die")
	assert(world.get_tree().get_nodes_in_group("edible_meat").size() == meat_before + 1, "Defeated dinosaur did not drop edible meat")
	var minimap := world.find_child("MiniMap", true, false)
	assert(minimap != null and minimap.get_feast_marker_count() == meat_before + 1, "Minimap did not register the feast location")
	var meat := world.get_tree().get_nodes_in_group("edible_meat")[-1] as Node3D
	player.global_position = meat.global_position + Vector3(0.0, 0.1, 0.8)
	player.energy = 40.0
	player.set_mobile_action("eat", true)
	for frame in 30:
		await physics_frame
	player.set_mobile_action("eat", false)
	assert(player.energy > 48.0, "Carnivore did not regain energy from defeated prey")

	# Place one surviving pack and one predator in already explored terrain.
	# The pack must collapse to one green marker while the solitary hunter gets
	# its own red marker.
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)
		dinosaur.global_position = Vector3(175.0, 0.1, 175.0)
	player.global_position = Vector3.ZERO
	var marker_pack_id := -1
	var marker_pack_members: Array = []
	var surviving_packs: Dictionary = {}
	for candidate in herbivores:
		if bool(candidate.dead):
			continue
		var surviving_pack_id: int = candidate.pack_id
		var surviving_members: Array = surviving_packs.get(surviving_pack_id, [])
		surviving_members.append(candidate)
		surviving_packs[surviving_pack_id] = surviving_members
	for surviving_pack_id in surviving_packs:
		var surviving_members: Array = surviving_packs[surviving_pack_id]
		if surviving_members.size() >= 2:
			marker_pack_id = int(surviving_pack_id)
			marker_pack_members = surviving_members
			break
	assert(marker_pack_members.size() >= 2, "Could not find a surviving pack for minimap grouping")
	for member_index in marker_pack_members.size():
		marker_pack_members[member_index].global_position = Vector3(float(member_index) * 1.5, 0.1, 4.0)
	hunter.global_position = Vector3(-5.0, 0.1, 2.0)
	minimap._reveal_player_area()
	var wildlife_markers: Array[Dictionary] = minimap.get_wildlife_marker_data()
	var matching_pack_markers := 0
	var predator_markers := 0
	for marker_data in wildlife_markers:
		if marker_data["pack_id"] == marker_pack_id:
			matching_pack_markers += 1
		if marker_data["kind"] == "predator":
			predator_markers += 1
	assert(matching_pack_markers == 1, "Minimap did not collapse an herbivore pack to one marker")
	assert(predator_markers == 1, "Minimap did not show the explored predator marker")

	print("Wildlife AI smoke test passed: combat, feeding, feast drops, and grouped explored map markers")
	world.queue_free()
	await process_frame
	quit()
