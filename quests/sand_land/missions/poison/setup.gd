extends RefCounted


func setup(controller: Node) -> void:
	for index in range(controller.generated_dinosaurs.size() - 1, -1, -1):
		if str(controller.generated_dinosaurs[index].get("species", "")) == "trex":
			controller.generated_dinosaurs.remove_at(index)
	controller.generated_vegetation.append({
		"type": "poisonous", "position": Vector3(0.0, 0.02, 17.0),
		"scale": 1.35, "rotation": 0.4
	})
	controller.generated_tokens.append({
		"type": "health", "position": Vector3(20.0, 0.0, 31.0)
	})
