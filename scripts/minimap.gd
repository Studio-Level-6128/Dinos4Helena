extends Control

# Runtime-drawn minimap. World coordinates map into a fixed square and a small
# byte grid stores persistent fog-of-war discovery without allocating textures.
const FOG_GRID_SIZE := 40
const REVEAL_RADIUS := 34.0

var player: Node3D
var world_half_size := 200.0
var map_layout: Dictionary = {}
var discovered := PackedByteArray()
var draw_time := 0.0
var draw_interval := 0.18


func setup(target: Node3D, half_size: float, layout: Dictionary) -> void:
	player = target
	world_half_size = half_size
	map_layout = layout
	discovered.resize(FOG_GRID_SIZE * FOG_GRID_SIZE)
	discovered.fill(0)
	_reveal_player_area()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	draw_time -= delta
	if draw_time <= 0.0:
		draw_time = draw_interval
		_reveal_player_area()
		queue_redraw()


func set_performance_tier(tier: int) -> void:
	# Terrain and fog do not need a frame-rate refresh. Slower refresh intervals
	# eliminate hundreds of small draw calls per second on constrained phones.
	draw_interval = [0.40, 0.28, 0.12][clampi(tier, 0, 2)]


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	var map_theme := str(map_layout.get("theme", "grassland"))
	var frame_colors := {
		"grassland": [Color(0.025, 0.075, 0.045, 0.94), Color(0.72, 0.83, 0.42, 0.88), Color("668b49")],
		"desert": [Color(0.12, 0.075, 0.035, 0.94), Color("e2b566"), Color("bd8d4e")],
		"winter": [Color(0.055, 0.075, 0.10, 0.96), Color("b9d6e5"), Color("dce8ed")],
		"volcano": [Color(0.075, 0.035, 0.025, 0.96), Color("d16a3b"), Color("4d4841")]
	}
	var colors: Array = frame_colors.get(map_theme, frame_colors["grassland"])
	draw_rect(bounds, colors[0], true)
	draw_rect(bounds.grow(-2.0), colors[1], false, 2.0)
	var play_area := _play_area()
	draw_rect(play_area, colors[2], true)
	draw_rect(play_area, colors[1], false, 1.5)

	for biome in map_layout.get("biomes", []):
		var biome_position: Vector2 = biome["position"]
		var biome_radius: float = biome["radius"] * play_area.size.x / (world_half_size * 2.0)
		var biome_color := Color("6d9b55") if biome["type"] == "oasis" else (Color("a8753e") if biome["type"] == "desert" else (Color(0.12, 0.29, 0.12, 0.72) if biome["type"] == "forest" else Color(0.48, 0.62, 0.29, 0.62)))
		if map_theme == "winter":
			biome_color = Color("afc4cb") if biome["type"] == "forest" else Color("d9e5e8")
		draw_circle(_world_to_map(biome_position), biome_radius, biome_color)
	for pond in map_layout.get("ponds", []):
		var pond_position: Vector3 = pond["position"]
		var pond_size: Vector2 = pond["size"]
		var pixel_size := _world_size_to_map(pond_size)
		draw_rect(Rect2(_world_to_map(Vector2(pond_position.x, pond_position.z)) - pixel_size * 0.5, pixel_size), (Color("9ed5e5") if map_theme == "winter" else Color(0.16, 0.49, 0.66, 0.92)), true)
	for river in map_layout.get("rivers", []):
		var river_map_points := PackedVector2Array()
		for river_point in river["points"]:
			river_map_points.append(_world_to_map(river_point))
		var river_width := float(river["width"]) * play_area.size.x / (world_half_size * 2.0)
		draw_polyline(river_map_points, Color("a7d8e6") if map_theme == "winter" else Color(0.12, 0.42, 0.55, 0.95), maxf(river_width, 2.0), true)
	if not map_layout.get("volcano", {}).is_empty():
		var volcano: Dictionary = map_layout["volcano"]
		var volcano_radius := float(volcano["radius"]) * play_area.size.x / (world_half_size * 2.0)
		draw_circle(_world_to_map(Vector2.ZERO), volcano_radius, Color("332c29"))
		draw_circle(_world_to_map(Vector2.ZERO), volcano_radius * 0.25, Color("ff5a20"))
	for stream in map_layout.get("lava_streams", []):
		var lava_points := PackedVector2Array()
		for lava_point in stream["points"]:
			lava_points.append(_world_to_map(lava_point))
		var lava_width := float(stream["width"]) * play_area.size.x / (world_half_size * 2.0)
		draw_polyline(lava_points, Color("ff6528"), maxf(lava_width, 2.0), true)
	for hill in map_layout.get("hills", []):
		var hill_position: Vector3 = hill["position"]
		var hill_scale: Vector3 = hill["scale"]
		var hill_radius := maxf(hill_scale.x, hill_scale.z) * play_area.size.x / (world_half_size * 2.0)
		draw_circle(_world_to_map(Vector2(hill_position.x, hill_position.z)), hill_radius, Color(0.27, 0.38, 0.2, 0.92))
	for formation in map_layout.get("high_ground", []):
		var formation_position: Vector3 = formation["position"]
		draw_circle(_world_to_map(Vector2(formation_position.x, formation_position.z)), 3.2, Color(0.38, 0.39, 0.32, 0.96))
	for tree in map_layout.get("trees", []):
		var tree_position: Vector3 = tree["position"]
		draw_circle(_world_to_map(Vector2(tree_position.x, tree_position.z)), 2.1, Color(0.08, 0.28, 0.12, 1.0))
	for rock in map_layout.get("rocks", []):
		var rock_position: Vector3 = rock["position"]
		draw_circle(_world_to_map(Vector2(rock_position.x, rock_position.z)), 1.7, Color(0.48, 0.49, 0.45, 1.0))
	for log_data in map_layout.get("logs", []):
		var log_position: Vector3 = log_data["position"]
		draw_circle(_world_to_map(Vector2(log_position.x, log_position.z)), 1.5, Color(0.30, 0.20, 0.11, 1.0))
	_draw_feast_markers()
	_draw_wildlife_markers()

	_draw_unexplored_fog()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 5.0, 20.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if not is_instance_valid(player):
		return
	var marker := _world_to_map(Vector2(player.global_position.x, player.global_position.z))
	var forward_3d := -player.global_transform.basis.z.normalized()
	var direction := Vector2(forward_3d.x, forward_3d.z).normalized()
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		marker + direction * 8.0,
		marker - direction * 5.0 + side * 4.5,
		marker - direction * 5.0 - side * 4.5
	])
	draw_colored_polygon(arrow, Color("ffcf4d"))
	var outline := PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]])
	draw_polyline(outline, Color(0.08, 0.06, 0.02, 0.95), 2.0, true)


