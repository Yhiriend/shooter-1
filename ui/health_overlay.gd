class_name HealthOverlay
extends Control
## Barras de vida sobre la cabeza de cada Pawtner visible (aliados en verde, enemigos en rojo).

const OVERHEAD_SIZE := Vector2(110, 16)
## Tamaño del número de vida (y del escudo) dentro de la barra.
const HEALTH_FONT_SIZE := 15
## Altura (m) de la barra sobre los pies. La cabeza llega a ~1,5 m; con la cámara
## inclinada hace falta bastante margen para que no se vea pegada.
const OVERHEAD_HEIGHT := 2.7

const COLOR_ALLY := Color(0.45, 0.9, 0.45)
const COLOR_ENEMY := Color(1.0, 0.38, 0.38)
const COLOR_SHIELD := Color(0.85, 0.95, 1.0)
const COLOR_BACK := Color(0.12, 0.09, 0.18, 0.75)
const COLOR_TEXT := Color(1, 1, 1)
const COLOR_OUTLINE := Color(0.12, 0.09, 0.18)
## Escudo máximo de referencia (escudo pesado) para el ancho de su barra.
const SHIELD_REFERENCE := 50.0

const ASSIST_MARK_HEIGHT := 0.8
const ASSIST_MARK_RADIUS := 34.0
const COLOR_ASSIST := Color(1.0, 0.9, 0.4)

const AMMO_HEIGHT := 6.0
## Separación entre la barra de vida y la de munición, y entre segmentos.
const AMMO_GAP := 5.0
const AMMO_SEGMENT_GAP := 2.0
const COLOR_AMMO := Color(1.0, 0.86, 0.45)
const COLOR_AMMO_EMPTY := Color(0.35, 0.3, 0.4)
const COLOR_RELOAD := Color(0.75, 0.75, 0.8)

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
	_draw_assist_marker(cam)


## Mira sobre el rival que tiene fijado el apuntado asistido (toque sin arrastrar).
func _draw_assist_marker(cam: Camera3D) -> void:
	var m := MatchManager.current
	if m == null or m.player == null:
		return
	var pc := m.player.get_node_or_null("PlayerController") as PlayerController
	if pc == null or pc.assist_target == null or not is_instance_valid(pc.assist_target):
		return
	var world := pc.assist_target.get_global_transform_interpolated().origin + Vector3.UP * ASSIST_MARK_HEIGHT
	if cam.is_position_behind(world):
		return
	var c := cam.unproject_position(world)
	draw_arc(c, ASSIST_MARK_RADIUS, 0.0, TAU, 32, COLOR_OUTLINE, 6.0)
	draw_arc(c, ASSIST_MARK_RADIUS, 0.0, TAU, 32, COLOR_ASSIST, 3.0)
	for i in 4:
		var d := Vector2.from_angle(i * PI * 0.5)
		draw_line(c + d * (ASSIST_MARK_RADIUS - 8.0), c + d * (ASSIST_MARK_RADIUS + 8.0), COLOR_ASSIST, 3.0)


func _draw_overhead(cam: Camera3D, p: Pawtner, ally: bool) -> void:
	var world := p.get_global_transform_interpolated().origin + Vector3.UP * OVERHEAD_HEIGHT
	if cam.is_position_behind(world):
		return
	var center := cam.unproject_position(world)
	var rect := Rect2(center - Vector2(OVERHEAD_SIZE.x * 0.5, 0.0), OVERHEAD_SIZE)
	_draw_bar(rect, p, COLOR_ALLY if ally else COLOR_ENEMY)
	_draw_ammo(Rect2(rect.position + Vector2(0.0, rect.size.y + AMMO_GAP), Vector2(rect.size.x, AMMO_HEIGHT)), p.weapon)
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
	_draw_health_number(rect, p)


## Número de vida centrado en la barra; con escudo, «+N» en azul claro a su lado.
func _draw_health_number(rect: Rect2, p: Pawtner) -> void:
	var fs := HEALTH_FONT_SIZE
	var hp := str(ceili(maxf(p.health, 0.0)))
	var sh := " +%d" % ceili(p.shield) if p.shield > 0.0 else ""
	var w_hp := _font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w_sh := _font.get_string_size(sh, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if sh != "" else 0.0
	# Centrado vertical aproximado: la línea base va algo por debajo del centro.
	var baseline := Vector2(rect.get_center().x - (w_hp + w_sh) * 0.5, rect.get_center().y + fs * 0.36)
	draw_string_outline(_font, baseline, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, COLOR_OUTLINE)
	draw_string(_font, baseline, hp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_TEXT)
	if sh != "":
		var at := baseline + Vector2(w_hp, 0.0)
		draw_string_outline(_font, at, sh, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, COLOR_OUTLINE)
		draw_string(_font, at, sh, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_SHIELD)


## Segmentos de munición bajo la vida: uno por bala del cargador.
## Mientras recarga, una barra gris se llena con el progreso.
func _draw_ammo(rect: Rect2, weapon: Weapon) -> void:
	if weapon == null or weapon.data == null:
		return
	draw_rect(rect.grow(2.0), COLOR_BACK)
	if weapon.is_reloading:
		var w := rect.size.x * weapon.reload_progress()
		draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), COLOR_RELOAD)
		return
	var magazine := maxi(weapon.data.magazine, 1)
	var gap := AMMO_SEGMENT_GAP if magazine > 1 else 0.0
	var seg := (rect.size.x - gap * (magazine - 1)) / magazine
	for i in magazine:
		var r := Rect2(rect.position + Vector2((seg + gap) * i, 0.0), Vector2(seg, rect.size.y))
		draw_rect(r, COLOR_AMMO if i < weapon.ammo else COLOR_AMMO_EMPTY)


func _draw_text(text: String, baseline: Vector2, size: int) -> void:
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, COLOR_OUTLINE)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR_TEXT)


func _draw_text_centered(text: String, baseline: Vector2, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_draw_text(text, baseline - Vector2(w * 0.5, 0.0), size)
