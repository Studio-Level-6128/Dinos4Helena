extends "res://quests/heart_of_volcano/event.gd"

const PATTERNS := [[false, true], [true, false, false], [false, true, false]]
var answer := 0
var roar_active := false
var roar_duration := 0.0
var call_label: Label3D
var call_generation := 0

func setup(world_controller: Node, mission_objective: Dictionary) -> void:
	super.setup(world_controller, mission_objective)
	controller.player.screamed.connect(_on_screamed)
	call_label = _label(Vector3(0, 5, 86), "echo_help")
	_disk(Vector3(0, 0.05, 80), 7, BLUE)
	for x in [-17, 17]: _box(Vector3(x, 3, 92), Vector3(3, 6, 3), BASALT, true)
	var replay := Button.new()
	replay.name = "ReplayScoutCall"
	replay.text = Localization.text("lava.replay")
	replay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	replay.position = Vector2(-90, 112)
	replay.size = Vector2(180, 38)
	replay.pressed.connect(_replay)
	controller.game_hud.add_child(replay)
	_replay()
	_update_ui()

func _process(delta: float) -> void:
	if ended or not is_instance_valid(controller.player) or controller.player.dead: return
	_tick(delta)
	if roar_active:
		if controller.player.call("_action_pressed", "scream"): roar_duration += delta
		else:
			roar_active = false
			_submit_roar(roar_duration >= float(objective.get("long_roar_seconds", 1.0)))
	_update_ui()

func _on_screamed() -> void:
	if ended: return
	roar_active = true
	roar_duration = 0

func _submit_roar(long_roar: bool) -> void:
	if ended: return
	if long_roar != PATTERNS[stage][answer]:
		answer = 0
		_message("wrong_call")
		_play("retry")
		return
	answer += 1
	_play("long_call" if long_roar else "short_call")
	if answer == PATTERNS[stage].size():
		stage += 1
		answer = 0
		_saved(checkpoint)
		if stage == 3: complete()
		else: _replay()

func _pattern_text() -> String:
	var symbols: PackedStringArray = []
	for long_roar in PATTERNS[stage]: symbols.append("━━" if long_roar else "●")
	return "  ".join(symbols)

func _replay() -> void:
	if ended: return
	call_generation += 1
	var generation := call_generation
	var pattern: Array = PATTERNS[stage].duplicate()
	for long_roar in pattern:
		if ended or generation != call_generation: return
		call_label.text = Localization.text("lava.listening", [Localization.text("lava.long" if long_roar else "lava.short")])
		_play("long_call" if long_roar else "short_call")
		await get_tree().create_timer(1.6 if long_roar else 0.7).timeout
	if not ended and generation == call_generation: call_label.text = Localization.text("lava.echo_help")

func _update_ui() -> void:
	if ended: return
	_progress("echo", [stage, _pattern_text(), answer, PATTERNS[stage].size()])
