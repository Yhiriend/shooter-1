class_name ThrownObject
extends Node3D
## Objeto lanzado: el ovillo de Mochi (rebota y revela al detenerse) o su cascabel
## (vuela hasta el punto y estalla dejando casi sin visión a quien ve el estallido).

enum Kind { YARN, BELL }

const YARN_SPEED := 14.0
const YARN_MAX_BOUNCES := 3
const YARN_LIFETIME := 1.4
const BELL_FLIGHT_TIME := 0.5
## Destello del estallido del cascabel.
const FLASH_COLOR := Color(1.0, 1.0, 0.94)
const FLASH_TIME := 0.45
const FLASH_SPHERE_RADIUS := 1.8
const FLASH_LIGHT_ENERGY := 3.0

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
		if normal.length_squared() < 0.0001:
			# Golpe por arriba (tapa de una cobertura): rebota hacia atrás.
			normal = -Vector3(_velocity.x, 0.0, _velocity.z)
			if normal.length_squared() < 0.0001:
				normal = Vector3.BACK
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
				for p in perception.pawtners:
					# Solo ciega a enemigos (decisión de diseño: más legible en móvil), dentro del
					# área y que vean el estallido con su visión real (sin importar hacia dónde miren).
					if p.is_alive and p.team != team and _flat_distance(p.global_position) <= radius \
							and perception.can_pawtner_see_point(p, global_position):
						p.apply_blind(duration)
	if kind == Kind.BELL:
		_spawn_flash()
	else:
		AbilityEffects.spawn_pulse(global_position, radius, Color(1.0, 0.6, 0.75))
	Sfx.at("bell" if kind == Kind.BELL else "chime", global_position)
	queue_free()


func _flat_distance(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()


## Estallido del cascabel: una esfera blanca que se expande y se desvanece, una luz que
## ilumina el entorno y un anillo blanco en el suelo hasta el borde del área.
func _spawn_flash() -> void:
	var map := HuertoLunar.current
	if map == null:
		return
	var flash := Node3D.new()
	map.add_child(flash)
	flash.global_position = global_position

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = FLASH_COLOR
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.15
	flash.add_child(ball)

	var light := OmniLight3D.new()
	light.light_color = FLASH_COLOR
	light.light_energy = FLASH_LIGHT_ENERGY
	light.omni_range = radius * 0.7
	light.position.y = 0.6
	flash.add_child(light)

	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * FLASH_SPHERE_RADIUS, FLASH_TIME) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, FLASH_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, FLASH_TIME).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(flash.queue_free)
	AbilityEffects.spawn_pulse(global_position, radius, Color.WHITE)
