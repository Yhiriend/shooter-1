class_name CharacterSelect
extends Control
## Pantalla para elegir Pawtner antes de la partida.
## Abajo, un carrete de retratos cuadrados (solo la cabeza). Arriba, el Pawtner elegido:
## su modelo 3D a la izquierda (se gira arrastrando) y sus habilidades a la derecha.

signal picked(character: CharacterData)

const PANEL_COLOR := Color(0.16, 0.12, 0.24, 0.98)
const CARD_COLOR := Color(0.28, 0.22, 0.40)
const ACCENT := Color(0.78, 0.55, 1.0)
const TEXT_SOFT := Color(0.85, 0.82, 0.92)
const TEXT_DIM := Color(0.7, 0.66, 0.8)
## Fondo de los retratos (azul, como la referencia) y borde del elegido.
const PORTRAIT_BG := Color(0.2, 0.47, 0.88)
const PORTRAIT_SIZE := 104.0
## Colores de las ranuras: los mismos que los botones táctiles de habilidad.
const SLOT_COLORS := {
	"C": Color(0.55, 0.75, 1.0), "Q": Color(0.55, 0.75, 1.0),
	"E": Color(0.55, 0.9, 0.7), "X": Color(1.0, 0.8, 0.35),
}
const AIM_MODE_NAMES := ["Instantánea", "Dirección", "Área"]
const ROLE_TEXT := {
	"Zarpa": "Entra primero, saca información y gana duelos",
	"Madriguera": "Tapa visión, controla zonas y protege al dúo",
}
## Giro del modelo: lento solo, y arrastrando con el dedo o el ratón.
const IDLE_SPIN := 0.35
const DRAG_SPIN := 0.01

var _selected: CharacterData
var _thumbs := {}  # CharacterData -> Button
var _pivot: Node3D
var _model: Node3D
var _dragging := false

var _name_label: Label
var _sub_label: Label
var _personality_label: Label
var _abilities_box: VBoxContainer
var _confirm: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = PANEL_COLOR
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	margin.add_child(main)

	var title := EndScreen._label("Elige tu Pawtner", 30, ACCENT)
	main.add_child(title)

	# Arriba: modelo 3D a la izquierda, ficha y habilidades a la derecha.
	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 18)
	main.add_child(stage)
	stage.add_child(_build_viewer())
	stage.add_child(_build_info())

	# Abajo: carrete de retratos y botón para confirmar.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	main.add_child(bottom)
	var hint := EndScreen._label("Tu compañero será del otro rol;\nlos rivales, los otros dos.", 16, TEXT_DIM)
	hint.custom_minimum_size = Vector2(230, 0)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hint)
	var reel := HBoxContainer.new()
	reel.alignment = BoxContainer.ALIGNMENT_CENTER
	reel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reel.add_theme_constant_override("separation", 14)
	bottom.add_child(reel)
	for c in Roster.CHARACTERS:
		var thumb := _thumbnail(c)
		_thumbs[c] = thumb
		reel.add_child(thumb)
	_confirm = EndScreen._button("Jugar", _on_confirm)
	_confirm.custom_minimum_size = Vector2(230, PORTRAIT_SIZE)
	_confirm.add_theme_font_size_override("font_size", 28)
	_confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_confirm)

	_select(Roster.CHARACTERS[0])


func _process(delta: float) -> void:
	if _pivot and not _dragging:
		_pivot.rotate_y(IDLE_SPIN * delta)


# --- Visor 3D ---

func _build_viewer() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_stretch_ratio = 0.85
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_viewer_input)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.8, 0.95)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30.0, 150.0, 0.0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.8, 0.7, 1.0)
	vp.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	# Todavía fuera del árbol: look_at() no sirve aquí.
	cam.look_at_from_position(Vector3(0.0, 1.35, 4.6), Vector3(0.0, 0.85, 0.0))

	# Plataforma bajo el Pawtner.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.9
	cyl.height = 0.08
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.28, 0.52)
	disc.material_override = mat
	disc.position.y = -0.04
	vp.add_child(disc)

	_pivot = Node3D.new()
	vp.add_child(_pivot)
	return container


