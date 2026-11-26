class_name Perception
extends Node3D
## Visión y oído de cada equipo, y niebla de guerra del jugador local.
## Jugadores y bots usan las mismas reglas: nadie ve a través de coberturas altas.
## Ver docs/GDD.md, «Controles, cámara y visión» y «Bots (IA)».

## Un enemigo (`source`) hizo ruido en `position` y lo oyó el equipo `team`.
signal noise_heard(team: int, position: Vector3, source: Pawtner)

static var current: Perception

@export var vision_radius := 12.0
@export var update_hz := 10.0
## Velocidad con la que la niebla se abre y se cierra (por segundo).
@export var fog_fade_speed := 6.0
@export var fog_color := Color(0.1, 0.08, 0.2, 0.6)

var local_team := 0
var pawtners: Array[Pawtner] = []

var _map: HuertoLunar
var _visible_by_team: Array[Dictionary] = [{}, {}]  # equipo -> {Pawtner: true}
## Revelados a la fuerza (polen, habilidades): equipo -> {Pawtner: segundos restantes}.
var _forced_reveal: Array[Dictionary] = [{}, {}]
## Nubes que bloquean la visión: [{"node": Node, "center": Vector3, "radius": float}].
var _smokes: Array[Dictionary] = []
## Vigías (pajarito de Capi): [{"node": Node3D, "team": int, "radius": float, "dir": Vector3, "half_angle": float}].
var _watchers: Array[Dictionary] = []
## Radio de visión estando cegado.
const BLIND_RADIUS := 1.0
var _update_timer := 0.0

