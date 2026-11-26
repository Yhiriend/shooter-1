class_name Clover
extends Node3D
## Trébol del mapa: el primer Pawtner que pasa por encima gana 1 punto de definitiva.
## Ver docs/GDD.md, «Mapa MVP: Huerto Lunar».

signal collected(by: Pawtner)

const PICKUP_RADIUS := 0.9

var _time := 0.0
var _mesh: Node3D


func _ready() -> void:
	_mesh = Node3D.new()
	add_child(_mesh)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.45, 0.9, 0.45)
	for i in 4:
		var leaf := SphereMesh.new()
		leaf.radius = 0.16
		leaf.height = 0.12
		leaf.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = leaf
		mi.position = Vector3(cos(i * PI * 0.5), 0.0, sin(i * PI * 0.5)) * 0.15
		_mesh.add_child(mi)


func _physics_process(delta: float) -> void:
	_time += delta
	_mesh.position.y = 0.5 + sin(_time * 2.5) * 0.08
	_mesh.rotation.y = _time
	if Perception.current == null:
		return
	visible = Perception.current.is_point_visible_to_local(global_position)
	for p in Perception.current.pawtners:
		if p.is_alive and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() <= PICKUP_RADIUS:
			p.kit.add_ult_point()
			collected.emit(p)
			queue_free()
			return
