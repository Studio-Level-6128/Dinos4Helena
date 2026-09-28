extends "res://quests/mission_event.gd"

var prey_killed := false


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.food_consumed.connect(_on_food_consumed)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "hunt_prey":
			npc.died.connect(_on_prey_died)
	set_progress("Find and kill the marked prey")


func _on_prey_died(prey: CharacterBody3D) -> void:
	if prey.get("last_attacker") == controller.player:
		prey_killed = true
		set_progress("Prey killed — eat the meat")


func _on_food_consumed(food_kind: String) -> void:
	if prey_killed and food_kind == "meat":
		complete()

