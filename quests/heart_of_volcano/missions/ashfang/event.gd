extends "res://quests/heart_of_volcano/event.gd"

var boss: CharacterBody3D
var phase := 0
var phase_health := 160
var state := ""
var state_time := 0.0
var charge_direction := Vector3.ZERO
var charge_end := Vector3.ZERO
var attack_number := 0
var hit_player := false
var guard: MeshInstance3D
var telegraph: MeshInstance3D
var sweep_marker: MeshInstance3D
var patches: Array[MeshInstance3D] = []
var gate: Node3D
var bars: Array[ProgressBar] = []
var boss_title: Label
var lava_damage_time := 0.0
var retreat_complete := false

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	phase_health = int(objective.get("phase_health", 160))
	boss = CharacterBody3D.new()
	boss.name = "Ashfang"
	boss.set_script(load("res://quests/heart_of_volcano/boss.gd"))
	boss.set("dino_id", "trex")
	boss.set("texture_variant", 2)
	boss.set("mission", self)
	boss.position = Vector3(0, 0.1, 112)
	boss.scale = Vector3.ONE * 1.4
	boss.set_meta("mission_role", "ashfang")
	add_child(boss)
	boss.set("max_health", int(objective.get("phase_health", 160)) * 3)
	boss.set("health", boss.get("max_health"))
	guard = _disk(Vector3(0, 0.06, 112), 4.5, GREEN)
	telegraph = _box(Vector3.ZERO, Vector3(1, 0.05, 1), AMBER)
	sweep_marker = _disk(Vector3(0, 0.05, 112), 11, AMBER)
	for point in [Vector3(-12, 0.05, 105), Vector3(12, 0.05, 105), Vector3(0, 0.05, 124)]:
		patches.append(_disk(point, 4, RED))
		patches.back().visible = false
	gate = _box(Vector3(0, 4, 144), Vector3(46, 8, 2), BASALT, true).get_parent()
	_label(Vector3(0, 5, 151), "escape")
	_box(Vector3(0, 0.04, 154), Vector3(44, 0.08, 17), Color("628c53"))
	_build_hud()
	_begin_attack()

func _build_hud() -> void:
	var panel := VBoxContainer.new()
	panel.name = "AshfangHealth"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-225, 112)
	panel.size = Vector2(450, 48)
	controller.game_hud.add_child(panel)
	boss_title = Label.new()
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(boss_title)
	var row := HBoxContainer.new()
	panel.add_child(row)
	for index in 3:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(145, 16)
		bar.max_value = int(objective.get("phase_health", 160))
		bar.show_percentage = false
		var background := StyleBoxFlat.new()
		background.bg_color = Color("302b30")
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = [Color("dba449"), Color("e77739"), Color("c94a42")][index]
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		bars.append(bar)
	_update_hud()

func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	_tick(delta)
	state_time -= delta
	guard.position = Vector3(boss.position.x, 0.07, boss.position.z)
	guard.visible = state == "recover"
	if phase == 3:
		if controller.player.global_position.z > 148:
			complete()
			return
		_progress("boss_exit")
		return
	match state:
		"windup_charge":
			if state_time <= 0:
				state = "charge"
				state_time = 5
				_color(telegraph, RED)
				_play("rumble")
			_progress("boss_charge")
		"charge":
			if not hit_player and _distance(controller.player.global_position, boss.position) < 4.5:
				hit_player = true
				_damage_player(int(objective.get("boss_damage", 25)))
			if state == "charge" and (_distance(boss.position, charge_end) < 1.0 or state_time <= 0): _recover()
			_progress("boss_charge")
		"windup_sweep":
			if state_time <= 0:
				state = "sweep"
				state_time = 0.6
				_color(sweep_marker, RED)
				boss.call("_play_animation", "attack", true)
				_play("rumble")
			_progress("boss_sweep")
		"sweep":
			if not hit_player and _distance(controller.player.global_position, boss.position) < 11:
				hit_player = true
				_damage_player(int(objective.get("boss_damage", 25)))
			if state == "sweep" and state_time <= 0: _recover()
			_progress("boss_sweep")
		"recover":
			if state_time <= 0: _begin_attack()
			_progress("boss_recover")
	if phase == 2:
		lava_damage_time -= delta
		var active := fmod(clock, 6.0) >= 3
		for patch in patches:
			patch.visible = true
			_color(patch, RED if active else AMBER)
			if active and lava_damage_time <= 0 and _distance(controller.player.global_position, patch.position) < 4:
				lava_damage_time = 1
				_damage_player(15)
				_message("boss_lava")
	_update_hud()

