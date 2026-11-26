class_name CharacterSelect
extends Control
## Pantalla para elegir Pawtner antes de la partida.

signal picked(character: CharacterData)

const PANEL_COLOR := Color(0.16, 0.12, 0.24, 0.97)
const CARD_COLOR := Color(0.28, 0.22, 0.40)
const CARD_HOVER := Color(0.38, 0.29, 0.54)
const ACCENT := Color(0.78, 0.55, 1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = PANEL_COLOR
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	var title := Label.new()
	title.text = "Elige tu Pawtner"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", ACCENT)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for c in Roster.CHARACTERS:
		row.add_child(_card(c))

	var hint := Label.new()
	hint.text = "Tu compañero será del otro rol; los rivales, los otros dos."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.8, 0.77, 0.88))
	column.add_child(hint)


func _card(c: CharacterData) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 330)
	b.add_theme_font_size_override("font_size", 19)
	var lines := PackedStringArray([c.display_name.to_upper(), "%s · %s" % [c.animal, c.role], ""])
	for a in c.abilities:
		lines.append("%s  %s" % [a.slot, a.display_name])
	b.text = "\n".join(lines)
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD_COLOR
	normal.set_corner_radius_all(18)
	normal.border_color = c.body_color
	normal.border_width_top = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = CARD_HOVER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func() -> void:
		picked.emit(c)
		queue_free())
	return b
