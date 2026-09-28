extends RefCounted


func setup(controller: Node) -> void:
	# Put two safe meals close to the starting clearing while retaining the
	# procedural world's other vegetation.
	for index in 2:
		controller.generated_vegetation.append({
			"type": "grass",
			"position": Vector3(-4.0 + index * 8.0, 0.015, 13.0),
			"scale": 1.3,
			"rotation": index * 1.7
		})

