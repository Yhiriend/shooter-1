class_name BotController
extends Node
## IA que escribe la misma intención que el PlayerController.
## Solo usa lo que su equipo ve u oye (Perception) y lo que es público en la partida
## (dónde está la semilla caída o la planta). Ver docs/GDD.md, «Bots (IA)».

enum State { ADVANCE, HOLD, COMBAT, INVESTIGATE, OBJECTIVE }

@export_group("Dificultad")
## Tiempo desde que ve a un enemigo hasta que empieza a disparar.
@export var reaction_time := 0.4
## Error de puntería inicial (grados); baja con el tiempo apuntando.
@export var aim_error_deg := 7.0
@export var aim_settle_time := 0.8
@export var burst_time := 0.45
@export var burst_pause := 0.3

@export_group("Comportamiento")
## Zonas a las que va cuando no tiene un objetivo urgente: "A", "B", "M".
@export var goal_zones: PackedStringArray = ["A", "B", "M"]
@export var hold_time_min := 2.0
@export var hold_time_max := 5.0
## Por debajo de esta fracción del alcance deja de acercarse y se planta a disparar.
@export var engage_distance_ratio := 0.75
## Distancia máxima a la que va a rescatar a su compañero.
@export var rescue_max_distance := 18.0

const OBJECTIVE_EVAL_INTERVAL := 0.3

var state := State.ADVANCE

var _pawtner: Pawtner
var _map: HuertoLunar
var _path := PackedVector3Array()
var _path_index := 0
var _goal := Vector3.ZERO
var _hold_left := 0.0
var _target: Pawtner
var _target_time := 0.0
var _aim_error_start := 0.0
var _burst_clock := 0.0
var _last_known := Vector3.ZERO
var _repath_left := 0.0
var _stuck_time := 0.0
var _objective_timer := 0.0
## Interacción a mantener al llegar al objetivo ("" = solo ir).
var _objective_action := ""
var _abilities := BotAbilities.new()


func setup(map: HuertoLunar) -> void:
	_map = map


func _ready() -> void:
	process_physics_priority = -1
	_pawtner = get_parent() as Pawtner
	assert(_pawtner != null, "BotController debe ser hijo de un Pawtner")
	if Perception.current:
		Perception.current.noise_heard.connect(_on_noise_heard)
	_pawtner.revived.connect(_choose_new_goal)


## Lo llama MatchManager al empezar cada ronda.
func reset_for_round(zones: PackedStringArray) -> void:
	goal_zones = zones
	_abilities.reset_round()
	_target = null
	_objective_action = ""
	_burst_clock = 0.0
	_choose_new_goal()


func _physics_process(delta: float) -> void:
	_clear_intent()
	if not _pawtner.is_alive or _map == null or _pawtner.frozen:
		return

	var enemy := _closest_visible_enemy()
	if enemy:
		if enemy != _target:
			_target = enemy
			_target_time = 0.0
			_aim_error_start = randf_range(-aim_error_deg, aim_error_deg)
		_last_known = enemy.global_position
		state = State.COMBAT
	elif state == State.COMBAT:
		# Lo perdimos de vista: ir a donde lo vimos por última vez, con cuidado.
		_target = null
		_investigate(_last_known)

	if state != State.COMBAT:
		_objective_timer -= delta
		if _objective_timer <= 0.0:
			_objective_timer = OBJECTIVE_EVAL_INTERVAL
			_evaluate_objective()

	match state:
		State.ADVANCE, State.INVESTIGATE:
			_follow_path(delta)
		State.HOLD:
			_hold(delta)
		State.COMBAT:
			_combat(delta)
		State.OBJECTIVE:
			_pursue_objective(delta)
	# Las habilidades se deciden al final: pueden ajustar el movimiento (impulsos).
	_abilities.think(self, _pawtner, delta)


# --- Consultas para BotAbilities ---

## Enemigo con el que está combatiendo (o null).
func current_target() -> Pawtner:
	return _target if state == State.COMBAT else null


