class_name Shop
extends Control
## Tienda de la fase de compra, en tres secciones: Armas, Escudo y Habilidades.
## Se porta un arma y un escudo (o ninguno). Lo comprado queda marcado; tocarlo lo devuelve,
## y elegir otra cosa de la misma sección devuelve la compra anterior.
## Se abre sola al empezar la fase de compra; botón «Tienda» o tecla B para reabrirla.

const TITLE_SIZE := 30
const SECTION_SIZE := 22
const CARD_SIZE := 19
const CARD_MIN := Vector2(300, 100)

const PANEL_COLOR := Color(0.16, 0.12, 0.24, 0.98)
const CARD_COLOR := Color(0.28, 0.22, 0.40)
const CARD_HOVER := Color(0.36, 0.28, 0.50)
const CARD_DIM := Color(0.20, 0.17, 0.26)
const CARD_BOUGHT := Color(0.42, 0.28, 0.58)
const ACCENT := Color(0.78, 0.55, 1.0)
const EQUIPPED_BORDER := Color(0.85, 0.85, 0.95)
const TEXT_DIM := Color(0.75, 0.72, 0.82)

var touch_controls: TouchControls

var _panel: PanelContainer
var _title: Label
var _credits_label: Label
var _spent_label: Label
var _weapon_cards: Array[Button] = []
## Índice 0 = «Sin escudo»; 1.. = Economy.SHIELDS.
var _shield_cards: Array[Button] = []
var _toggle: Button
var _abilities_row: HBoxContainer
## Ranuras de habilidad comprables, en el mismo orden que _ability_cards.
var _ability_slots: Array[String] = []
var _ability_cards: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_set_open(false)
	var m := MatchManager.current
	if m:
		m.buy_phase_started.connect(func() -> void: _set_open(true))
		m.economy.credits_changed.connect(func(_p: Pawtner, _c: int) -> void: _refresh())
		m.economy.purchases_changed.connect(func(_p: Pawtner) -> void: _refresh())


func _process(_delta: float) -> void:
	var m := MatchManager.current
	var buying := m != null and m.player != null and m.is_buy_phase()
	if not buying and _panel.visible:
		_set_open(false)
	_toggle.visible = buying and not _panel.visible
	if buying and _panel.visible:
		# El panel tapa el reloj del HUD: se muestra aquí el tiempo de compra restante.
		_title.text = "Tienda  ·  %d s" % ceili(m.time_left)
	if buying and Input.is_action_just_pressed("shop"):
		_set_open(not _panel.visible)


func _set_open(open: bool) -> void:
	_panel.visible = open
	if touch_controls:
		touch_controls.set_sticks_enabled(not open)
	if open:
		_refresh()


