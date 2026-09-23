extends CharacterBody3D

# Shared wildlife controller. Carnivores use risk-aware hunt/stalk/feed states;
# herbivores use flee/retaliate/defend states and a leader-based pack formation.
# State priority is deliberate: survival and combat always override roaming.
signal died(npc: CharacterBody3D)

const CONFIG_PATH := "res://config/dinosaurs.cfg"
const GENERATED_MATERIALS := preload("res://scripts/generated_materials.gd")
const HUNTER_SIGHT_RANGE := 58.0
const HERBIVORE_DANGER_RANGE := 34.0
const PACK_COHESION_RANGE := 11.0
const PACK_WELCOME_RANGE := 30.0
const PACK_DEFENSE_RANGE := 42.0
const PACK_DEFENSE_SECONDS := 10.0
const RETALIATION_SECONDS := 7.0
const HUNGER_THRESHOLD := 45.0
const HEAVY_INJURY_RATIO := 0.50
const MINIMUM_STALK_ODDS := 0.78
const STRIKE_ODDS := 1.0
const BABY_MINIMUM_HUNT_ODDS := 0.55
const BABY_STRIKE_ODDS := 0.68
const STALK_DISTANCE := 9.0
const PACK_SUPPORT_RADIUS := 24.0
const AVOID_DANGER_RANGE := 26.0
const PACK_FORMATION_GAP := 1.4
const PACK_STRAGGLER_DISTANCE := 34.0
const PACK_GOAL_MIN_DISTANCE := 55.0
const PACK_GOAL_MAX_DISTANCE := 105.0
const PACK_GOAL_REACHED_DISTANCE := 6.0
const PACK_GOAL_WORLD_LIMIT := 184.0

var dino_id := "triceratops"
var texture_variant := 0
var pack_id := -1
var pack_slot := -1
var rng_seed := 1
var patrol_center := Vector3.ZERO
var diet := "herbivore"
var display_name := "Dinosaur"
var model_scale := 0.2
var walk_speed := 3.0
var run_speed := 6.0
var turn_speed := 2.0
var strength := 5
var max_health := 100
var health := 100
var max_energy := 100.0
var energy := 100.0
var walk_energy_cost := 0.18
var run_energy_cost := 0.70
var attack_energy_cost := 9.0
var meat_energy_per_second := 22.0
var starvation_damage_per_second := 2.5
var starvation_damage_accumulator := 0.0
var collision_radius := 0.8
var collision_height := 2.8
var dead := false
var state := "wandering"
var attack_cooldown := 0.0
var wander_time := 0.0
var wander_target := Vector3.ZERO
var straggler_time := 0.0
var straggler_cooldown := 0.0
var pack_goal := Vector3.ZERO
var pack_goal_initialized := false
var pack_goal_resets := 0
var pack_avoid_direction := Vector3.ZERO
var pack_avoid_time := 0.0
var forced_target: Node3D
var retaliation_target: Node3D
var retaliation_time := 0.0
var ally_defense_target: Node3D
var ally_defense_time := 0.0
var food_target: Node3D
var model_root: Node3D
var animation_player: AnimationPlayer
var health_label: Label3D
var collision_shape: CollisionShape3D
var current_animation := ""
var rng := RandomNumberGenerator.new()
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var pack_members: Array = []
var same_species_allies: Array = []


