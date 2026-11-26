class_name AimIndicator
extends MeshInstance3D
## Dibuja en el suelo el cono de precisión del arma del Pawtner padre.
## Se vuelve verde cuando el próximo disparo es un tiro certero.

const COLOR_NORMAL := Color(1, 1, 1, 0.18)
const COLOR_PRECISE := Color(0.55, 1.0, 0.6, 0.3)

var _pawtner: Pawtner
var _imesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


func _ready() -> void:
	_pawtner = get_parent() as Pawtner
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true
	material_override = _mat
	position = Vector3(0.0, 0.06, 0.0)


func _process(_delta: float) -> void:
	_imesh.clear_surfaces()
	if _pawtner == null or not _pawtner.is_alive or _pawtner.weapon == null:
		return
	var weapon := _pawtner.weapon
	var half := deg_to_rad(weapon.current_half_spread_deg())
	var length := weapon.data.max_range
	_mat.albedo_color = COLOR_PRECISE if weapon.is_precise_shot_ready() else COLOR_NORMAL

	# Abanico en espacio local: el frente es -Z.
	const SEGMENTS := 8
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := lerpf(-half, half, float(i) / SEGMENTS)
		var a1 := lerpf(-half, half, float(i + 1) / SEGMENTS)
		_imesh.surface_add_vertex(Vector3(0.0, 0.0, -0.6))
		_imesh.surface_add_vertex(Vector3(-sin(a0), 0.0, -cos(a0)) * length)
		_imesh.surface_add_vertex(Vector3(-sin(a1), 0.0, -cos(a1)) * length)
	_imesh.surface_end()
