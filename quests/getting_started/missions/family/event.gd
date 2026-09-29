extends "res://quests/mission_event.gd"

var together_seconds := 0.0
var update_time := 0.0


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player):
		return
	var nearby := 0
	var radius := float(objective.get("pack_radius", 18.0))
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "family_pack" and not bool(npc.get("dead")) and controller.player.global_position.distance_to(npc.global_position) <= radius:
			nearby += 1
	if nearby >= int(objective.get("required_pack_members", 3)):
		together_seconds += delta
	else:
		together_seconds = 0.0
	update_time -= delta
	if update_time <= 0.0:
		update_time = 0.5
		var target := float(objective.get("pack_seconds", 180.0))
		set_progress(Localization.text("mission.stay_with_pack", [int(together_seconds), int(target)]))
	if together_seconds >= float(objective.get("pack_seconds", 180.0)):
		complete()