func _ready() -> void:
	var config := ConfigFile.new()
	assert(config.load(CONFIG_PATH) == OK, "Could not load dinosaur configuration")
	diet = config.get_value(dino_id, "diet", "herbivore")
	display_name = config.get_value(dino_id, "display_name", dino_id.capitalize())
	model_scale = config.get_value(dino_id, "model_scale", 0.2)
	walk_speed = config.get_value(dino_id, "walk_speed", 3.0)
	run_speed = config.get_value(dino_id, "run_speed", 6.0)
	turn_speed = config.get_value(dino_id, "turn_speed", 2.0)
	strength = config.get_value(dino_id, "strength", 5)
	max_health = config.get_value(dino_id, "max_health", 100)
	health = max_health
	max_energy = config.get_value("energy", "max_energy", 100.0)
	energy = max_energy
	walk_energy_cost = config.get_value("energy", "walk_cost_per_second", 0.18)
	run_energy_cost = config.get_value("energy", "run_cost_per_second", 0.70)
	attack_energy_cost = config.get_value("energy", "attack_cost", 9.0)
	meat_energy_per_second = config.get_value("energy", "meat_energy_per_second", 22.0)
	starvation_damage_per_second = config.get_value("energy", "starvation_damage_per_second", 2.5)
	collision_radius = config.get_value(dino_id, "collision_radius", 0.8)
	collision_height = config.get_value(dino_id, "collision_height", 2.8)
	rng.seed = rng_seed
	add_to_group("npc_dinosaur")
	if diet == "carnivore":
		add_to_group("hunter_dinosaur")
	else:
		add_to_group("prey_dinosaur")
	_build_collision()
	_build_model(config.get_value(dino_id, "model_path", ""))
	_build_health_label()
	_choose_wander_target()
	if diet == "herbivore":
		straggler_cooldown = rng.randf_range(12.0, 26.0)
		call_deferred("_initialize_pack_relations")


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector3.ZERO
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	retaliation_time = maxf(retaliation_time - delta, 0.0)
	if retaliation_time <= 0.0 or (is_instance_valid(retaliation_target) and bool(retaliation_target.get("dead"))):
		retaliation_target = null
	ally_defense_time = maxf(ally_defense_time - delta, 0.0)
	if ally_defense_time <= 0.0 or (is_instance_valid(ally_defense_target) and bool(ally_defense_target.get("dead"))):
		ally_defense_target = null
	if not is_on_floor():
		velocity.y -= gravity * delta
	var move_direction := Vector3.ZERO
	var move_speed := walk_speed
	# Carnivore priority: retreat when critically hurt, feed when hungry, then
	# hunt only targets that pass the combat-odds calculation.
	if diet == "carnivore":
		var retreat_threat := _nearest_opponent(AVOID_DANGER_RANGE * 1.6) if _is_heavily_injured() else null
		if is_instance_valid(retreat_threat):
			state = "retreating"
			var retreat_offset := global_position - retreat_threat.global_position
			move_direction = Vector3(retreat_offset.x, 0.0, retreat_offset.z).normalized()
			move_speed = run_speed
		elif _should_feed():
			if not is_instance_valid(food_target):
				food_target = _nearest_meat(global_position, HUNTER_SIGHT_RANGE)
			if is_instance_valid(food_target):
				var food_offset := food_target.global_position - global_position
				var food_distance := Vector2(food_offset.x, food_offset.z).length()
				_face_direction(food_offset, delta)
				if food_distance <= collision_radius + 1.5:
					state = "eating"
					_eat_meat(delta)
				else:
					state = "seeking_food"
					move_direction = Vector3(food_offset.x, 0.0, food_offset.z).normalized()
			else:
				move_direction = _hunt_direction(delta)
				if state in ["hunting", "attacking", "avoiding"]:
					move_speed = run_speed
		else:
			move_direction = _hunt_direction(delta)
			if state in ["hunting", "attacking", "avoiding"]:
				move_speed = run_speed
	else:
		# Herbivore priority: defend alerted allies, respond to a direct threat,
		# then resume the moving pack formation.
		if is_instance_valid(ally_defense_target):
			var defense_offset := ally_defense_target.global_position - global_position
			var defense_distance := Vector2(defense_offset.x, defense_offset.z).length()
			_face_direction(defense_offset, delta)
			if defense_distance <= collision_radius + _body_radius(ally_defense_target) + 1.8:
				state = "defending_pack"
				_attack(ally_defense_target)
			else:
				state = "protecting_pack"
				move_direction = Vector3(defense_offset.x, 0.0, defense_offset.z).normalized()
				move_speed = run_speed
		else:
			var threat: Node3D = retaliation_target if is_instance_valid(retaliation_target) else _nearest_hunter()
			if is_instance_valid(threat):
				var danger_distance := global_position.distance_to(threat.global_position)
				if threat == retaliation_target and danger_distance <= collision_radius + _body_radius(threat) + 1.8:
					state = "defending"
					_face_direction(threat.global_position - global_position, delta)
					_attack(threat)
				else:
					state = "fleeing"
					var escape := global_position - threat.global_position
					move_direction = Vector3(escape.x, 0.0, escape.z).normalized()
					move_speed = run_speed
			else:
				move_direction = _pack_direction(delta)
				if state == "regrouping":
					move_speed = run_speed
	_apply_movement(move_direction, move_speed, delta)
	if diet == "carnivore":
		_update_energy(delta, move_direction.length_squared() > 0.01, state in ["hunting", "attacking", "avoiding", "retreating"])


