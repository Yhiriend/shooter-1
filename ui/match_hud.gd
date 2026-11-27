class_name MatchHud
extends Control
## HUD de la partida: marcador, reloj, rol, avisos de fase, munición y barra de interacción.

const COLOR_TEXT := Color(1, 1, 1)
const COLOR_OUTLINE := Color(0.12, 0.09, 0.18)
const COLOR_WIN := Color(0.55, 1.0, 0.6)
const COLOR_LOSE := Color(1.0, 0.5, 0.5)
const COLOR_SEED := MoonSeed.COLOR
const COLOR_BACK := Color(0.12, 0.09, 0.18, 0.75)

const INTERACT_LABELS := {
	"Sembrar": "Sembrando...",
	"Arrancar": "Arrancando...",
	"Rescatar": "Rescatando...",
}

const COLOR_ALLY := Color(0.55, 0.88, 0.78)
const COLOR_RIVAL := Color(1.0, 0.62, 0.55)
## Cuánto se ve cada línea del registro de bajas, y cuántas a la vez.
const FEED_TIME := 6.0
const FEED_LINES := 4

var _font: Font
## Registro de bajas: {"killer", "victim", "killer_team", "victim_team", "time"}.
var _feed: Array[Dictionary] = []
var _connected: MatchManager

## Borde rojo de la pantalla al recibir un impacto.
const HURT_FLASH_TIME := 0.4
const HURT_FLASH_ALPHA := 0.45
const HURT_BORDER := 90.0
const COLOR_HURT := Color(1.0, 0.2, 0.25)
var _hurt_time := 0.0
var _hurt_strength := 0.0
## Pawtner del jugador cuyo daño se escucha (cambia con la revancha o al cambiar de Pawtner).
var _hurt_source: Pawtner


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	var m := MatchManager.current
	if m and _connected != m:
		_connected = m
		m.pawtner_killed.connect(_on_killed)
		m.round_started.connect(func(_n: int) -> void: _feed.clear())
	if m and m.player != _hurt_source:
		_bind_hurt(m.player)
	_hurt_time = maxf(_hurt_time - delta, 0.0)
	for e in _feed:
		e["time"] -= delta
	_feed = _feed.filter(func(e: Dictionary) -> bool: return e["time"] > 0.0)
	queue_redraw()


func _bind_hurt(p: Pawtner) -> void:
	if _hurt_source and is_instance_valid(_hurt_source) and _hurt_source.damaged.is_connected(_on_player_damaged):
		_hurt_source.damaged.disconnect(_on_player_damaged)
	_hurt_source = p
	_hurt_time = 0.0
	if p:
		p.damaged.connect(_on_player_damaged)


func _on_player_damaged(amount: float, _to_shield: float, _source: Pawtner) -> void:
	_hurt_time = HURT_FLASH_TIME
	_hurt_strength = clampf(0.45 + amount / 60.0, 0.45, 1.0)


## Viñeta roja: bandas concéntricas en el borde que se desvanecen hacia el centro.
func _draw_hurt(screen: Vector2) -> void:
	var a := HURT_FLASH_ALPHA * _hurt_strength * (_hurt_time / HURT_FLASH_TIME)
	const BANDS := 6
	var band := HURT_BORDER / BANDS
	for i in BANDS:
		var inset := band * i + band * 0.5
		var c := Color(COLOR_HURT, a * (1.0 - float(i) / BANDS))
		draw_rect(Rect2(Vector2(inset, inset), screen - Vector2(inset, inset) * 2.0), c, false, band)


func _on_killed(killer: Pawtner, victim: Pawtner) -> void:
	_feed.append({
		"killer": killer.display_name if killer else "",
		"killer_team": killer.team if killer else -1,
		"victim": victim.display_name,
		"victim_team": victim.team,
		"time": FEED_TIME,
	})
	while _feed.size() > FEED_LINES:
		_feed.pop_front()


