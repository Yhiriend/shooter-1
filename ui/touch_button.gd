class_name TouchButton
extends Control
## Botón táctil redondo que se mantiene pulsado (sembrar, arrancar, rescatar).
## Va después de los joysticks en el árbol para recibir el toque antes que ellos.

@export var text := ""
## Segunda línea, más pequeña (cargas o puntos).
@export var sub_text := ""
@export var color := Color(0.78, 0.55, 1.0, 0.75)
## Atenuado: se ve pero indica que no se puede usar ahora.
var dimmed := false
## Relleno 0..1 alrededor (carga de la definitiva).
var fill := -1.0

var pressed := false
## Arrastre desde el centro mientras se mantiene, longitud 0..1 (para apuntar habilidades).
var drag_vector := Vector2.ZERO
## Distancia de arrastre (px) que equivale a 1.
@export var drag_radius := 120.0

var _touch_index := -1


func set_label(value: String) -> void:
	if value != text:
		text = value
		queue_redraw()


func set_state(label: String, sub: String, is_dimmed: bool, fill_ratio := -1.0) -> void:
	if label != text or sub != sub_text or is_dimmed != dimmed or not is_equal_approx(fill_ratio, fill):
		text = label
		sub_text = sub
		dimmed = is_dimmed
		fill = fill_ratio
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
			drag_vector = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		var drag := event as InputEventScreenDrag
		drag_vector = ((drag.position - (global_position + size * 0.5)) / drag_radius).limit_length(1.0)
		queue_redraw()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _release() -> void:
	if _touch_index == -1 and not pressed:
		return
	_touch_index = -1
	pressed = false
	# drag_vector se conserva hasta el próximo toque: quien lanza la habilidad lo lee al soltar.
	queue_redraw()


func _contains(pos: Vector2) -> bool:
	var r := minf(size.x, size.y) * 0.5
	return pos.distance_to(global_position + size * 0.5) <= r


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var c := color.lightened(0.25) if pressed else color
	if dimmed:
		c = Color(c.darkened(0.45), c.a * 0.7)
	draw_circle(center, r, c)
	if pressed and drag_vector != Vector2.ZERO:
		# Indicador del arrastre: hacia dónde se está apuntando.
		draw_circle(center + drag_vector * minf(drag_radius, r * 1.6), r * 0.35, Color(1, 1, 1, 0.6))
	if fill >= 0.0:
		draw_arc(center, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 40,
			Color(1.0, 0.92, 0.5), 5.0)
	var font := ThemeDB.fallback_font
	var fs := 24
	var y_main := fs * 0.35 if sub_text == "" else -2.0
	_draw_centered(font, text, center + Vector2(0.0, y_main), fs)
	if sub_text != "":
		_draw_centered(font, sub_text, center + Vector2(0.0, 20.0), 16)


func _draw_centered(font: Font, value: String, baseline: Vector2, fs: int) -> void:
	var tw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := baseline - Vector2(tw * 0.5, 0.0)
	draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.12, 0.09, 0.18))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
