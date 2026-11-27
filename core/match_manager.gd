class_name MatchManager
extends Node
## Partida 2v2 por rondas con la Semilla Lunar: tú + 1 bot aliado contra 2 bots.
## Ver docs/GDD.md, «Modo de juego: Semilla Lunar» y «Reglas de partida 2v2».

signal round_started(round_number: int)
signal buy_phase_started
signal round_ended(winner: int, reason: String)
## Eliminación (para el registro de bajas del HUD). `killer` puede ser null.
signal pawtner_killed(killer: Pawtner, victim: Pawtner)
## Terminó la partida: el HUD muestra los resultados.
signal match_finished(winner: int)

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

## Celdas de los tréboles (mitad de cada pasillo), en la cuadrícula de Huerto Lunar.
const CLOVER_CELLS: Array[Vector2i] = [Vector2i(6, 17), Vector2i(33, 17)]

## Plan de ataque de los bots: puntos donde se reúnen antes de entrar a cada maceta.
## Por el pasillo de la maceta o por la rampa central (ver LAYOUT de Huerto Lunar).
const STAGE_CELLS := {
	"A": [Vector2i(6, 20), Vector2i(19, 20)],
	"B": [Vector2i(33, 20), Vector2i(20, 20)],
}
## Si atacas tú, a esta distancia de una maceta tu compañero entra contigo.
const PLAYER_COMMIT_RADIUS := 9.0
## Distancia a la que se considera que el dúo atacante ya está reunido.
const STAGE_GATHER_RADIUS := 4.5
## Si a la ronda le queda menos que esto, los atacantes entran aunque no estén reunidos.
const STAGE_DEADLINE := 50.0

## Modo de prueba (ver GameMode): reaparición, compra corta y recarga de recursos.
const PRACTICE_RESPAWN_TIME := 2.0
const PRACTICE_BUY_TIME := 5.0
const PRACTICE_REFILL_INTERVAL := 0.5

const ACTION_PLANT := "Sembrar"
const ACTION_UPROOT := "Arrancar"
const ACTION_RESCUE := "Rescatar"

static var current: MatchManager

@export var map_path: NodePath
@export var perception_path: NodePath
@export var camera_path: NodePath
@export var touch_controls_path: NodePath
## Probabilidad de que un bot prefiera la escopeta al rifle cuando le alcanza.
@export_range(0.0, 1.0) var bot_shotgun_preference := 0.35

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
## Punto de reunión de los atacantes y si ya dieron la orden de entrar.
var attack_stage := Vector3.ZERO
var attack_go := false
## Estadísticas de la partida por Pawtner: kills, deaths, plants, uproots, rescues.
var stats := {}

var player: Pawtner
var pawtners: Array[Pawtner] = []
var seed: MoonSeed
var plant: MoonPlant
var plushes: Array[Plush] = []
var rescue_used: Array[bool] = [false, false]
var economy := Economy.new()
## Sin tipo: puede contener tréboles ya recogidos (liberados).
var _clovers: Array = []

## Bots que prefieren la escopeta en esta partida.
var _prefers_shotgun := {}

var _map: HuertoLunar
var _camera: TopDownCamera
var _plant_progress := 0.0
## Modo de prueba: bots quietos, reaparición a los 2 s, ronda sin fin y recursos infinitos.
var practice := false
## Pawtners muertos esperando reaparecer (modo de prueba): Pawtner -> segundos restantes.
var _respawn_queue := {}
var _refill_timer := 0.0
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
	practice = GameMode.practice

	seed = MoonSeed.new()
	seed.name = "MoonSeed"
	_map.add_child(seed)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	# Por encima de los controles táctiles: la selección y la tienda deben recibir los toques.
	hud.layer = 2
	add_child(hud)
	var overlay := HealthOverlay.new()
	overlay.name = "HealthOverlay"
	hud.add_child(overlay)
	var minimap := Minimap.new()
	minimap.name = "Minimap"
	hud.add_child(minimap)
	var damage_numbers := DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	hud.add_child(damage_numbers)
	var match_hud := MatchHud.new()
	match_hud.name = "MatchHud"
	hud.add_child(match_hud)
	var shop := Shop.new()
	shop.name = "Shop"
	shop.touch_controls = get_node(touch_controls_path) as TouchControls
	hud.add_child(shop)
	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	hud.add_child(pause)

	var picked := await _pick_character(hud)
	_spawn_teams(picked)
	_start_match()