func _hunt_direction(delta: float) -> Vector3:
	var prey := _choose_prey()
	if is_instance_valid(prey):
		var offset := prey.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		_face_direction(offset, delta)
		var odds := _combat_odds(prey)
		var is_baby := prey.is_in_group("baby_dinosaur")
		var minimum_odds := BABY_MINIMUM_HUNT_ODDS if is_baby else MINIMUM_STALK_ODDS
		var strike_odds := BABY_STRIKE_ODDS if is_baby else STRIKE_ODDS
		if odds < minimum_odds:
			state = "avoiding"
			return -Vector3(offset.x, 0.0, offset.z).normalized() if distance < AVOID_DANGER_RANGE else Vector3.ZERO
		if odds >= strike_odds and distance <= collision_radius + _body_radius(prey) + 1.6:
			state = "attacking"
			_attack(prey)
			# Keep closing the gap through the strike instead of planting the
			# hunter in place for every attack animation.
			return Vector3(offset.x, 0.0, offset.z).normalized()
		if odds >= strike_odds:
			state = "hunting"
			return Vector3(offset.x, 0.0, offset.z).normalized()
		state = "stalking"
		return _stalk_direction(prey, offset, distance)
	var danger := _nearest_overwhelming_opponent(AVOID_DANGER_RANGE)
	if is_instance_valid(danger):
		state = "avoiding"
		var escape := global_position - danger.global_position
		return Vector3(escape.x, 0.0, escape.z).normalized()
	state = "wandering"
	return _wander_direction(delta)


func _choose_prey() -> Node3D:
	if is_instance_valid(forced_target) and not bool(forced_target.get("dead")) and not _is_same_species(forced_target):
		var forced_minimum := BABY_MINIMUM_HUNT_ODDS if forced_target.is_in_group("baby_dinosaur") else MINIMUM_STALK_ODDS
		if global_position.distance_to(forced_target.global_position) <= HUNTER_SIGHT_RANGE * 1.35 and _combat_odds(forced_target) >= forced_minimum:
			return forced_target
	forced_target = null
	var nearest: Node3D
	var best_score := -INF
	var candidates := get_tree().get_nodes_in_group("prey_dinosaur") + get_tree().get_nodes_in_group("player_dinosaur")
	for candidate in candidates:
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")) or _is_same_species(candidate):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance > HUNTER_SIGHT_RANGE:
			continue
		var odds := _combat_odds(candidate_node)
		var minimum_odds := BABY_MINIMUM_HUNT_ODDS if candidate_node.is_in_group("baby_dinosaur") else MINIMUM_STALK_ODDS
		if odds < minimum_odds:
			continue
		var score := odds - distance / HUNTER_SIGHT_RANGE * 0.35
		# Babies are easier prey, but only after the normal risk gate above has
		# accounted for their parent and any nearby herd defenders.
		if candidate_node.is_in_group("baby_dinosaur"):
			score += 1.0
		if score > best_score:
			nearest = candidate_node
			best_score = score
	return nearest


func _stalk_direction(prey: Node3D, offset: Vector3, distance: float) -> Vector3:
	var direction := Vector3(offset.x, 0.0, offset.z).normalized()
	var desired_distance := STALK_DISTANCE + collision_radius + _body_radius(prey)
	if distance > desired_distance + 1.5:
		return direction
	if distance < desired_distance - 1.5:
		return -direction
	var side := Vector3(-direction.z, 0.0, direction.x)
	var prey_velocity_value = prey.get("velocity")
	if prey_velocity_value is Vector3 and Vector2(prey_velocity_value.x, prey_velocity_value.z).length_squared() > 0.1:
		var follow := Vector3(prey_velocity_value.x, 0.0, prey_velocity_value.z).normalized()
		return (follow * 0.7 + side * 0.3).normalized()
	return side


