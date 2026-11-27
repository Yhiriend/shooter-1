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

@export_group("Temblor")
## Desplazamiento máximo (m) con el temblor al máximo.
@export var max_shake_offset := 0.45
## Giro máximo (grados) con el temblor al máximo.
@export var max_shake_roll_deg := 1.5
## Cuánto temblor se pierde por segundo (0..1).
@export var shake_decay := 2.2
@export var shake_speed := 28.0
## Temblor mínimo por impacto y cuánto suma cada punto de daño.
@export var shake_per_hit := 0.22
@export var shake_per_damage := 0.008

var _target: Pawtner
var _focus := Vector3.ZERO
var _initialized := false
## 0..1; el temblor real es su cuadrado, para que los golpes chicos se noten poco.
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0


func _ready() -> void:
	# Se mueve en _process: la interpolación de física no le aplica. Sigue la posición
	# interpolada del Pawtner para que no tiemble en pantallas de 90/120 Hz.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = field_of_view
	_noise.seed = randi()
	_noise.frequency = 1.0
	_bind(get_node_or_null(target_path) as Pawtner)


func set_target(target: Pawtner) -> void:
	_bind(target)
	_initialized = false


## Suma temblor (0..1). Lo usan los impactos al Pawtner seguido.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _bind(target: Pawtner) -> void:
	if _target and is_instance_valid(_target) and _target.damaged.is_connected(_on_target_damaged):
		_target.damaged.disconnect(_on_target_damaged)
	_target = target
	if _target:
		_target.damaged.connect(_on_target_damaged)


func _on_target_damaged(amount: float, _to_shield: float, _source: Pawtner) -> void:
	add_trauma(shake_per_hit + amount * shake_per_damage)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var target_pos := _target.get_global_transform_interpolated().origin
	if not _initialized:
		_focus = target_pos
		_initialized = true

	var lead := _target.aim_point - _target.global_position
	lead.y = 0.0
	var limit := max_lead_aiming if _target.is_aiming_fine else max_lead
	lead = (lead * lead_factor).limit_length(limit)

	var desired := target_pos + lead
	_focus = _focus.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_noise_t += delta * shake_speed
	_apply()


func _apply() -> void:
	var p := deg_to_rad(pitch_degrees)
	global_position = _focus + Vector3(0.0, sin(p), cos(p)) * distance
	look_at(_focus, Vector3.UP)
	if _trauma > 0.0:
		var shake := _trauma * _trauma
		var right := global_basis.x
		var up := global_basis.y
		var jitter := right * _noise.get_noise_2d(_noise_t, 0.0) + up * _noise.get_noise_2d(0.0, _noise_t)
		global_position += jitter * max_shake_offset * shake
		var roll := deg_to_rad(max_shake_roll_deg) * shake * _noise.get_noise_2d(_noise_t, _noise_t)
		rotate_object_local(Vector3.BACK, roll)
