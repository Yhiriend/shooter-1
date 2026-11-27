class_name StatusIndicators
extends Node3D
## Señales sobre la cabeza del Pawtner para los estados alterados, visibles para todos:
## - Cegado: una cinta blanca alrededor de la cabeza, a la altura de los ojos.
## - Aturdido: estrellitas que giran alrededor de la cabeza.
## Va pegado al hueso «Head» del modelo, así que sigue sus animaciones.

## Medidas en unidades de los vértices del modelo (o del greybox si no hay modelo).
const BAND_PAD := 0.03          ## Cuánto sobresale la cinta por arriba y por abajo de los ojos.
const BAND_MARGIN := 0.035      ## Separación entre la cinta y la cabeza.
const BAND_CORNER := 0.16       ## Radio de las esquinas redondeadas.
const BAND_SEGMENTS := 8        ## Segmentos por esquina.
const HEAD_SLICE := 0.3         ## Media altura de la franja de la cabeza que se mide alrededor de los ojos (sin orejas).
const STAR_COUNT := 4
const STAR_SIZE := 0.12
const STAR_HEIGHT := 0.62       ## Sobre el centro de los ojos.
const STAR_ORBIT_MARGIN := 0.12
const STAR_ORBIT_SPEED := 4.5   ## rad/s
const STAR_BOB := 0.05
const COLOR_BAND := Color.WHITE
const COLOR_STAR := Color(1.0, 0.88, 0.25)

## Medidas de cabeza por personaje (centro de los ojos y semiancho de la cabeza en x/z).
static var _head_cache := {}
static var _star_mesh: ArrayMesh

var _pawtner: Pawtner
var _band: MeshInstance3D
var _stars: Node3D
var _time := 0.0


## Coloca los indicadores en la cabeza del modelo (o del greybox) que cuelga de `visual`.
func attach(p: Pawtner, visual: Node3D) -> void:
	_pawtner = p
	name = "StatusIndicators"
	var model := visual.get_node_or_null("Model")
	var skeleton: Skeleton3D = null
	if model:
		var found := model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skeleton = found[0]
	var head := _measure_head(p, model, skeleton, visual)
	var center: Vector3 = head["center"]
	var bone := skeleton.find_bone("Head") if skeleton else -1
	if bone >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.name = "HeadAttachment"
		attachment.bone_name = "Head"
		skeleton.add_child(attachment)
		attachment.add_child(self)
		# Las medidas están en el espacio de los vértices de la malla; la pose de enlace
		# del hueso los lleva al espacio del hueso (incluida la escala del esqueleto).
		transform = _head_bind_pose(model, skeleton, bone) * Transform3D(Basis(), center)
	else:
		visual.add_child(self)
		position = center
	_build(head["half"], head["band_height"])


func _process(delta: float) -> void:
	if _pawtner == null:
		return
	_band.visible = _pawtner.is_blinded()
	var stunned := _pawtner.is_stunned()
	_stars.visible = stunned
	if stunned:
		_time += delta
		_stars.rotation.y = _time * STAR_ORBIT_SPEED
		for i in _stars.get_child_count():
			var star := _stars.get_child(i).get_child(0) as Node3D
			star.position.y = sin(_time * 6.0 + i * TAU / STAR_COUNT) * STAR_BOB


func _build(half: Vector2, band_height: float) -> void:
	_band = MeshInstance3D.new()
	_band.name = "BlindBand"
	_band.mesh = _band_mesh(half + Vector2.ONE * BAND_MARGIN, band_height)
	_band.material_override = _flat_material(COLOR_BAND)
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_band.visible = false
	add_child(_band)

	_stars = Node3D.new()
	_stars.name = "StunStars"
	_stars.visible = false
	add_child(_stars)
	var orbit := maxf(half.x, half.y) + STAR_ORBIT_MARGIN
	var star_mat := _flat_material(COLOR_STAR)
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.billboard_keep_scale = true
	for i in STAR_COUNT:
		var angle := i * TAU / STAR_COUNT
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * orbit, STAR_HEIGHT, sin(angle) * orbit)
		var star := MeshInstance3D.new()
		star.mesh = _get_star_mesh()
		star.material_override = star_mat
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# El pivote fija la posición en la órbita; la estrella rebota dentro.
		pivot.add_child(star)
		_stars.add_child(pivot)


# --- Medidas de la cabeza ---

## Pose de enlace del hueso «Head» en la piel de la malla «Body» (del espacio de la malla
## al del hueso). Sin piel, la inversa de la pose de reposo.
static func _head_bind_pose(model: Node, skeleton: Skeleton3D, bone: int) -> Transform3D:
	var body := model.find_child("Body", true, false) as MeshInstance3D
	var bind := _head_bind_index(body, skeleton) if body else -1
	if bind >= 0 and body.skin:
		return body.skin.get_bind_pose(bind)
	return skeleton.get_bone_global_rest(bone).affine_inverse()


