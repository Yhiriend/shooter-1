class_name MainMenu
extends Node
## Menú principal: Partida (2v2 contra bots) o Probar Pawtner (modo de práctica con
## rivales quietos para probar habilidades y mecánicas). De fondo, los 4 Pawtners.

const ACCENT := Color(0.78, 0.55, 1.0)
const BACKGROUND := Color(0.16, 0.12, 0.24)
const TEXT_SOFT := Color(0.85, 0.82, 0.92)
## Separación entre Pawtners en la vitrina y velocidad de giro (rad/s).
const SHOWCASE_SPACING := 1.5
const SHOWCASE_SPIN := 0.5

var _models: Array[Node3D] = []


func _ready() -> void:
	# Sin pantalla (pruebas automáticas) se salta el menú y empieza una partida normal.
	if DisplayServer.get_name() == "headless":
		GameMode.start_match.call_deferred(get_tree(), false)
		return
	_build_showcase()
	_build_ui()


func _process(delta: float) -> void:
	for m in _models:
		m.rotate_y(SHOWCASE_SPIN * delta)


func _notification(what: int) -> void:
	# Botón «atrás» de Android en el menú: salir del juego.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _build_showcase() -> void:
	var world := Node3D.new()
	world.name = "Showcase"
	add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.8, 0.95)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.1
	world.add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 35.0
	cam.position = Vector3(0.0, 2.6, 7.5)
	world.add_child(cam)
	cam.look_at(Vector3(0.0, 0.2, 0.0))

	var count := Roster.CHARACTERS.size()
	for i in count:
		var c := Roster.CHARACTERS[i]
		if c.model == null:
			continue
		var model := c.model.instantiate() as Node3D
		model.position = Vector3((i - (count - 1) * 0.5) * SHOWCASE_SPACING, -0.75, 0.0)
		# Cada uno empieza mirando un poco distinto.
		model.rotation.y = PI + i * 0.7
		world.add_child(model)
		_models.append(model)
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			for anim_name in anim.get_animation_list():
				if anim_name.ends_with("Idle"):
					anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
					anim.play(anim_name)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Título arriba.
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 36.0
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)
	top.add_child(EndScreen._label("Pawtners", 64, ACCENT))
	top.add_child(EndScreen._label("Shooter táctico 2v2", 24, TEXT_SOFT))

	# Botones abajo, debajo de los Pawtners.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -190.0
	bottom.offset_bottom = -30.0
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	bottom.add_child(row)
	var play := EndScreen._button("Partida", func() -> void: GameMode.start_match(get_tree(), false))
	var practice := EndScreen._button("Probar Pawtner", func() -> void: GameMode.start_match(get_tree(), true))
	for b: Button in [play, practice]:
		b.custom_minimum_size = Vector2(320, 90)
		b.add_theme_font_size_override("font_size", 30)
		row.add_child(b)

	var hint := EndScreen._label(
		"Partida: tú y un bot contra 2 bots, al mejor de 9 rondas.   ·   "
		+ "Probar Pawtner: rivales quietos, reaparición en 2 s y recursos infinitos.", 18, TEXT_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
