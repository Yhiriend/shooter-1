class_name BambooWall
extends StaticBody3D
## Muro de bambú de Tofu: bloquea movimiento, balas y visión; tiene vida y dura un tiempo.

const SEGMENT := 1.0
const HEIGHT := 1.8

var health := 300.0
var duration := 10.0

var _time_left := 0.0
var _cells: Array[Vector2i] = []
var _material: StandardMaterial3D


## `center` y `along` (dirección del muro, normalizada); `length` en metros.
func build(center: Vector3, along: Vector3, length: float, hp: float, seconds: float) -> void:
	health = hp
	duration = seconds
	collision_layer = Layers.WORLD | Layers.VISION_BLOCKER
	collision_mask = 0
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.55, 0.78, 0.38)
	var box := BoxMesh.new()
	box.size = Vector3(SEGMENT, HEIGHT, 0.5)
	var shape := BoxShape3D.new()
	shape.size = box.size
	var count := maxi(int(round(length / SEGMENT)), 1)
	var yaw := atan2(along.x, along.z) - PI * 0.5
	var map := HuertoLunar.current
	for i in count:
		var offset := (i - (count - 1) * 0.5) * SEGMENT
		var pos := center + along * offset
		if map and not map.is_point_free(pos):
			continue  # no se mete dentro de coberturas ni de la valla
		var xf := Transform3D(Basis(Vector3.UP, yaw), pos - center + Vector3.UP * HEIGHT * 0.5)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = xf
		add_child(col)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = _material
		mi.transform = xf
		add_child(mi)
		if map:
			_cells.append(map.world_to_cell(pos))
	position = center
	if map:
		map.set_cells_blocked(_cells, true)


func _ready() -> void:
	_time_left = duration


func take_damage(amount: float, _source: Pawtner) -> void:
	health -= amount
	if health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _exit_tree() -> void:
	if HuertoLunar.current:
		HuertoLunar.current.set_cells_blocked(_cells, false)
