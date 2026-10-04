extends Node

signal progress_changed(message: String)
signal mission_completed
signal mission_failed(reason: String)

var controller: Node
var objective: Dictionary = {}
var ended := false


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	controller = world_controller
	objective = mission_objective


func set_progress(message: String) -> void:
	if not ended:
		progress_changed.emit(message)


func has_meat_from(source: Node3D) -> bool:
	if not is_instance_valid(source):
		return false
	for meat in get_tree().get_nodes_in_group("edible_meat"):
		if is_instance_valid(meat) and not meat.is_queued_for_deletion() and meat.get_meta("source_dinosaur", null) == source:
			return true
	return false


func complete() -> void:
	if ended:
		return
	ended = true
	mission_completed.emit()
	set_process(false)


func fail(reason: String) -> void:
	if ended:
		return
	ended = true
	mission_failed.emit(reason)
	set_process(false)
