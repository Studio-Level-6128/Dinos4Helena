extends "res://quests/mission_event.gd"

var baby: CharacterBody3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		var role := str(npc.get_meta("mission_role", ""))
		if role == "lost_baby":
			baby = npc
			baby.died.connect(_on_baby_died)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "lost_baby_hunter":
			npc.set("forced_target", baby)
	set_progress(Localization.text("mission.lost_baby_search"))


func _process(_delta: float) -> void:
	if ended or not is_instance_valid(baby) or baby.dead:
		return
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "lost_baby_hunter":
			npc.set("forced_target", baby)
	if controller.player.global_position.distance_to(baby.global_position) <= float(objective.get("find_radius", 10.0)):
		complete()


func _on_baby_died(_baby: CharacterBody3D) -> void:
	fail(Localization.text("mission.lost_baby_killed"))
