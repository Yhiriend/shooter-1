class_name MoonSeed
extends Node3D
## La Semilla Lunar antes de sembrarse: la lleva un atacante o queda en el suelo.
## Ver docs/GDD.md, «Modo de juego: Semilla Lunar».

enum State { CARRIED, DROPPED, NONE }

const COLOR := Color(0.78, 0.55, 1.0)
## Distancia a la que un atacante la recoge del suelo.
const PICKUP_RADIUS := 1.0

var state := State.NONE
var carrier: Pawtner

var _mesh: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR
	sphere.material = mat
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


func give_to(p: Pawtner) -> void:
	if state == State.DROPPED:
		Sfx.at("seed_pick", p.global_position)
	if carrier:
		carrier.carrying_seed = false
	carrier = p
	p.carrying_seed = true
	state = State.CARRIED


## Cae al suelo en `pos`. Ambos equipos ven dónde está.
func drop(pos: Vector3) -> void:
	if carrier:
		carrier.carrying_seed = false
	carrier = null
	state = State.DROPPED
	global_position = Vector3(pos.x, 0.3, pos.z)


## Se usó para sembrar, o se retira al terminar la ronda.
func clear() -> void:
	if carrier:
		carrier.carrying_seed = false
	carrier = null
	state = State.NONE


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.CARRIED:
			global_position = carrier.global_position + Vector3(0.0, 1.75, 0.0)
			visible = carrier.is_alive and carrier.is_revealed()
		State.DROPPED:
			visible = true
			_mesh.position.y = sin(_time * 3.0) * 0.08
		State.NONE:
			visible = false