## Interacción del objetivo actual ("Sembrar", "Arrancar", "Rescatar" o "").
func objective_action() -> String:
	return _objective_action if state == State.OBJECTIVE else ""


## Punto al que se dirige.
func goal() -> Vector3:
	return _goal


func _clear_intent() -> void:
	_pawtner.move_input = Vector2.ZERO
	_pawtner.wants_walk = false
	_pawtner.wants_shoot = false
	_pawtner.wants_aim_fine = false
	_pawtner.wants_interact = false


func _closest_visible_enemy() -> Pawtner:
	if Perception.current == null:
		return null
	var best: Pawtner = null
	var best_d := INF
	for e in Perception.current.visible_enemies(_pawtner.team):
		var d := e.global_position.distance_squared_to(_pawtner.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- Objetivo de la ronda ---

## Devuelve {"pos": Vector3, "action": String} o {} si no hay nada urgente.
func _current_objective() -> Dictionary:
	var m := MatchManager.current
	if m == null or not (m.phase in [MatchManager.Phase.ACTION, MatchManager.Phase.PLANTED]):
		return {}
	var me := _pawtner

	# 1. Rescatar al compañero si no hay enemigos a la vista.
	if not m.rescue_used[me.team]:
		for plush in m.plushes:
			if plush.pawtner.team == me.team and plush.pawtner != me \
					and me.global_position.distance_to(plush.global_position) <= rescue_max_distance:
				return {"pos": plush.global_position, "action": MatchManager.ACTION_RESCUE}

	if m.is_attacker(me):
		# 2. Sembrar si lleva la semilla.
		if me.carrying_seed and m.phase == MatchManager.Phase.ACTION:
			return {"pos": m.site_point(m.target_site), "action": MatchManager.ACTION_PLANT}
		# 3. Recoger la semilla caída si es el atacante vivo más cercano.
		if m.seed.state == MoonSeed.State.DROPPED and _is_closest_teammate_to(m.seed.global_position):
			return {"pos": m.seed.global_position, "action": ""}
	elif m.phase == MatchManager.Phase.PLANTED and m.plant:
		# 4. Defensores: arrancar la planta.
		return {"pos": m.plant.global_position, "action": MatchManager.ACTION_UPROOT}
	return {}


func _evaluate_objective() -> void:
	var obj := _current_objective()
	if obj.is_empty():
		if state == State.OBJECTIVE:
			_choose_new_goal()
		return
	var pos: Vector3 = obj["pos"]
	if state != State.OBJECTIVE or _goal.distance_to(pos) > 1.0:
		state = State.OBJECTIVE
		_goal = pos
		_set_path_to(pos)
	_objective_action = obj["action"]


func _pursue_objective(delta: float) -> void:
	var to_goal := _goal - _pawtner.global_position
	to_goal.y = 0.0
	var arrive := MatchManager.INTERACT_RANGE * 0.6 if _objective_action != "" else 0.4
	var can_act := _objective_action != "" and _pawtner.available_interaction == _objective_action
	if to_goal.length() <= arrive or can_act:
		# Quieto y manteniendo la interacción (sembrar exige estar dentro de la maceta).
		if can_act:
			_pawtner.wants_interact = true
			return
		if _objective_action == "":
			return
	if _path_index >= _path.size():
		_set_path_to(_goal)
	var moving := _move_along_path(false)
	if not moving:
		# Último tramo directo, por si el camino termina antes del punto exacto.
		var dir := to_goal.normalized()
		_pawtner.move_input = Vector2(dir.x, dir.z)
		_pawtner.aim_point = _pawtner.global_position + dir * 3.0
	_check_stuck(delta, true)


func _is_closest_teammate_to(pos: Vector3) -> bool:
	var m := MatchManager.current
	var my_d := _pawtner.global_position.distance_to(pos)
	for p in m.team_members(_pawtner.team):
		if p != _pawtner and p.is_alive and p.get_node_or_null("BotController") \
				and p.global_position.distance_to(pos) < my_d:
			return false
	return true


# --- Combate ---

func _combat(delta: float) -> void:
	_target_time += delta
	var to_target := _target.global_position - _pawtner.global_position
	to_target.y = 0.0
	var dist := to_target.length()
	var engage := _pawtner.weapon.data.max_range * engage_distance_ratio

	# El error de puntería se reduce mientras sigue al objetivo.
	var settle := clampf(_target_time / aim_settle_time, 0.0, 1.0)
	var err := lerpf(_aim_error_start, _aim_error_start * 0.25, settle)
	var aim_dir := to_target.normalized().rotated(Vector3.UP, deg_to_rad(err))
	_pawtner.aim_point = _pawtner.global_position + aim_dir * dist

	if dist > engage:
		# Lejos: acercarse corriendo sin disparar (correr abre el cono).
		_repath_left -= delta
		if _repath_left <= 0.0 or _path_index >= _path.size():
			_set_path_to(_target.global_position)
			_repath_left = 0.5
		_move_along_path(false)
		return

	# Cerca: plantarse (quieto = más preciso) y disparar en ráfagas cortas.
	if _target_time < reaction_time:
		return
	_burst_clock += delta
	if fmod(_burst_clock, burst_time + burst_pause) < burst_time:
		_pawtner.wants_shoot = true


# --- Patrulla e investigación ---

func _hold(delta: float) -> void:
	_hold_left -= delta
	if _hold_left <= 0.0:
		_choose_new_goal()


func _follow_path(delta: float) -> void:
	if _path_index >= _path.size():
		if state == State.INVESTIGATE:
			_choose_new_goal()
		else:
			state = State.HOLD
			_hold_left = randf_range(hold_time_min, hold_time_max)
		return
	var moving := _move_along_path(state == State.INVESTIGATE)
	_check_stuck(delta, moving)


## Mueve hacia el siguiente punto del camino. Devuelve false si ya no quedan puntos.
func _move_along_path(walk: bool) -> bool:
	while _path_index < _path.size():
		var to_next := _path[_path_index] - _pawtner.global_position
		to_next.y = 0.0
		if to_next.length() > 0.35:
			var dir := to_next.normalized()
			_pawtner.move_input = Vector2(dir.x, dir.z)
			_pawtner.wants_walk = walk
			if state != State.COMBAT:
				_pawtner.aim_point = _pawtner.global_position + dir * 3.0
			return true
		_path_index += 1
	return false


func _check_stuck(delta: float, moving: bool) -> void:
	if moving and _pawtner.get_real_velocity().length() < 0.3:
		_stuck_time += delta
		if _stuck_time > 0.8:
			_stuck_time = 0.0
			_set_path_to(_goal)
	else:
		_stuck_time = 0.0


func _choose_new_goal() -> void:
	if _map == null:
		return
	var m := MatchManager.current
	if m and m.plant and m.is_attacker(_pawtner):
		# Con la semilla sembrada, los atacantes la protegen desde cerca.
		_goal = _map.random_free_point_near(m.plant.global_position, 3)
	elif goal_zones.is_empty():
		return
	else:
		var zone := goal_zones[randi() % goal_zones.size()]
		_goal = _map.random_free_point_near(_map.zone_center(zone), 3)
	state = State.ADVANCE
	_set_path_to(_goal)


func _investigate(pos: Vector3) -> void:
	state = State.INVESTIGATE
	_goal = pos
	_set_path_to(pos)


func _set_path_to(pos: Vector3) -> void:
	_path = _map.find_path(_pawtner.global_position, pos)
	_path_index = 0


func _on_noise_heard(team: int, pos: Vector3, _source: Pawtner) -> void:
	if team != _pawtner.team or not _pawtner.is_alive:
		return
	# Combate y objetivo urgente (sembrar, arrancar, rescatar) van antes que un ruido.
	if state in [State.COMBAT, State.OBJECTIVE]:
		return
	if state == State.INVESTIGATE and _goal.distance_to(pos) < 3.0:
		return
	_investigate(pos)
