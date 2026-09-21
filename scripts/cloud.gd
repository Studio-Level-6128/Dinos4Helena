extends Node3D

var travel_direction := Vector3.RIGHT
var travel_speed := 1.0
var world_limit := 230.0


func setup(direction: Vector3, speed: float, limit: float) -> void:
	travel_direction = direction.normalized()
	travel_speed = speed
	world_limit = limit


func _process(delta: float) -> void:
	position += travel_direction * travel_speed * delta
	if position.x > world_limit:
		position.x = -world_limit
	elif position.x < -world_limit:
		position.x = world_limit
	if position.z > world_limit:
		position.z = -world_limit
	elif position.z < -world_limit:
		position.z = world_limit
