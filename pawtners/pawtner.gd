class_name Pawtner
extends CharacterBody3D
## Animalito jugable. Solo lee la *intención* (move_input, aim_point, wants_shoot...)
## que escribe un controlador hijo: PlayerController o BotController.
## Ver docs/GDD.md, «Controles, cámara y visión», «Reglas de partida» y «Arquitectura técnica».

signal died(victim: Pawtner, killer: Pawtner)
signal health_changed(health: float, shield: float)
signal respawned
## Revivido por un compañero (rescate de dúo o Calma total).
signal revived

enum MoveState { STILL, WALK, RUN }
## Movimientos especiales de habilidades: mientras duran no se controla ni se dispara.
enum Motion { NONE, DASH, BURROW, LEAP }

const TEAM_COLORS: Array[Color] = [Color(1.0, 0.55, 0.45), Color(0.4, 0.85, 0.72)]
const EYE_HEIGHT := 1.0
const FOOTSTEP_INTERVAL := 0.35
const FOOTSTEP_NOISE_RADIUS := 15.0
## Invulnerabilidad al reaparecer con protección (no se usa en rondas).
const RESPAWN_PROTECTION := 2.0
const LEAP_HEIGHT := 3.0

@export var display_name := "Pawtner"
## Equipo fijo: 0 = tu equipo (coral), 1 = rivales (menta). El rol (atacar o
## defender) lo decide MatchManager y cambia a mitad de partida.
@export var team := 0
@export var character: CharacterData
@export var weapon_data: WeaponData
@export var max_health := 100.0
@export var start_shield := 0.0

@export_group("Movimiento")
@export var run_speed := 5.5
@export var walk_speed := 2.8
## Multiplicador de velocidad con apuntado fino: frena un 30 %.
@export var aim_fine_speed_mult := 0.7
@export var acceleration := 40.0
@export var turn_sharpness := 20.0
## El portador de la Semilla Lunar corre un 5 % más lento.
@export var seed_speed_mult := 0.95

# --- Intención: la escribe el controlador cada frame de física ---
## Dirección de movimiento en pantalla (y negativa = arriba). Solo importa la dirección.
var move_input := Vector2.ZERO
var wants_walk := false
var wants_aim_fine := false
var wants_shoot := false
## Mantener para sembrar, arrancar o rescatar.
var wants_interact := false
## Habilidad a lanzar este frame ("C", "Q", "E", "X" o ""). Se consume al leerla.
var wants_ability := ""
## Punto elegido para la habilidad (arrastrando el botón). Si no hay, se usa aim_point.
var ability_target := Vector3.ZERO
var has_ability_target := false
## Punto del suelo hacia el que mira, en coordenadas globales.
var aim_point := Vector3.ZERO

# --- Estado ---
var health := 100.0
var shield := 0.0
## Escudo equipado: índice en Economy.SHIELDS, o -1 sin escudo.
var armor_index := -1
## Fracción del daño que se resta mientras al escudo le queden puntos.
var shield_reduction := 0.0
var is_alive := true
var is_aiming_fine := false
var move_state := MoveState.STILL
var weapon: Weapon
var kit: AbilityKit
## Congelado: no se mueve ni dispara (fase de compra y fin de ronda).
var frozen := false
var carrying_seed := false
## Interacción disponible ahora ("Sembrar", "Arrancar", "Rescatar" o ""). La escribe MatchManager.
var available_interaction := ""
## true mientras mantiene una interacción (no puede disparar).
var is_interacting := false
## Progreso 0..1 de la interacción en curso, para la UI.
var interaction_progress := 0.0
## Dónde murió por última vez (para revivir con Calma total si el peluche ya no está).
var death_position := Vector3.ZERO

# --- Estados alterados (habilidades) ---
var _slow_mult := 1.0
var _slow_time := 0.0
var _spread_mult := 1.0
var _spread_time := 0.0
var _blind_time := 0.0
var _stun_time := 0.0
var _root_time := 0.0
## Mientras dura, también los pasos caminando hacen ruido (charco de miel).
var _noisy_time := 0.0

# --- Movimiento especial ---
var _motion := Motion.NONE
var _motion_time := 0.0
var _motion_duration := 0.0
var _motion_from := Vector3.ZERO
var _motion_to := Vector3.ZERO
var _motion_on_end := Callable()

## false cuando está oculto por la niebla de guerra para el jugador local.
var _revealed := true
var _footstep_timer := 0.0
var _protection_left := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $Collision


func _ready() -> void:
	collision_layer = Layers.PAWTNER
	collision_mask = Layers.WORLD | Layers.PAWTNER
	health = max_health
	shield = start_shield
	weapon = Weapon.new()
	weapon.name = "Weapon"
	add_child(weapon)
	weapon.setup(self, weapon_data if weapon_data else preload("res://weapons/bubble_pistol.tres"))
	kit = AbilityKit.new()
	kit.name = "AbilityKit"
	add_child(kit)
	kit.setup(self, character)
	_apply_team_color()
	_apply_character_look()
	if Perception.current:
		Perception.current.register(self)


