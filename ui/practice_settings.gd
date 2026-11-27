class_name PracticeSettings
extends Control
## Configuración de la sala de pruebas: qué pueden hacer los demás Pawtners (moverse,
## atacar), por separado para los rivales y para tu compañero. Se aplica al momento y
## se guarda para la próxima vez. Se abre desde la pausa.

signal closed

const PANEL_COLOR := Color(0.12, 0.09, 0.18, 0.98)
const ON_COLOR := Color(0.45, 0.8, 0.55)
const OFF_COLOR := Color(0.38, 0.29, 0.54)
const TEXT_DIM := Color(0.75, 0.71, 0.85)

## key: nombre de la opción en GameMode (get_setting / set_setting).
const OPTIONS := [
	{"group": "Rivales", "key": "enemies_move", "label": "Se mueven"},
	{"group": "Rivales", "key": "enemies_attack", "label": "Disparan y usan habilidades"},
	{"group": "Tu compañero", "key": "ally_move", "label": "Se mueve"},
	{"group": "Tu compañero", "key": "ally_attack", "label": "Dispara y usa habilidades"},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = PANEL_COLOR
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(EndScreen._label("Configurar sala de pruebas", 40))
	column.add_child(EndScreen._label("Sin moverse ni atacar son blancos quietos. Los cambios se aplican al momento.", 18, TEXT_DIM))

	var group := ""
	for opt: Dictionary in OPTIONS:
		if opt["group"] != group:
			group = opt["group"]
			column.add_child(EndScreen._label(group, 24, Color(0.78, 0.55, 1.0)))
		var center := CenterContainer.new()
		center.add_child(_toggle(opt["key"], opt["label"]))
		column.add_child(center)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	var done := CenterContainer.new()
	done.add_child(EndScreen._button("Listo", close))
	column.add_child(done)


func _toggle(key: String, label: String) -> Button:
	var b := EndScreen._button("", func() -> void: pass)
	b.custom_minimum_size = Vector2(520, 60)
	b.add_theme_font_size_override("font_size", 22)
	_refresh(b, key, label)
	b.pressed.connect(func() -> void:
		GameMode.set_setting(key, not GameMode.get_setting(key))
		_refresh(b, key, label)
		GameMode.save_practice_settings()
		if MatchManager.current:
			MatchManager.current.apply_practice_settings())
	return b


func _refresh(b: Button, key: String, label: String) -> void:
	var on := GameMode.get_setting(key)
	b.text = "%s:  %s" % [label, "Sí" if on else "No"]
	var style := (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = ON_COLOR.darkened(0.35) if on else OFF_COLOR.darkened(0.2)
	style.border_color = ON_COLOR if on else Color(0.78, 0.55, 1.0)
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, style)


func close() -> void:
	closed.emit()
	queue_free()
