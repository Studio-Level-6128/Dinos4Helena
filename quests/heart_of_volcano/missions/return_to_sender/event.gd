extends "res://quests/heart_of_volcano/event.gd"

var landing := Vector3(0, 0.1, 90)
var flight_time := -2.0
var projectile: MeshInstance3D
var landing_marker: MeshInstance3D
var barriers: Array[Node3D] = []
var returning := false
var return_from := Vector3.ZERO
var started := false

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.attacked.connect(_on_attack)
	landing_marker = _disk(Vector3(0, 0.07, 90), 4, AMBER)
	_label(Vector3(0, 3, 90), "landing")
	for index in 5:
		barriers.append(_box(Vector3(-16 + index * 8, 3, 117), Vector3(7, 6, 2), BASALT, true).get_parent())
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	projectile = MeshInstance3D.new()
	projectile.mesh = sphere
	_color(projectile, RED)
	add_child(projectile)
	projectile.visible = false
	_progress("deflect", [stage])

func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	_tick(delta)
	if not started:
		if _distance(controller.player.global_position, landing) <= 4:
			started = true
			_saved(landing)
		_progress("deflect", [stage])
		return
	var previous := flight_time
	flight_time += delta
	var duration := float(objective.get("flight_seconds", 3.0))
	if previous < 0 and flight_time >= 0: _play("launch")
	projectile.visible = flight_time >= 0
	if returning:
		var target := barriers[stage].position + Vector3(0, 1, 0)
		projectile.position = return_from.lerp(target, minf(flight_time / 0.7, 1))
		if flight_time >= 0.7:
			barriers[stage].queue_free()
			stage += 1
			_saved(landing)
			_play("crack")
			returning = false
			flight_time = -2
			if stage == 5:
				complete()
				return
	else:
		var t := clampf(flight_time / duration, 0, 1)
		projectile.position = Vector3(0, 7, 112).lerp(landing + Vector3(0, 1.8, 0), t) + Vector3(0, sin(t * PI) * 5, 0)
		if flight_time >= duration:
			_retry("miss")
			flight_time = -2
	var ready := not returning and flight_time >= duration - float(objective.get("swing_window_seconds", 0.8)) and flight_time < duration
	_color(landing_marker, GREEN if ready else AMBER)
	if ready: _progress("swing")
	else: _progress("deflect", [stage])

func _on_attack() -> void:
	if ended or not is_instance_valid(controller.player) or returning or not started: return
	var duration := float(objective.get("flight_seconds", 3.0))
	if flight_time >= duration - float(objective.get("swing_window_seconds", 0.8)) and flight_time < duration and _distance(controller.player.global_position, landing) <= 4:
		returning = true
		return_from = projectile.position
		flight_time = 0
		_play("deflect")
	else: _message("early")