## Muestra la selección de personaje (o elige al azar sin pantalla, en pruebas).
func _pick_character(hud: CanvasLayer) -> CharacterData:
	if DisplayServer.get_name() == "headless":
		return Roster.CHARACTERS.pick_random()
	var touch := get_node(touch_controls_path) as TouchControls
	touch.set_sticks_enabled(false)
	var select := CharacterSelect.new()
	select.name = "CharacterSelect"
	hud.add_child(select)
	var c: CharacterData = await select.picked
	touch.set_sticks_enabled(true)
	return c


## Tu compañero es del otro rol; los rivales son los dos personajes restantes.
func _spawn_teams(mine: CharacterData) -> void:
	var other_role := "Madriguera" if mine.role == "Zarpa" else "Zarpa"
	var ally: CharacterData = Roster.by_role(other_role).pick_random()
	var rivals: Array[CharacterData] = []
	for c in Roster.CHARACTERS:
		if c != mine and c != ally:
			rivals.append(c)
	player = _spawn(mine, 0, true)
	_spawn(ally, 0, false)
	for c in rivals:
		_spawn(c, 1, false)


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
	_prefers_shotgun.clear()
	stats.clear()
	for p in pawtners:
		_prefers_shotgun[p] = randf() < bot_shotgun_preference
		stats[p] = {"kills": 0, "deaths": 0, "plants": 0, "uproots": 0, "rescues": 0}
	_start_round()


func _stat(p: Pawtner, key: String) -> void:
	if p and stats.has(p):
		stats[p][key] += 1


## Revancha: misma alineación, partida nueva.
func rematch() -> void:
	get_tree().paused = false
	_start_match()


## Vuelve a la selección de Pawtner y empieza una partida nueva.
func change_pawtner() -> void:
	get_tree().paused = false
	_teardown()
	var hud := get_node("HUD") as CanvasLayer
	var picked := await _pick_character(hud)
	_spawn_teams(picked)
	_start_match()


## Quita a todos los Pawtners y los objetos de la partida.
func _teardown() -> void:
	phase = Phase.MATCH_END
	time_left = INF
	_map.set_barriers_active(false)
	for node in get_tree().get_nodes_in_group(AbilityEffects.GROUP):
		node.queue_free()
	for plush in plushes:
		plush.queue_free()
	plushes.clear()
	if plant:
		plant.queue_free()
		plant = null
	seed.clear()
	for c: Variant in _clovers:
		if is_instance_valid(c):
			(c as Node).queue_free()
	_clovers.clear()
	for p in pawtners:
		p.queue_free()
	pawtners.clear()
	player = null
	var touch := get_node(touch_controls_path) as TouchControls
	touch.interact_button.visible = false
	for button: TouchButton in touch.ability_buttons.values():
		button.visible = false


## Inicio de partida y cambio de lado: 800 croquetas, pistola y sin escudo para todos.
func _reset_loadouts(keep_ult := false) -> void:
	economy.reset(pawtners)
	for p in pawtners:
		p.is_alive = false  # para que _start_round no conserve armas ni escudo
		p.kit.reset_match(keep_ult)


