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

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var m := MatchManager.current
	if m == null or m.player == null:
		return
	var screen := get_viewport_rect().size
	var w := screen.x
	var me := m.player.team

	# Marcador y reloj, arriba al centro.
	var role := "Atacas" if m.is_attacker(m.player) else "Defiendes"
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
			_text_centered("%d – %d · nueva partida en %d" % [m.score[me], m.score[1 - me], ceili(m.time_left)],
				Vector2(w * 0.5, screen.y * 0.3 + 50), 26)

	if m.player.carrying_seed:
		_text_centered("Llevas la Semilla Lunar", Vector2(w * 0.5, 116), 24, COLOR_SEED)

	# Munición (infinita: solo cuenta el cargador).
	var weapon := m.player.weapon
	var ammo := "Recargando..." if weapon.is_reloading else "%d / %d   ∞" % [weapon.ammo, weapon.data.magazine]
	_text_right(weapon.data.display_name, Vector2(w - 24, 44), 24)
	_text_right(ammo, Vector2(w - 24, 76), 28)

	# Barra de la interacción en curso.
	if m.player.is_interacting:
		var label: String = INTERACT_LABELS.get(m.player.available_interaction, "")
		_text_centered(label, Vector2(w * 0.5, screen.y * 0.62), 26)
		_bar(Rect2(w * 0.5 - 140, screen.y * 0.62 + 12, 280, 16), m.player.interaction_progress, COLOR_SEED)


func _clock(seconds: float) -> String:
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