func _draw_feast_markers() -> void:
	if not is_inside_tree():
		return
	for candidate in get_tree().get_nodes_in_group("edible_meat"):
		if not candidate is Node3D:
			continue
		var meat := candidate as Node3D
		var marker := _world_to_map(Vector2(meat.global_position.x, meat.global_position.z))
		draw_circle(marker, 4.0, Color("e94b3c"))
		draw_circle(marker, 4.0, Color("fff0c2"), false, 1.4)
		draw_line(marker + Vector2(-2.2, -2.2), marker + Vector2(2.2, 2.2), Color("fff0c2"), 1.2)
		draw_line(marker + Vector2(-2.2, 2.2), marker + Vector2(2.2, -2.2), Color("fff0c2"), 1.2)


func get_feast_marker_count() -> int:
	if not is_inside_tree():
		return 0
	return get_tree().get_nodes_in_group("edible_meat").size()


func _draw_wildlife_markers() -> void:
	for marker_data in get_wildlife_marker_data():
		var marker_position: Vector2 = marker_data["position"]
		var marker := _world_to_map(marker_position)
		var marker_color := Color("e4473f") if marker_data["kind"] == "predator" else Color("55d46a")
		draw_circle(marker, 3.7, Color(0.015, 0.025, 0.018, 0.92))
		draw_circle(marker, 2.6, marker_color)