func _start_round() -> void:
	round_number += 1
	if round_number == 1:
		_reset_loadouts()
	if round_number == SWAP_AFTER_ROUND + 1:
		attacker_team = 1 - attacker_team
		_reset_loadouts(true)
	if round_number == ROUNDS_TO_WIN * 2 - 1:
		# Ronda decisiva con 4–4: el lado se sortea.
		attacker_team = randi() % 2
	target_site = ["A", "B"].pick_random()
	# Ruta de los bots atacantes: 65 % por el pasillo de la maceta, 35 % por la rampa central.
	var cells: Array = STAGE_CELLS[target_site]
	var stage_cell: Vector2i = cells[0] if randf() < 0.65 else cells[1]
	attack_stage = _map.cell_to_world(stage_cell.x, stage_cell.y)
	attack_go = false
	last_winner = -1
	last_reason = ""

	if plant:
		plant.queue_free()
		plant = null
	# Trampas, vigías, nubes, muros... no pasan de una ronda a otra.
	for node in get_tree().get_nodes_in_group(AbilityEffects.GROUP):
		node.queue_free()
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
			# Quien sobrevivió conserva arma y escudo; quien murió vuelve a la pistola.
			var survived := p.is_alive
			var kept_shield := p.shield
			p.respawn_at(_map.spawn_point(role, i), false)
			if survived:
				p.shield = kept_shield
			else:
				p.clear_armor()
				p.equip(Economy.PISTOL)
			p.aim_point = p.global_position + Vector3(0.0, 0.0, -3.0 if role == 0 else 3.0)
			p.frozen = false
			var bot := p.get_node_or_null("BotController") as BotController
			if bot:
				bot.reset_for_round(_bot_zones(p, i))

	# La semilla alterna entre los dos atacantes en cada ronda.
	var attackers := team_members(attacker_team)
	seed.give_to(attackers[round_number % attackers.size()])

	economy.begin_round()
	for p in pawtners:
		p.kit.begin_round()
	_refresh_clovers()
	if not practice:
		for p in pawtners:
			if p != player:
				_bot_buy(p)
	_respawn_queue.clear()

	_camera.set_target(player)
	_set_phase(Phase.BUY, PRACTICE_BUY_TIME if practice else BUY_TIME)
	Sfx.ui("round_start", -4.0)
	round_started.emit(round_number)
	buy_phase_started.emit()


func _bot_zones(p: Pawtner, index: int) -> PackedStringArray:
	if is_attacker(p):
		return PackedStringArray([target_site])
	# Los defensores se reparten las macetas.
	return PackedStringArray(["A" if index == 0 else "B"])


func _set_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	time_left = duration
	# En la compra todos se mueven dentro de su zona (barreras), sin disparar ni interactuar.
	var freeze := new_phase in [Phase.ROUND_END, Phase.MATCH_END]
	var setup := new_phase == Phase.BUY
	for p in pawtners:
		p.frozen = freeze
		p.setup_lock = setup
	_map.set_barriers_active(setup)


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_node_ready() or pawtners.is_empty():
		return
	time_left -= delta
	match phase:
		Phase.BUY:
			if time_left <= 0.0:
				# En el modo de prueba la ronda no se acaba por tiempo.
				_set_phase(Phase.ACTION, INF if practice else ROUND_TIME)
				Sfx.ui("round_start", -2.0)
		Phase.ACTION:
			_update_attack_plan()
			_update_seed_pickup()
			_update_interactions(delta)
			if not practice:
				_check_elimination()
			if phase == Phase.ACTION and time_left <= 0.0:
				_end_round(defender_team(), "Se acabó el tiempo")
		Phase.PLANTED:
			time_left = plant.time_left()
			_update_interactions(delta)
			if not practice:
				_check_elimination()
		Phase.ROUND_END:
			if time_left <= 0.0:
				if score.max() >= ROUNDS_TO_WIN and not practice:
					_finish_match()
				else:
					_start_round()
		Phase.MATCH_END:
			# Con pantalla, la partida nueva la pide el jugador (Revancha / Cambiar Pawtner).
			if time_left <= 0.0:
				_start_match()
	_update_plushes(delta)
	if practice:
		_update_practice(delta)


