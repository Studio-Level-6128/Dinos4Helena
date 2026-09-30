extends "res://quests/mission_event.gd"

var rival: CharacterBody3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.set("allow_same_species_combat", true)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "kingpin_rival":
			rival = npc
			rival.set("forced_target", controller.player)
			rival.died.connect(_on_rival_died)
			break
	set_progress(Localization.text("mission.kingpin_defend"))


func _process(_delta: float) -> void:
	if not ended and is_instance_valid(rival) and not rival.dead:
		rival.set("forced_target", controller.player)


func _on_rival_died(_npc: CharacterBody3D) -> void:
	complete()
