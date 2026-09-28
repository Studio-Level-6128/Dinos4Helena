extends RefCounted


func setup(controller: Node) -> void:
	controller.generated_eggs = [
		{"position": Vector3(-7.0, 0.1, 20.0), "rotation": 0.4},
		{"position": Vector3(7.0, 0.1, 25.0), "rotation": 2.1}
	]