func _on_viewer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotate_y((event as InputEventMouseMotion).relative.x * DRAG_SPIN)


func _show_model(c: CharacterData) -> void:
	if _model:
		_model.queue_free()
		_model = null
	if c.model == null:
		return
	_model = c.model.instantiate() as Node3D
	_pivot.add_child(_model)
	# Mirando a la cámara (el frente del modelo es -Z) y un poco girado.
	_pivot.rotation.y = PI + 0.5
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for anim_name in anim.get_animation_list():
			if anim_name.ends_with("Idle"):
				anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
				anim.play(anim_name)
	# Pequeño salto al aparecer.
	_model.scale = Vector3.ONE * 0.85
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Ficha y habilidades ---

func _build_info() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	_name_label = _left_label("", 40, Color.WHITE)
	box.add_child(_name_label)
	_sub_label = _left_label("", 18, ACCENT)
	box.add_child(_sub_label)
	_personality_label = _left_label("", 16, TEXT_DIM)
	box.add_child(_personality_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)

	_abilities_box = VBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 8)
	box.add_child(_abilities_box)
	return box


func _fill_info(c: CharacterData) -> void:
	_name_label.text = c.display_name
	_sub_label.text = "%s · %s — %s" % [c.animal, c.role, ROLE_TEXT.get(c.role, "")]
	_personality_label.text = c.personality
	for child in _abilities_box.get_children():
		child.queue_free()
	for a in c.abilities:
		_abilities_box.add_child(_ability_row(a))


func _ability_row(a: AbilityData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_COLORS.get(a.slot, ACCENT)
	style.set_corner_radius_all(23)
	badge.add_theme_stylebox_override("panel", style)
	var key := EndScreen._label(a.slot, 22, Color(0.12, 0.09, 0.18))
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(key)
	row.add_child(badge)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_left_label(a.display_name, 19, Color.WHITE))
	head.add_child(_left_label("%s · %s" % [AIM_MODE_NAMES[a.aim_mode], _cost_text(a)], 14, TEXT_DIM))
	text.add_child(head)
	var desc := _left_label(a.description, 14, TEXT_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	row.add_child(text)
	return row


func _cost_text(a: AbilityData) -> String:
	match a.slot:
		"X":
			return "%d puntos" % a.ult_cost
		"E":
			if a.price > 0 and a.max_charges > 1:
				return "Gratis (2.ª: %d)" % a.price
			return "Gratis cada ronda"
		_:
			return "%d croquetas · máx. %d" % [a.price, a.max_charges]


static func _left_label(text: String, size: int, color: Color) -> Label:
	var l := EndScreen._label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


# --- Carrete de retratos ---

func _thumbnail(c: CharacterData) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = c.display_name
	_style_thumb(b, false)
	if c.portrait:
		var img := TextureRect.new()
		img.texture = c.portrait
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.offset_left = 4
		img.offset_top = 4
		img.offset_right = -4
		img.offset_bottom = -4
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(img)
	else:
		b.text = c.display_name
	b.pressed.connect(func() -> void:
		Sfx.ui("click", -8.0)
		_select(c))
	return b


func _style_thumb(b: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PORTRAIT_BG if selected else PORTRAIT_BG.darkened(0.35)
	style.set_corner_radius_all(16)
	style.border_color = ACCENT if selected else Color(1, 1, 1, 0.15)
	style.set_border_width_all(5 if selected else 2)
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, style)
	b.modulate = Color.WHITE if selected else Color(0.8, 0.8, 0.85)


func _select(c: CharacterData) -> void:
	_selected = c
	for other: CharacterData in _thumbs:
		_style_thumb(_thumbs[other], other == c)
	_fill_info(c)
	_show_model(c)
	_confirm.text = "Jugar con %s" % c.display_name


func _on_confirm() -> void:
	picked.emit(_selected)
	queue_free()
