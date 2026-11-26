class_name HealthOverlay
extends Control
## Barras de vida sobre la cabeza de cada Pawtner visible (aliados en verde, enemigos en rojo).

const OVERHEAD_SIZE := Vector2(110, 14)
const OVERHEAD_HEIGHT := 2.0

const COLOR_ALLY := Color(0.45, 0.9, 0.45)
const COLOR_ENEMY := Color(1.0, 0.38, 0.38)
const COLOR_SHIELD := Color(0.85, 0.95, 1.0)
const COLOR_BACK := Color(0.12, 0.09, 0.18, 0.75)
const COLOR_TEXT := Color(1, 1, 1)
const COLOR_OUTLINE := Color(0.12, 0.09, 0.18)
## Escudo máximo de referencia (caparazón pesado) para el ancho de su barra.
const SHIELD_REFERENCE := 50.0

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var perception := Perception.current
	var cam := get_viewport().get_camera_3d()
	if perception == null or cam == null:
		return
	for p in perception.pawtners:
		if p.is_alive and p.is_revealed():
			_draw_overhead(cam, p, p.team == perception.local_team)


func _draw_overhead(cam: Camera3D, p: Pawtner, ally: bool) -> void:
	var world := p.global_position + Vector3.UP * OVERHEAD_HEIGHT
	if cam.is_position_behind(world):
		return
	var center := cam.unproject_position(world)
	var rect := Rect2(center - Vector2(OVERHEAD_SIZE.x * 0.5, 0.0), OVERHEAD_SIZE)
	_draw_bar(rect, p, COLOR_ALLY if ally else COLOR_ENEMY)
	_draw_text_centered(p.display_name, Vector2(center.x, rect.position.y - 6.0), 20)
	if p.carrying_seed:
		# Marca del portador de la Semilla Lunar.
		draw_circle(Vector2(rect.end.x + 14.0, rect.get_center().y), 8.0, MoonSeed.COLOR)


func _draw_bar(rect: Rect2, p: Pawtner, color: Color) -> void:
	draw_rect(rect.grow(2.0), COLOR_BACK)
	var ratio := clampf(p.health / p.max_health, 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	if p.shield > 0.0:
		var s := clampf(p.shield / SHIELD_REFERENCE, 0.0, 1.0)
		var h := maxf(rect.size.y * 0.3, 3.0)
		draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - h), Vector2(rect.size.x * s, h)), COLOR_SHIELD)


func _draw_text(text: String, baseline: Vector2, size: int) -> void:
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, COLOR_OUTLINE)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_TEXT)


func _draw_text_centered(text: String, baseline: Vector2, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_draw_text(text, baseline - Vector2(w * 0.5, 0.0), size)