# --- Equipo ---

## Equipa un escudo: `points` de vida extra y `reduction` (0..1) de daño mientras dure.
func set_armor(index: int, points: float, reduction: float) -> void:
	armor_index = index
	shield = points
	shield_reduction = reduction
	health_changed.emit(health, shield)


func clear_armor() -> void:
	armor_index = -1
	shield = 0.0
	shield_reduction = 0.0


## Cambia el arma (tienda o pérdida del arma al morir). El cargador empieza lleno.
func equip(data: WeaponData) -> void:
	weapon_data = data
	weapon.setup(self, data)


func eye_position() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT


## Dirección del frente en el suelo.
func facing() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


# --- Estados alterados ---

func apply_slow(mult: float, seconds: float) -> void:
	_slow_mult = minf(_slow_mult, mult) if _slow_time > 0.0 else mult
	_slow_time = maxf(_slow_time, seconds)


func apply_spread(mult: float, seconds: float) -> void:
	_spread_mult = maxf(_spread_mult, mult) if _spread_time > 0.0 else mult
	_spread_time = maxf(_spread_time, seconds)


func apply_blind(seconds: float) -> void:
	_blind_time = maxf(_blind_time, seconds)


## Aturdido: no se mueve ni dispara.
func apply_stun(seconds: float) -> void:
	_stun_time = maxf(_stun_time, seconds)


## Inmovilizado: no se mueve, pero puede disparar.
func apply_root(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)


func apply_noisy(seconds: float) -> void:
	_noisy_time = maxf(_noisy_time, seconds)


func is_blinded() -> bool:
	return _blind_time > 0.0


func blind_time_left() -> float:
	return _blind_time


func spread_multiplier() -> float:
	return _spread_mult if _spread_time > 0.0 else 1.0


## Puede disparar y usar habilidades (vivo, sin aturdir y sin movimiento especial).
func can_act() -> bool:
	return is_alive and _stun_time <= 0.0 and _motion == Motion.NONE


func is_burrowing() -> bool:
	return _motion == Motion.BURROW


func is_in_motion() -> bool:
	return _motion != Motion.NONE


# --- Movimientos especiales (los lanzan las habilidades) ---

## Impulso en línea recta, chocando con las paredes.
func start_dash(direction: Vector3, distance: float, seconds: float) -> void:
	_begin_motion(Motion.DASH, global_position, global_position + direction * distance, seconds, Callable())


## Viaje bajo tierra: desaparece y sale en `to`.
func start_burrow(to: Vector3, seconds: float) -> void:
	_begin_motion(Motion.BURROW, global_position, to, seconds, Callable())
	_visual.visible = false


## Salto en arco por encima de las coberturas; `on_land` se llama al caer.
func start_leap(to: Vector3, seconds: float, on_land: Callable) -> void:
	_begin_motion(Motion.LEAP, global_position, to, seconds, on_land)
	collision_mask = 0


func _begin_motion(kind: Motion, from: Vector3, to: Vector3, seconds: float, on_end: Callable) -> void:
	_motion = kind
	_motion_from = from
	_motion_to = Vector3(to.x, from.y, to.z)
	_motion_duration = maxf(seconds, 0.01)
	_motion_time = 0.0
	_motion_on_end = on_end
	is_interacting = false


func _update_motion(delta: float) -> void:
	_motion_time += delta
	var t := clampf(_motion_time / _motion_duration, 0.0, 1.0)
	match _motion:
		Motion.DASH:
			velocity = (_motion_to - _motion_from) / _motion_duration
			velocity.y = 0.0
			move_and_slide()
		Motion.BURROW:
			if t >= 1.0:
				global_position = _motion_to
		Motion.LEAP:
			var p := _motion_from.lerp(_motion_to, t)
			global_position = p
			_visual.position.y = sin(t * PI) * LEAP_HEIGHT
	if t >= 1.0:
		_end_motion()


func _end_motion() -> void:
	var on_end := _motion_on_end
	_motion = Motion.NONE
	_motion_on_end = Callable()
	velocity = Vector3.ZERO
	collision_mask = Layers.WORLD | Layers.PAWTNER
	_visual.position.y = 0.0
	_refresh_visual()
	if on_end.is_valid():
		on_end.call()


