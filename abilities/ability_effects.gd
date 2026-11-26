class_name AbilityEffects
extends RefCounted
## Lógica de cada habilidad. Los parámetros (alcance, radio, duración, cantidad) vienen
## del AbilityData; aquí se decide qué objetos se crean y a quién afectan.
## Ver docs/GDD.md, «Roles y roster MVP».

enum CastResult { OK, REFUND, FAILED }

const BURROW_STEP := 0.5
const LEAP_TIME := 0.8
const WALL_DISTANCE := 2.5
const CALM_SHIELD := 50.0
const CALM_SHIELD_REDUCTION := 0.30
## Grupo de todo lo que crean las habilidades: MatchManager lo limpia al empezar cada ronda.
const GROUP := "ability_objects"

## Vigía activo de cada Pawtner (Capi E), para recogerlo con la misma tecla.
static var _watchers := {}


## Punto objetivo limitado al alcance de la habilidad (0 = la posición propia).
static func clamp_target(p: Pawtner, aim: Vector3, cast_range: float) -> Vector3:
	if cast_range <= 0.0:
		return p.global_position
	var v := aim - p.global_position
	v.y = 0.0
	return p.global_position + v.limit_length(cast_range)


static func find_watcher(p: Pawtner) -> PlacedDevice:
	var w: Variant = _watchers.get(p)
	if w != null and is_instance_valid(w):
		return w as PlacedDevice
	_watchers.erase(p)
	return null


static func cast(p: Pawtner, a: AbilityData, target: Vector3) -> CastResult:
	var map := HuertoLunar.current
	if map == null:
		return CastResult.FAILED
	match a.effect:
		AbilityData.Effect.YARN_REVEAL:
			_throw(map, ThrownObject.Kind.YARN, p, target, a)
		AbilityData.Effect.BELL_FLASH:
			_throw(map, ThrownObject.Kind.BELL, p, target, a)
		AbilityData.Effect.DASH:
			var dir := Vector3(p.move_input.x, 0.0, p.move_input.y)
			dir = dir.normalized() if dir.length_squared() > 0.01 else p.facing()
			p.start_dash(dir, a.amount, a.duration)
		AbilityData.Effect.NIGHT_EYES:
			var runner := NightEyes.new()
			runner.setup(p.team, a.duration)
			runner.add_to_group(GROUP)
			map.add_child(runner)
		AbilityData.Effect.DECOY:
			_place(map, PlacedDevice.Kind.DECOY, p, map.nearest_free_point(target), a.radius, a.duration)
		AbilityData.Effect.GROUND_SLAM:
			for enemy in _enemies_near(p.team, p.global_position, a.radius):
				enemy.apply_slow(a.amount, a.duration)
				enemy.apply_spread(3.0, a.duration)
			spawn_pulse(p.global_position, a.radius, Color(0.75, 0.55, 0.35))
		AbilityData.Effect.BURROW:
			var dest := _burrow_destination(map, p, a.amount)
			if dest.distance_to(p.global_position) < 0.5:
				return CastResult.FAILED
			spawn_pulse(p.global_position, 0.8, Color(0.6, 0.45, 0.3))
			spawn_pulse(dest, 0.8, Color(0.6, 0.45, 0.3))
			p.start_burrow(dest, a.duration)
		AbilityData.Effect.BIG_LEAP:
			var landing := map.nearest_free_point(target)
			var team := p.team
			var r := a.radius
			var stun := a.duration
			p.start_leap(landing, LEAP_TIME, func() -> void:
				for enemy in _enemies_near(team, landing, r):
					enemy.apply_stun(stun)
				spawn_pulse(landing, r, Color(1.0, 0.9, 0.5)))
		AbilityData.Effect.BAMBOO_WALL:
			# Se levanta delante, perpendicular a la dirección elegida.
			var forward := _direction_to(p, target)
			var wall := BambooWall.new()
			wall.build(p.global_position + forward * WALL_DISTANCE, forward.cross(Vector3.UP).normalized(),
				a.amount, a.radius, a.duration)
			wall.add_to_group(GROUP)
			map.add_child(wall)
		AbilityData.Effect.HONEY_POOL:
			_zone(map, AbilityZone.Kind.HONEY, p.team, target, a.radius, a.duration, a.amount)
		AbilityData.Effect.SMOKE:
			_zone(map, AbilityZone.Kind.SMOKE, p.team, target, a.radius, a.duration)
		AbilityData.Effect.BIG_SMOKE:
			_zone(map, AbilityZone.Kind.BIG_SMOKE, p.team, target, a.radius, a.duration)
		AbilityData.Effect.ORANGE_TRAP:
			_place(map, PlacedDevice.Kind.TRAP, p, map.nearest_free_point(target), a.radius, 0.0, a.duration)
		AbilityData.Effect.HOT_SPRING:
			_zone(map, AbilityZone.Kind.HEAL, p.team, target, a.radius, a.duration, a.amount)
		AbilityData.Effect.WATCHER:
			var existing := find_watcher(p)
			if existing:
				existing.queue_free()
				_watchers.erase(p)
				return CastResult.REFUND
			var device := _place(map, PlacedDevice.Kind.WATCHER, p, map.nearest_free_point(target), a.radius, 0.0,
				0.0, _direction_to(p, target))
			_watchers[p] = device
		AbilityData.Effect.TOTAL_CALM:
			if MatchManager.current == null:
				return CastResult.FAILED
			MatchManager.current.total_calm(p, a.amount, CALM_SHIELD, CALM_SHIELD_REDUCTION)
	return CastResult.OK


