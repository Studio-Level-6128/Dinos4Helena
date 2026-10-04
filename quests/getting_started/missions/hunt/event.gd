extends "res://quests/mission_event.gd"

var prey_killed := false
var marked_prey: CharacterBody3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.food_source_consumed.connect(_on_food_source_consumed)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "hunt_prey":
			marked_prey = npc
			npc.died.connect(_on_prey_died)
	set_progress(Localization.text("mission.find_prey"))


func _process(_delta: float) -> void:
	if prey_killed and not ended and not has_meat_from(marked_prey):
		fail(Localization.text("mission.meal_lost"))


func _on_prey_died(prey: CharacterBody3D) -> void:
	if prey.get("last_attacker") == controller.player:
		prey_killed = true
		set_progress(Localization.text("mission.prey_killed"))
	else:
		fail(Localization.text("mission.hunt_prey_lost"))


func _on_food_source_consumed(source: Node3D) -> void:
	if prey_killed and source == marked_prey:
		complete()
