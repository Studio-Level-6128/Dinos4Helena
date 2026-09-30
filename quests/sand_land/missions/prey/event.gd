extends "res://quests/mission_event.gd"

var leader: CharacterBody3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	var water: Vector3 = controller.get_meta("sand_land_water_position", Vector3.ZERO)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "prey_leader":
			leader = npc
			leader.set("pack_goal", water)
			leader.set("pack_goal_initialized", true)
			leader.died.connect(_on_leader_died)
			break
	set_progress(Localization.text("mission.prey_hunt"))


func _process(_delta: float) -> void:
	if ended or not is_instance_valid(leader) or leader.dead:
		return
	var water: Vector3 = controller.get_meta("sand_land_water_position", Vector3.ZERO)
	var size: Vector2 = controller.get_meta("sand_land_water_size", Vector2(20.0, 16.0))
	if leader.global_position.distance_to(water) <= maxf(size.x, size.y) * 0.5 + 5.0:
		fail(Localization.text("mission.prey_escaped"))


func _on_leader_died(npc: CharacterBody3D) -> void:
	if npc.get("last_attacker") == controller.player:
		complete()
	else:
		fail(Localization.text("mission.prey_not_yours"))
