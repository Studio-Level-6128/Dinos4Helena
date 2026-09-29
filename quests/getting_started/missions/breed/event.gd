extends "res://quests/mission_event.gd"

var tracked_babies: Array[Node] = []


func _process(_delta: float) -> void:
	if ended:
		return
	for baby in get_tree().get_nodes_in_group("baby_dinosaur"):
		if baby not in tracked_babies:
			tracked_babies.append(baby)
			baby.died.connect(_on_baby_died)
	var target := int(objective.get("target_children", 2))
	set_progress(Localization.text("mission.children_hatched", [tracked_babies.size(), target]))
	if tracked_babies.size() >= target:
		complete()


func _on_baby_died(_baby: CharacterBody3D) -> void:
	fail(Localization.text("mission.child_killed"))

