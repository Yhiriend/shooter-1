class_name Weapon
extends Node3D
## Arma equipada por un Pawtner. Lee `wants_shoot` del dueño y dispara proyectiles
## dentro del cono de precisión. Ver docs/GDD.md, «Precisión».

signal fired
signal ammo_changed(ammo: int, magazine: int)
signal reload_started
signal reload_finished

const MUZZLE_HEIGHT := 0.8
const MUZZLE_FORWARD := 0.55

var data: WeaponData
var ammo := 0
var bloom_deg := 0.0
var is_reloading := false

var _owner_pawtner: Pawtner
var _cooldown := 0.0
var _reload_left := 0.0
var _since_last_shot := 99.0


func setup(owner_pawtner: Pawtner, weapon_data: WeaponData) -> void:
	_owner_pawtner = owner_pawtner
	data = weapon_data
	refill()


func refill() -> void:
	ammo = data.magazine
	is_reloading = false
	bloom_deg = 0.0
	_cooldown = 0.0
	_since_last_shot = 99.0
	ammo_changed.emit(ammo, data.magazine)


## Medio ángulo actual del cono, en grados.
func current_half_spread_deg() -> float:
	var mult := 1.0
	match _owner_pawtner.move_state:
		Pawtner.MoveState.WALK:
			mult = data.walk_spread_mult
		Pawtner.MoveState.RUN:
			mult = data.run_spread_mult
	if _owner_pawtner.is_aiming_fine:
		mult *= data.aim_fine_spread_mult
	return data.base_spread_deg * mult + bloom_deg


## El próximo disparo será un tiro certero (+daño).
func is_precise_shot_ready() -> bool:
	return data.first_shot_bonus > 0.0 \
		and _owner_pawtner.move_state == Pawtner.MoveState.STILL \
		and _since_last_shot >= data.first_shot_recovery_time


func start_reload() -> void:
	if is_reloading or ammo == data.magazine:
		return
	is_reloading = true
	_reload_left = data.reload_time
	reload_started.emit()


func _physics_process(delta: float) -> void:
	if data == null or _owner_pawtner == null:
		return
	_since_last_shot += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	bloom_deg = maxf(bloom_deg - data.bloom_recovery_deg_per_s * delta, 0.0)

	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			is_reloading = false
			ammo = data.magazine
			ammo_changed.emit(ammo, data.magazine)
			reload_finished.emit()
		return

	var o := _owner_pawtner
	if not o.is_alive or not o.wants_shoot or o.frozen or o.is_interacting or _cooldown > 0.0:
		return
	if ammo <= 0:
		start_reload()
		return
	_fire()


func _fire() -> void:
	var precise := is_precise_shot_ready()
	var half_spread := deg_to_rad(current_half_spread_deg())
	var forward := -_owner_pawtner.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var muzzle := _owner_pawtner.global_position + Vector3.UP * MUZZLE_HEIGHT + forward * MUZZLE_FORWARD

	var damage := data.damage * (1.0 + data.first_shot_bonus if precise else 1.0)
	# Sin fuego amigo: los proyectiles atraviesan a los aliados.
	var exclude: Array = [_owner_pawtner.get_rid()]
	if Perception.current:
		exclude = Perception.current.team_rids(_owner_pawtner.team)
	for i in data.pellets:
		# Suma de dos uniformes: los disparos se concentran en el centro del cono.
		var angle := (randf() + randf() - 1.0) * half_spread
		var dir := forward.rotated(Vector3.UP, angle)
		var p := Projectile.new()
		p.setup(_owner_pawtner, muzzle, dir * data.projectile_speed, damage, data.max_range,
			data.projectile_color, data.projectile_radius, exclude)
		get_tree().current_scene.add_child(p)

	ammo -= 1
	_cooldown = data.fire_interval
	_since_last_shot = 0.0
	bloom_deg = minf(bloom_deg + data.bloom_per_shot_deg, data.max_bloom_deg)
	ammo_changed.emit(ammo, data.magazine)
	fired.emit()
	if Perception.current:
		Perception.current.emit_noise(_owner_pawtner, _owner_pawtner.global_position, data.noise_radius)
	if ammo <= 0:
		start_reload()
