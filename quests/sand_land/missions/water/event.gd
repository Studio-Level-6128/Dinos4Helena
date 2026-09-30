extends "res://quests/mission_event.gd"

var drink_time := 0.0


func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player):
		return
	var water: Vector3 = controller.get_meta("sand_land_water_position", Vector3.ZERO)
	var size: Vector2 = controller.get_meta("sand_land_water_size", Vector2(20.0, 16.0))
	var water_radius := maxf(size.x, size.y) * 0.5 + 5.0
	var at_water: bool = controller.player.global_position.distance_to(water) <= water_radius
	var nearby := 0
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		var role := str(npc.get_meta("mission_role", ""))
		if role in ["water_pack_leader", "water_pack", "water_child"] and not bool(npc.get("dead")) and npc.global_position.distance_to(water) <= water_radius + 22.0:
			nearby += 1
	var required := int(objective.get("required_pack_nearby", 4))
	if at_water and nearby >= required and Input.is_action_pressed("eat"):
		drink_time += delta
	else:
		drink_time = 0.0
	var target := float(objective.get("drink_seconds", 2.0))
	set_progress(Localization.text("mission.water_progress", [nearby, required, int(ceil(drink_time)), int(ceil(target))]))
	if drink_time >= target:
		complete()
