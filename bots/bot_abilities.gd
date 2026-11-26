class_name BotAbilities
extends RefCounted
## Cuándo usa un bot cada habilidad. Las reglas van por efecto (no por personaje),
## así un Pawtner nuevo hereda el comportamiento de los efectos que usa.
## Solo usan lo que su equipo ve u oye, como el resto de la IA. Ver docs/GDD.md, «Bots (IA)».

const THINK_INTERVAL := 0.4
## Pausa mínima entre dos usos de la misma ranura.
const SLOT_COOLDOWN := 6.0
## Lo único que preparan los bots durante la compra.
const SETUP_EFFECTS: Array[AbilityData.Effect] = [AbilityData.Effect.ORANGE_TRAP, AbilityData.Effect.WATCHER]

var _think_left := 0.0
var _cooldowns := {}  # slot -> segundos
var _trap_placed_round := -1
var _watcher_round := -1


func reset_round() -> void:
	_cooldowns.clear()


func think(bot: BotController, p: Pawtner, delta: float) -> void:
	for slot: String in _cooldowns.keys():
		_cooldowns[slot] -= delta
	_think_left -= delta
	if _think_left > 0.0 or p.kit == null or p.kit.character == null or not p.can_act():
		return
	_think_left = THINK_INTERVAL
	var m := MatchManager.current
	if m == null or not (m.phase in [MatchManager.Phase.ACTION, MatchManager.Phase.PLANTED, MatchManager.Phase.BUY]):
		return
	for a in p.kit.character.abilities:
		if p.setup_lock and not (a.effect in SETUP_EFFECTS):
			continue
		if _ready(p, a.slot) and _try(bot, p, a, m):
			_cooldowns[a.slot] = SLOT_COOLDOWN
			return  # una habilidad por decisión


func _ready(p: Pawtner, slot: String) -> bool:
	return _cooldowns.get(slot, 0.0) <= 0.0 and p.kit.can_cast(slot)


## Decide si usar la habilidad `a` ahora. true si la lanzó.
func _try(bot: BotController, p: Pawtner, a: AbilityData, m: MatchManager) -> bool:
	var target := bot.current_target()
	var in_combat := bot.state == BotController.State.COMBAT and target != null
	var dist := p.global_position.distance_to(target.global_position) if target else INF
	var hurt := p.health < 50.0
	var critical := bot.objective_action() in [MatchManager.ACTION_PLANT, MatchManager.ACTION_UPROOT]

	match a.effect:
		AbilityData.Effect.YARN_REVEAL:
			# Antes de entrar a una zona: lanzar el ovillo hacia donde va.
			if not in_combat and bot.state in [BotController.State.ADVANCE, BotController.State.OBJECTIVE, BotController.State.INVESTIGATE] \
					and p.global_position.distance_to(bot.goal()) < 11.0 and p.global_position.distance_to(bot.goal()) > 3.0:
				return _cast(p, a, bot.goal())
		AbilityData.Effect.BELL_FLASH:
			if in_combat and dist <= a.cast_range:
				return _cast(p, a, target.global_position)
		AbilityData.Effect.DASH:
			if in_combat and hurt:
				return _cast(p, a, p.global_position, _sideways_away(p, target))
		AbilityData.Effect.NIGHT_EYES:
			if not in_combat and m.alive_count(1 - p.team) > 0:
				return _cast(p, a, p.global_position)
		AbilityData.Effect.DECOY:
			# Esperando: pasos falsos hacia un costado para distraer.
			if not in_combat and bot.state == BotController.State.HOLD:
				var side := p.facing().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
				return _cast(p, a, p.global_position + side * a.cast_range)
		AbilityData.Effect.GROUND_SLAM:
			if in_combat and dist <= a.radius:
				return _cast(p, a, p.global_position)
		AbilityData.Effect.BURROW:
			if in_combat and p.health < 40.0:
				return _cast(p, a, p.global_position, _away(p, target))
		AbilityData.Effect.BIG_LEAP:
			if in_combat and dist >= 4.0 and dist <= a.cast_range:
				return _cast(p, a, target.global_position)
		AbilityData.Effect.BAMBOO_WALL:
			# Taparse mientras siembra o arranca, o al quedar herido.
			if in_combat and (critical or hurt):
				return _cast(p, a, target.global_position)
		AbilityData.Effect.HONEY_POOL:
			if in_combat and dist >= 3.0 and dist <= a.cast_range:
				return _cast(p, a, target.global_position)
		AbilityData.Effect.SMOKE:
			if in_combat and (hurt or critical):
				# Nube entre el bot y el enemigo, para cortar la línea de vista.
				return _cast(p, a, p.global_position.lerp(target.global_position, 0.5))
		AbilityData.Effect.BIG_SMOKE:
			if in_combat and (critical or Perception.current.visible_enemies(p.team).size() >= 2):
				return _cast(p, a, target.global_position)
		AbilityData.Effect.ORANGE_TRAP:
			# Una trampa por ronda donde espera (defendiendo o junto a la planta).
			if not in_combat and bot.state == BotController.State.HOLD and _trap_placed_round != m.round_number:
				_trap_placed_round = m.round_number
				return _cast(p, a, p.global_position)
		AbilityData.Effect.HOT_SPRING:
			if not in_combat:
				var patient := _hurt_teammate_near(p, 4.0)
				if patient:
					return _cast(p, a, patient.global_position)
		AbilityData.Effect.WATCHER:
			# Esperando: dejar el vigía mirando hacia el lado del rival.
			if not in_combat and bot.state == BotController.State.HOLD and _watcher_round != m.round_number:
				_watcher_round = m.round_number
				var enemy_spawn := HuertoLunar.current.zone_center("d" if m.is_attacker(p) else "a")
				var dir := enemy_spawn - p.global_position
				dir.y = 0.0
				return _cast(p, a, p.global_position + dir.normalized() * minf(a.cast_range, 4.0))
		AbilityData.Effect.TOTAL_CALM:
			# Revivir al compañero caído, o escudo para ambos en pleno combate.
			if _teammate_down(p, m) or (in_combat and p.shield < 25.0):
				return _cast(p, a, p.global_position)
	return false


## Lanza la habilidad hacia `target`; `move` orienta los impulsos (dash, madriguera).
func _cast(p: Pawtner, a: AbilityData, target: Vector3, move := Vector2.ZERO) -> bool:
	if move != Vector2.ZERO:
		p.move_input = move
	p.ability_target = target
	p.has_ability_target = true
	p.wants_ability = a.slot
	return true


func _away(p: Pawtner, target: Pawtner) -> Vector2:
	var v := p.global_position - target.global_position
	return Vector2(v.x, v.z).normalized()


## Hacia un costado y algo hacia atrás: sale de la línea de tiro.
func _sideways_away(p: Pawtner, target: Pawtner) -> Vector2:
	var away := _away(p, target)
	var side := Vector2(-away.y, away.x) * (1.0 if randf() < 0.5 else -1.0)
	return (side + away * 0.5).normalized()


func _hurt_teammate_near(p: Pawtner, radius: float) -> Pawtner:
	for mate in MatchManager.current.team_members(p.team):
		if mate.is_alive and mate.health < 70.0 and mate.global_position.distance_to(p.global_position) <= radius:
			return mate
	return null


func _teammate_down(p: Pawtner, m: MatchManager) -> bool:
	for mate in m.team_members(p.team):
		if mate != p and not mate.is_alive:
			return true
	return false
