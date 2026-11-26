class_name TopDownCamera
extends Camera3D
## Cámara 3/4 cenital fija que sigue al Pawtner y se adelanta hacia el cursor.
## Ver docs/GDD.md, sección «Controles, cámara y visión».

@export var target_path: NodePath
@export_range(30.0, 89.0) var pitch_degrees := 57.0
## Con FOV de 35° y 18 m de distancia se ven unos 22 × 13 m.
@export var distance := 18.0
@export var field_of_view := 35.0
@export var max_lead := 3.0
@export var max_lead_aiming := 5.0
## Fracción de la distancia al cursor que se usa como adelanto.
@export var lead_factor := 0.35
@export var follow_sharpness := 8.0

var _target: Pawtner
var _focus := Vector3.ZERO
var _initialized := false


func _ready() -> void:
	fov = field_of_view
	_target = get_node_or_null(target_path) as Pawtner


func set_target(target: Pawtner) -> void:
	_target = target
	_initialized = false


func _process(delta: float) -> void:
	if _target == null:
		return
	if not _initialized:
		_focus = _target.global_position
		_initialized = true

	var lead := _target.aim_point - _target.global_position
	lead.y = 0.0
	var limit := max_lead_aiming if _target.is_aiming_fine else max_lead
	lead = (lead * lead_factor).limit_length(limit)

	var desired := _target.global_position + lead
	_focus = _focus.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	_apply()


func _apply() -> void:
	var p := deg_to_rad(pitch_degrees)
	global_position = _focus + Vector3(0.0, sin(p), cos(p)) * distance
	look_at(_focus, Vector3.UP)