## Modo de prueba: reaparece a los muertos a los 2 s y mantiene al jugador con croquetas,
## cargas y definitiva al máximo para probar todo sin esperar rondas.
func _update_practice(delta: float) -> void:
	for p: Pawtner in _respawn_queue.keys():
		if not is_instance_valid(p):
			_respawn_queue.erase(p)
			continue
		_respawn_queue[p] -= delta
		if _respawn_queue[p] <= 0.0:
			_respawn_queue.erase(p)
			_practice_respawn(p)
	_refill_timer -= delta
	if _refill_timer <= 0.0 and player:
		_refill_timer = PRACTICE_REFILL_INTERVAL
		economy.add(player, Economy.MAX_CREDITS)
		var kit := player.kit
		for slot in ["C", "Q", "E"]:
			var a := kit.ability(slot)
			if a and kit.charges.get(slot, 0) < a.max_charges:
				kit.add_charge(slot, a.max_charges)
		kit.add_ult_point(kit.ult_cost())


## Sala de pruebas: aplica a cada bot lo que se eligió en la configuración (se puede
## cambiar en plena partida desde la pausa). Fuera de la sala, los bots juegan completos.
func apply_practice_settings() -> void:
	for p in pawtners:
		_apply_bot_permissions(p)


func _apply_bot_permissions(p: Pawtner) -> void:
	var bot := p.get_node_or_null("BotController") as BotController
	if bot == null:
		return
	var local_team := player.team if player else 0
	bot.can_move = not practice or GameMode.bot_can_move(p.team, local_team)
	bot.can_attack = not practice or GameMode.bot_can_attack(p.team, local_team)


## Los bots vuelven donde estaban (son blancos quietos); el jugador, a su spawn.
func _practice_respawn(p: Pawtner) -> void:
	if p.is_alive:
		return
	var pos := p.death_position
	if p == player:
		pos = _map.spawn_point(role_of(p), team_members(p.team).find(p))
	p.clear_armor()
	p.respawn_at(pos, false)
	p.frozen = phase in [Phase.ROUND_END, Phase.MATCH_END]
	p.setup_lock = phase == Phase.BUY
	if p == player:
		_camera.set_target(player)


func _finish_match() -> void:
	var headless := DisplayServer.get_name() == "headless"
	_set_phase(Phase.MATCH_END, MATCH_END_TIME if headless else INF)
	match_finished.emit(0 if score[0] > score[1] else 1)
	if not headless:
		# Un momento para ver el último cartel antes de los resultados.
		await get_tree().create_timer(2.0).timeout
		if phase == Phase.MATCH_END and player:
			var screen := EndScreen.new()
			screen.name = "EndScreen"
			get_node("HUD").add_child(screen)


## Los atacantes bot entran cuando el dúo está reunido en el punto de ataque,
## cuando uno de ellos ya está peleando o cuando se acaba el tiempo.
func _update_attack_plan() -> void:
	if attack_go:
		return
	# Si atacas tú, tu compañero bot sigue tu decisión: entra a la maceta a la que te acerques.
	if is_attacker(player) and player.is_alive:
		for site in ["A", "B"]:
			if _flat_distance(player.global_position, site_point(site)) <= PLAYER_COMMIT_RADIUS:
				_retarget_attack(site)
				attack_go = true
				return
	var gathered := true
	for p in team_members(attacker_team):
		if not p.is_alive or p == player:
			continue
		if _flat_distance(p.global_position, attack_stage) > STAGE_GATHER_RADIUS:
			gathered = false
		var bot := p.get_node_or_null("BotController") as BotController
		if bot and bot.state == BotController.State.COMBAT:
			attack_go = true
			return
	# Con un humano atacando, el bot espera a que elijas maceta (o al límite de tiempo).
	if is_attacker(player) and player.is_alive:
		gathered = false
	if gathered or time_left < STAGE_DEADLINE:
		attack_go = true


func _retarget_attack(site: String) -> void:
	if site == target_site:
		return
	target_site = site
	for p in team_members(attacker_team):
		var bot := p.get_node_or_null("BotController") as BotController
		if bot:
			bot.goal_zones = PackedStringArray([site])


