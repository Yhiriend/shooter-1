class_name TouchStick
extends Control
## Joystick táctil flotante: aparece donde el dedo toca dentro de este Control
## y entrega `value` (longitud 0..1). Pensado para cubrir media pantalla.

@export var radius := 90.0
@export_range(0.0, 0.5) var dead_zone := 0.12
@export var base_color := Color(1, 1, 1, 0.18)
@export var knob_color := Color(1, 1, 1, 0.55)
## Posición del joystick en reposo, relativa al tamaño del Control (0..1).
@export var idle_anchor := Vector2(0.5, 0.7)

var value := Vector2.ZERO

var _touch_index := -1
var _center := Vector2.ZERO  # en coordenadas globales del canvas


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_active() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_center = touch.position
			_update(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update(drag.position)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Si la app pierde el foco con el dedo puesto, soltamos el joystick.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release()


func _release() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	queue_redraw()


func _update(pos: Vector2) -> void:
	var v := ((pos - _center) / radius).limit_length(1.0)
	value = Vector2.ZERO if v.length() < dead_zone else v
	queue_redraw()


func _draw() -> void:
	var local_center := (_center - global_position) if is_active() else size * idle_anchor
	draw_circle(local_center, radius, base_color)
	draw_circle(local_center + value * radius, radius * 0.4, knob_color)
