class_name MatchManager
extends Node
## Partida 2v2 por rondas con la Semilla Lunar: tú + 1 bot aliado contra 2 bots.
## Ver docs/GDD.md, «Modo de juego: Semilla Lunar» y «Reglas de partida 2v2».

signal round_started(round_number: int)
signal round_ended(winner: int, reason: String)

enum Phase { BUY, ACTION, PLANTED, ROUND_END, MATCH_END }

const PAWTNER_SCENE := preload("res://pawtners/pawtner.tscn")

const BUY_TIME := 15.0
const ROUND_TIME := 75.0
const ROUND_END_TIME := 5.0
const MATCH_END_TIME := 8.0
const ROUNDS_TO_WIN := 5
const SWAP_AFTER_ROUND := 4
const PLANT_TIME := 3.0
const RESCUE_TIME := 3.0
const PLUSH_TIME := 8.0
const RESCUE_HEALTH := 30.0
const INTERACT_RANGE := 1.4
const HUG_NOISE_INTERVAL := 0.5
const HUG_NOISE_RADIUS := 15.0

const ACTION_PLANT := "Sembrar"
const ACTION_UPROOT := "Arrancar"
const ACTION_RESCUE := "Rescatar"

static var current: MatchManager

@export var map_path: NodePath
@export var perception_path: NodePath
@export var camera_path: NodePath
@export var touch_controls_path: NodePath
@export var player_weapon: WeaponData = preload("res://weapons/seed_rifle.tres")
@export var bot_weapon: WeaponData = preload("res://weapons/seed_rifle.tres")

var phase := Phase.BUY
var time_left := 0.0
var round_number := 0
## Rondas ganadas por equipo (0 = el tuyo, 1 = rivales).
var score: Array[int] = [0, 0]
## Equipo que ataca esta ronda.
var attacker_team := 0
## Maceta que atacan los bots esta ronda.
var target_site := "A"
var last_winner := -1
var last_reason := ""

var player: Pawtner
var pawtners: Array[Pawtner] = []
var seed: MoonSeed
var plant: MoonPlant
var plushes: Array[Plush] = []
var rescue_used: Array[bool] = [false, false]

var _map: HuertoLunar
var _camera: TopDownCamera
var _plant_progress := 0.0
var _hug_noise_timer := 0.0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_map = get_node(map_path) as HuertoLunar
	if not _map.is_node_ready():
		await _map.ready
	(get_node(perception_path) as Perception).setup(_map, 0)
	_camera = get_node(camera_path) as TopDownCamera

	seed = MoonSeed.new()
	seed.name = "MoonSeed"
	_map.add_child(seed)

	player = _spawn("Tú", 0, true)
	_spawn("Pip", 0, false)
	_spawn("Tofu", 1, false)
	_spawn("Capi", 1, false)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var overlay := HealthOverlay.new()
	overlay.name = "HealthOverlay"
	hud.add_child(overlay)
	var match_hud := MatchHud.new()
	match_hud.name = "MatchHud"
	hud.add_child(match_hud)

	_start_match()


# --- Consultas (las usan bots y HUD) ---

func is_attacker(p: Pawtner) -> bool:
	return p.team == attacker_team


func defender_team() -> int:
	return 1 - attacker_team


func team_members(team: int) -> Array[Pawtner]:
	var result: Array[Pawtner] = []
	for p in pawtners:
		if p.team == team:
			result.append(p)
	return result


func alive_count(team: int) -> int:
	var n := 0
	for p in pawtners:
		if p.team == team and p.is_alive:
			n += 1
	return n


func site_point(site: String) -> Vector3:
	return _map.zone_center(site)


# --- Flujo de partida ---

func _start_match() -> void:
	score = [0, 0]
	round_number = 0
	attacker_team = 0
	_start_round()


