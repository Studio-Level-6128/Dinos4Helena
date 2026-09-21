extends Control

const FOG_GRID_SIZE := 40
const REVEAL_RADIUS := 34.0
const DRAW_INTERVAL := 0.12

var player: Node3D
var world_half_size := 200.0
var map_layout: Dictionary = {}
var discovered := PackedByteArray()
var draw_time := 0.0


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
		draw_time = DRAW_INTERVAL
		_reveal_player_area()
		queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.025, 0.075, 0.045, 0.94), true)
	draw_rect(bounds.grow(-2.0), Color(0.72, 0.83, 0.42, 0.88), false, 2.0)
	var play_area := _play_area()
	draw_rect(play_area, Color("668b49"), true)
	draw_rect(play_area, Color(0.9, 0.88, 0.58, 0.75), false, 1.5)

	for pond in map_layout.get("ponds", []):
		var pond_position: Vector3 = pond["position"]
		var pond_size: Vector2 = pond["size"]
		var pixel_size := _world_size_to_map(pond_size)
		draw_rect(Rect2(_world_to_map(Vector2(pond_position.x, pond_position.z)) - pixel_size * 0.5, pixel_size), Color(0.16, 0.49, 0.66, 0.92), true)
	for hill in map_layout.get("hills", []):
		var hill_position: Vector3 = hill["position"]
		var hill_scale: Vector3 = hill["scale"]
		var hill_radius := maxf(hill_scale.x, hill_scale.z) * play_area.size.x / (world_half_size * 2.0)
		draw_circle(_world_to_map(Vector2(hill_position.x, hill_position.z)), hill_radius, Color(0.27, 0.38, 0.2, 0.92))
	for tree in map_layout.get("trees", []):
		var tree_position: Vector3 = tree["position"]
		draw_circle(_world_to_map(Vector2(tree_position.x, tree_position.z)), 2.1, Color(0.08, 0.28, 0.12, 1.0))
	for rock in map_layout.get("rocks", []):
		var rock_position: Vector3 = rock["position"]
		draw_circle(_world_to_map(Vector2(rock_position.x, rock_position.z)), 1.7, Color(0.48, 0.49, 0.45, 1.0))

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