## Anillo que se expande y se desvanece (feedback visual de una habilidad).
static func spawn_pulse(pos: Vector3, radius: float, color: Color) -> void:
	var map := HuertoLunar.current
	if map == null:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.9)
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(ring)
	ring.global_position = Vector3(pos.x, 0.1, pos.z)
	ring.scale = Vector3.ONE * maxf(radius * 0.2, 0.1)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * maxf(radius, 0.3), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)


static func _enemies_near(team: int, pos: Vector3, radius: float) -> Array[Pawtner]:
	var result: Array[Pawtner] = []
	if Perception.current == null:
		return result
	for p in Perception.current.pawtners:
		if p.is_alive and p.team != team and Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length() <= radius:
			result.append(p)
	return result


static func _throw(map: HuertoLunar, kind: ThrownObject.Kind, p: Pawtner, target: Vector3, a: AbilityData) -> void:
	var obj := ThrownObject.new()
	obj.setup(kind, p, target, a.radius, a.duration)
	obj.add_to_group(GROUP)
	map.add_child(obj)


## Dirección en el suelo desde el Pawtner hacia `target` (su frente si coinciden).
static func _direction_to(p: Pawtner, target: Vector3) -> Vector3:
	var v := target - p.global_position
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.04 else p.facing()


static func _place(map: HuertoLunar, kind: PlacedDevice.Kind, p: Pawtner, pos: Vector3, radius: float,
		seconds: float, value := 0.0, look_dir := Vector3.ZERO) -> PlacedDevice:
	var device := PlacedDevice.new()
	device.setup(kind, p, radius, seconds, value)
	device.look_dir = look_dir
	device.add_to_group(GROUP)
	device.position = Vector3(pos.x, 0.0, pos.z)
	map.add_child(device)
	return device


static func _zone(map: HuertoLunar, kind: AbilityZone.Kind, team: int, pos: Vector3, radius: float,
		seconds: float, value := 0.0) -> void:
	var zone := AbilityZone.new()
	zone.setup(kind, team, radius, seconds, value)
	zone.position = Vector3(pos.x, 0.0, pos.z)
	zone.add_to_group(GROUP)
	map.add_child(zone)


## Punto libre más lejano en la dirección de avance, hasta `distance` (pasa bajo coberturas).
static func _burrow_destination(map: HuertoLunar, p: Pawtner, distance: float) -> Vector3:
	var dir := Vector3(p.move_input.x, 0.0, p.move_input.y)
	dir = dir.normalized() if dir.length_squared() > 0.01 else p.facing()
	var d := distance
	while d >= BURROW_STEP:
		var candidate := p.global_position + dir * d
		if map.is_point_free(candidate):
			return candidate
		d -= BURROW_STEP
	return p.global_position


## Ojos nocturnos (Mochi X): mientras dura, revela a todo enemigo que corra.
class NightEyes extends Node:
	const TICK := 0.25
	var team := 0
	var time_left := 8.0
	var _tick := 0.0

	func setup(owner_team: int, seconds: float) -> void:
		team = owner_team
		time_left = seconds

	func _physics_process(delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0 or Perception.current == null:
			queue_free()
			return
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = TICK
		for p in Perception.current.pawtners:
			if p.is_alive and p.team != team and p.move_state == Pawtner.MoveState.RUN:
				Perception.current.reveal_to_team(team, p, TICK + 0.2)
