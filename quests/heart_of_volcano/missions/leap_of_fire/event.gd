extends "res://quests/heart_of_volcano/event.gd"

var lifts: Array[AnimatableBody3D] = []
var ledges: Array[Vector3] = []
var rode_lift := false
var lift_top := 0.0
var lift_labels: Array[Label3D] = []
var ledge_labels: Array[Label3D] = []

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	_lava(Vector3(0, 0.045, 107), Vector3(46, 0.06, 56))
	for index in 3:
		var point := Vector3(0, 3.05, 94 + index * 18)
		ledges.append(point)
		_box(point - Vector3(0, 0.55, 0), Vector3(9, 1, 7), BASALT, true)
		ledge_labels.append(_label(point + Vector3(0, 2, 0), "ledge"))
		ledge_labels.back().visible = false
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.position = Vector3(0, 1, 84 + index * 18)
		add_child(body)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(7, 1, 7)
		mesh.mesh = box
		_color(mesh, BASALT)
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		body.add_child(collision)
		lifts.append(body)
		lift_labels.append(_label(Vector3(0, 5, 84 + index * 18), "ride"))
		lift_labels.back().visible = index == 0
	_progress("leap", [stage])

func _physics_process(delta: float) -> void:
	if ended: return
	clock += delta
	var cycle := float(objective.get("lift_cycle_seconds", 5.0))
	for lift in lifts: lift.position.y = 1.2 + sin(clock * TAU / cycle) * 0.7

func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	notice_time = maxf(0, notice_time - delta)
	var position: Vector3 = controller.player.global_position
	lift_top = lifts[stage].position.y + 0.5
	if controller.player.is_on_floor() and _distance(position, lifts[stage].position) < 3.6 and absf(position.y - lift_top) < 0.6:
		rode_lift = true
	if rode_lift and controller.player.is_on_floor() and _distance(position, ledges[stage]) < 3.6 and position.y > 2.7:
		_saved(ledges[stage])
		stage += 1
		rode_lift = false
		if stage == 3:
			complete()
			return
	if position.z > 79 and position.z < 135 and position.y < 0.45:
		_retry("retry_lava")
		rode_lift = false
	for index in 3:
		lift_labels[index].visible = index == stage and not rode_lift
		ledge_labels[index].visible = index == stage and rode_lift
	_progress("leap", [stage])
