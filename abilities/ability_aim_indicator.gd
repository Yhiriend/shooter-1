class_name AbilityAimIndicator
extends MeshInstance3D
## Muestra en el suelo cómo va a salir la habilidad que se está apuntando:
## área = círculo de alcance alrededor del Pawtner + zona de caída con su radio;
## dirección = flecha hasta el alcance.

const RANGE_COLOR := Color(1, 1, 1, 0.28)
const TARGET_COLOR := Color(0.78, 0.55, 1.0, 0.45)
const ARROW_COLOR := Color(0.78, 0.55, 1.0, 0.5)
const HEIGHT := 0.07
const SEGMENTS := 48
const RING_WIDTH := 0.08
const ARROW_WIDTH := 0.35
## Radio mínimo dibujado para efectos puntuales (cascabel, vigía).
const MIN_TARGET_RADIUS := 0.6

var controller: PlayerController

var _imesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	material_override = mat


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	if controller == null or controller.aiming_slot == "":
		return
	var p := controller.get_parent() as Pawtner
	var a := p.kit.ability(controller.aiming_slot)
	if a == null or not p.is_alive:
		return
	var origin := Vector3(p.global_position.x, HEIGHT, p.global_position.z)
	var target := Vector3(controller.aiming_target.x, HEIGHT, controller.aiming_target.z)
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if a.aim_mode == AbilityData.AimMode.AREA:
		_ring(origin, maxf(a.cast_range, 3.0), RANGE_COLOR)
		_disc(target, maxf(a.radius, MIN_TARGET_RADIUS), TARGET_COLOR)
	else:
		_arrow(origin, target, ARROW_COLOR)
	_imesh.surface_end()


func _ring(center: Vector3, radius: float, color: Color) -> void:
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var o0 := center + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var o1 := center + Vector3(cos(a1), 0.0, sin(a1)) * radius
		var i0 := center + Vector3(cos(a0), 0.0, sin(a0)) * (radius - RING_WIDTH)
		var i1 := center + Vector3(cos(a1), 0.0, sin(a1)) * (radius - RING_WIDTH)
		_tri(o0, o1, i0, color)
		_tri(i0, o1, i1, color)


func _disc(center: Vector3, radius: float, color: Color) -> void:
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		_tri(center, center + Vector3(cos(a0), 0.0, sin(a0)) * radius,
			center + Vector3(cos(a1), 0.0, sin(a1)) * radius, color)
	_ring(center, radius, Color(color, 0.9))


func _arrow(from: Vector3, to: Vector3, color: Color) -> void:
	var dir := to - from
	if dir.length_squared() < 0.01:
		return
	var length := dir.length()
	dir /= length
	var side := dir.cross(Vector3.UP) * ARROW_WIDTH * 0.5
	var head := maxf(length - 0.8, 0.0)
	var base := from + dir * head
	_tri(from + side, from - side, base + side, color)
	_tri(base + side, from - side, base - side, color)
	_tri(base + side * 2.2, base - side * 2.2, to, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_imesh.surface_set_color(color)
	_imesh.surface_add_vertex(a)
	_imesh.surface_add_vertex(b)
	_imesh.surface_add_vertex(c)