func _start_round() -> void:
	round_number += 1
	if round_number == SWAP_AFTER_ROUND + 1:
		attacker_team = 1 - attacker_team
	if round_number == ROUNDS_TO_WIN * 2 - 1:
		# Ronda decisiva con 4–4: el lado se sortea.
		attacker_team = randi() % 2
	target_site = ["A", "B"].pick_random()
	last_winner = -1
	last_reason = ""

	if plant:
		plant.queue_free()
		plant = null
	for plush in plushes:
		plush.queue_free()
	plushes.clear()
	rescue_used = [false, false]
	_plant_progress = 0.0
	seed.clear()

	for team in 2:
		var members := team_members(team)
		for i in members.size():
			var p := members[i]
			var role := 0 if team == attacker_team else 1
			p.respawn_at(_map.spawn_point(role, i), false)
			p.aim_point = p.global_position + Vector3(0.0, 0.0, -3.0 if role == 0 else 3.0)
			p.frozen = true
			var bot := p.get_node_or_null("BotController") as BotController
			if bot:
				bot.reset_for_round(_bot_zones(p, i))

	# La semilla alterna entre los dos atacantes en cada ronda.
	var attackers := team_members(attacker_team)
	seed.give_to(attackers[round_number % attackers.size()])

	_camera.set_target(player)
	_set_phase(Phase.BUY, BUY_TIME)
	round_started.emit(round_number)


func _bot_zones(p: Pawtner, index: int) -> PackedStringArray:
	if is_attacker(p):
		return PackedStringArray([target_site])
	# Los defensores se reparten las macetas.
	return PackedStringArray(["A" if index == 0 else "B"])


func _set_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	time_left = duration
	var freeze := new_phase in [Phase.BUY, Phase.ROUND_END, Phase.MATCH_END]
	for p in pawtners:
		p.frozen = freeze


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_node_ready() or pawtners.is_empty():
		return
	time_left -= delta
	match phase:
		Phase.BUY:
			if time_left <= 0.0:
				_set_phase(Phase.ACTION, ROUND_TIME)
		Phase.ACTION:
			_update_seed_pickup()
			_update_interactions(delta)
			_check_elimination()
			if phase == Phase.ACTION and time_left <= 0.0:
				_end_round(defender_team(), "Se acabó el tiempo")
		Phase.PLANTED:
			time_left = plant.time_left()
			_update_interactions(delta)
			_check_elimination()
		Phase.ROUND_END:
			if time_left <= 0.0:
				if score.max() >= ROUNDS_TO_WIN:
					_set_phase(Phase.MATCH_END, MATCH_END_TIME)
				else:
					_start_round()
		Phase.MATCH_END:
			if time_left <= 0.0:
				_start_match()
	_update_plushes(delta)


func _end_round(winner: int, reason: String) -> void:
	if phase in [Phase.ROUND_END, Phase.MATCH_END]:
		return
	score[winner] += 1
	last_winner = winner
	last_reason = reason
	for p in pawtners:
		p.is_interacting = false
		p.available_interaction = ""
	_set_phase(Phase.ROUND_END, ROUND_END_TIME)
	round_ended.emit(winner, reason)


func _check_elimination() -> void:
	var atk := alive_count(attacker_team)
	var def := alive_count(defender_team())
	if phase == Phase.ACTION:
		if atk == 0:
			_end_round(defender_team(), "Atacantes eliminados")
		elif def == 0:
			_end_round(attacker_team, "Defensores eliminados")
	elif phase == Phase.PLANTED and def == 0:
		# Con la semilla sembrada, solo cuenta eliminar a los defensores.
		_end_round(attacker_team, "Defensores eliminados")


# --- Semilla ---

func _update_seed_pickup() -> void:
	if seed.state != MoonSeed.State.DROPPED:
		return
	for p in pawtners:
		if p.is_alive and is_attacker(p) and _flat_distance(p.global_position, seed.global_position) <= MoonSeed.PICKUP_RADIUS:
			seed.give_to(p)
			return


func _plant_seed(p: Pawtner) -> void:
	var site := _map.site_at(p.global_position)
	seed.clear()
	plant = MoonPlant.new()
	plant.name = "MoonPlant"
	plant.setup(site, attacker_team)
	_map.add_child(plant)
	plant.global_position = Vector3(p.global_position.x, 0.0, p.global_position.z)
	plant.bloomed.connect(func() -> void: _end_round(attacker_team, "¡La Semilla Lunar floreció!"))
	_plant_progress = 0.0
	_set_phase(Phase.PLANTED, MoonPlant.GROW_TIME)


# --- Interacciones: sembrar, arrancar, rescatar ---

func _available_interaction(p: Pawtner) -> String:
	if not p.is_alive or p.frozen:
		return ""
	if not rescue_used[p.team] and _plush_in_reach(p) != null:
		return ACTION_RESCUE
	if phase == Phase.ACTION and p.carrying_seed and _map.site_at(p.global_position) != "":
		return ACTION_PLANT
	if phase == Phase.PLANTED and not is_attacker(p) and plant \
			and _flat_distance(p.global_position, plant.global_position) <= INTERACT_RANGE:
		return ACTION_UPROOT
	return ""


