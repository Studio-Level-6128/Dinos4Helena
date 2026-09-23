extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "Android orientation is not locked to landscape")
	assert(ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/ui/menu/dino-fight-splash.png", "Native startup splash artwork is not configured")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	assert(is_instance_valid(world.splash_layer) and world.splash_layer.visible, "Startup splash was not shown on launch")
	assert(not world.menu_layer.visible, "Main menu appeared above the startup splash")
	var splash_art := world.splash_layer.find_child("DinoFightArtwork", true, false) as TextureRect
	assert(splash_art != null and splash_art.texture != null, "Generated dinosaur-fight splash artwork is missing")
	world._dismiss_splash(true)
	assert(world.menu_layer.visible, "Dismissing the splash did not reveal the main menu")
	var guide_button := world.menu_layer.find_child("PlayGuideButton", true, false) as Button
	assert(guide_button != null, "Landing page has no play-guide button")
	world._open_play_guide()
	assert(world.play_guide_overlay.visible, "Play guide did not open")
	var guide_text := world.play_guide_overlay.find_child("PlayGuideText", true, false) as RichTextLabel
	assert(guide_text != null and "EGGS AND BABIES" in guide_text.text and "WILDLIFE" in guide_text.text, "Play guide is incomplete")
	world._close_play_guide()
	assert(not world.play_guide_overlay.visible, "Play guide did not close")
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
	var movement_wheel: Control = world.game_hud.find_child("MovementWheel", true, false) as Control
	assert(movement_wheel != null, "Touch HUD has no analog movement wheel")
	movement_wheel.call("set_input_vector", Vector2(0.05, 0.04))
	assert((movement_wheel.call("get_movement") as Vector2).is_zero_approx(), "Movement wheel dead zone allows unwanted drift")
	var analog_start_position: Vector3 = player.position
	var analog_start_rotation: float = player.rotation.y
	var touch_position := movement_wheel.size * 0.5 + Vector2(-0.65, -0.75) * float(movement_wheel.call("_wheel_radius"))
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 3
	touch_press.position = touch_position
	touch_press.pressed = true
	movement_wheel.call("_gui_input", touch_press)
	var analog_input: Vector2 = movement_wheel.call("get_movement")
	assert(analog_input.x > 0.35 and analog_input.y > 0.35, "Diagonal wheel position did not combine forward and left input")
	for frame in 18:
		await physics_frame
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 3
	touch_release.position = touch_position
	touch_release.pressed = false
	movement_wheel.call("_gui_input", touch_release)
	assert(player.position.distance_to(analog_start_position) > 0.35, "Analog wheel did not move the dinosaur")
	assert(player.rotation.y > analog_start_rotation + 0.15, "Analog wheel did not steer while moving")
	assert(player.mobile_movement.is_zero_approx(), "Movement wheel did not recenter on release")
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await physics_frame

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
