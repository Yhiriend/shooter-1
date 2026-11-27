class_name DamageNumbers
extends Control
## Números de daño que saltan y rebotan sobre el Pawtner que recibe un impacto.
## Solo aparecen si el jugador local ve a la víctima (respeta la niebla de guerra).
## Los perdigones de un mismo disparo se juntan en un solo número.
## Ver docs/GDD.md, «Dirección de arte y audio» (feedback).

static var current: DamageNumbers

const LIFETIME := 0.85
## Impactos a la misma víctima dentro de esta ventana suman al mismo número.
const MERGE_WINDOW := 0.12
## Por encima de la barra de vida y el nombre (HealthOverlay.OVERHEAD_HEIGHT).
const HEAD_HEIGHT := 3.2
const RISE_PX := 70.0
const POP_TIME := 0.16
const POP_SCALE := 1.7
const FADE_TIME := 0.3

const COLOR_ENEMY := Color(1.0, 1.0, 1.0)
const COLOR_BY_ME := Color(1.0, 0.9, 0.4)
const COLOR_ON_ALLY := Color(1.0, 0.45, 0.4)
const COLOR_SHIELD := Color(0.7, 0.88, 1.0)
const COLOR_OUTLINE := Color(0.12, 0.09, 0.18)

var _font: Font
## {"victim", "pos", "amount", "shield_only", "color", "age", "jitter"}
var _entries: Array[Dictionary] = []


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


## Lo llama Pawtner.take_damage. `to_shield` es la parte que absorbió el escudo.
func report(victim: Pawtner, amount: float, to_shield: float, source: Pawtner) -> void:
	if amount <= 0.0 or not victim.is_revealed():
		return
	var shield_only := to_shield >= amount - 0.01
	for e in _entries:
		if e["victim"] == victim and e["age"] < MERGE_WINDOW:
			e["amount"] += amount
			e["shield_only"] = e["shield_only"] and shield_only
			e["age"] = 0.0
			return
	_entries.append({
		"victim": victim,
		"pos": victim.global_position + Vector3.UP * HEAD_HEIGHT,
		"amount": amount,
		"shield_only": shield_only,
		"color": _color_for(victim, source),
		"age": 0.0,
		"jitter": randf_range(-28.0, 28.0),
	})


func clear() -> void:
	_entries.clear()


func _color_for(victim: Pawtner, source: Pawtner) -> Color:
	var perception := Perception.current
	if perception and victim.team == perception.local_team:
		return COLOR_ON_ALLY
	if source and MatchManager.current and source == MatchManager.current.player:
		return COLOR_BY_ME
	return COLOR_ENEMY


func _process(delta: float) -> void:
	for e in _entries:
		e["age"] += delta
	_entries = _entries.filter(func(e: Dictionary) -> bool: return e["age"] < LIFETIME)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for e in _entries:
		var pos: Vector3 = e["pos"]
		if cam.is_position_behind(pos):
			continue
		var age: float = e["age"]
		var t := age / LIFETIME
		# Sube rápido y frena (ease out), con un pequeño arco lateral.
		var rise := RISE_PX * (1.0 - pow(1.0 - t, 3.0))
		var screen := cam.unproject_position(pos) + Vector2(e["jitter"] * t, -rise)
		# Rebote al aparecer: crece de golpe y vuelve a su tamaño con un poco de sobrepaso.
		var pop := 1.0
		if age < POP_TIME:
			var k := age / POP_TIME
			pop = lerpf(POP_SCALE, 1.0, k) + sin(k * PI) * 0.15
		var amount: float = e["amount"]
		var base := 22 if e["color"] == COLOR_ON_ALLY else clampi(24 + int(amount * 0.3), 24, 44)
		var font_size := maxi(int(base * pop), 8)
		var color: Color = COLOR_SHIELD if e["shield_only"] else e["color"]
		color.a = clampf((LIFETIME - age) / FADE_TIME, 0.0, 1.0)
		var outline := Color(COLOR_OUTLINE, color.a)
		var text := str(roundi(amount))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := screen - Vector2(w * 0.5, 0.0)
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, outline)
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