func _combat_odds(opponent: Node3D) -> float:
	# Nearby same-species herbivores contribute partial defensive power. This is
	# why a protected pack is unattractive while a temporary straggler is viable.
	if not is_instance_valid(opponent) or _is_same_species(opponent):
		return 0.0
	var hunter_power := _body_power(self) * 1.2
	var opposition_power := _body_power(opponent)
	var baby_parent: Node3D
	if opponent.is_in_group("baby_dinosaur"):
		var parent_value = opponent.get("parent_dino")
		if parent_value is Node3D and is_instance_valid(parent_value) and not bool(parent_value.get("dead")):
			baby_parent = parent_value
	var parent_counted := false
	if str(opponent.get("diet")) == "herbivore":
		var possible_allies: Array = []
		# Wild herbivores already cache their species peers. Reusing that cache
		# turns the hunters' most frequent nested whole-world scan into a short loop.
		if opponent.is_in_group("prey_dinosaur") and not opponent.is_in_group("baby_dinosaur"):
			var cached_allies = opponent.get("pack_members")
			var cached_species_allies = opponent.get("same_species_allies")
			if cached_species_allies is Array:
				cached_allies = cached_species_allies
			if cached_allies is Array:
				possible_allies = cached_allies.duplicate()
		if possible_allies.is_empty():
			possible_allies = get_tree().get_nodes_in_group("prey_dinosaur")
		else:
			# Babies can hatch after the adult caches were built.
			possible_allies.append_array(get_tree().get_nodes_in_group("baby_dinosaur"))
		possible_allies.append_array(get_tree().get_nodes_in_group("player_dinosaur"))
		for ally in possible_allies:
			if not ally is Node3D or ally == opponent or bool(ally.get("dead")):
				continue
			if str(ally.get("dino_id")) != str(opponent.get("dino_id")):
				continue
			if ally.global_position.distance_to(opponent.global_position) <= PACK_SUPPORT_RADIUS:
				var support_factor := 0.70 if ally == baby_parent else 0.55
				opposition_power += _body_power(ally) * support_factor
				parent_counted = parent_counted or ally == baby_parent
	if is_instance_valid(baby_parent) and not parent_counted and baby_parent.global_position.distance_to(opponent.global_position) <= PACK_SUPPORT_RADIUS:
		opposition_power += _body_power(baby_parent) * 0.70
	return hunter_power / maxf(opposition_power, 1.0)


func _body_power(body: Node) -> float:
	var current_health := float(body.get("health"))
	var maximum_health := maxf(float(body.get("max_health")), 1.0)
	var body_strength := float(body.get("strength"))
	var body_radius := float(body.get("collision_radius"))
	var body_height := float(body.get("collision_height"))
	var energy_factor := 1.0
	var body_energy = body.get("energy")
	var body_max_energy = body.get("max_energy")
	if body_energy != null and body_max_energy != null:
		energy_factor = lerpf(0.62, 1.0, clampf(float(body_energy) / maxf(float(body_max_energy), 1.0), 0.0, 1.0))
	var size_power := body_radius * 18.0 + body_height * 4.0
	return (current_health * 0.65 + maximum_health * 0.15 + body_strength * 12.0 + size_power) * energy_factor


