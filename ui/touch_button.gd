class_name TouchButton
extends Control
## Botón táctil redondo que se mantiene pulsado (sembrar, arrancar, rescatar).
## Va después de los joysticks en el árbol para recibir el toque antes que ellos.

@export var text := ""
@export var color := Color(0.78, 0.55, 1.0, 0.75)

var pressed := false

var _touch_index := -1


func set_label(value: String) -> void:
	if value != text:
		text = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_release()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _contains(touch.position):
			_touch_index = touch.index
			pressed = true
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _release() -> void:
	if _touch_index == -1 and not pressed:
		return
	_touch_index = -1
	pressed = false
	queue_redraw()


func _contains(pos: Vector2) -> bool:
	var r := minf(size.x, size.y) * 0.5
	return pos.distance_to(global_position + size * 0.5) <= r


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(center, r, color.lightened(0.25) if pressed else color)
	var font := ThemeDB.fallback_font
	var fs := 24
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := center + Vector2(-tw * 0.5, fs * 0.35)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.12, 0.09, 0.18))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
