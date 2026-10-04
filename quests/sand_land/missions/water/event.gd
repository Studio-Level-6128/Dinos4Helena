extends "res://quests/mission_event.gd"

var drink_time := 0.0


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	_rally_herd()


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player):
		return
	_rally_herd()
	var water: Vector3 = controller.get_meta("sand_land_water_position", Vector3.ZERO)
	var size: Vector2 = controller.get_meta("sand_land_water_size", Vector2(20.0, 16.0))
	var water_radius := maxf(size.x, size.y) * 0.5 + 5.0
	var at_water: bool = controller.player.global_position.distance_to(water) <= water_radius
	var nearby := 0
	var living := 0
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		var role := str(npc.get_meta("mission_role", ""))
		if role not in ["water_pack_leader", "water_pack", "water_child"] or npc.get("dead") == true:
			continue
		living += 1
		if npc.global_position.distance_to(water) <= water_radius + 22.0:
			nearby += 1
	var required := int(objective.get("required_pack_nearby", 4))
	if living < required:
		fail(Localization.text("mission.water_herd_lost"))
		return
	if at_water and nearby >= required and controller.player.call("_action_pressed", "eat") == true:
		drink_time += delta
	else:
		drink_time = 0.0
	var target := float(objective.get("drink_seconds", 2.0))
	set_progress(Localization.text("mission.water_progress", [nearby, required, int(ceil(drink_time)), int(ceil(target))]))
	if drink_time >= target:
		complete()


func _rally_herd() -> void:
	if not is_instance_valid(controller.player):
		return
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) in ["water_pack_leader", "water_pack"] and npc.has_method("receive_help_call"):
			npc.call("receive_help_call", controller.player)