func _nearest_opponent(maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := maximum_distance
	for candidate in get_tree().get_nodes_in_group("prey_dinosaur") + get_tree().get_nodes_in_group("player_dinosaur"):
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")) or _is_same_species(candidate):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate_node
			nearest_distance = distance
	return nearest


func _nearest_overwhelming_opponent(maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := maximum_distance
	for candidate in get_tree().get_nodes_in_group("prey_dinosaur") + get_tree().get_nodes_in_group("player_dinosaur"):
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")) or _is_same_species(candidate):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance and _combat_odds(candidate_node) < MINIMUM_STALK_ODDS:
			nearest = candidate_node
			nearest_distance = distance
	return nearest


func _is_heavily_injured() -> bool:
	return float(health) / maxf(float(max_health), 1.0) < HEAVY_INJURY_RATIO


func _pack_direction(delta: float) -> Vector3:
	# A single leader wanders; followers target staggered offsets behind it.
	# Separation steering handles visual spacing while collision exceptions make
	# it impossible for packmates to form a physics deadlock.
	var welcomed_player := _nearby_same_species_player()
	if is_instance_valid(welcomed_player):
		var welcome_offset := welcomed_player.global_position - global_position
		if Vector2(welcome_offset.x, welcome_offset.z).length() > PACK_COHESION_RANGE:
			state = "welcoming"
			var welcome_direction := Vector3(welcome_offset.x, 0.0, welcome_offset.z).normalized()
			return (welcome_direction + _pack_separation() * 1.35).normalized()
	_update_straggler_schedule(delta)
	var separation := _pack_separation()
	var leader := _pack_leader()
	if not is_instance_valid(leader) or leader == self:
		state = "leading"
		return (_pack_goal_direction(delta) + separation * 1.45).normalized()

	var follow_target := _pack_follow_target(leader)
	var follow_offset := follow_target - global_position
	var follow_distance := Vector2(follow_offset.x, follow_offset.z).length()
	var formation_direction := Vector3.ZERO
	if follow_distance > 1.1:
		formation_direction = Vector3(follow_offset.x, 0.0, follow_offset.z).normalized()
	else:
		var leader_velocity_value = leader.get("velocity")
		if leader_velocity_value is Vector3:
			formation_direction = Vector3(leader_velocity_value.x, 0.0, leader_velocity_value.z).normalized()
	if straggler_time > 0.0:
		state = "trailing"
	elif follow_distance > 12.0:
		state = "regrouping"
	else:
		state = "packing"
	return (formation_direction + separation * 1.7).normalized()


func _pack_leader() -> Node3D:
	var leader: Node3D
	var lowest_slot := 1000000
	for candidate in _pack_candidates():
		if not candidate is Node3D or bool(candidate.get("dead")):
			continue
		if candidate.get("pack_id") != pack_id or str(candidate.get("dino_id")) != dino_id:
			continue
		var candidate_slot := int(candidate.get("pack_slot"))
		if candidate_slot < lowest_slot:
			leader = candidate
			lowest_slot = candidate_slot
	return leader


func _pack_goal_direction(delta: float) -> Vector3:
	# Unlike individual wandering, a pack goal has no short timer. The leader
	# holds it until arrival, while temporary avoidance only bends the route.
	if not pack_goal_initialized:
		_choose_pack_goal()
	var offset := pack_goal - global_position
	offset.y = 0.0
	if offset.length() <= PACK_GOAL_REACHED_DISTANCE:
		pack_goal_resets += 1
		_choose_pack_goal()
		offset = pack_goal - global_position
		offset.y = 0.0
	var goal_direction := offset.normalized()
	pack_avoid_time = maxf(pack_avoid_time - delta, 0.0)
	if pack_avoid_time > 0.0:
		return (goal_direction * 0.45 + pack_avoid_direction * 1.25).normalized()
	return goal_direction


func _choose_pack_goal() -> void:
	var origin := Vector2(global_position.x, global_position.z)
	for attempt in 16:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(PACK_GOAL_MIN_DISTANCE, PACK_GOAL_MAX_DISTANCE)
		var candidate := origin + Vector2(cos(angle), sin(angle)) * distance
		candidate.x = clampf(candidate.x, -PACK_GOAL_WORLD_LIMIT, PACK_GOAL_WORLD_LIMIT)
		candidate.y = clampf(candidate.y, -PACK_GOAL_WORLD_LIMIT, PACK_GOAL_WORLD_LIMIT)
		var proposed_goal := Vector3(candidate.x, 0.1, candidate.y)
		if candidate.distance_to(origin) >= PACK_GOAL_MIN_DISTANCE * 0.72 and _pack_goal_is_clear(proposed_goal):
			pack_goal = proposed_goal
			pack_goal_initialized = true
			return
	# Near a corner, clamping can reject every random candidate. Moving toward
	# the opposite side still provides a valid long traversal.
	pack_goal = Vector3(-global_position.x * 0.75, 0.1, -global_position.z * 0.75)
	pack_goal_initialized = true


func _pack_goal_is_clear(proposed_goal: Vector3) -> bool:
	var controllers := get_tree().get_nodes_in_group("world_controller")
	if controllers.is_empty() or not controllers[0].has_method("is_pack_destination_clear"):
		return true
	return bool(controllers[0].call("is_pack_destination_clear", proposed_goal))


func _pack_follow_target(leader: Node3D) -> Vector3:
	var side_sign := 1.0 if pack_slot % 2 == 1 else -1.0
	var rank := floorf(float(maxi(pack_slot - 1, 0)) / 2.0)
	var leader_radius := float(leader.get("collision_radius"))
	var lateral_gap := leader_radius + collision_radius + PACK_FORMATION_GAP + rank * 0.75
	var distance_behind := 4.0 + rank * 4.0
	if straggler_time > 0.0:
		distance_behind = PACK_STRAGGLER_DISTANCE + rank * 2.0
		lateral_gap *= 0.45
	return leader.global_position \
		+ leader.global_transform.basis.z.normalized() * distance_behind \
		+ leader.global_transform.basis.x.normalized() * lateral_gap * side_sign


func _update_straggler_schedule(delta: float) -> void:
	# Slot one is the occasional straggler, ensuring only one animal per pack
	# creates a hunting opportunity at a time.
	if pack_slot != 1:
		return
	if straggler_time > 0.0:
		straggler_time = maxf(straggler_time - delta, 0.0)
		if straggler_time <= 0.0:
			straggler_cooldown = rng.randf_range(24.0, 42.0)
		return
	straggler_cooldown = maxf(straggler_cooldown - delta, 0.0)
	if straggler_cooldown <= 0.0:
		straggler_time = rng.randf_range(7.0, 11.0)


func _pack_separation() -> Vector3:
	var separation := Vector3.ZERO
	for candidate in _pack_candidates():
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")):
			continue
		if candidate.get("pack_id") != pack_id or str(candidate.get("dino_id")) != dino_id:
			continue
		var packmate := candidate as Node3D
		var away := global_position - packmate.global_position
		away.y = 0.0
		var distance := away.length()
		var desired_gap := collision_radius + float(packmate.get("collision_radius")) + PACK_FORMATION_GAP
		if distance >= desired_gap:
			continue
		if distance <= 0.05:
			var low_slot := mini(pack_slot, int(packmate.get("pack_slot")))
			var angle := TAU * float(posmod(pack_id * 3 + low_slot * 5, 13)) / 13.0
			away = Vector3(cos(angle), 0.0, sin(angle))
			if pack_slot < int(packmate.get("pack_slot")):
				away = -away
		else:
			away /= distance
		separation += away * (1.0 - distance / desired_gap)
	return separation


func _initialize_pack_relations() -> void:
	pack_members.clear()
	same_species_allies.clear()
	for candidate in get_tree().get_nodes_in_group("prey_dinosaur"):
		if not candidate is Node3D or str(candidate.get("dino_id")) != dino_id:
			continue
		same_species_allies.append(candidate)
		if candidate.get("pack_id") == pack_id:
			pack_members.append(candidate)
	_configure_friendly_collision_exceptions()


func _pack_candidates() -> Array:
	return pack_members if not pack_members.is_empty() else get_tree().get_nodes_in_group("prey_dinosaur")


func _configure_friendly_collision_exceptions() -> void:
	var friendly_candidates := _pack_candidates().duplicate()
	friendly_candidates.append_array(get_tree().get_nodes_in_group("player_dinosaur"))
	for candidate in friendly_candidates:
		if not candidate is PhysicsBody3D or candidate == self or bool(candidate.get("dead")):
			continue
		var same_pack: bool = candidate.is_in_group("prey_dinosaur") and candidate.get("pack_id") == pack_id and str(candidate.get("dino_id")) == dino_id
		var welcomed_player: bool = candidate.is_in_group("player_dinosaur") and _is_same_species(candidate) and str(candidate.get("diet")) == "herbivore"
		if same_pack or welcomed_player:
			add_collision_exception_with(candidate)
			candidate.add_collision_exception_with(self)


func _nearby_same_species_player() -> Node3D:
	var nearest: Node3D
	var nearest_distance := PACK_WELCOME_RANGE
	for candidate in get_tree().get_nodes_in_group("player_dinosaur"):
		if not candidate is Node3D or bool(candidate.get("dead")) or not _is_same_species(candidate):
			continue
		if str(candidate.get("diet")) != "herbivore":
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _wander_direction(delta: float) -> Vector3:
	wander_time -= delta
	if wander_time <= 0.0 or global_position.distance_to(wander_target) < 2.5:
		_choose_wander_target()
	var offset := wander_target - global_position
	return Vector3(offset.x, 0.0, offset.z).normalized()


func _choose_wander_target() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(7.0, 20.0)
	wander_target = patrol_center + Vector3(cos(angle), 0.0, sin(angle)) * distance
	wander_time = rng.randf_range(4.0, 9.0)


func _nearest_group_member(group_name: StringName, maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance := maximum_distance
	for candidate in get_tree().get_nodes_in_group(group_name):
		if not candidate is Node3D or candidate == self or bool(candidate.get("dead")):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate_node
			nearest_distance = distance
	return nearest


func _nearest_hunter() -> Node3D:
	var nearest := _nearest_group_member("hunter_dinosaur", HERBIVORE_DANGER_RANGE)
	var player_hunter := _nearest_group_member("player_hunter", HERBIVORE_DANGER_RANGE)
	if not is_instance_valid(nearest):
		return player_hunter
	if is_instance_valid(player_hunter) and global_position.distance_to(player_hunter.global_position) < global_position.distance_to(nearest.global_position):
		return player_hunter
	return nearest


func _apply_movement(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() > 0.01:
		_face_direction(direction, delta)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 8.0 * delta)
	move_and_slide()
	if state == "leading":
		_update_pack_obstacle_avoidance()
	if state != "eating" and is_instance_valid(model_root):
		model_root.rotation.x = lerpf(model_root.rotation.x, 0.0, 7.0 * delta)
	if get_slide_collision_count() > 0 and state in ["wandering", "leading", "packing", "regrouping", "trailing"]:
		wander_time = 0.0
	_update_animation(direction.length_squared() > 0.01, is_equal_approx(speed, run_speed))


func _update_pack_obstacle_avoidance() -> void:
	# Preserve the long-distance goal when scenery blocks the direct path. The
	# collision normal selects whichever tangent still points most toward it.
	for collision_index in get_slide_collision_count():
		var normal := get_slide_collision(collision_index).get_normal()
		if absf(normal.y) > 0.55:
			continue
		var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
		var to_goal := pack_goal - global_position
		to_goal.y = 0.0
		if tangent.dot(to_goal) < 0.0:
			tangent = -tangent
		pack_avoid_direction = (tangent + normal * 0.22).normalized()
		pack_avoid_time = 1.4
		return


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() <= 0.001:
		return
	var target_rotation := atan2(-flat.x, -flat.y)
	rotation.y = rotate_toward(rotation.y, target_rotation, turn_speed * delta)


func _attack(target: Node3D) -> void:
	if attack_cooldown > 0.0 or not is_instance_valid(target) or _is_same_species(target):
		return
	attack_cooldown = 1.35
	_spend_energy(attack_energy_cost)
	_play_animation("attack", true)
	var damage := maxi(strength * 3, 1)
	if target.is_in_group("player_dinosaur"):
		target.call("take_damage", damage, true, self)
	else:
		target.call("take_damage", damage, self)
	if bool(target.get("dead")):
		food_target = _nearest_meat(target.global_position, 3.0)


func take_damage(amount: int, attacker: Node3D = null) -> void:
	if amount <= 0 or dead or (is_instance_valid(attacker) and _is_same_species(attacker)):
		return
	health = maxi(health - amount, 0)
	_show_health()
	if is_instance_valid(attacker) and diet == "carnivore":
		forced_target = attacker
	elif is_instance_valid(attacker) and diet == "herbivore":
		retaliation_target = attacker
		retaliation_time = RETALIATION_SECONDS
		_alert_same_species_pack(attacker)
	if health <= 0:
		_die(attacker)


func receive_ally_alert(ally: Node3D, attacker: Node3D) -> void:
	if dead or diet != "herbivore" or not is_instance_valid(ally) or not is_instance_valid(attacker):
		return
	if not _is_same_species(ally) or _is_same_species(attacker):
		return
	if global_position.distance_to(ally.global_position) > PACK_DEFENSE_RANGE:
		return
	ally_defense_target = attacker
	ally_defense_time = PACK_DEFENSE_SECONDS


func _alert_same_species_pack(attacker: Node3D) -> void:
	var candidates := same_species_allies if not same_species_allies.is_empty() else get_tree().get_nodes_in_group("prey_dinosaur")
	for candidate in candidates:
		if candidate != self and candidate.has_method("receive_ally_alert"):
			candidate.call("receive_ally_alert", self, attacker)


func _is_same_species(other: Node) -> bool:
	return is_instance_valid(other) and str(other.get("dino_id")) == dino_id


func _die(attacker: Node3D = null) -> void:
	if dead:
		return
	dead = true
	state = "dead"
	remove_from_group("hunter_dinosaur")
	remove_from_group("prey_dinosaur")
	collision_shape.set_deferred("disabled", true)
	_play_animation("death", true)
	if animation_player:
		animation_player.speed_scale = 0.85
	var meat := _drop_meat()
	if is_instance_valid(attacker) and attacker.has_method("claim_meal"):
		attacker.call("claim_meal", meat)
	died.emit(self)
	get_tree().create_timer(14.0).timeout.connect(queue_free)


func _drop_meat() -> Node3D:
	var meat := Node3D.new()
	meat.name = "Meat"
	meat.add_to_group("edible_meat")
	meat.set_meta("energy_remaining", 55.0)
	get_parent().add_child(meat)
	meat.global_position = global_position + Vector3(0.0, 0.28, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.55
	mesh.height = 0.8
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(1.5, 0.55, 0.9)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8f3028")
	material.roughness = 0.9
	mesh_instance.material_override = material
	meat.add_child(mesh_instance)
	return meat


func claim_meal(meat: Node3D) -> void:
	if diet == "carnivore" and is_instance_valid(meat):
		food_target = meat
		forced_target = null


func _should_feed() -> bool:
	return is_instance_valid(food_target) or energy <= HUNGER_THRESHOLD


func _nearest_meat(origin: Vector3, maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance: float = maximum_distance
	for candidate in get_tree().get_nodes_in_group("edible_meat"):
		if not candidate is Node3D:
			continue
		var meat := candidate as Node3D
		var distance := origin.distance_to(meat.global_position)
		if distance < nearest_distance:
			nearest = meat
			nearest_distance = distance
	return nearest


func _eat_meat(delta: float) -> void:
	if not is_instance_valid(food_target):
		return
	energy = minf(energy + meat_energy_per_second * delta, max_energy)
	var remaining: float = food_target.get_meta("energy_remaining", 55.0)
	remaining -= meat_energy_per_second * delta
	food_target.set_meta("energy_remaining", remaining)
	if is_instance_valid(model_root):
		model_root.rotation.x = lerpf(model_root.rotation.x, deg_to_rad(-16.0 + sin(Time.get_ticks_msec() * 0.008) * 3.0), 8.0 * delta)
	_play_animation("idle")
	if remaining <= 0.0:
		food_target.queue_free()
		food_target = null
	elif energy >= max_energy:
		food_target = null


func _update_energy(delta: float, moving: bool, running: bool) -> void:
	if moving and state != "eating":
		_spend_energy((run_energy_cost if running else walk_energy_cost) * delta)
	if energy <= 0.0:
		starvation_damage_accumulator += starvation_damage_per_second * delta
		var damage := int(floor(starvation_damage_accumulator))
		if damage > 0:
			starvation_damage_accumulator -= float(damage)
			take_damage(damage)
	else:
		starvation_damage_accumulator = 0.0


func _spend_energy(amount: float) -> void:
	energy = maxf(energy - maxf(amount, 0.0), 0.0)


func _build_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = collision_radius
	shape.height = collision_height
	collision_shape.shape = shape
	collision_shape.position.y = collision_height * 0.5
	add_child(collision_shape)


func _build_model(model_path: String) -> void:
	var model_scene := load(model_path) as PackedScene
	model_root = model_scene.instantiate()
	model_root.name = "DinosaurModel"
	model_root.scale = Vector3.ONE * model_scale
	model_root.rotation.y = PI
	add_child(model_root)
	GENERATED_MATERIALS.apply_dino_skin(model_root, texture_variant)
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		for keyword in ["idle", "walk", "run"]:
			var animation_name := _find_animation(keyword)
			if animation_name != "":
				animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
		var death_animation := _find_animation("death")
		if death_animation != "":
			animation_player.get_animation(death_animation).loop_mode = Animation.LOOP_NONE
		_play_animation("idle", true)


func _build_health_label() -> void:
	health_label = Label3D.new()
	health_label.position.y = collision_height + 0.8
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 34
	health_label.pixel_size = 0.012
	health_label.outline_size = 6
	health_label.modulate = Color("ffd7a1")
	health_label.no_depth_test = true
	health_label.visible = false
	add_child(health_label)
	_update_health_label()


func _show_health() -> void:
	_update_health_label()
	health_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(health_label) and not dead:
			health_label.visible = false
	)


func _update_health_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "%s  %d/%d" % [display_name, health, max_health]


func _update_animation(moving: bool, running: bool) -> void:
	if dead or animation_player == null or attack_cooldown > 0.9:
		return
	_play_animation(("run" if running else "walk") if moving else "idle")


func _play_animation(keyword: String, force := false) -> void:
	if animation_player == null:
		return
	var animation_name := _find_animation(keyword)
	if animation_name == "" or (animation_name == current_animation and not force):
		return
	current_animation = animation_name
	animation_player.play(animation_name, 0.15)


func _find_animation(keyword: String) -> String:
	if animation_player == null:
		return ""
	for animation_name in animation_player.get_animation_list():
		if keyword.to_lower() in animation_name.to_lower():
			return animation_name
	return ""


func _body_radius(body: Node) -> float:
	var value = body.get("collision_radius")
	return float(value) if value != null else 0.8