func get_wildlife_marker_data() -> Array[Dictionary]:
	# Pack members move close together and would otherwise make the small map
	# unreadable. Average only currently explored members into one live marker;
	# solitary hunters and babies retain their own marker.
	var markers: Array[Dictionary] = []
	var explored_packs: Dictionary = {}
	if not is_inside_tree():
		return markers
	for candidate in get_tree().get_nodes_in_group("npc_dinosaur"):
		if not candidate is Node3D or bool(candidate.get("dead")):
			continue
		var dinosaur := candidate as Node3D
		var world_position := Vector2(dinosaur.global_position.x, dinosaur.global_position.z)
		if not is_world_position_explored(world_position):
			continue
		var pack_id := int(dinosaur.get("pack_id"))
		var is_herbivore_pack := dinosaur.is_in_group("prey_dinosaur") and not dinosaur.is_in_group("baby_dinosaur") and pack_id >= 0
		if is_herbivore_pack:
			var pack_key := "%s:%d" % [str(dinosaur.get("dino_id")), pack_id]
			var pack_data: Dictionary = explored_packs.get(pack_key, {"position_sum": Vector2.ZERO, "count": 0, "pack_id": pack_id})
			pack_data["position_sum"] = pack_data["position_sum"] + world_position
			pack_data["count"] = int(pack_data["count"]) + 1
			explored_packs[pack_key] = pack_data
		else:
			markers.append({
				"position": world_position,
				"kind": "predator" if dinosaur.is_in_group("hunter_dinosaur") else "herbivore",
				"pack_id": -1
			})
	for pack_data in explored_packs.values():
		markers.append({
			"position": pack_data["position_sum"] / float(pack_data["count"]),
			"kind": "herbivore",
			"pack_id": pack_data["pack_id"]
		})
	return markers


func _draw_unexplored_fog() -> void:
	if discovered.is_empty():
		return
	var area := _play_area()
	var cell_pixels := area.size / float(FOG_GRID_SIZE)
	for cell_y in FOG_GRID_SIZE:
		var hidden_run_start := -1
		for cell_x in FOG_GRID_SIZE + 1:
			var hidden := cell_x < FOG_GRID_SIZE and discovered[cell_y * FOG_GRID_SIZE + cell_x] == 0
			if hidden and hidden_run_start < 0:
				hidden_run_start = cell_x
			elif not hidden and hidden_run_start >= 0:
				var cell_position := area.position + Vector2(hidden_run_start, cell_y) * cell_pixels
				var run_size := Vector2(float(cell_x - hidden_run_start) * cell_pixels.x, cell_pixels.y) + Vector2.ONE
				draw_rect(Rect2(cell_position, run_size), Color(0.01, 0.018, 0.014, 0.96), true)
				hidden_run_start = -1


func _reveal_player_area() -> void:
	if not is_instance_valid(player) or discovered.is_empty():
		return
	var player_position := Vector2(player.global_position.x, player.global_position.z)
	var cell_world_size := world_half_size * 2.0 / float(FOG_GRID_SIZE)
	for cell_y in FOG_GRID_SIZE:
		for cell_x in FOG_GRID_SIZE:
			var cell_center := Vector2(
				-world_half_size + (float(cell_x) + 0.5) * cell_world_size,
				-world_half_size + (float(cell_y) + 0.5) * cell_world_size
			)
			if cell_center.distance_to(player_position) <= REVEAL_RADIUS:
				discovered[cell_y * FOG_GRID_SIZE + cell_x] = 1


func is_world_position_explored(world_position: Vector2) -> bool:
	var normalized := (world_position + Vector2.ONE * world_half_size) / (world_half_size * 2.0)
	var cell_x := clampi(int(normalized.x * FOG_GRID_SIZE), 0, FOG_GRID_SIZE - 1)
	var cell_y := clampi(int(normalized.y * FOG_GRID_SIZE), 0, FOG_GRID_SIZE - 1)
	return not discovered.is_empty() and discovered[cell_y * FOG_GRID_SIZE + cell_x] == 1


func get_explored_fraction() -> float:
	if discovered.is_empty():
		return 0.0
	var explored := 0
	for value in discovered:
		explored += int(value)
	return float(explored) / float(discovered.size())


func _play_area() -> Rect2:
	return Rect2(Vector2(10, 10), size - Vector2(20, 20))


func _world_size_to_map(world_size: Vector2) -> Vector2:
	return world_size / (world_half_size * 2.0) * _play_area().size


func _world_to_map(world_position: Vector2) -> Vector2:
	var normalized := (world_position + Vector2.ONE * world_half_size) / (world_half_size * 2.0)
	return _play_area().position + normalized * _play_area().size