func _update_interactions(delta: float) -> void:
	var uprooters := 0
	var planting := false
	var hugged: Array[Plush] = []

	for p in pawtners:
		p.available_interaction = _available_interaction(p)
		p.is_interacting = p.available_interaction != "" and p.wants_interact and p.move_input == Vector2.ZERO
		p.interaction_progress = 0.0
		if not p.is_interacting:
			continue
		match p.available_interaction:
			ACTION_PLANT:
				planting = true
				_plant_progress += delta
				p.interaction_progress = _plant_progress / PLANT_TIME
				if _plant_progress >= PLANT_TIME:
					_plant_seed(p)
					return
			ACTION_UPROOT:
				uprooters += 1
			ACTION_RESCUE:
				var plush := _plush_in_reach(p)
				if not hugged.has(plush):
					hugged.append(plush)
					plush.hug_progress += delta
				p.interaction_progress = plush.hug_progress / RESCUE_TIME
				_emit_hug_noise(p, delta)

	if not planting:
		_plant_progress = 0.0

	for plush in plushes.duplicate():
		if not hugged.has(plush):
			plush.hug_progress = 0.0
		elif plush.hug_progress >= RESCUE_TIME:
			_rescue(plush)

	if plant:
		plant.tick_uproot(delta, uprooters)
		for p in pawtners:
			if p.is_interacting and p.available_interaction == ACTION_UPROOT:
				p.interaction_progress = plant.uproot_progress
		if plant.uproot_progress >= 1.0:
			_end_round(defender_team(), "¡Planta arrancada!")


func _emit_hug_noise(p: Pawtner, delta: float) -> void:
	_hug_noise_timer -= delta
	if _hug_noise_timer <= 0.0 and Perception.current:
		_hug_noise_timer = HUG_NOISE_INTERVAL
		Perception.current.emit_noise(p, p.global_position, HUG_NOISE_RADIUS)


# --- Rescate de dúo ---

func _plush_in_reach(p: Pawtner) -> Plush:
	for plush in plushes:
		if plush.pawtner.team == p.team and plush.pawtner != p \
				and _flat_distance(p.global_position, plush.global_position) <= INTERACT_RANGE:
			return plush
	return null


func _rescue(plush: Plush) -> void:
	rescue_used[plush.pawtner.team] = true
	plush.pawtner.revive(RESCUE_HEALTH)
	if plush.pawtner == player:
		_camera.set_target(player)
	_remove_plush(plush)


func _update_plushes(delta: float) -> void:
	for plush in plushes.duplicate():
		plush.time_left -= delta
		if plush.time_left <= 0.0:
			_remove_plush(plush)


func _remove_plush(plush: Plush) -> void:
	plushes.erase(plush)
	plush.queue_free()


# --- Muertes ---

func _on_pawtner_died(victim: Pawtner, _killer: Pawtner) -> void:
	if victim.carrying_seed:
		seed.drop(victim.global_position)
	if phase in [Phase.ACTION, Phase.PLANTED]:
		var plush := Plush.new()
		plush.name = "Plush_%s" % victim.display_name
		plush.setup(victim, PLUSH_TIME)
		_map.add_child(plush)
		plush.global_position = Vector3(victim.global_position.x, 0.0, victim.global_position.z)
		plushes.append(plush)
	if victim == player:
		# Mientras estás muerto, la cámara sigue a tu compañero.
		for p in team_members(player.team):
			if p != player and p.is_alive:
				_camera.set_target(p)


# --- Creación de Pawtners ---

func _spawn(display_name: String, team: int, is_player: bool) -> Pawtner:
	var p := PAWTNER_SCENE.instantiate() as Pawtner
	p.name = display_name
	p.display_name = display_name
	p.team = team
	p.weapon_data = player_weapon if is_player else bot_weapon
	if is_player:
		var pc := PlayerController.new()
		pc.name = "PlayerController"
		p.add_child(pc)
		var indicator := AimIndicator.new()
		indicator.name = "AimIndicator"
		p.add_child(indicator)
	else:
		var bot := BotController.new()
		bot.name = "BotController"
		bot.setup(_map)
		p.add_child(bot)
	_map.add_child(p)
	if is_player:
		(p.get_node("PlayerController") as PlayerController).set_touch_controls(
			get_node(touch_controls_path) as TouchControls)
	p.died.connect(_on_pawtner_died)
	pawtners.append(p)
	return p


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