func _begin_attack() -> void:
	if phase >= 3: return
	hit_player = false
	guard.visible = false
	var charge := phase == 0 or (phase == 2 and attack_number % 2 == 0)
	attack_number += 1
	telegraph.visible = charge
	sweep_marker.visible = not charge
	if charge:
		state = "windup_charge"
		state_time = float(objective.get("charge_warning_seconds", 2.5))
		var offset: Vector3 = controller.player.global_position - boss.position
		offset.y = 0
		charge_direction = offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
		var distance := 0.0
		# The locked charge extends to the arena wall; dodging cannot redirect it.
		for step in 80:
			var point := boss.position + charge_direction * (step + 1)
			if absf(point.x) > 20 or point.z < 86 or point.z > 137: break
			distance = step + 1
		charge_end = boss.position + charge_direction * distance
		telegraph.position = boss.position.lerp(charge_end, 0.5)
		telegraph.position.y = 0.08
		telegraph.scale = Vector3(5, 1, maxf(distance, 1))
		telegraph.rotation.y = atan2(charge_direction.x, charge_direction.z)
		_color(telegraph, AMBER)
		boss.rotation.y = atan2(-charge_direction.x, -charge_direction.z)
	else:
		state = "windup_sweep"
		state_time = float(objective.get("sweep_warning_seconds", 2.5))
		boss.position = Vector3(0, 0.1, 112)
		sweep_marker.position = Vector3(0, 0.08, 112)
		_color(sweep_marker, AMBER)
	boss.call("_play_animation", "idle")
	_play("warning")

func move_boss(actor: CharacterBody3D, delta: float) -> void:
	if ended: return
	var direction := charge_direction if state == "charge" else Vector3.ZERO
	var speed := 13.0
	if phase == 3:
		direction = Vector3.BACK if actor.position.z < 158 else Vector3.ZERO
		speed = 5
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	actor.velocity.y = actor.velocity.y - 9.8 * delta if not actor.is_on_floor() else 0.0
	actor.move_and_slide()
	if direction.length() > 0.1:
		actor.rotation.y = atan2(-direction.x, -direction.z)
		actor.call("_play_animation", "run" if speed > 8 else "walk")

func _recover() -> void:
	state = "recover"
	state_time = float(objective.get("recovery_seconds", 6.0))
	boss.velocity = Vector3.ZERO
	telegraph.visible = false
	sweep_marker.visible = false
	guard.visible = true
	boss.call("_play_animation", "idle")
	_play("opening")

func hit_boss(amount: int, attacker: Node3D) -> void:
	if ended or phase >= 3 or amount <= 0 or attacker != controller.player: return
	if state != "recover":
		_message("boss_guard")
		return
	phase_health = maxi(0, phase_health - amount)
	boss.health = phase_health + (2 - phase) * int(objective.get("phase_health", 160))
	if phase_health == 0:
		phase += 1
		_restore_player()
		_play("checkpoint")
		if phase == 3:
			state = "retreat"
			gate.queue_free()
			telegraph.visible = false
			sweep_marker.visible = false
			guard.visible = false
			for patch in patches: patch.visible = false
		else:
			phase_health = int(objective.get("phase_health", 160))
			_message("phase_saved")
			_begin_attack()
	_update_hud()

func _damage_player(amount: int) -> void:
	if controller.player.health <= amount:
		_retry_phase()
	else:
		controller.player.take_damage(amount, true)

func _retry_phase() -> void:
	if ended or phase >= 3: return
	phase_health = int(objective.get("phase_health", 160))
	boss.health = phase_health + (2 - phase) * phase_health
	boss.position = Vector3(0, 0.1, 112)
	boss.velocity = Vector3.ZERO
	_retry("boss_retry")
	_begin_attack()
	_update_hud()

func _update_hud() -> void:
	boss_title.text = Localization.text("lava.boss_name", [mini(phase + 1, 3)])
	for index in 3:
		bars[index].value = 0 if index < phase else (phase_health if index == phase else int(objective.get("phase_health", 160)))
