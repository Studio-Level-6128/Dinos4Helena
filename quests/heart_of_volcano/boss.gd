extends "res://scripts/npc_dino.gd"

# Keep the existing model, animations, collision, and player attack targeting,
# while the mission owns Ashfang's attacks and phase health.
var mission: Node

func _physics_process(delta: float) -> void:
	if not is_instance_valid(mission) or mission.ended: return
	mission.move_boss(self, delta)

func take_damage(amount: int, attacker: Node3D = null) -> void:
	if is_instance_valid(mission): mission.hit_boss(amount, attacker)