# --- Bucle ---

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_tick_statuses(delta)
	if _protection_left > 0.0:
		_protection_left -= delta
		# Parpadeo mientras dura la protección.
		_visual.visible = _revealed and (_protection_left <= 0.0 or fmod(_protection_left, 0.2) < 0.12)

	if _motion != Motion.NONE:
		_update_motion(delta)
		wants_ability = ""
		return

	if wants_ability != "":
		kit.cast(wants_ability, ability_target if has_ability_target else aim_point)
		wants_ability = ""
		has_ability_target = false
		if _motion != Motion.NONE:
			return

	# La inclinación del joystick solo decide caminar o correr (lo hace el controlador).
	var dir := Vector3(move_input.x, 0.0, move_input.y)
	var can_move := not frozen and _stun_time <= 0.0 and _root_time <= 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 and can_move else Vector3.ZERO
	var walking := wants_walk
	is_aiming_fine = wants_aim_fine

	var speed := walk_speed if walking else run_speed
	if is_aiming_fine:
		speed *= aim_fine_speed_mult
	if carrying_seed:
		speed *= seed_speed_mult
	if _slow_time > 0.0:
		speed *= _slow_mult

	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	if _stun_time <= 0.0:
		_face_aim(delta)

	if dir == Vector3.ZERO:
		move_state = MoveState.STILL
	elif walking:
		move_state = MoveState.WALK
	else:
		move_state = MoveState.RUN
	_emit_footsteps(delta)


func _tick_statuses(delta: float) -> void:
	_slow_time = maxf(_slow_time - delta, 0.0)
	_spread_time = maxf(_spread_time - delta, 0.0)
	_blind_time = maxf(_blind_time - delta, 0.0)
	_stun_time = maxf(_stun_time - delta, 0.0)
	_root_time = maxf(_root_time - delta, 0.0)
	_noisy_time = maxf(_noisy_time - delta, 0.0)


func take_damage(amount: float, source: Pawtner) -> void:
	if not is_alive or _protection_left > 0.0:
		return
	var damage := amount
	if shield > 0.0:
		damage *= 1.0 - shield_reduction
	var absorbed := minf(shield, damage)
	shield -= absorbed
	health -= damage - absorbed
	if shield <= 0.0:
		# El escudo se rompió: deja de reducir daño.
		clear_armor()
	health_changed.emit(health, shield)
	if health <= 0.0:
		_die(source)


func heal(amount: float) -> void:
	if not is_alive:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, shield)


## Reaparece con vida completa. `protect` da unos segundos de invulnerabilidad.
func respawn_at(pos: Vector3, protect := true) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = max_health
	shield = start_shield
	is_alive = true
	collision_layer = Layers.PAWTNER
	collision_mask = Layers.WORLD | Layers.PAWTNER
	_collision.set_deferred("disabled", false)
	weapon.refill()
	_protection_left = RESPAWN_PROTECTION if protect else 0.0
	carrying_seed = false
	is_interacting = false
	interaction_progress = 0.0
	_clear_statuses()
	_refresh_visual()
	respawned.emit()


## Vuelve a la vida con `hp` de vida y sin escudo, donde está su cuerpo.
func revive(hp: float) -> void:
	health = hp
	shield = 0.0
	is_alive = true
	velocity = Vector3.ZERO
	collision_layer = Layers.PAWTNER
	_collision.set_deferred("disabled", false)
	_clear_statuses()
	_refresh_visual()
	health_changed.emit(health, shield)
	revived.emit()


## Lo llama Perception: false si el jugador local no ve a este Pawtner.
func is_revealed() -> bool:
	return _revealed


func set_revealed(value: bool) -> void:
	if value != _revealed:
		_revealed = value
		_refresh_visual()


func _clear_statuses() -> void:
	_slow_time = 0.0
	_spread_time = 0.0
	_blind_time = 0.0
	_stun_time = 0.0
	_root_time = 0.0
	_noisy_time = 0.0
	if _motion != Motion.NONE:
		_motion = Motion.NONE
		_motion_on_end = Callable()
		collision_mask = Layers.WORLD | Layers.PAWTNER
		_visual.position.y = 0.0


func _die(killer: Pawtner) -> void:
	is_alive = false
	health = 0.0
	death_position = global_position
	velocity = Vector3.ZERO
	move_state = MoveState.STILL
	is_interacting = false
	_clear_statuses()
	collision_layer = 0
	_collision.set_deferred("disabled", true)
	_refresh_visual()
	died.emit(self, killer)


func _refresh_visual() -> void:
	_visual.visible = is_alive and _revealed and _motion != Motion.BURROW


func _face_aim(delta: float) -> void:
	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length_squared() < 0.01:
		return
	# El frente del personaje es -Z.
	var target_yaw := atan2(-to_aim.x, -to_aim.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_sharpness * delta))


func _emit_footsteps(delta: float) -> void:
	var loud := move_state == MoveState.RUN or (move_state == MoveState.WALK and _noisy_time > 0.0)
	if not loud:
		_footstep_timer = 0.0
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		_footstep_timer = FOOTSTEP_INTERVAL
		if Perception.current:
			Perception.current.emit_noise(self, global_position, FOOTSTEP_NOISE_RADIUS)


func _apply_team_color() -> void:
	var ring := $Visual/Ring as MeshInstance3D
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TEAM_COLORS[team]
	ring.material_override = mat


func _apply_character_look() -> void:
	if character == null:
		return
	var fur := StandardMaterial3D.new()
	fur.albedo_color = character.body_color
	($Visual/Body as MeshInstance3D).material_override = fur
	($Visual/Head as MeshInstance3D).material_override = fur
