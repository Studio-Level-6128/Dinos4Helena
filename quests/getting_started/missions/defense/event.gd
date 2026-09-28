extends "res://quests/mission_event.gd"

var attacker: CharacterBody3D
var defended_pack_member: CharacterBody3D


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		var role := str(npc.get_meta("mission_role", ""))
		if role == "defense_attacker":
			attacker = npc
			npc.died.connect(_on_attacker_died)
		elif role == "defense_pack":
			if not is_instance_valid(defended_pack_member):
				defended_pack_member = npc
			npc.died.connect(_on_defender_died)
	if is_instance_valid(attacker):
		attacker.set("forced_target", defended_pack_member)
	set_progress("Defeat the Velociraptor — keep every pack member alive")


func _process(_delta: float) -> void:
	if not ended and is_instance_valid(attacker) and not attacker.dead:
		attacker.forced_target = defended_pack_member


func _on_attacker_died(_npc: CharacterBody3D) -> void:
	complete()


func _on_defender_died(_npc: CharacterBody3D) -> void:
	fail("A member of your pack was killed")
