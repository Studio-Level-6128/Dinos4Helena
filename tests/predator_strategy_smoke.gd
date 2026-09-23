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
	assert(herbivores.size() >= 2 and not hunters.is_empty(), "Test world lacks wildlife")
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)

	var hunter = hunters[0]
	var prey = herbivores[0]
	var ally: Node3D
	for candidate in herbivores:
		if candidate != prey and candidate.dino_id == prey.dino_id:
			ally = candidate
			break
	assert(ally != null, "Could not find a same-species herd ally")

	# Park all unrelated animals and the player outside the decision area.
	var parked_index := 0
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		if dinosaur == hunter or dinosaur == prey or dinosaur == ally:
			continue
		dinosaur.global_position = Vector3(-180.0 + parked_index * 3.0, 0.1, -180.0)
		parked_index += 1
	world.player.global_position = Vector3(-220.0, 0.1, -220.0)

	# A marginal lone target is shadowed from a safe distance, not rushed.
	hunter.max_health = 100
	hunter.health = 100
	hunter.strength = 10
	hunter.collision_radius = 1.0
	hunter.collision_height = 2.0
	hunter.energy = hunter.max_energy
	prey.max_health = 100
	prey.health = 100
	prey.strength = 14
	prey.collision_radius = 1.0
	prey.collision_height = 2.0
	hunter.global_position = Vector3(80.0, 0.1, 80.0)
	prey.global_position = Vector3(80.0, 0.1, 94.0)
	ally.global_position = Vector3(-210.0, 0.1, -210.0)
	hunter.forced_target = prey
	var stalk_health: int = prey.health
	var stalk_direction: Vector3 = hunter._hunt_direction(0.1)
	assert(hunter.state == "stalking", "Hunter did not stalk a marginal target")
	assert(stalk_direction.dot(Vector3.FORWARD) < -0.8, "Hunter did not shadow the prey")
	assert(prey.health == stalk_health, "Stalking hunter attacked before the odds were good")

	# A nearby same-species ally makes the target too risky. The hunter must
	# account for the herd's combined power and create distance.
	ally.max_health = 100
	ally.health = 100
	ally.strength = 14
	ally.collision_radius = 1.0
	ally.collision_height = 2.0
	ally.global_position = prey.global_position + Vector3(2.0, 0.0, 0.0)
	hunter.forced_target = prey
	var avoid_direction: Vector3 = hunter._hunt_direction(0.1)
	var away_from_prey: Vector3 = hunter.global_position - prey.global_position
	away_from_prey.y = 0.0
	assert(hunter.state == "avoiding", "Hunter challenged an overpowering herd")
	assert(avoid_direction.dot(away_from_prey.normalized()) > 0.8, "Hunter did not back away from the herd")

	# Once the target is isolated and the balance is favorable, the hunter
	# closes in and attacks at striking range.
	ally.global_position = Vector3(-210.0, 0.1, -210.0)
	prey.health = 60
	prey.strength = 4
	prey.global_position = hunter.global_position + Vector3(0.0, 0.0, -12.0)
	hunter.forced_target = prey
	var pursuit_direction: Vector3 = hunter._hunt_direction(0.1)
	assert(hunter.state == "hunting", "Hunter did not commit to a favorable target")
	assert(pursuit_direction.dot(Vector3.FORWARD) > 0.8, "Hunter did not close on favorable prey")
	prey.global_position = hunter.global_position + Vector3(0.0, 0.0, -1.2)
	hunter.forced_target = prey
	hunter.attack_cooldown = 0.0
	var prey_health_before: int = prey.health
	var strike_direction: Vector3 = hunter._hunt_direction(0.1)
	assert(hunter.state == "attacking" and prey.health < prey_health_before, "Hunter did not strike when success odds were good")
	assert(strike_direction.dot(Vector3.FORWARD) > 0.8, "Hunter stopped pursuing while attacking")

	# Severe injury always overrides hunting while an opponent is nearby.
	prey.health = prey.max_health
	prey.global_position = hunter.global_position + Vector3(0.0, 0.0, -5.0)
	hunter.health = 29
	hunter.forced_target = prey
	hunter.set_physics_process(true)
	await physics_frame
	hunter.set_physics_process(false)
	var retreat_direction := Vector3(hunter.velocity.x, 0.0, hunter.velocity.z).normalized()
	var expected_retreat: Vector3 = hunter.global_position - prey.global_position
	expected_retreat.y = 0.0
	assert(hunter.state == "retreating", "Heavily injured hunter did not retreat")
	assert(retreat_direction.dot(expected_retreat.normalized()) > 0.8, "Injured hunter retreated in the wrong direction")

	print("Predator strategy smoke test passed: stalking, pack avoidance, favorable strikes, and injury retreat")
	world.queue_free()
	await process_frame
	quit()
