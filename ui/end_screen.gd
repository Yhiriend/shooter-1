class_name EndScreen
extends Control
## Resultados al terminar la partida: marcador, estadísticas por Pawtner y botones
## para la revancha o para elegir otro Pawtner.

const PANEL_COLOR := Color(0.16, 0.12, 0.24, 0.94)
const ROW_COLOR := Color(0.28, 0.22, 0.40)
const COLOR_WIN := Color(0.55, 1.0, 0.6)
const COLOR_LOSE := Color(1.0, 0.5, 0.5)
const COLOR_ALLY := Color(0.55, 0.88, 0.78)
const COLOR_RIVAL := Color(1.0, 0.62, 0.55)
const COLUMNS := ["Pawtner", "Bajas", "Caídas", "Siembras", "Arranques", "Rescates"]
const KEYS := ["kills", "deaths", "plants", "uproots", "rescues"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := MatchManager.current
	var me := m.player.team
	var won := m.score[me] > m.score[1 - me]

	var back := ColorRect.new()
	back.color = PANEL_COLOR
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	column.add_child(_label("¡Victoria!" if won else "Derrota", 56, COLOR_WIN if won else COLOR_LOSE))
	column.add_child(_label("Nosotros %d  –  %d Rivales" % [m.score[me], m.score[1 - me]], 30))

	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	center.add_child(grid)
	column.add_child(center)
	for title: String in COLUMNS:
		grid.add_child(_label(title, 20, Color(0.8, 0.77, 0.88)))
	# Tu equipo primero; dentro de cada equipo, más bajas arriba.
	var order := m.pawtners.duplicate()
	order.sort_custom(func(a: Pawtner, b: Pawtner) -> bool:
		if a.team != b.team:
			return a.team == me
		return m.stats[a]["kills"] > m.stats[b]["kills"])
	for p: Pawtner in order:
		var color := COLOR_ALLY if p.team == me else COLOR_RIVAL
		grid.add_child(_label(p.display_name, 22, color))
		for key: String in KEYS:
			grid.add_child(_label(str(m.stats[p][key]), 22))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	buttons.add_child(_button("Revancha", func() -> void:
		queue_free()
		m.rematch()))
	buttons.add_child(_button("Cambiar Pawtner", func() -> void:
		queue_free()
		m.change_pawtner()))
	buttons.add_child(_button("Menú principal", func() -> void: GameMode.go_to_menu(get_tree())))


static func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(260, 76)
	b.add_theme_font_size_override("font_size", 26)
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_COLOR
	style.set_corner_radius_all(18)
	style.border_color = Color(0.78, 0.55, 1.0)
	style.set_border_width_all(3)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.29, 0.54)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", pressed)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func() -> void: Sfx.ui("click", -6.0))
	b.pressed.connect(action)
	return b
