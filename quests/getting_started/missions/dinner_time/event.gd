extends "res://quests/mission_event.gd"

var plants_eaten := 0


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.food_consumed.connect(_on_food_consumed)
	set_progress(Localization.text("mission.plants_eaten", [0, int(objective.get("target_count", 2))]))


func _on_food_consumed(food_kind: String) -> void:
	if food_kind != "plant" or ended:
		return
	plants_eaten += 1
	var target := int(objective.get("target_count", 2))
	set_progress(Localization.text("mission.plants_eaten", [plants_eaten, target]))
	if plants_eaten >= target:
		complete()

