extends Area3D

# One Area3D owns every collision segment of a lava stream. Damage is applied
# at a fixed cadence, keeping cost independent of the visual ribbon resolution.
@export var damage_per_second := 12

var damage_interval := 0.5
var damage_time := 0.0


func _ready() -> void:
	add_to_group("lava_hazard")
	monitoring = true


func _physics_process(delta: float) -> void:
	damage_time -= delta
	if damage_time > 0.0:
		return
	damage_time = damage_interval
	for body in get_overlapping_bodies():
		apply_damage_to(body)


func apply_damage_to(body: Node) -> void:
	if is_instance_valid(body) and body.has_method("take_damage"):
		body.call("take_damage", maxi(int(ceil(float(damage_per_second) * damage_interval)), 1))
