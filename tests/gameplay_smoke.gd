extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	assert(world.menu_layer.visible, "Main menu was not shown on launch")
	world.seed_input.text = "123456"
	world._start_game("velociraptor")
	await physics_frame

	var player := world.get_node("PrehistoricWorld/PlayerDinosaur") as CharacterBody3D
	assert(player.audio_streams.size() == 7, "Velociraptor sound library did not load")
	assert(world.get_node_or_null("PrehistoricWorld/PrehistoricJungle") != null, "Jungle ambience did not start")
	assert(world.get_node_or_null("PrehistoricWorld/DistantDinosaurs") != null, "Distant dinosaur ambience did not start")
	var boundary := world.get_node_or_null("PrehistoricWorld/MapBoundary")
	assert(boundary != null and boundary.get_child_count() == 4, "Map boundary is incomplete")
	var obstacles := world.get_tree().get_nodes_in_group("world_obstacle")
	var expected_obstacles: int = world.generated_hills.size() + world.generated_trees.size() + world.generated_rocks.size() + world.generated_logs.size() + world.generated_high_ground.size() * 4
	assert(obstacles.size() == expected_obstacles and obstacles.size() >= 100, "Procedural landscape obstacles are missing collision bodies")
	for obstacle in obstacles:
		assert(not obstacle.find_children("*", "CollisionShape3D", true, false).is_empty(), "An obstacle has no collision shape")
	var minimap: Control = world.game_hud.find_child("MiniMap", true, false) as Control
	assert(minimap != null and minimap.get("player") == player, "Minimap is not tracking the player")
	assert(minimap.call("_world_to_map", Vector2.ZERO).is_equal_approx(minimap.size * 0.5), "Minimap world coordinates are misaligned")
	assert(minimap.call("is_world_position_explored", Vector2.ZERO), "Starting area was not revealed on the minimap")
	assert(not minimap.call("is_world_position_explored", Vector2(180, 180)), "Unexplored minimap area was revealed")
	assert(float(minimap.call("get_explored_fraction")) < 0.1, "Too much of the minimap starts revealed")
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

	var health_before_hit: int = player.health
	player.take_damage(12)
	assert(player.health == health_before_hit - 12, "Damage did not reduce dinosaur health")
	assert(player.vocal_audio.playing, "Hurt sound did not play")

	player.attack_time = 0.0
	player.scream_time = 0.0
	player.global_position = Vector3(0.0, 0.1, -197.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await physics_frame
	player.set_mobile_action("move_forward", true)
	player.set_mobile_action("run", true)
	for frame in 90:
		await physics_frame
	player.set_mobile_action("move_forward", false)
	player.set_mobile_action("run", false)
	assert(player.global_position.z > -199.5, "Dinosaur escaped through the north map boundary")

	var test_tree: Dictionary = world.generated_trees[0]
	var test_tree_position: Vector3 = test_tree["position"]
	player.global_position = test_tree_position + Vector3(0.0, 0.1, 4.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await physics_frame
	player.set_mobile_action("move_forward", true)
	for frame in 90:
		await physics_frame
	player.set_mobile_action("move_forward", false)
	assert(player.global_position.z > test_tree_position.z + 0.4, "Dinosaur walked through a tree")

	print("Gameplay smoke test passed: movement, actions, audio, collisions, boundary, and minimap")
	world.queue_free()
	await process_frame
	quit()
