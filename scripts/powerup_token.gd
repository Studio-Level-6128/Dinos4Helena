extends Area3D

# Non-blocking collectible. Visual meshes are built procedurally so each token
# stays cheap to render and needs no additional model asset.
signal consumed(token_type: String)

const COLORS := {
	"health": Color("e94b4b"),
	"speed": Color("42cfee"),
	"strength": Color("f2a43a")
}
const LABEL_KEYS := {
	"health": "token.health",
	"speed": "token.speed",
	"strength": "token.strength"
}

var token_type := "health"
var rotation_speed := 1.8
var bob_time := 0.0
var base_height := 1.35
var visual_root: Node3D
var collected := false


func _ready() -> void:
	name = "%sToken" % token_type.capitalize()
	add_to_group("powerup_token")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_build_collision()
	_build_visual()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if collected or not is_instance_valid(visual_root):
		return
	bob_time += delta
	visual_root.rotation.y += rotation_speed * delta
	visual_root.position.y = base_height + sin(bob_time * 2.4) * 0.18


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	collision.shape = shape
	collision.position.y = base_height
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "RotatingSymbol"
	visual_root.position.y = base_height
	add_child(visual_root)
	var color: Color = COLORS.get(token_type, COLORS["health"])
	var material := _token_material(color)
	match token_type:
		"speed":
			_build_speed_symbol(material)
		"strength":
			_build_strength_symbol(material)
		_:
			_build_health_symbol(material)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.72
	ring_mesh.outer_radius = 0.86
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90.0
	ring.material_override = material
	visual_root.add_child(ring)
	var label := Label3D.new()
	label.text = Localization.text(LABEL_KEYS.get(token_type, "token." + token_type))
	label.position = Vector3(0.0, 1.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.pixel_size = 0.012
	label.outline_size = 6
	label.modulate = color.lightened(0.25)
	visual_root.add_child(label)


func _build_health_symbol(material: Material) -> void:
	_add_box(Vector3(0.34, 1.35, 0.28), Vector3.ZERO, 0.0, material)
	_add_box(Vector3(1.35, 0.34, 0.28), Vector3.ZERO, 0.0, material)


func _build_speed_symbol(material: Material) -> void:
	for offset in [-0.42, 0.12, 0.66]:
		_add_box(Vector3(0.28, 0.95, 0.24), Vector3(offset, 0.0, 0.0), deg_to_rad(-32.0), material)


func _build_strength_symbol(material: Material) -> void:
	_add_box(Vector3(1.35, 0.25, 0.25), Vector3.ZERO, 0.0, material)
	_add_box(Vector3(0.28, 0.82, 0.42), Vector3(-0.68, 0.0, 0.0), 0.0, material)
	_add_box(Vector3(0.28, 0.82, 0.42), Vector3(0.68, 0.0, 0.0), 0.0, material)


func _add_box(box_size: Vector3, box_position: Vector3, z_rotation: float, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = box_position
	instance.rotation.z = z_rotation
	instance.material_override = material
	visual_root.add_child(instance)


func _token_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.35
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = color * 0.7
	material.emission_energy_multiplier = 1.8
	return material


func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player_dinosaur") or not body.has_method("collect_token"):
		return
	collected = true
	set_deferred("monitoring", false)
	body.call("collect_token", token_type)
	consumed.emit(token_type)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", Vector3.ONE * 1.7, 0.22).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual_root, "position:y", base_height + 1.0, 0.22)
	tween.finished.connect(queue_free)
