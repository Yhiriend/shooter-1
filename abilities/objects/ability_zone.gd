class_name AbilityZone
extends Node3D
## Zona circular temporal creada por una habilidad.
## SMOKE bloquea la visión; HONEY frena y hace ruido; HEAL cura aliados; BIG_SMOKE bloquea y ciega.

enum Kind { SMOKE, HONEY, HEAL, BIG_SMOKE }

const TICK := 0.2

var kind := Kind.SMOKE
var team := 0
var radius := 3.0
var duration := 10.0
## HONEY: multiplicador de velocidad. HEAL: curación total máxima por aliado.
var amount := 0.0
## HEAL: vida por segundo.
var heal_per_second := 8.0

var _time_left := 0.0
var _tick_left := 0.0
var _healed := {}  # Pawtner -> vida ya curada
var _material: StandardMaterial3D


func setup(zone_kind: Kind, owner_team: int, zone_radius: float, seconds: float, value := 0.0) -> void:
	kind = zone_kind
	team = owner_team
	radius = zone_radius
	duration = seconds
	amount = value


func _ready() -> void:
	_time_left = duration
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		Kind.SMOKE, Kind.BIG_SMOKE:
			var sphere := SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 1.2
			mi.mesh = sphere
			mi.position.y = radius * 0.3
			_material.albedo_color = Color(0.85, 0.95, 0.85, 0.9) if kind == Kind.SMOKE else Color(0.82, 0.78, 0.95, 0.9)
			if Perception.current:
				# La Siesta del bosque solo tapa a los rivales: el equipo de Tofu ve a través.
				var own := team if kind == Kind.BIG_SMOKE else -1
				Perception.current.add_smoke(self, global_position, radius, own)
				if own >= 0 and own == Perception.current.local_team:
					_material.albedo_color.a = 0.35
		Kind.HONEY, Kind.HEAL:
			var disc := CylinderMesh.new()
			disc.top_radius = radius
			disc.bottom_radius = radius
			disc.height = 0.04
			mi.mesh = disc
			mi.position.y = 0.05
			_material.albedo_color = Color(1.0, 0.75, 0.25, 0.55) if kind == Kind.HONEY else Color(0.55, 0.85, 1.0, 0.55)
	mi.material_override = _material
	add_child(mi)


func _exit_tree() -> void:
	if Perception.current and kind in [Kind.SMOKE, Kind.BIG_SMOKE]:
		Perception.current.remove_smoke(self)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	# Se desvanece en el último segundo.
	if _time_left < 1.0:
		_material.albedo_color.a = minf(_material.albedo_color.a, _time_left * 0.9)
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	if Perception.current == null or kind == Kind.SMOKE:
		return
	for p in Perception.current.pawtners:
		if not p.is_alive or _flat_distance(p.global_position) > radius:
			continue
		match kind:
			Kind.HONEY:
				if p.team != team:
					p.apply_slow(amount, TICK + 0.05)
					p.apply_noisy(TICK + 0.05)
			Kind.BIG_SMOKE:
				if p.team != team:
					p.apply_blind(TICK + 0.05)
			Kind.HEAL:
				if p.team == team:
					var done: float = _healed.get(p, 0.0)
					var step := minf(heal_per_second * TICK, amount - done)
					if step > 0.0 and p.health < p.max_health:
						p.heal(step)
						_healed[p] = done + step


func _flat_distance(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
