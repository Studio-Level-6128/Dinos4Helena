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
	await process_frame # allow deferred friendly collision setup

	var herbivores := world.get_tree().get_nodes_in_group("prey_dinosaur")
	for dinosaur in world.get_tree().get_nodes_in_group("npc_dinosaur"):
		dinosaur.set_physics_process(false)
	for hunter in world.get_tree().get_nodes_in_group("hunter_dinosaur"):
		hunter.global_position = Vector3(-180.0, 0.1, -180.0)
	world.player.global_position = Vector3(-180.0, 0.1, 180.0)

	var leader: CharacterBody3D
	var follower: CharacterBody3D
	for candidate in herbivores:
		if candidate.pack_slot == 0:
			for packmate in herbivores:
				if packmate.pack_id == candidate.pack_id and packmate.dino_id == candidate.dino_id and packmate.pack_slot == 1:
					leader = candidate
					follower = packmate
					break
		if is_instance_valid(follower):
			break
	assert(is_instance_valid(leader) and is_instance_valid(follower), "Could not find leader and follower in one pack")
	assert(leader.get_collision_exceptions().has(follower), "Packmates can still physically deadlock each other")
	assert(follower.get_collision_exceptions().has(leader), "Friendly collision exception is not mutual")

	for candidate in herbivores:
		if candidate != leader and candidate != follower:
			candidate.global_position = Vector3(170.0, 0.1, 170.0)
	var clear_origin := Vector3(0.0, 0.1, 0.0)
	leader.global_position = clear_origin
	follower.global_position = leader.global_position + Vector3(0.0, 0.0, 14.0)

	# The leader chooses one world-scale destination and keeps it until arrival;
	# elapsed time alone must not replace it.
	leader.pack_goal_initialized = false
	var goal_direction: Vector3 = leader._pack_goal_direction(0.1)
	var first_goal: Vector3 = leader.pack_goal
	var first_goal_distance := first_goal.distance_to(leader.global_position)
	assert(first_goal_distance >= 39.0 and first_goal_distance <= 106.0, "Pack goal is not a long-distance destination")
	assert(world.is_pack_destination_clear(first_goal), "Pack selected an unreachable destination")
	assert(goal_direction.length() > 0.9, "Leader did not pursue its long-distance goal")
	leader._pack_goal_direction(30.0)
	assert(leader.pack_goal.is_equal_approx(first_goal), "Pack goal reset before it was reached")
	leader.global_position = first_goal
	leader._pack_goal_direction(0.1)
	assert(leader.pack_goal_resets == 1 and not leader.pack_goal.is_equal_approx(first_goal), "Leader did not choose a new goal after arrival")

	# Overlap recovery remains independent from destination selection.
	leader.global_position = clear_origin
	follower.global_position = leader.global_position
	leader.pack_goal = leader.global_position + Vector3(70.0, 0.0, 0.0)
	leader.pack_goal_initialized = true
	var leader_separation: Vector3 = leader._pack_separation()
	var follower_separation: Vector3 = follower._pack_separation()
	assert(leader_separation.length() > 0.1 and follower_separation.length() > 0.1, "Overlapping packmates did not generate separation steering")
	assert(leader_separation.dot(follower_separation) < -0.8, "Overlapping packmates were not steered apart")

	# Followers occupy offset trail positions instead of converging on one
	# shared center point.
	follower.global_position = leader.global_position + Vector3(0.0, 0.0, 10.0)
	follower.straggler_time = 0.0
	var formation_target: Vector3 = follower._pack_follow_target(leader)
	assert(formation_target.distance_to(leader.global_position) > 4.0, "Follower formation target is too close to the leader")
	assert(absf(formation_target.x - leader.global_position.x) > 1.0, "Follower has no side-by-side formation offset")

	# The designated individual periodically trails beyond the pack-support
	# radius, giving a hunter a viable isolated target.
	follower.straggler_time = 8.0
	var trailing_target: Vector3 = follower._pack_follow_target(leader)
	assert(trailing_target.distance_to(leader.global_position) > 24.0, "Straggler did not leave the pack's defensive power radius")
	var trailing_direction: Vector3 = follower._pack_direction(0.1)
	assert(follower.state == "trailing" and trailing_direction.length() > 0.8, "Straggler did not actively follow the moving pack")

	# Simulate the former worst case: two members spawned in the same spot.
	# They must both move and spread out instead of remaining collision-locked.
	follower.straggler_time = 0.0
	leader.global_position = clear_origin
	follower.global_position = leader.global_position
	leader.pack_goal_initialized = false
	leader._pack_goal_direction(0.0)
	var movement_goal: Vector3 = leader.pack_goal
	var starting_position: Vector3 = leader.global_position
	leader.set_physics_process(true)
	follower.set_physics_process(true)
	for frame in 180:
		await physics_frame
	leader.set_physics_process(false)
	follower.set_physics_process(false)
	assert(leader.global_position.distance_to(starting_position) > 5.0, "Pack leader failed to travel toward its distant goal")
	assert(follower.global_position.distance_to(starting_position) > 3.0, "Follower did not travel with the pack")
	assert(leader.global_position.distance_to(follower.global_position) > 1.0, "Overlapping packmates did not separate")
	assert(leader.pack_goal.is_equal_approx(movement_goal), "Leader abandoned an unreached movement goal")

	print("Pack movement smoke test passed: persistent goals, formation, stragglers, avoidance, and deadlock recovery")
	world.queue_free()
	await process_frame
	quit()
