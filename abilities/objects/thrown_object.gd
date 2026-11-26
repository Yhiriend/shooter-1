class_name ThrownObject
extends Node3D
## Objeto lanzado: el ovillo de Mochi (rebota y revela al detenerse) o su cascabel
## (vuela hasta el punto y estalla dejando casi sin visión a quien lo mira).

enum Kind { YARN, BELL }

const YARN_SPEED := 14.0
const YARN_MAX_BOUNCES := 3
const YARN_LIFETIME := 1.4
const BELL_FLIGHT_TIME := 0.5
## Medio ángulo de «estar mirando» al cascabel cuando estalla.
const BELL_LOOK_HALF_ANGLE := 1.047198  # 60°

var kind := Kind.YARN
var owner_pawtner: Pawtner
var team := 0
var radius := 5.0
var duration := 2.0

var _velocity := Vector3.ZERO
var _target := Vector3.ZERO
var _time := 0.0
var _bounces := 0
var _done := false


func setup(object_kind: Kind, from: Pawtner, target: Vector3, effect_radius: float, effect_duration: float) -> void:
	kind = object_kind
	owner_pawtner = from
	team = from.team
	radius = effect_radius
	duration = effect_duration
	position = from.global_position + Vector3.UP * 0.6
	_target = Vector3(target.x, 0.6, target.z)
	var dir := _target - position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else from.facing()
	_velocity = dir * (YARN_SPEED if kind == Kind.YARN else position.distance_to(_target) / BELL_FLIGHT_TIME)


func _ready() -> void:
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.75) if kind == Kind.YARN else Color(1.0, 0.85, 0.3)
	s.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = s
	add_child(mi)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var step := _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		normal.y = 0.0
		global_position = (hit["position"] as Vector3) + normal.normalized() * 0.2
		if kind == Kind.BELL:
			_finish()
			return
		_bounces += 1
		_velocity = _velocity.bounce(normal.normalized()) * 0.8
		if _bounces > YARN_MAX_BOUNCES:
			_finish()
		return
	global_position += step
	if Perception.current:
		visible = team == Perception.current.local_team or Perception.current.is_point_visible_to_local(global_position)
	if kind == Kind.YARN and _time >= YARN_LIFETIME:
		_finish()
	elif kind == Kind.BELL and _time >= BELL_FLIGHT_TIME:
		_finish()


func _finish() -> void:
	_done = true
	var perception := Perception.current
	if perception:
		match kind:
			Kind.YARN:
				for p in perception.pawtners:
					if p.is_alive and p.team != team and p.global_position.distance_to(global_position) <= radius:
						perception.reveal_to_team(team, p, duration)
			Kind.BELL:
				var eye := global_position
				for p in perception.pawtners:
					# Solo ciega a enemigos (decisión de diseño: más legible en móvil).
					if not p.is_alive or p.team == team or p.global_position.distance_to(eye) > radius:
						continue
					if not perception.line_clear(p.eye_position(), eye):
						continue
					var to_bell := eye - p.global_position
					to_bell.y = 0.0
					# Ciega a quien lo está mirando.
					if to_bell.length() < 1.0 or p.facing().angle_to(to_bell.normalized()) <= BELL_LOOK_HALF_ANGLE:
						p.apply_blind(duration)
	AbilityEffects.spawn_pulse(global_position, radius, Color(1.0, 0.6, 0.75) if kind == Kind.YARN else Color(1, 1, 0.8))
	queue_free()
