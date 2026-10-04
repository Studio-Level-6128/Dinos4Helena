extends "res://quests/mission_event.gd"

var baby: CharacterBody3D
var rescue_leader: CharacterBody3D
var baby_killed := false


func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.food_source_consumed.connect(_on_food_source_consumed)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		var role := str(npc.get_meta("mission_role", ""))
		if role == "hunted_baby":
			baby = npc
			baby.died.connect(_on_baby_died)
		elif role == "baby_rescue_leader":
			rescue_leader = npc
	if is_instance_valid(rescue_leader) and is_instance_valid(baby):
		rescue_leader.set("pack_goal", baby.global_position)
		rescue_leader.set("pack_goal_initialized", true)
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "baby_hunter_pack":
			npc.set("forced_target", baby)
	set_progress(Localization.text("mission.eat_baby_find"))


func _process(_delta: float) -> void:
	if ended:
		return
	if baby_killed:
		if not has_meat_from(baby):
			fail(Localization.text("mission.meal_lost"))
		return
	if not is_instance_valid(baby):
		return
	for npc in get_tree().get_nodes_in_group("npc_dinosaur"):
		if str(npc.get_meta("mission_role", "")) == "baby_hunter_pack":
			npc.set("forced_target", baby)
	if is_instance_valid(rescue_leader):
		rescue_leader.set("pack_goal", baby.global_position)
		rescue_leader.set("pack_goal_initialized", true)
		if rescue_leader.global_position.distance_to(baby.global_position) <= float(objective.get("rescue_radius", 11.0)):
			fail(Localization.text("mission.eat_baby_rescued"))


func _on_baby_died(_baby: CharacterBody3D) -> void:
	baby_killed = true
	set_progress(Localization.text("mission.eat_baby_eat"))


func _on_food_source_consumed(source: Node3D) -> void:
	if baby_killed and source == baby:
		complete()