func _draw() -> void:
	var m := MatchManager.current
	if m == null or m.player == null:
		return
	var screen := get_viewport_rect().size
	var w := screen.x
	var me := m.player.team

	# Marcador y reloj, arriba al centro.
	var role := "Atacas" if m.is_attacker(m.player) else "Defiendes"
	if m.practice:
		_text_centered("Modo práctica", Vector2(w * 0.5, 44), 30, COLOR_SEED)
		_text_centered("%s · %s · reaparición en 2 s · recursos infinitos" % [role, _practice_bots_text()],
			Vector2(w * 0.5, 80), 22)
	else:
		_text_centered("Nosotros %d  –  %d Rivales" % [m.score[me], m.score[1 - me]], Vector2(w * 0.5, 44), 30)
		_text_centered("Ronda %d · %s · %s" % [m.round_number, role, _clock(m.time_left)], Vector2(w * 0.5, 80), 24)

	# Estado del objetivo / avisos de fase en el centro.
	match m.phase:
		MatchManager.Phase.BUY:
			_text_centered("Fase de compra  %d" % ceili(m.time_left), Vector2(w * 0.5, screen.y * 0.3), 40)
			var goal := "Lleva la Semilla Lunar a una maceta" if m.is_attacker(m.player) else "Protege las macetas A y B"
			_text_centered(goal, Vector2(w * 0.5, screen.y * 0.3 + 44), 26)
		MatchManager.Phase.PLANTED:
			var plant := m.plant
			var text := "Semilla en %s · %s · %d s" % [plant.site, plant.stage_name(), ceili(plant.time_left())]
			_text_centered(text, Vector2(w * 0.5, 116), 24, COLOR_SEED)
			if plant.uproot_progress > 0.0:
				_bar(Rect2(w * 0.5 - 120, 128, 240, 10), plant.uproot_progress, COLOR_SEED)
		MatchManager.Phase.ROUND_END:
			var won := m.last_winner == me
			_text_centered("¡Ronda ganada!" if won else "Ronda perdida", Vector2(w * 0.5, screen.y * 0.3), 48,
				COLOR_WIN if won else COLOR_LOSE)
			_text_centered(m.last_reason, Vector2(w * 0.5, screen.y * 0.3 + 46), 26)
		MatchManager.Phase.MATCH_END:
			var won := m.score[me] > m.score[1 - me]
			_text_centered("¡Victoria!" if won else "Derrota", Vector2(w * 0.5, screen.y * 0.3), 56,
				COLOR_WIN if won else COLOR_LOSE)
			_text_centered("%d – %d" % [m.score[me], m.score[1 - me]], Vector2(w * 0.5, screen.y * 0.3 + 50), 26)

	# Registro de bajas, arriba a la izquierda (debajo del minimapa).
	var y := Minimap.bottom_y() + 34.0
	for e in _feed:
		var x := 24.0
		if e["killer"] != "":
			x = _text_part(e["killer"], Vector2(x, y), 22, _team_color(e["killer_team"], me))
			x = _text_part("  »  ", Vector2(x, y), 22, COLOR_TEXT)
		_text_part(e["victim"], Vector2(x, y), 22, _team_color(e["victim_team"], me))
		y += 30.0

	if m.player.carrying_seed:
		_text_centered("Llevas la Semilla Lunar", Vector2(w * 0.5, 116), 24, COLOR_SEED)

	# Munición (infinita: solo cuenta el cargador).
	var weapon := m.player.weapon
	var ammo := "Recargando..." if weapon.is_reloading else "%d / %d   ∞" % [weapon.ammo, weapon.data.magazine]
	_text_right(weapon.data.display_name, Vector2(w - 24, 44), 24)
	_text_right(ammo, Vector2(w - 24, 76), 28)
	_text_right("%d croquetas" % m.economy.credits(m.player), Vector2(w - 24, 108), 24, COLOR_SEED)

	# Habilidades (en móvil ya las muestran los botones).
	if not DisplayServer.is_touchscreen_available() and m.player.kit.character:
		var kit := m.player.kit
		var parts := PackedStringArray()
		for slot in AbilityKit.SLOTS:
			var ab := kit.ability(slot)
			if slot == "X":
				parts.append("X %s %d/%d" % [ab.display_name, kit.ult_points, kit.ult_cost()])
			else:
				parts.append("%s %s x%d" % [slot, ab.display_name, kit.charges.get(slot, 0)])
		_text_centered("   ".join(parts), Vector2(w * 0.5, screen.y - 24), 20)

	if _hurt_time > 0.0:
		_draw_hurt(screen)

	# Cegado (cascabel o siesta del bosque): la pantalla se vuelve blanca.
	if m.player.is_blinded():
		var alpha := clampf(m.player.blind_time_left() / 1.5, 0.0, 1.0) * 0.85
		draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 1, 1, alpha))

	# Barra de la interacción en curso.
	if m.player.is_interacting:
		var label: String = INTERACT_LABELS.get(m.player.available_interaction, "")
		_text_centered(label, Vector2(w * 0.5, screen.y * 0.62), 26)
		_bar(Rect2(w * 0.5 - 140, screen.y * 0.62 + 12, 280, 16), m.player.interaction_progress, COLOR_SEED)


## Resumen de la configuración de la sala para el HUD («rivales quietos», «rivales atacan»...).
func _practice_bots_text() -> String:
	if GameMode.enemies_move and GameMode.enemies_attack:
		return "rivales juegan"
	if GameMode.enemies_move:
		return "rivales se mueven"
	if GameMode.enemies_attack:
		return "rivales quietos que disparan"
	return "rivales quietos"


func _team_color(team: int, me: int) -> Color:
	return COLOR_ALLY if team == me else COLOR_RIVAL


## Dibuja un texto y devuelve dónde termina (para encadenar colores en una línea).
func _text_part(text: String, baseline: Vector2, font_size: int, color: Color) -> float:
	_text(text, baseline, font_size, color)
	return baseline.x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _clock(seconds: float) -> String:
	if is_inf(seconds):
		return "∞"
	var s := maxi(ceili(seconds), 0)
	return "%d:%02d" % [s / 60, s % 60]


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect.grow(2.0), COLOR_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)


func _text(text: String, baseline: Vector2, font_size: int, color := COLOR_TEXT) -> void:
	draw_string_outline(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, COLOR_OUTLINE)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered(text: String, baseline: Vector2, font_size: int, color := COLOR_TEXT) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(text, baseline - Vector2(tw * 0.5, 0.0), font_size, color)


func _text_right(text: String, baseline: Vector2, font_size: int, color := COLOR_TEXT) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(text, baseline - Vector2(tw, 0.0), font_size, color)
