extends "res://quests/heart_of_volcano/event.gd"

var points: Array[Vector3] = [Vector3(-6, 2.9, 99), Vector3(6, 2.9, 108), Vector3(0, 2.9, 117)]
var slab: StaticBody3D
var tilt := 0.0
var held := 0.0
var markers: Array[MeshInstance3D] = []

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	_lava(Vector3(0, 0.03, 108), Vector3(46, 0.04, 35))
	_box(Vector3(0, 1, 108), Vector3(5, 2, 5), BASALT, true)
	slab = _box(Vector3(0, 2.2, 108), Vector3(20, 1, 34), BASALT, true).get_parent()
	var entry := _box(Vector3(0, 1.15, 84), Vector3(18, 0.5, 18), BASALT, true).get_parent() as Node3D
	entry.rotation.x = -atan(2.7 / 18)
	var exit := _box(Vector3(0, 1.15, 133), Vector3(18, 0.5, 18), BASALT, true).get_parent() as Node3D
	exit.rotation.x = atan(2.7 / 18)
	for point in points:
		markers.append(_disk(Vector3(point.x, 2.76, point.z), 2.4, AMBER))
		_label(point + Vector3(0, 2, 0), "balance_point")

func _physics_process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	_tick(delta)
	var position: Vector3 = controller.player.global_position
	var on_slab := position.z > 91 and position.z < 125 and position.y > 0.8
	var target_x := points[stage].x if stage < 3 else 0.0
	var desired := clampf((position.x - target_x) * 0.018, -0.22, 0.22) if on_slab else 0.12
	if on_slab and absf(position.x) > 8: desired = signf(position.x) * 0.4
	tilt = move_toward(tilt, desired, delta * 0.22)
	slab.rotation.z = tilt
	for index in markers.size():
		markers[index].position.y = 2.76 + sin(tilt) * points[index].x
	if absf(tilt) > 0.3 or (position.z > 92 and position.z < 125 and position.y < 0.4):
		_retry("retry_balance")
		tilt = 0
		held = 0
		return
	if stage < 3:
		var settled := _distance(position, points[stage]) < 2.4 and position.y > 1.3 and absf(tilt) < 0.06
		held = held + delta if settled else 0
		if held >= float(objective.get("balance_hold_seconds", 1.8)):
			_color(markers[stage], GREEN)
			_saved(Vector3(points[stage].x, 3.1, points[stage].z))
			stage += 1
			held = 0
	elif position.z >= 140 and absf(position.x) < 10:
		complete()
		return
	if stage < 3: _progress("balance", [stage, int(absf(rad_to_deg(tilt))), int(held / float(objective.get("balance_hold_seconds", 1.8)) * 100)])
	else: _progress("balance_exit")
