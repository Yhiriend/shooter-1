class_name HuertoLunar
extends Node3D
## Greybox de Huerto Lunar construido desde una cuadrícula de texto (1 celda = 1 m).
## Editar LAYOUT y volver a ejecutar: así se itera el mapa tras cada playtest.
## Ver docs/GDD.md, sección «Mapa MVP: Huerto Lunar».
##
## Leyenda:
##   W  valla perimetral (tapa balas y visión)
##   #  cobertura alta   (tapa balas y visión)
##   :  cobertura baja   (tapa balas, no visión)
##   A  suelo de la Maceta A     B  suelo de la Maceta B
##   M  suelo del centro (invernadero)
##   d  spawn defensores         a  spawn atacantes
##   .  suelo normal

const CELL := 1.0
const FENCE_HEIGHT := 1.2
const HIGH_COVER_HEIGHT := 1.6
const LOW_COVER_HEIGHT := 0.6

const SOLID_CHARS := "W#:"
const VISION_BLOCKER_CHARS := "W#"

const COLOR_GROUND := Color(0.96, 0.78, 0.62)
const COLOR_FENCE := Color(0.72, 0.5, 0.35)
const COLOR_HIGH := Color(0.62, 0.42, 0.3)
const COLOR_LOW := Color(0.93, 0.83, 0.5)
const COLOR_SITE := Color(0.78, 0.66, 0.95)
const COLOR_MID := Color(0.75, 0.9, 0.8)
const COLOR_DEF := Color(0.55, 0.88, 0.78)
const COLOR_ATK := Color(1.0, 0.62, 0.55)

const LAYOUT: Array[String] = [
	"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
	"W..............dddddddddd..............W",
	"W..............dddddddddd..............W",
	"W..............dddddddddd..............W",
	"W......................................W",
	"W............######..######............W",
	"W.AAAAAAAAAAA..............BBBBBBBBBBB.W",
	"W.AAAAAAAAAAA..............BBBBBBBBBBB.W",
	"W.AAA#AAA:AAA..............BBB:BBB#BBB.W",
	"W.AAAAAAAAAAA..............BBBBBBBBBBB.W",
	"W.AAAAAAAAAAA.#####..#####.BBBBBBBBBBB.W",
	"W.AAAAAAAAAAA..MMMMMMMMMM..BBBBBBBBBBB.W",
	"W.AAAAAAAAAAA..M#MMMMMMMM..BBBBBBBBBBB.W",
	"W............#.MMMMMMMMMM.#............W",
	"W............#.MMMMMMMMMM.#............W",
	"W...:........#.MMMMMMMMMM.#........:...W",
	"W............#.MMMMMMMM#M.#............W",
	"W............#.MMMMMMMMMM.#............W",
	"W.......#....#............#....#.......W",
	"W............######..######............W",
	"W............#............#............W",
	"W..:.........#............#.........:..W",
	"W......................................W",
	"W......................................W",
	"W..............aaaaaaaaaa..............W",
	"W..............aaaaaaaaaa..............W",
	"W..............aaaaaaaaaa..............W",
	"WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW",
]

var cols := 0
var rows := 0
## Centro de cada zona, por carácter de la leyenda ("A", "B", "M", "a", "d").
var zone_centers := {}

var _astar := AStarGrid2D.new()


func _ready() -> void:
	_build()
	_build_navigation()


func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3(
		(col - cols * 0.5 + 0.5) * CELL,
		0.0,
		(row - rows * 0.5 + 0.5) * CELL
	)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL + cols * 0.5), floori(p.z / CELL + rows * 0.5))


func is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func cell_char(cell: Vector2i) -> String:
	return LAYOUT[cell.y][cell.x] if is_cell_inside(cell) else "W"


func is_cell_solid(cell: Vector2i) -> bool:
	return SOLID_CHARS.contains(cell_char(cell))


func is_cell_vision_blocker(cell: Vector2i) -> bool:
	return VISION_BLOCKER_CHARS.contains(cell_char(cell))


## "A" o "B" si `pos` está sobre una maceta; "" si no.
func site_at(pos: Vector3) -> String:
	var ch := cell_char(world_to_cell(pos))
	return ch if ch == "A" or ch == "B" else ""


func zone_center(zone: String) -> Vector3:
	return zone_centers.get(zone, Vector3.ZERO)


