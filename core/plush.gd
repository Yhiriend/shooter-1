class_name Plush
extends Node3D
## Peluche que deja un Pawtner al morir. Su compañero puede abrazarlo para revivirlo.
## Ver docs/GDD.md, «Rescate de dúo».

var pawtner: Pawtner
var time_left := 8.0
## Segundos de abrazo acumulados (se reinicia si nadie lo abraza).
var hug_progress := 0.0

var _base_scale := Vector3.ONE


func setup(owner_pawtner: Pawtner, duration: float) -> void:
	pawtner = owner_pawtner
	time_left = duration


func _ready() -> void:
	var body := SphereMesh.new()
	body.radius = 0.4
	body.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Pawtner.TEAM_COLORS[pawtner.team].lerp(Color.WHITE, 0.35)
	body.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.scale = Vector3(1.0, 0.55, 1.0)
	mi.position.y = 0.22
	add_child(mi)
	_base_scale = scale


func _process(_delta: float) -> void:
	var perception := Perception.current
	if perception:
		visible = pawtner.team == perception.local_team \
			or perception.is_point_visible_to_local(global_position)
	# Se encoge a medida que se acaba su tiempo.
	scale = _base_scale * clampf(0.5 + time_left / 16.0, 0.5, 1.0)
