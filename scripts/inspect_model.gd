extends SceneTree


func _initialize() -> void:
	var source := "res://assets/models/trex/Trex.fbx"
	var packed := load(source) as PackedScene
	if packed == null:
		push_error("Could not load " + source)
		quit(1)
		return
	var instance := packed.instantiate()
	_print_node(instance, "")
	instance.free()
	quit()


func _print_node(node: Node, indent: String) -> void:
	var transform_info := ""
	if node is Node3D:
		transform_info = " pos=" + str(node.position) + " rot=" + str(node.rotation_degrees) + " scale=" + str(node.scale)
	print(indent + node.name + " [" + node.get_class() + "]" + transform_info)
	if node is MeshInstance3D and node.mesh:
		print(indent + "  aabb: " + str(node.mesh.get_aabb()))
	if node is Skeleton3D:
		for bone_index in node.get_bone_count():
			print(indent + "  bone: " + node.get_bone_name(bone_index))
	if node is AnimationPlayer:
		for library_name in node.get_animation_library_list():
			var library: AnimationLibrary = node.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				var full_name: String = animation_name if library_name == "" else library_name + "/" + animation_name
				print(indent + "  animation: " + full_name)
	for child in node.get_children():
		_print_node(child, indent + "  ")
