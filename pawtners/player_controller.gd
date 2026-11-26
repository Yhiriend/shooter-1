class_name PlayerController
extends Node
## Escribe la intención del Pawtner padre desde la entrada del jugador:
## joysticks táctiles en móvil, o teclado y ratón en PC.
## Un futuro BotController escribirá las mismas variables.

@export var touch_controls_path: NodePath
## Inclinación del joystick izquierdo por debajo de la cual se camina en silencio.
@export_range(0.1, 0.9) var walk_threshold := 0.5
## Distancia a la que se proyecta el punto de mira con el joystick derecho.
@export var touch_aim_distance := 6.0
@export_range(0.0, 0.9) var aim_stick_threshold := 0.25
## Inclinación del joystick derecho a partir de la cual dispara (apuntar y empujar al borde).
@export_range(0.5, 1.0) var fire_stick_threshold := 0.85

var _pawtner: Pawtner
var _touch: TouchControls
## Armas de disparo al soltar: true mientras se arrastra el joystick de disparo.
var _release_armed := false
## Estado anterior de los botones de habilidad, para detectar el toque (flanco).
var _ability_was_pressed := {}

const ABILITY_ACTIONS := {"C": "ability_c", "Q": "ability_q", "E": "ability_e", "X": "ability_x"}


func _ready() -> void:
	# Corre antes que el Pawtner para que use la intención de este mismo frame.
	process_physics_priority = -1
	_pawtner = get_parent() as Pawtner
	assert(_pawtner != null, "PlayerController debe ser hijo de un Pawtner")
	_touch = get_node_or_null(touch_controls_path) as TouchControls


func set_touch_controls(touch: TouchControls) -> void:
	_touch = touch


func _physics_process(_delta: float) -> void:
	if _touch and _touch.is_touch_mode():
		_read_touch()
	else:
		_read_keyboard_mouse()
	_update_interact_button()
	_read_abilities()


## Habilidad que se está apuntando ("" = ninguna) y su punto objetivo, para el indicador.
var aiming_slot := ""
var aiming_target := Vector3.ZERO

## Por debajo de este arrastre se considera un toque corto: lanza hacia donde miras.
const QUICK_CAST_DRAG := 0.18
## Toque corto en habilidades de área: cae a esta fracción del alcance.
const QUICK_CAST_RANGE := 0.6


func _read_abilities() -> void:
	var touch := _touch != null and _touch.is_touch_mode()
	for slot: String in ABILITY_ACTIONS:
		var held := false
		var drag := Vector2.ZERO
		if touch:
			var button: TouchButton = _touch.ability_buttons[slot]
			held = button.pressed
			drag = button.drag_vector
			_update_ability_button(button, slot)
		else:
			held = Input.is_action_pressed(ABILITY_ACTIONS[slot])
		var was_held: bool = _ability_was_pressed.get(slot, false)
		_ability_was_pressed[slot] = held
		_handle_ability(slot, held, was_held, drag, touch)


func _handle_ability(slot: String, held: bool, was_held: bool, drag: Vector2, touch: bool) -> void:
	var kit := _pawtner.kit
	var a := kit.ability(slot) if kit else null
	if a == null:
		return
	if a.aim_mode == AbilityData.AimMode.INSTANT:
		if held and not was_held:
			_pawtner.wants_ability = slot
		return
	# Dirección y área: se apunta mientras se mantiene y se lanza al soltar.
	if held:
		if aiming_slot == "" and kit.can_cast(slot):
			aiming_slot = slot
		if aiming_slot == slot:
			aiming_target = _ability_target(a, drag, touch)
	elif was_held and aiming_slot == slot:
		_pawtner.ability_target = aiming_target
		_pawtner.has_ability_target = true
		_pawtner.wants_ability = slot
		aiming_slot = ""


## Punto objetivo según el modo: en táctil, el arrastre del botón; en PC, el ratón.
func _ability_target(a: AbilityData, drag: Vector2, touch: bool) -> Vector3:
	var origin := _pawtner.global_position
	var reach := maxf(a.cast_range, 3.0)
	var offset := Vector3.ZERO
	if touch:
		if drag.length() < QUICK_CAST_DRAG:
			var quick := 1.0 if a.aim_mode == AbilityData.AimMode.DIRECTION else QUICK_CAST_RANGE
			offset = _pawtner.facing() * reach * quick
		elif a.aim_mode == AbilityData.AimMode.DIRECTION:
			offset = Vector3(drag.x, 0.0, drag.y).normalized() * reach
		else:
			offset = Vector3(drag.x, 0.0, drag.y) * reach
	else:
		offset = _pawtner.aim_point - origin
		offset.y = 0.0
		if a.aim_mode == AbilityData.AimMode.DIRECTION:
			offset = offset.normalized() * reach if offset.length_squared() > 0.01 else _pawtner.facing() * reach
		else:
			offset = offset.limit_length(reach)
	return origin + offset


func _update_ability_button(button: TouchButton, slot: String) -> void:
	var kit := _pawtner.kit
	var a := kit.ability(slot) if kit else null
	button.visible = a != null and _touch.move_stick.visible
	if a == null:
		return
	if slot == "X":
		button.set_state("X", "%d/%d" % [kit.ult_points, kit.ult_cost()], not kit.can_cast(slot),
			float(kit.ult_points) / maxf(kit.ult_cost(), 1))
	else:
		button.set_state(slot, "x%d" % kit.charges.get(slot, 0), not kit.can_cast(slot))


func _update_interact_button() -> void:
	if _touch == null:
		return
	var button := _touch.interact_button
	var action := _pawtner.available_interaction
	button.visible = _touch.is_touch_mode() and action != ""
	button.set_label(action)


func _read_touch() -> void:
	var move: Vector2 = _touch.move_stick.value
	_pawtner.move_input = move
	_pawtner.wants_walk = move != Vector2.ZERO and move.length() < walk_threshold
	_pawtner.wants_aim_fine = false
	_pawtner.wants_interact = _touch.interact_button.pressed

	var aim: Vector2 = _touch.aim_stick.value
	var aiming := aim.length() >= aim_stick_threshold
	if _fires_on_release():
		# Rifle: arrastrar solo apunta; al soltar sale el tiro hacia donde se apuntaba.
		_pawtner.wants_shoot = _release_armed and not aiming
		_release_armed = aiming
		if _pawtner.wants_shoot:
			return
	else:
		_release_armed = false
		_pawtner.wants_shoot = aim.length() >= fire_stick_threshold
	if aiming:
		_pawtner.aim_point = _point_toward(aim)
	elif move != Vector2.ZERO:
		# Sin apuntar, el animal mira hacia donde camina.
		_pawtner.aim_point = _point_toward(move)


func _read_keyboard_mouse() -> void:
	_pawtner.move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_pawtner.wants_walk = Input.is_action_pressed("walk")
	_pawtner.wants_aim_fine = Input.is_action_pressed("aim_fine")
	if _fires_on_release():
		_pawtner.wants_shoot = Input.is_action_just_released("shoot")
	else:
		_pawtner.wants_shoot = Input.is_action_pressed("shoot")
	_pawtner.wants_interact = Input.is_action_pressed("interact")

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var plane := Plane(Vector3.UP, _pawtner.global_position.y)
	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))
	if hit != null:
		_pawtner.aim_point = hit


func _fires_on_release() -> bool:
	return _pawtner.weapon != null and _pawtner.weapon.data.fire_on_release


func _point_toward(screen_dir: Vector2) -> Vector3:
	var d := screen_dir.normalized()
	return _pawtner.global_position + Vector3(d.x, 0.0, d.y) * touch_aim_distance
