class_name Minimap
extends Control
## Minimapa (arriba a la izquierda): el Huerto Lunar entero con la niebla de guerra de tu
## equipo. Muestra a tu dúo siempre, a los rivales solo si tu equipo los ve, la semilla
## caída o quién la lleva, y la planta sembrada. Nunca da información que el juego oculta.

## Esquina superior izquierda (debajo de los botones de pausa y tienda) y tamaño de cada celda.
const TOP_LEFT := Vector2(20, 96)
const CELL_PX := 6.0
## Oscuridad de lo que tu equipo no ve.
const FOG_ALPHA := 0.5

const COLOR_FRAME := Color(0.12, 0.09, 0.18, 0.85)
const COLOR_ALLY := Color(0.55, 0.88, 0.78)
const COLOR_ENEMY := Color(1.0, 0.45, 0.4)
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_OUTLINE := Color(0.12, 0.09, 0.18)
const DOT_RADIUS := 4.5

const FOG_SHADER := """
shader_type canvas_item;
uniform float fog_alpha = 0.6;
void fragment() {
	// La textura de niebla vale 1 donde tu equipo ve y 0 donde no.
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - texture(TEXTURE, UV).r) * fog_alpha);
}
"""

var _map: HuertoLunar
var _base: TextureRect
var _fog: TextureRect
var _markers: Control
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = TOP_LEFT
	_font = ThemeDB.fallback_font


## Bajo el minimapa (para colocar lo que va debajo, como el registro de bajas).
static func bottom_y() -> float:
	var map := HuertoLunar.current
	var rows := map.rows if map else 28
	return TOP_LEFT.y + rows * CELL_PX


func _process(_delta: float) -> void:
	var m := MatchManager.current
	visible = m != null and m.player != null and HuertoLunar.current != null
	if not visible:
		return
	if _map != HuertoLunar.current:
		_build(HuertoLunar.current)
	if _fog.texture == null and Perception.current:
		_fog.texture = Perception.current.fog_texture()
	_markers.queue_redraw()


func _build(map: HuertoLunar) -> void:
	_map = map
	for child in get_children():
		child.queue_free()
	size = Vector2(map.cols, map.rows) * CELL_PX

	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_FRAME
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(-4, -4)
	frame.size = size + Vector2(8, 8)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_base = _layer()
	_base.texture = _map_texture(map)

	_fog = _layer()
	_fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = FOG_SHADER
	mat.set_shader_parameter("fog_alpha", FOG_ALPHA)
	_fog.material = mat

	_markers = Control.new()
	_markers.size = size
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	add_child(_markers)


func _layer() -> TextureRect:
	var t := TextureRect.new()
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


## Una celda por píxel, con los mismos colores del greybox.
func _map_texture(map: HuertoLunar) -> ImageTexture:
	var colors := {
		"W": HuertoLunar.COLOR_FENCE, "#": HuertoLunar.COLOR_HIGH, ":": HuertoLunar.COLOR_LOW,
		"A": HuertoLunar.COLOR_SITE, "B": HuertoLunar.COLOR_SITE, "M": HuertoLunar.COLOR_MID,
		"d": HuertoLunar.COLOR_DEF, "a": HuertoLunar.COLOR_ATK,
	}
	var img := Image.create(map.cols, map.rows, false, Image.FORMAT_RGBA8)
	for r in map.rows:
		for c in map.cols:
			img.set_pixel(c, r, colors.get(map.cell_char(Vector2i(c, r)), HuertoLunar.COLOR_GROUND))
	return ImageTexture.create_from_image(img)


## Posición del mundo (x, z) en píxeles del minimapa. Arriba del minimapa = -Z, como la cámara.
func _to_map(p: Vector3) -> Vector2:
	return Vector2(p.x / HuertoLunar.CELL + _map.cols * 0.5, p.z / HuertoLunar.CELL + _map.rows * 0.5) * CELL_PX


func _draw_markers() -> void:
	var m := MatchManager.current
	var perception := Perception.current
	if m == null or perception == null or _map == null:
		return
	# Letras de las macetas.
	for site in ["A", "B"]:
		var at := _to_map(_map.zone_center(site))
		_text(site, at + Vector2(-5, 6), 16, Color(1, 1, 1, 0.9))

	# Planta sembrada (todos saben dónde está).
	if m.plant and is_instance_valid(m.plant):
		var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		var at := _to_map(m.plant.global_position)
		_markers.draw_circle(at, 6.0 * pulse, MoonSeed.COLOR)
		_markers.draw_arc(at, 6.0 * pulse, 0.0, TAU, 20, COLOR_OUTLINE, 1.5)

	# Semilla caída (la ven ambos equipos).
	if m.seed and m.seed.state == MoonSeed.State.DROPPED:
		_diamond(_to_map(m.seed.global_position), 5.0, MoonSeed.COLOR)

	# Pawtners: tu dúo siempre; los rivales solo si tu equipo los ve.
	for p in perception.pawtners:
		if not p.is_alive:
			continue
		var ally := p.team == perception.local_team
		if not ally and not p.is_revealed():
			continue
		var at := _to_map(p.get_global_transform_interpolated().origin)
		if p.carrying_seed:
			_markers.draw_arc(at, DOT_RADIUS + 3.5, 0.0, TAU, 20, MoonSeed.COLOR, 2.5)
		if p == m.player:
			_player_arrow(at, p.facing())
		else:
			_markers.draw_circle(at, DOT_RADIUS + 1.5, COLOR_OUTLINE)
			_markers.draw_circle(at, DOT_RADIUS, COLOR_ALLY if ally else COLOR_ENEMY)


## Tu Pawtner: flecha blanca que apunta hacia donde mira.
func _player_arrow(at: Vector2, facing: Vector3) -> void:
	var f := Vector2(facing.x, facing.z).normalized()
	if f == Vector2.ZERO:
		f = Vector2.UP
	var side := Vector2(-f.y, f.x)
	var tip := at + f * 8.0
	var points := PackedVector2Array([tip, at - f * 5.0 + side * 5.5, at - f * 2.5, at - f * 5.0 - side * 5.5])
	var outline := PackedVector2Array(points)
	outline.append(tip)
	_markers.draw_colored_polygon(points, COLOR_PLAYER)
	_markers.draw_polyline(outline, COLOR_OUTLINE, 1.5, true)


func _diamond(at: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	_markers.draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	_markers.draw_polyline(outline, COLOR_OUTLINE, 1.5, true)


func _text(text: String, baseline: Vector2, size_px: int, color: Color) -> void:
	_markers.draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, COLOR_OUTLINE)
	_markers.draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