func _end_round(winner: int, reason: String) -> void:
	if phase in [Phase.ROUND_END, Phase.MATCH_END]:
		return
	score[winner] += 1
	economy.award_round(pawtners, winner)
	last_winner = winner
	last_reason = reason
	for p in pawtners:
		p.is_interacting = false
		p.available_interaction = ""
	_set_phase(Phase.ROUND_END, ROUND_END_TIME)
	if player:
		Sfx.ui("win" if winner == player.team else "lose", -3.0)
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
	p.kit.add_ult_point()
	_stat(p, "plants")
	Sfx.ui("plant", -2.0)
	var site := _map.site_at(p.global_position)
	seed.clear()
	plant = MoonPlant.new()
	plant.name = "MoonPlant"
	plant.setup(site, attacker_team)
	_map.add_child(plant)
	plant.global_position = Vector3(p.global_position.x, 0.0, p.global_position.z)
	plant.reset_physics_interpolation()
	plant.bloomed.connect(func() -> void: _end_round(attacker_team, "¡La Semilla Lunar floreció!"))
	economy.add_team(pawtners, attacker_team, Economy.OBJECTIVE_REWARD)
	_plant_progress = 0.0
	_set_phase(Phase.PLANTED, MoonPlant.GROW_TIME)


# --- Interacciones: sembrar, arrancar, rescatar ---

func _available_interaction(p: Pawtner) -> String:
	if not p.is_alive or p.frozen or p.setup_lock:
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
					plush.rescuer = p
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
			for p in pawtners:
				if p.is_interacting and p.available_interaction == ACTION_UPROOT:
					p.kit.add_ult_point()
					_stat(p, "uproots")
			economy.add_team(pawtners, defender_team(), Economy.OBJECTIVE_REWARD)
			Sfx.ui("uproot", -2.0)
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
	Sfx.at("chime", plush.global_position, 2.0)
	_stat(plush.rescuer, "rescues")
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

func _on_pawtner_died(victim: Pawtner, killer: Pawtner) -> void:
	if killer and killer.team != victim.team:
		economy.add(killer, Economy.KILL_REWARD)
		killer.kit.on_kill()
		_stat(killer, "kills")
	_stat(victim, "deaths")
	pawtner_killed.emit(killer, victim)
	if victim.carrying_seed:
		seed.drop(victim.global_position)
	if practice:
		_respawn_queue[victim] = PRACTICE_RESPAWN_TIME
	elif phase in [Phase.ACTION, Phase.PLANTED]:
		var plush := Plush.new()
		plush.name = "Plush_%s" % victim.display_name
		plush.setup(victim, PLUSH_TIME)
		_map.add_child(plush)
		plush.global_position = Vector3(victim.global_position.x, 0.0, victim.global_position.z)
		plush.reset_physics_interpolation()
		plushes.append(plush)
	if victim == player:
		# Mientras estás muerto, la cámara sigue a tu compañero.
		for p in team_members(player.team):
			if p != player and p.is_alive:
				_camera.set_target(p)


# --- Creación de Pawtners ---

func _spawn(character: CharacterData, team: int, is_player: bool) -> Pawtner:
	var p := PAWTNER_SCENE.instantiate() as Pawtner
	p.name = character.display_name
	p.character = character
	p.display_name = "%s (tú)" % character.display_name if is_player else character.display_name
	p.team = team
	p.weapon_data = Economy.PISTOL
	if is_player:
		var pc := PlayerController.new()
		pc.name = "PlayerController"
		p.add_child(pc)
		var indicator := AimIndicator.new()
		indicator.name = "AimIndicator"
		p.add_child(indicator)
		var ability_indicator := AbilityAimIndicator.new()
		ability_indicator.name = "AbilityAimIndicator"
		ability_indicator.controller = pc
		p.add_child(ability_indicator)
	else:
		var bot := BotController.new()
		bot.name = "BotController"
		bot.setup(_map)
		p.add_child(bot)
		_apply_bot_permissions(p)
	_map.add_child(p)
	if is_player:
		(p.get_node("PlayerController") as PlayerController).set_touch_controls(
			get_node(touch_controls_path) as TouchControls)
	p.died.connect(_on_pawtner_died)
	pawtners.append(p)
	return p