## Índice del hueso «Head» en la piel de `body` (el que usan los pesos de sus vértices).
static func _head_bind_index(body: MeshInstance3D, skeleton: Skeleton3D) -> int:
	var head_bone := skeleton.find_bone("Head")
	if body.skin == null:
		return head_bone
	for i in body.skin.get_bind_count():
		var bind_name := body.skin.get_bind_name(i)
		if bind_name == "Head" or (bind_name == "" and body.skin.get_bind_bone(i) == head_bone):
			return i
	return -1


## Centro de los ojos y tamaño de la cabeza a esa altura, en el espacio de la malla.
## Se mide una vez por personaje a partir de los vértices de la cabeza del modelo.
func _measure_head(p: Pawtner, model: Node, skeleton: Skeleton3D, visual: Node3D) -> Dictionary:
	var key: String = p.character.id if p.character and model else ""
	if key != "" and _head_cache.has(key):
		return _head_cache[key]
	var result := {}
	var eyes := model.find_child("Eyes", true, false) as MeshInstance3D if model else null
	var body := model.find_child("Body", true, false) as MeshInstance3D if model else null
	if eyes and body and skeleton:
		var eyes_box := eyes.transform * eyes.get_aabb()
		var eye_center := eyes_box.get_center()
		var bounds := _head_slice(body, skeleton, eye_center.y)
		# El frente de la cinta pasa justo por delante de los ojos (así no la empuja el
		# hocico de Capi); los lados y la nuca, por fuera de la cabeza.
		var front := eyes_box.position.z
		var back := maxf(bounds.end.z, front + 0.2)
		result = {
			"center": Vector3(bounds.get_center().x, eye_center.y, (front + back) * 0.5),
			"half": Vector2(bounds.size.x * 0.5, (back - front) * 0.5),
			"band_height": eyes_box.size.y + BAND_PAD * 2.0,
		}
	else:
		# Greybox: la esfera «Head» de pawtner.tscn.
		var head := visual.get_node_or_null("Head") as MeshInstance3D
		var box := head.transform * head.get_aabb() if head else AABB(Vector3(-0.3, 1.0, -0.3), Vector3(0.6, 0.6, 0.6))
		var c := box.get_center()
		result = {
			"center": c,
			"half": Vector2(box.size.x, box.size.z) * 0.5,
			"band_height": box.size.y * 0.25,
		}
	if key != "":
		_head_cache[key] = result
	return result


## Caja de los vértices de la cabeza (peso del hueso «Head» > 0,5) en una franja alrededor de `y`.
func _head_slice(body: MeshInstance3D, skeleton: Skeleton3D, y: float) -> AABB:
	var head_bind := _head_bind_index(body, skeleton)
	var mn := Vector3.INF
	var mx := -Vector3.INF
	for s in body.mesh.get_surface_count():
		var arrays := body.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or verts.is_empty():
			continue
		var per_vertex: int = weights.size() / verts.size()
		for i in verts.size():
			var v := verts[i]
			if absf(v.y - y) > HEAD_SLICE:
				continue
			for j in per_vertex:
				if bones[i * per_vertex + j] == head_bind and weights[i * per_vertex + j] > 0.5:
					mn = mn.min(v)
					mx = mx.max(v)
					break
	if mn == Vector3.INF:
		var box := body.get_aabb()
		return AABB(Vector3(box.position.x, y, box.position.z), Vector3(box.size.x, 0.0, box.size.z))
	return AABB(mn, mx - mn)


# --- Mallas ---

## Cinta: pared de un rectángulo de esquinas redondeadas (vista desde los dos lados).
static func _band_mesh(half: Vector2, height: float) -> ArrayMesh:
	var r := minf(BAND_CORNER, minf(half.x, half.y))
	var corners := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r),
		Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	var path: Array[Vector2] = []
	for c in corners.size():
		for k in BAND_SEGMENTS + 1:
			var a := (c + float(k) / BAND_SEGMENTS) * PI * 0.5
			path.append(corners[c] + Vector2(cos(a), sin(a)) * r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := height * 0.5
	for i in path.size():
		var a := path[i]
		var b := path[(i + 1) % path.size()]
		var a_top := Vector3(a.x, h, a.y)
		var a_bot := Vector3(a.x, -h, a.y)
		var b_top := Vector3(b.x, h, b.y)
		var b_bot := Vector3(b.x, -h, b.y)
		st.add_vertex(a_bot); st.add_vertex(b_top); st.add_vertex(a_top)
		st.add_vertex(a_bot); st.add_vertex(b_bot); st.add_vertex(b_top)
	return st.commit()


## Estrella plana de 5 puntas en el plano XY (se orienta a la cámara con el material).
static func _get_star_mesh() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + i * PI / 5.0
		var radius := STAR_SIZE if i % 2 == 0 else STAR_SIZE * 0.45
		points.append(Vector3(cos(a), sin(a), 0.0) * radius)
	for i in points.size():
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(points[(i + 1) % points.size()])
		st.add_vertex(points[i])
	_star_mesh = st.commit()
	return _star_mesh


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat
