extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	world.seed_input.text = "246810"
	world._start_game("trex")
	await physics_frame

	assert(world.get_performance_tier_name() == "high", "Gameplay did not start at full rendering quality")
	assert(world.quality_geometry.size() >= world.generated_vegetation.size(), "Dense world geometry was not registered for adaptive culling")
	var minimap: Control = world.active_minimap
	var cameras: Array[Node] = world.player.find_children("*", "Camera3D", true, false)
	assert(not cameras.is_empty(), "Player follow camera is missing")
	var camera := cameras[0] as Camera3D
	var small_geometry: GeometryInstance3D
	for geometry in world.quality_geometry:
		if str(geometry.get_meta("_quality_category", "")) == "small":
			small_geometry = geometry
			break
	assert(small_geometry != null, "Vegetation was not registered as small adaptive geometry")

	world._apply_performance_tier(world.QUALITY_MEDIUM)
	assert(is_equal_approx(root.scaling_3d_scale, 0.86), "Medium tier did not reduce only the 3D render scale")
	assert(world.sun_light.shadow_enabled and is_equal_approx(world.sun_light.directional_shadow_max_distance, 62.0), "Medium tier shadow distance is incorrect")
	assert(is_equal_approx(small_geometry.visibility_range_end, 95.0), "Medium tier did not distance-cull vegetation")
	assert(is_equal_approx(minimap.draw_interval, 0.28), "Medium tier did not reduce minimap refresh cost")

	world._apply_performance_tier(world.QUALITY_LOW)
	assert(is_equal_approx(root.scaling_3d_scale, 0.72), "Low tier render scale is incorrect")
	assert(not world.sun_light.shadow_enabled, "Low tier did not disable the expensive world shadow")
	assert(is_equal_approx(camera.far, 170.0), "Low tier did not reduce the camera range")
	assert(is_equal_approx(small_geometry.visibility_range_end, 62.0), "Low tier vegetation culling distance is incorrect")
	assert(small_geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Low tier vegetation still casts shadows")
	assert(is_equal_approx(minimap.draw_interval, 0.40), "Low tier minimap refresh interval is incorrect")

	world._apply_performance_tier(world.QUALITY_HIGH)
	assert(is_equal_approx(root.scaling_3d_scale, 1.0), "High tier did not restore native 3D resolution")
	assert(world.sun_light.shadow_enabled, "High tier did not restore shadows")
	assert(is_equal_approx(minimap.draw_interval, 0.12), "High tier did not restore the original minimap refresh rate")
	assert(is_equal_approx(small_geometry.visibility_range_end, float(small_geometry.get_meta("_quality_original_range", 0.0))), "High tier did not restore the original draw range")

	print("Performance scaling smoke test passed: adaptive resolution, shadows, culling, camera, and minimap")
	world.queue_free()
	await process_frame
	quit()