# --- Construcción ---

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, 24))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# Cabecera: título a la izquierda, croquetas a la derecha.
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("Tienda", TITLE_SIZE, Color.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_credits_label = _label("", TITLE_SIZE, ACCENT)
	header.add_child(_credits_label)
	_spent_label = _label("", SECTION_SIZE - 2, TEXT_DIM)
	column.add_child(_spent_label)

	column.add_child(_label("ARMAS", SECTION_SIZE, ACCENT))
	var weapons_row := HBoxContainer.new()
	weapons_row.add_theme_constant_override("separation", 10)
	column.add_child(weapons_row)
	for i in Economy.WEAPONS.size():
		var card := _card(_on_weapon_pressed.bind(i))
		weapons_row.add_child(card)
		_weapon_cards.append(card)

	column.add_child(_label("ESCUDO  (vida extra y menos daño mientras dure)", SECTION_SIZE, ACCENT))
	var shields_row := HBoxContainer.new()
	shields_row.add_theme_constant_override("separation", 10)
	column.add_child(shields_row)
	for i in Economy.SHIELDS.size() + 1:
		var card := _card(_on_shield_pressed.bind(i - 1))
		shields_row.add_child(card)
		_shield_cards.append(card)

	column.add_child(_label("HABILIDADES  (las cargas que no uses se guardan)", SECTION_SIZE, ACCENT))
	_abilities_row = HBoxContainer.new()
	_abilities_row.add_theme_constant_override("separation", 10)
	column.add_child(_abilities_row)

	var done := Button.new()
	done.text = "Listo"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(0, 52)
	done.add_theme_font_size_override("font_size", TITLE_SIZE - 4)
	for state in ["normal", "hover", "pressed"]:
		done.add_theme_stylebox_override(state, _box(ACCENT.darkened(0.35 if state == "normal" else 0.2), 16))
	done.pressed.connect(_set_open.bind(false))
	column.add_child(done)

	_toggle = Button.new()
	_toggle.text = "Tienda"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.custom_minimum_size = Vector2(180, 64)
	_toggle.add_theme_font_size_override("font_size", TITLE_SIZE - 4)
	for state in ["normal", "hover", "pressed"]:
		_toggle.add_theme_stylebox_override(state, _box(ACCENT.darkened(0.35), 16))
	_toggle.pressed.connect(_set_open.bind(true))
	add_child(_toggle)
	_toggle.position = Vector2(24, 24)


func _card(callback: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_MIN
	b.add_theme_font_size_override("font_size", CARD_SIZE)
	b.pressed.connect(callback)
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Estado ---

func _refresh() -> void:
	var m := MatchManager.current
	if m == null or m.player == null:
		return
	var p := m.player
	var eco := m.economy
	_credits_label.text = "%d croquetas" % eco.credits(p)
	var spent := eco.spent_this_round(p)
	_spent_label.text = ("Gastado esta ronda: %d  ·  toca lo comprado para devolverlo" % spent) if spent > 0 \
		else "Un arma y un escudo (o ninguno). Elegir otro reemplaza al anterior."

	var start_weapon := eco.weapon_at_round_start(p)
	for i in Economy.WEAPONS.size():
		var data := Economy.WEAPONS[i]
		var bought := eco.bought_weapon(p) == data
		var equipped := p.weapon.data == data
		var affordable := data == start_weapon or eco.can_afford_swap(p, "weapon", data.price)
		var stats := _weapon_stats(data)
		var status := "Comprada  ·  tocar para devolver" if bought \
			else ("Equipada" if equipped else ("Gratis" if data.price == 0 else "%d croquetas" % data.price))
		_style_card(_weapon_cards[i], "%s\n%s\n%s" % [data.display_name, stats, status],
			bought, equipped and not bought, not affordable and not equipped)

	_refresh_abilities(p, eco)

	var bought_shield := eco.bought_shield(p)
	# «Sin escudo»: solo se puede elegir devolviendo el escudo comprado en esta ronda.
	var none_equipped := p.armor_index == -1
	_style_card(_shield_cards[0], "Sin escudo\nSolo tu vida (100)\n%s" % ("Equipado" if none_equipped else "Devolver escudo"),
		false, none_equipped, not none_equipped and bought_shield == -1)
	for i in Economy.SHIELDS.size():
		var item: Dictionary = Economy.SHIELDS[i]
		var price: int = item["price"]
		var bought := bought_shield == i
		var equipped := p.armor_index == i
		var affordable := eco.can_afford_swap(p, "shield", price)
		var stats := "+%d vida  ·  -%d %% daño" % [int(item["amount"]), roundi(float(item["reduction"]) * 100.0)]
		var status := "Comprado  ·  tocar para devolver" if bought \
			else ("Equipado (%d)" % ceili(p.shield) if equipped else "%d croquetas" % price)
		_style_card(_shield_cards[i + 1], "%s\n%s\n%s" % [item["name"], stats, status],
			bought, equipped and not bought, not affordable and not equipped)


func _refresh_abilities(p: Pawtner, eco: Economy) -> void:
	if _ability_cards.is_empty() and p.kit.character:
		for a in p.kit.character.abilities:
			if a.price > 0 and a.slot != "X":
				var card := _card(_on_ability_pressed.bind(a.slot))
				_abilities_row.add_child(card)
				_ability_cards.append(card)
				_ability_slots.append(a.slot)
	for i in _ability_cards.size():
		var slot := _ability_slots[i]
		var a := p.kit.ability(slot)
		var charges: int = p.kit.charges.get(slot, 0)
		var bought := eco.bought_ability_count(p, slot)
		var full := charges >= a.max_charges
		var status: String
		if full and bought > 0:
			status = "Comprada x%d  ·  tocar para devolver" % bought
		elif full:
			status = "Completa"
		else:
			status = "%d croquetas" % a.price
		var label := "%s  ·  %s\nCargas %d/%d\n%s" % [slot, a.display_name, charges, a.max_charges, status]
		_style_card(_ability_cards[i], label, bought > 0, full and bought == 0,
			not full and not eco.can_afford(p, a.price))


func _on_ability_pressed(slot: String) -> void:
	var m := MatchManager.current
	if m == null or not m.is_buy_phase():
		return
	var p := m.player
	var a := p.kit.ability(slot)
	if p.kit.charges.get(slot, 0) >= a.max_charges:
		m.economy.sell_ability(p, slot)
	else:
		m.economy.buy_ability(p, slot)
	_refresh()


func _weapon_stats(data: WeaponData) -> String:
	var damage := "%d×%d daño" % [data.pellets, int(data.damage)] if data.pellets > 1 else "%d daño" % int(data.damage)
	var bullets := "1 bala" if data.magazine == 1 else "%d balas" % data.magazine
	return "%s  ·  %s  ·  %s m" % [damage, bullets, str(snappedf(data.max_range, 0.5))]


func _style_card(card: Button, text: String, bought: bool, equipped: bool, unaffordable: bool) -> void:
	card.text = text
	card.disabled = unaffordable
	var base := CARD_BOUGHT if bought else CARD_COLOR
	var border := ACCENT if bought else (EQUIPPED_BORDER if equipped else Color.TRANSPARENT)
	var width := 4 if bought or equipped else 0
	card.add_theme_stylebox_override("normal", _box(base, 16, border, width))
	card.add_theme_stylebox_override("hover", _box(base.lightened(0.08) if bought else CARD_HOVER, 16, border, width))
	card.add_theme_stylebox_override("pressed", _box(CARD_HOVER.lightened(0.1), 16, border, width))
	card.add_theme_stylebox_override("disabled", _box(CARD_DIM, 16))
	card.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))


# --- Acciones ---

func _on_weapon_pressed(i: int) -> void:
	var m := MatchManager.current
	if m == null or not m.is_buy_phase():
		return
	var data := Economy.WEAPONS[i]
	if m.economy.bought_weapon(m.player) == data:
		m.economy.sell_weapon(m.player)
	else:
		m.economy.buy_weapon(m.player, data)
	_refresh()


## `i` = -1 para «Sin escudo».
func _on_shield_pressed(i: int) -> void:
	var m := MatchManager.current
	if m == null or not m.is_buy_phase():
		return
	if i < 0 or m.economy.bought_shield(m.player) == i:
		m.economy.sell_shield(m.player)
	else:
		m.economy.buy_shield(m.player, i)
	_refresh()


func _box(color: Color, radius: int, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