# --- Habilidades ---

## Calma total (Capi X): revive al compañero caído en esta ronda; si está vivo, escudo a ambos.
func total_calm(caster: Pawtner, revive_health: float, shield_points: float, shield_reduction: float) -> void:
	for mate in team_members(caster.team):
		if mate == caster or mate.is_alive:
			continue
		var pos := mate.death_position
		for plush in plushes.duplicate():
			if plush.pawtner == mate:
				pos = plush.global_position
				_remove_plush(plush)
		mate.global_position = Vector3(pos.x, 0.0, pos.z)
		mate.reset_physics_interpolation()
		mate.revive(revive_health)
		if mate == player:
			_camera.set_target(player)
		AbilityEffects.spawn_pulse(pos, 2.0, Color(0.6, 1.0, 0.7))
		return
	for mate in team_members(caster.team):
		if mate.shield < shield_points:
			mate.set_armor(1, shield_points, shield_reduction)
		AbilityEffects.spawn_pulse(mate.global_position, 1.5, Color(0.85, 0.95, 1.0))


## Tréboles: uno en cada pasillo; reaparecen cada 2 rondas.
func _refresh_clovers() -> void:
	if round_number % 2 == 0:
		return
	for cell: Vector2i in CLOVER_CELLS:
		var pos := _map.cell_to_world(cell.x, cell.y)
		var taken := false
		for c: Variant in _clovers:
			if is_instance_valid(c) and (c as Clover).global_position.distance_to(pos) < 0.5:
				taken = true
		if not taken:
			var clover := Clover.new()
			clover.name = "Clover"
			clover.position = pos
			_map.add_child(clover)
			_clovers.append(clover)
	_clovers = _clovers.filter(func(c: Variant) -> bool: return is_instance_valid(c))


# --- Compras ---

func is_buy_phase() -> bool:
	if practice:
		return phase in [Phase.BUY, Phase.ACTION, Phase.PLANTED]
	return phase == Phase.BUY


## Rol del Pawtner para las zonas del mapa: 0 = atacante, 1 = defensor.
func role_of(p: Pawtner) -> int:
	return 0 if is_attacker(p) else 1


## ¿`pos` está en la zona de preparación del equipo de `p`?
func in_setup_zone(p: Pawtner, pos: Vector3) -> bool:
	return _map.in_setup_zone(role_of(p), pos)


## Regla simple de compra para bots: arma + escudo ligero si alcanza; si no, ahorra (eco).
func _bot_buy(p: Pawtner) -> void:
	if p.weapon.data == Economy.PISTOL:
		var prefer: WeaponData = Economy.SHOTGUN if _prefers_shotgun.get(p, false) else Economy.RIFLE
		var light_price: int = Economy.SHIELDS[0]["price"]
		if economy.can_afford(p, prefer.price + light_price):
			economy.buy_weapon(p, prefer)
		elif economy.can_afford(p, Economy.SHOTGUN.price + light_price):
			economy.buy_weapon(p, Economy.SHOTGUN)
		else:
			return  # eco: ahorra todo para la siguiente ronda
	if not economy.buy_shield(p, 1):
		economy.buy_shield(p, 0)
	_bot_buy_abilities(p)


## Con lo que sobra, cargas de habilidades (primero las más baratas).
func _bot_buy_abilities(p: Pawtner) -> void:
	var abilities := p.kit.character.abilities.filter(func(a: AbilityData) -> bool: return a.price > 0 and a.slot != "X")
	abilities.sort_custom(func(x: AbilityData, y: AbilityData) -> bool: return x.price < y.price)
	for a: AbilityData in abilities:
		while economy.buy_ability(p, a.slot):
			pass


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
