extends Control

const MAP_HALF_SIZE := 55.0
const POND_POSITION := Vector2(-17.0, -15.0)
const HILL_POSITIONS := [
	Vector2(-28.0, -30.0), Vector2(25.0, -34.0),
	Vector2(34.0, 20.0), Vector2(-37.0, 25.0)
]
const TREE_POSITIONS := [
	Vector2(-8, -11), Vector2(8, -13), Vector2(15, -22), Vector2(-13, -27),
	Vector2(-26, -9), Vector2(27, -8), Vector2(21, 10), Vector2(-18, 13),
	Vector2(7, 20), Vector2(-31, 30), Vector2(34, 31), Vector2(40, -20),
	Vector2(-41, -19), Vector2(1, -35), Vector2(-5, 31)
]
const ROCK_POSITIONS := [
	Vector2(-4, -18), Vector2(12, 7), Vector2(-21, 4),
	Vector2(25, 24), Vector2(-32, -4), Vector2(5, 30)
]

var player: Node3D


func setup(target: Node3D) -> void:
	player = target
	queue_redraw()


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(0.025, 0.075, 0.045, 0.88), true)
	draw_rect(bounds.grow(-2.0), Color(0.72, 0.83, 0.42, 0.88), false, 2.0)
	var play_area := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_rect(play_area, Color("668b49"), true)
	draw_rect(play_area, Color(0.9, 0.88, 0.58, 0.75), false, 1.5)

	var pond_center := _world_to_map(POND_POSITION)
	draw_circle(pond_center, 12.0, Color(0.16, 0.49, 0.66, 0.9))
	for hill_position in HILL_POSITIONS:
		draw_circle(_world_to_map(hill_position), 11.0, Color(0.27, 0.38, 0.2, 0.9))
	for tree_position in TREE_POSITIONS:
		draw_circle(_world_to_map(tree_position), 3.0, Color(0.08, 0.28, 0.12, 1.0))
	for rock_position in ROCK_POSITIONS:
		draw_circle(_world_to_map(rock_position), 2.5, Color(0.48, 0.49, 0.45, 1.0))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 5.0, 20.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if not is_instance_valid(player):
		return
	var marker := _world_to_map(Vector2(player.global_position.x, player.global_position.z))
	var forward_3d := -player.global_transform.basis.z.normalized()
	var direction := Vector2(forward_3d.x, forward_3d.z).normalized()
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		marker + direction * 9.0,
		marker - direction * 6.0 + side * 5.0,
		marker - direction * 6.0 - side * 5.0
	])
	draw_colored_polygon(arrow, Color("ffcf4d"))
	var outline := PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]])
	draw_polyline(outline, Color(0.08, 0.06, 0.02, 0.95), 2.0, true)


func _world_to_map(world_position: Vector2) -> Vector2:
	var normalized := (world_position + Vector2.ONE * MAP_HALF_SIZE) / (MAP_HALF_SIZE * 2.0)
	var inset := Vector2(10, 10)
	return inset + normalized * (size - inset * 2.0)