# Niebla: un valor por celda del mapa (1 = visible, 0 = en niebla).
var _fog_target := PackedFloat32Array()
var _fog_shown := PackedFloat32Array()
var _fog_bytes := PackedByteArray()
var _fog_image: Image
var _fog_texture: ImageTexture

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec4 fog_color : source_color;
void fragment() {
	float v = texture(fog_tex, UV).r;
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * (1.0 - v);
}
"""


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func setup(map: HuertoLunar, player_team: int) -> void:
	_map = map
	local_team = player_team
	var cells := _map.cols * _map.rows
	_fog_target.resize(cells)
	_fog_shown.resize(cells)
	_fog_bytes.resize(cells)
	_fog_target.fill(0.0)
	_fog_shown.fill(0.0)
	_fog_image = Image.create_empty(_map.cols, _map.rows, false, Image.FORMAT_L8)
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_create_fog_overlay()


func register(p: Pawtner) -> void:
	if not pawtners.has(p):
		pawtners.append(p)
		p.tree_exiting.connect(func() -> void: pawtners.erase(p))


func team_rids(team: int) -> Array[RID]:
	var rids: Array[RID] = []
	for p in pawtners:
		if p.team == team:
			rids.append(p.get_rid())
	return rids


## ¿El equipo `team` ve ahora mismo a `target`?
func can_team_see(team: int, target: Pawtner) -> bool:
	if target.team == team:
		return true
	return _visible_by_team[team].has(target)


## Enemigos vivos que el equipo `team` ve ahora mismo.
func visible_enemies(team: int) -> Array[Pawtner]:
	var result: Array[Pawtner] = []
	for p: Pawtner in _visible_by_team[team]:
		if is_instance_valid(p) and p.is_alive:
			result.append(p)
	return result


## Revela `target` al equipo `team` durante `seconds`, aunque no esté en su línea de vista.
func reveal_to_team(team: int, target: Pawtner, seconds: float) -> void:
	var forced := _forced_reveal[team]
	forced[target] = maxf(forced.get(target, 0.0), seconds)


func add_smoke(node: Node, center: Vector3, radius: float) -> void:
	_smokes.append({"node": node, "center": center, "radius": radius})


func remove_smoke(node: Node) -> void:
	_smokes = _smokes.filter(func(s: Dictionary) -> bool: return s["node"] != node)


func add_watcher(node: Node3D, team: int, radius: float, dir: Vector3, half_angle: float) -> void:
	_watchers.append({"node": node, "team": team, "radius": radius, "dir": dir, "half_angle": half_angle})


func remove_watcher(node: Node3D) -> void:
	_watchers = _watchers.filter(func(w: Dictionary) -> bool: return w["node"] != node)


## Ruido sin dueño visible (zanahoria señuelo): lo oyen los enemigos de `owner_team` en radio.
func emit_fake_noise(owner_team: int, pos: Vector3, radius: float) -> void:
	for team in 2:
		if team == owner_team or not _team_has_member_within(team, pos, radius):
			continue
		noise_heard.emit(team, pos, null)
		if team == local_team:
			_spawn_noise_ring(pos)


## ¿Hay línea de vista entre dos puntos? (coberturas altas, muros y nubes la cortan)
func line_clear(from: Vector3, to: Vector3) -> bool:
	return _line_clear(from, to)


func is_point_visible_to_local(point: Vector3) -> bool:
	if _map == null:
		return true
	var cell := _map.world_to_cell(point)
	if not _map.is_cell_inside(cell):
		return false
	return _fog_target[cell.y * _map.cols + cell.x] > 0.5


## Un Pawtner hace ruido (pasos o disparos). Lo oyen los enemigos en radio que no lo ven.
func emit_noise(source: Pawtner, pos: Vector3, radius: float) -> void:
	for team in 2:
		if team == source.team or can_team_see(team, source):
			continue
		if not _team_has_member_within(team, pos, radius):
			continue
		noise_heard.emit(team, pos, source)
		if team == local_team:
			_spawn_noise_ring(pos)


func _physics_process(delta: float) -> void:
	if _map == null:
		return
	for forced in _forced_reveal:
		for p: Pawtner in forced.keys():
			forced[p] -= delta
			if forced[p] <= 0.0:
				forced.erase(p)
	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = 1.0 / update_hz
		_update_team_vision()
		_update_fog_target()
		for p in pawtners:
			p.set_revealed(p.team == local_team or _visible_by_team[local_team].has(p))


func _process(delta: float) -> void:
	if _map == null:
		return
	var step := fog_fade_speed * delta
	for i in _fog_shown.size():
		_fog_shown[i] = move_toward(_fog_shown[i], _fog_target[i], step)
		_fog_bytes[i] = int(_fog_shown[i] * 255.0)
	_fog_image.set_data(_map.cols, _map.rows, false, Image.FORMAT_L8, _fog_bytes)
	_fog_texture.update(_fog_image)


func _member_vision_radius(member: Pawtner) -> float:
	return BLIND_RADIUS if member.is_blinded() else vision_radius


func _update_team_vision() -> void:
	for team in 2:
		var seen := {}
		for enemy in pawtners:
			if enemy.team == team or not enemy.is_alive or enemy.is_burrowing():
				continue
			for member in pawtners:
				if member.team != team or not member.is_alive:
					continue
				if member.global_position.distance_to(enemy.global_position) > _member_vision_radius(member):
					continue
				if _line_clear(member.eye_position(), enemy.eye_position()):
					seen[enemy] = true
					break
			if not seen.has(enemy) and _watchers_see(team, enemy.eye_position()):
				seen[enemy] = true
		for p: Pawtner in _forced_reveal[team]:
			if p.is_alive and p.team != team:
				seen[p] = true
		_visible_by_team[team] = seen


func _update_fog_target() -> void:
	_fog_target.fill(0.0)
	for member in pawtners:
		if member.team == local_team and member.is_alive:
			_reveal_fog_from(member.eye_position(), _member_vision_radius(member), Vector3.ZERO, PI)
	for w in _watchers:
		if w["team"] == local_team and is_instance_valid(w["node"]):
			var node: Node3D = w["node"]
			_reveal_fog_from(node.global_position, w["radius"], w["dir"], w["half_angle"])


## Abre la niebla desde `eye` hasta `radius`, en un cono de medio ángulo `half_angle` hacia `dir`.
func _reveal_fog_from(eye: Vector3, radius: float, dir: Vector3, half_angle: float) -> void:
	var r := int(ceil(radius))
	var center := _map.world_to_cell(eye)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			if not _map.is_cell_inside(cell):
				continue
			var idx := cell.y * _map.cols + cell.x
			if _fog_target[idx] > 0.5:
				continue
			var point := _map.cell_to_world(cell.x, cell.y) + Vector3.UP * 0.5
			if eye.distance_to(point) > radius or not _in_cone(eye, point, dir, half_angle):
				continue
			# Las celdas de cobertura alta se marcan visibles: el rayo chocaría con ellas mismas.
			if _map.is_cell_vision_blocker(cell) or _line_clear(eye, point):
				_fog_target[idx] = 1.0


func _in_cone(from: Vector3, to: Vector3, dir: Vector3, half_angle: float) -> bool:
	if half_angle >= PI or dir == Vector3.ZERO:
		return true
	var v := to - from
	v.y = 0.0
	return v.length_squared() < 0.01 or v.normalized().angle_to(dir) <= half_angle


func _watchers_see(team: int, point: Vector3) -> bool:
	for w in _watchers:
		if w["team"] != team or not is_instance_valid(w["node"]):
			continue
		var node: Node3D = w["node"]
		var from := node.global_position
		if from.distance_to(point) <= w["radius"] and _in_cone(from, point, w["dir"], w["half_angle"]) \
				and _line_clear(from, point):
			return true
	return false


func _line_clear(from: Vector3, to: Vector3) -> bool:
	if _blocked_by_smoke(from, to):
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.VISION_BLOCKER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Una nube corta la línea si el segmento (en el suelo) pasa por su círculo.
## Dentro de una nube solo se ve lo que está a menos de 1 m.
func _blocked_by_smoke(from: Vector3, to: Vector3) -> bool:
	if _smokes.is_empty():
		return false
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if a.distance_to(b) <= BLIND_RADIUS:
		return false
	for s in _smokes:
		var c3: Vector3 = s["center"]
		var c := Vector2(c3.x, c3.z)
		var r: float = s["radius"]
		var closest := Geometry2D.get_closest_point_to_segment(c, a, b)
		if closest.distance_to(c) < r:
			return true
	return false


func _team_has_member_within(team: int, pos: Vector3, radius: float) -> bool:
	for p in pawtners:
		if p.team == team and p.is_alive and p.global_position.distance_to(pos) <= radius:
			return true
	return false


func _create_fog_overlay() -> void:
	var shader := Shader.new()
	shader.code = FOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fog_tex", _fog_texture)
	mat.set_shader_parameter("fog_color", fog_color)
	var plane := PlaneMesh.new()
	plane.size = Vector2(_map.cols * HuertoLunar.CELL, _map.rows * HuertoLunar.CELL)
	var mi := MeshInstance3D.new()
	mi.name = "FogOverlay"
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.04
	add_child(mi)


func _spawn_noise_ring(pos: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.8)
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(pos.x, 0.08, pos.z)
	ring.scale = Vector3.ONE * 0.3
	add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.4, 0.8)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.chain().tween_callback(ring.queue_free)
