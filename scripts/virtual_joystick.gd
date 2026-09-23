extends Control

# Touch-first analog movement wheel. Screen-space drag direction is converted
# to the player's forward throttle and left-positive steering convention.
signal movement_changed(throttle: float, steering: float)

const DEAD_ZONE := 0.12
const EDGE_PADDING := 10.0

var screen_vector := Vector2.ZERO
var active_touch := -1
var mouse_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Drag in any direction to move and steer"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			_update_from_local_position(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			reset()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_from_local_position(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_active = event.pressed
		if mouse_active:
			_update_from_local_position(event.position)
		else:
			reset()
		accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_update_from_local_position(event.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _update_from_local_position(local_position: Vector2) -> void:
	var radius := _wheel_radius()
	if radius <= 0.0:
		return
	set_input_vector((local_position - size * 0.5) / radius)


func set_input_vector(value: Vector2) -> void:
	var limited := value.limit_length(1.0)
	var magnitude := limited.length()
	if magnitude <= DEAD_ZONE:
		limited = Vector2.ZERO
	else:
		# Removing the dead zone and remapping the remaining radius preserves
		# the full analog range while preventing accidental drift at the center.
		limited = limited.normalized() * ((magnitude - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	if screen_vector.is_equal_approx(limited):
		return
	screen_vector = limited
	queue_redraw()
	movement_changed.emit(-screen_vector.y, -screen_vector.x)


func reset() -> void:
	set_input_vector(Vector2.ZERO)


func get_movement() -> Vector2:
	# Vector axes are steering (left positive), throttle (forward positive).
	return Vector2(-screen_vector.x, -screen_vector.y)


func _wheel_radius() -> float:
	return maxf(minf(size.x, size.y) * 0.5 - EDGE_PADDING, 1.0)


func _draw() -> void:
	var center := size * 0.5
	var radius := _wheel_radius()
	var outer_color := Color(0.035, 0.09, 0.055, 0.82)
	var rim_color := Color(0.76, 0.86, 0.46, 0.88)
	var guide_color := Color(0.82, 0.91, 0.58, 0.34)
	draw_circle(center, radius, outer_color)
	draw_arc(center, radius, 0.0, TAU, 72, rim_color, 3.0, true)
	draw_circle(center, radius * 0.68, Color(0.10, 0.22, 0.13, 0.48))
	draw_arc(center, radius * 0.68, 0.0, TAU, 64, Color(0.67, 0.80, 0.42, 0.35), 1.5, true)

	for index in 8:
		var angle := float(index) * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * radius * 0.75, center + direction * radius * 0.92, guide_color, 2.0, true)
	draw_line(center + Vector2(-radius * 0.54, 0.0), center + Vector2(radius * 0.54, 0.0), guide_color, 1.5, true)
	draw_line(center + Vector2(0.0, -radius * 0.54), center + Vector2(0.0, radius * 0.54), guide_color, 1.5, true)

	var knob_center := center + screen_vector * radius * 0.70
	var knob_radius := radius * 0.25
	draw_circle(knob_center + Vector2(2.0, 3.0), knob_radius, Color(0, 0, 0, 0.32))
	draw_circle(knob_center, knob_radius, Color(0.48, 0.67, 0.25, 0.96))
	draw_arc(knob_center, knob_radius, 0.0, TAU, 40, Color(0.94, 0.94, 0.72, 0.95), 2.5, true)
	draw_circle(knob_center - Vector2(knob_radius * 0.22, knob_radius * 0.24), knob_radius * 0.13, Color(1, 1, 0.82, 0.44))
