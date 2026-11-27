class_name PauseMenu
extends Control
## Botón de pausa (arriba a la izquierda) y menú: Reanudar, Cambiar Pawtner o Menú principal.
## También se abre con Esc o con el botón «atrás» de Android.

const PANEL_COLOR := Color(0.12, 0.09, 0.18, 0.85)

var _button: Button
var _panel: Control
## Panel de configuración de la sala de pruebas abierto (o null).
var _settings: PracticeSettings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_button = EndScreen._button("II", toggle)
	_button.custom_minimum_size = Vector2(72, 64)
	_button.position = Vector2(20, 20)
	add_child(_button)

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var back := ColorRect.new()
	back.color = PANEL_COLOR
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(back)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(column)
	column.add_child(EndScreen._label("Pausa", 48))
	var buttons := [EndScreen._button("Reanudar", toggle)]
	if GameMode.practice:
		buttons.append(EndScreen._button("Configurar sala", _open_practice_settings))
	buttons.append(EndScreen._button("Cambiar Pawtner", _change_pawtner))
	buttons.append(EndScreen._button("Menú principal", func() -> void: GameMode.go_to_menu(get_tree())))
	for b in buttons:
		var center := CenterContainer.new()
		center.add_child(b)
		column.add_child(center)


func _process(_delta: float) -> void:
	# Solo durante la partida (no en la selección de Pawtner ni en los resultados).
	var m := MatchManager.current
	_button.visible = m != null and m.player != null and m.phase != MatchManager.Phase.MATCH_END \
		and not _panel.visible and _settings == null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_button.visible or _panel.visible or _settings):
		_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and (_button.visible or _panel.visible or _settings):
		_back()


## Esc / «atrás»: con la configuración abierta vuelve a la pausa; si no, pausa o reanuda.
func _back() -> void:
	if _settings:
		_settings.close()
	else:
		toggle()


func toggle() -> void:
	_panel.visible = not _panel.visible
	get_tree().paused = _panel.visible


## Sala de pruebas: qué pueden hacer los demás Pawtners. Al cerrarla se vuelve a la pausa.
func _open_practice_settings() -> void:
	_panel.visible = false
	_settings = PracticeSettings.new()
	_settings.name = "PracticeSettings"
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings = null
		_panel.visible = true)


## Vuelve a elegir Pawtner sin salir del modo (partida o práctica).
func _change_pawtner() -> void:
	_panel.visible = false
	MatchManager.current.change_pawtner()
