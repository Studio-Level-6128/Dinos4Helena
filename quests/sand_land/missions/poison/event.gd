extends "res://quests/mission_event.gd"

var poison_triggered := false


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.poisoning_changed.connect(_on_poisoning_changed)
	set_progress(Localization.text("mission.poison_find"))


func _on_poisoning_changed(active: bool) -> void:
	if active:
		poison_triggered = true
		set_progress(Localization.text("mission.poison_heal"))
	elif poison_triggered:
		complete()
