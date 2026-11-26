class_name PlacedDevice
extends StaticBody3D
## Objeto colocado por una habilidad: trampa (Capi C), señuelo (Pip C) o vigía (Capi E).
## Los dispositivos con vida caen de un impacto.

enum Kind { TRAP, DECOY, WATCHER }

const TICK := 0.1
const DECOY_STEP_INTERVAL := 0.35
## Los enemigos ven la trampa solo a esta distancia.
const TRAP_VISIBLE_RADIUS := 3.0
const TRAP_REVEAL_TIME := 3.0
const WATCHER_HALF_ANGLE := 0.785398  # 45°

var kind := Kind.TRAP
var owner_pawtner: Pawtner
var team := 0
var radius := 1.0
var duration := 0.0
var amount := 0.0
## Vigía: hacia dónde mira (si no, el frente de quien lo colocó).
var look_dir := Vector3.ZERO

var _time_left := 0.0
var _tick_left := 0.0
var _step_left := 0.0
var _mesh: MeshInstance3D


func setup(device_kind: Kind, from: Pawtner, device_radius: float, seconds: float, value := 0.0) -> void:
	kind = device_kind
	owner_pawtner = from
	team = from.team
	radius = device_radius
	duration = seconds
	amount = value


func _ready() -> void:
	_time_left = duration
	collision_layer = Layers.WORLD if kind == Kind.WATCHER else 0
	collision_mask = 0
	var mat := StandardMaterial3D.new()
	_mesh = MeshInstance3D.new()
	match kind:
		Kind.TRAP:
			var s := SphereMesh.new()
			s.radius = 0.22
			s.height = 0.44
			_mesh.mesh = s
			_mesh.position.y = 0.22
			mat.albedo_color = Color(1.0, 0.6, 0.15)
		Kind.DECOY:
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.16
			c.height = 0.6
			_mesh.mesh = c
			_mesh.position.y = 0.3
			_mesh.rotation_degrees.x = 180.0
			mat.albedo_color = Color(1.0, 0.55, 0.2)
		Kind.WATCHER:
			var s := SphereMesh.new()
			s.radius = 0.25
			s.height = 0.5
			_mesh.mesh = s
			_mesh.position.y = 1.0
			mat.albedo_color = Color(0.55, 0.8, 1.0)
			var shape := SphereShape3D.new()
			shape.radius = 0.3
			var col := CollisionShape3D.new()
			col.shape = shape
			col.position.y = 1.0
			add_child(col)
			if Perception.current:
				var dir := look_dir if look_dir != Vector3.ZERO else owner_pawtner.facing()
				Perception.current.add_watcher(self, team, radius, dir, WATCHER_HALF_ANGLE)
	_mesh.material_override = mat
	add_child(_mesh)


func _exit_tree() -> void:
	if kind == Kind.WATCHER and Perception.current:
		Perception.current.remove_watcher(self)


## Los proyectiles enemigos lo destruyen de un impacto (vigía).
func take_damage(_amount: float, source: Pawtner) -> void:
	if source == null or source.team != team:
		queue_free()


func _physics_process(delta: float) -> void:
	if duration > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			queue_free()
			return
	_update_visibility()
	match kind:
		Kind.TRAP:
			_tick_left -= delta
			if _tick_left <= 0.0:
				_tick_left = TICK
				_check_trap()
		Kind.DECOY:
			_step_left -= delta
			if _step_left <= 0.0 and Perception.current:
				_step_left = DECOY_STEP_INTERVAL
				Perception.current.emit_fake_noise(team, global_position, radius)


func _check_trap() -> void:
	if Perception.current == null:
		return
	for p in Perception.current.pawtners:
		if p.is_alive and p.team != team and _flat_distance(p.global_position) <= radius:
			p.apply_root(amount)
			Sfx.at("trap", global_position, 2.0)
			Perception.current.reveal_to_team(team, p, TRAP_REVEAL_TIME)
			queue_free()
			return


func _update_visibility() -> void:
	var perception := Perception.current
	if perception == null:
		return
	if team == perception.local_team:
		visible = true
	elif kind == Kind.TRAP:
		# Casi invisible: solo se ve muy de cerca.
		visible = false
		for p in perception.pawtners:
			if p.team == perception.local_team and p.is_alive \
					and _flat_distance(p.global_position) <= TRAP_VISIBLE_RADIUS:
				visible = true
				break
	else:
		visible = perception.is_point_visible_to_local(global_position)


func _flat_distance(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
