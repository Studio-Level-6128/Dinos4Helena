extends "res://quests/mission_event.gd"

var update_time := 0.0


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.active_minimap):
		return
	update_time -= delta
	if update_time > 0.0:
		return
	update_time = 0.5
	var explored := float(controller.active_minimap.call("get_explored_fraction"))
	set_progress(Localization.text("mission.map_explored", [int(round(explored * 100.0))]))
	if explored >= float(objective.get("target_fraction", 1.0)):
		complete()

