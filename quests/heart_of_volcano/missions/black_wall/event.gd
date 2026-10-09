extends "res://quests/heart_of_volcano/event.gd"

var weak_points: Array[Vector3] = []
var sections: Array[Node3D] = []
var broken: Array[bool] = [false, false, false]
var markers: Array[MeshInstance3D] = []

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.attacked.connect(_on_attack)
	for index in 3:
		var point := Vector3(-14 + index * 14, 0.1, 104)
		weak_points.append(point)
		sections.append(_box(Vector3(point.x, 4, 106), Vector3(14, 8, 3), BASALT, true).get_parent())
		markers.append(_box(Vector3(point.x, 2, 104.4), Vector3(0.4, 4, 0.08), AMBER))
		_label(Vector3(point.x, 6, 103), "weak_spot")
	_box(Vector3(0, 9, 106), Vector3(46, 2, 4), BASALT, true)
	_progress("charge", [stage])

func _on_attack() -> void:
	if ended or not is_instance_valid(controller.player): return
	var position: Vector3 = controller.player.global_position
	var velocity: Vector3 = controller.player.velocity
	var forward: Vector3 = -controller.player.global_transform.basis.z.normalized()
	var charging: bool = controller.player.call("_action_pressed", "run") and Vector2(velocity.x, velocity.z).length() >= float(objective.get("charge_min_speed", 3.5))
	for index in 3:
		if broken[index]: continue
		var offset := weak_points[index] - position
		offset.y = 0
		if charging and position.z < 104 and offset.length() < 5.5 and absf(offset.x) < 2.5 and forward.dot(offset.normalized()) > 0.9:
			broken[index] = true
			sections[index].queue_free()
			markers[index].visible = false
			stage += 1
			_saved(Vector3(weak_points[index].x, 0.1, 97))
			_play("crack")
			return
	_message("glancing")

func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	_tick(delta)
	if stage == 3 and controller.player.global_position.z > 112: complete()
	elif stage == 3: _progress("wall_exit")
	else: _progress("charge", [stage])