## Punto de aparición `index` según el rol: 0 = atacantes, 1 = defensores.
func spawn_point(role: int, index: int) -> Vector3:
	var center := zone_center("a" if role == 0 else "d")
	return center + Vector3((index - 0.5) * 3.0, 0.0, 0.0)


## Camino por la cuadrícula (A*) entre dos puntos del mundo, como puntos en el suelo.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var a := _nearest_free_cell(world_to_cell(from))
	var b := _nearest_free_cell(world_to_cell(to))
	var ids := _astar.get_id_path(a, b, true)
	for i in range(1, ids.size()):
		result.append(cell_to_world(ids[i].x, ids[i].y))
	if not result.is_empty() and b == world_to_cell(to):
		result[result.size() - 1] = Vector3(to.x, 0.0, to.z)
	return result


## Celda libre al azar a menos de `radius` celdas de `center`.
func random_free_point_near(center: Vector3, radius: int) -> Vector3:
	var c := world_to_cell(center)
	for attempt in 20:
		var cell := c + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if is_cell_inside(cell) and not is_cell_solid(cell):
			return cell_to_world(cell.x, cell.y)
	return center


func _build_navigation() -> void:
	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.cell_size = Vector2(CELL, CELL)
	# No corta esquinas: evita que los bots se traben en el borde de una cobertura.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for row in rows:
		for col in cols:
			if is_cell_solid(Vector2i(col, row)):
				_astar.set_point_solid(Vector2i(col, row))


func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	if is_cell_inside(cell) and not is_cell_solid(cell):
		return cell
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if is_cell_inside(c) and not is_cell_solid(c):
					return c
	return cell.clamp(Vector2i.ZERO, Vector2i(cols - 1, rows - 1))


func _build() -> void:
	rows = LAYOUT.size()
	cols = LAYOUT[0].length()

	var cells := {}  # carácter -> Array[Vector3]
	for row in rows:
		var line := LAYOUT[row]
		assert(line.length() == cols, "Huerto Lunar: la fila %d mide %d, se esperaban %d" % [row, line.length(), cols])
		for col in cols:
			var ch := line[col]
			if ch == ".":
				continue
			if not cells.has(ch):
				cells[ch] = []
			cells[ch].append(cell_to_world(col, row))

	_add_ground()
	for ch: String in cells:
		var list: Array = cells[ch]
		match ch:
			"W":
				_add_blocks(list, FENCE_HEIGHT, COLOR_FENCE, true)
			"#":
				_add_blocks(list, HIGH_COVER_HEIGHT, COLOR_HIGH, true)
			":":
				_add_blocks(list, LOW_COVER_HEIGHT, COLOR_LOW, false)
			"A", "B":
				_add_zone(list, COLOR_SITE)
				zone_centers[ch] = _average(list)
			"M":
				_add_zone(list, COLOR_MID)
				zone_centers[ch] = _average(list)
			"d":
				_add_zone(list, COLOR_DEF)
				zone_centers[ch] = _average(list)
			"a":
				_add_zone(list, COLOR_ATK)
				zone_centers[ch] = _average(list)
			_:
				push_warning("Huerto Lunar: carácter desconocido '%s'" % ch)


func _add_ground() -> void:
	var size := Vector3(cols * CELL, 0.2, rows * CELL)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = Layers.WORLD
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = -0.1
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = -0.1
	mi.material_override = _material(COLOR_GROUND)
	body.add_child(mi)
	add_child(body)


func _add_blocks(positions: Array, height: float, color: Color, blocks_vision: bool) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(CELL, height, CELL)
	var shape := BoxShape3D.new()
	shape.size = box.size

	var body := StaticBody3D.new()
	body.name = "Cover_%s" % ("High" if blocks_vision else "Low")
	body.collision_layer = Layers.WORLD | (Layers.VISION_BLOCKER if blocks_vision else 0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in positions:
		var xf := Transform3D(Basis.IDENTITY, p + Vector3(0.0, height * 0.5, 0.0))
		st.append_from(box, 0, xf)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = xf
		body.add_child(col)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(color)
	body.add_child(mi)
	add_child(body)


func _add_zone(positions: Array, color: Color) -> void:
	var tile := BoxMesh.new()
	tile.size = Vector3(CELL, 0.02, CELL)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in positions:
		st.append_from(tile, 0, Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.01, 0.0)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _average(positions: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in positions:
		sum += p
	return sum / positions.size()
