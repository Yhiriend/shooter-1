class_name MoonPlant
extends Node3D
## La planta de la Semilla Lunar: crece en 3 etapas (brote, tallo, flor) y florece a los 40 s.
## En la etapa de tallo suelta polen que revela defensores cercanos.
## Arrancar tarda 6 s (4 s entre dos); el progreso baja un 10 %/s tras 2 s sin tocarla.
## Ver docs/GDD.md, «Modo de juego: Semilla Lunar».

signal bloomed

const GROW_TIME := 40.0
const STAGES := 3
const STAGE_NAMES: Array[String] = ["brote", "tallo", "flor"]
const POLLEN_RADIUS := 4.0
const POLLEN_INTERVAL := 3.0
const POLLEN_REVEAL_TIME := 1.0
const UPROOT_TIME_ONE := 6.0
const UPROOT_TIME_TWO := 4.0
const UPROOT_DECAY_DELAY := 2.0
const UPROOT_DECAY_PER_S := 0.1

var site := ""
var attacker_team := 0
var elapsed := 0.0
## 0..1; al llegar a 1 la planta queda arrancada.
var uproot_progress := 0.0

var _since_uproot := 99.0
var _pollen_timer := 0.0
var _bloomed := false
var _stem: MeshInstance3D
var _bud: MeshInstance3D
var _pollen_ring: MeshInstance3D


func setup(plant_site: String, attackers: int) -> void:
	site = plant_site
	attacker_team = attackers


func stage() -> int:
	return mini(int(elapsed / (GROW_TIME / STAGES)), STAGES - 1)


func stage_name() -> String:
	return STAGE_NAMES[stage()]


func time_left() -> float:
	return maxf(GROW_TIME - elapsed, 0.0)


func _ready() -> void:
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.06
	stem_mesh.bottom_radius = 0.09
	stem_mesh.height = 1.0
	stem_mesh.material = _unshaded(Color(0.45, 0.8, 0.4))
	_stem = MeshInstance3D.new()
	_stem.mesh = stem_mesh
	add_child(_stem)

	var bud_mesh := SphereMesh.new()
	bud_mesh.radius = 0.25
	bud_mesh.height = 0.5
	bud_mesh.material = _unshaded(MoonSeed.COLOR)
	_bud = MeshInstance3D.new()
	_bud.mesh = bud_mesh
	add_child(_bud)

	var ring := TorusMesh.new()
	ring.inner_radius = POLLEN_RADIUS - 0.08
	ring.outer_radius = POLLEN_RADIUS
	ring.rings = 48
	ring.ring_segments = 4
	var ring_mat := _unshaded(Color(1.0, 0.95, 0.55, 0.0))
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material = ring_mat
	_pollen_ring = MeshInstance3D.new()
	_pollen_ring.mesh = ring
	_pollen_ring.position.y = 0.06
	add_child(_pollen_ring)
	_update_visual()


## Avanza el arrancado según cuántos defensores lo hacen a la vez este frame.
func tick_uproot(delta: float, uprooters: int) -> void:
	if uprooters > 0:
		var duration := UPROOT_TIME_ONE if uprooters == 1 else UPROOT_TIME_TWO
		uproot_progress = minf(uproot_progress + delta / duration, 1.0)
		_since_uproot = 0.0
	else:
		_since_uproot += delta
		if _since_uproot > UPROOT_DECAY_DELAY:
			uproot_progress = maxf(uproot_progress - UPROOT_DECAY_PER_S * delta, 0.0)


func _physics_process(delta: float) -> void:
	if _bloomed:
		return
	elapsed += delta
	if stage() == 1:
		_pollen_timer -= delta
		if _pollen_timer <= 0.0:
			_pollen_timer = POLLEN_INTERVAL
			_release_pollen()
	_update_visual()
	if elapsed >= GROW_TIME:
		_bloomed = true
		bloomed.emit()


func _release_pollen() -> void:
	var perception := Perception.current
	if perception == null:
		return
	for p in perception.pawtners:
		if p.is_alive and p.team != attacker_team and p.global_position.distance_to(global_position) <= POLLEN_RADIUS:
			perception.reveal_to_team(attacker_team, p, POLLEN_REVEAL_TIME)
	var mat := (_pollen_ring.mesh as TorusMesh).material as StandardMaterial3D
	mat.albedo_color.a = 0.7
	create_tween().tween_property(mat, "albedo_color:a", 0.0, 1.0)


func _update_visual() -> void:
	var t := clampf(elapsed / GROW_TIME, 0.0, 1.0)
	var height := lerpf(0.25, 1.4, t)
	_stem.scale = Vector3(1.0, height, 1.0)
	_stem.position.y = height * 0.5
	_bud.position.y = height
	# La flor se abre en la última etapa.
	_bud.scale = Vector3.ONE * (0.6 + 0.3 * stage() + (0.5 if stage() == 2 else 0.0))


func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
