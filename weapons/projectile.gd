class_name Projectile
extends Node3D
## Proyectil visible (burbuja, semilla, confeti). Avanza con un raycast por frame
## para no atravesar nada aunque vaya rápido.

var shooter: Pawtner
var velocity := Vector3.ZERO
var damage := 0.0

var _range_left := 0.0
var _exclude: Array[RID] = []
var _color := Color.WHITE
var _radius := 0.08


func setup(from: Pawtner, origin: Vector3, vel: Vector3, dmg: float, max_range: float,
		color: Color, radius: float, exclude: Array) -> void:
	shooter = from
	position = origin
	velocity = vel
	damage = dmg
	_range_left = max_range
	_color = color
	_radius = radius
	_exclude.assign(exclude)


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _radius
	mesh.height = _radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _color
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_update_visibility()


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step,
		Layers.WORLD | Layers.PAWTNER, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Pawtners, muros de bambú y vigías reciben daño; el resto solo frena el proyectil.
		var target: Object = hit["collider"]
		if target and target.has_method("take_damage"):
			target.call("take_damage", damage, shooter)
		queue_free()
		return

	global_position += step
	_range_left -= step.length()
	if _range_left <= 0.0:
		queue_free()
		return
	_update_visibility()


func _update_visibility() -> void:
	# Fuera de la visión de tu equipo no se ven proyectiles.
	if Perception.current:
		visible = Perception.current.is_point_visible_to_local(global_position)
