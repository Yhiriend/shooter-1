# Genera los modelos de los 4 Pawtners a partir de «Generic Male» (J-Toastie):
# misma cabeza cúbica, ojos, cuerpo, manos y pies flotantes y animaciones, con
# colores y piezas nuevas (orejas, hocico, cola, accesorios) por personaje.
#
# Uso (desde la raíz del proyecto):
#   blender -b --python tools/build_pawtners.py -- <generic_male.glb> <carpeta_salida> [id ...]
#
# Coordenadas de Blender del modelo base (Z arriba, el frente mira a -Y):
#   cabeza x ±0,5 · y -0,6 (cara) a 0,38 (nuca) · z 0,2 a 1,15
#   cuerpo x ±0,3 · y -0,39 a 0,2 · z -0,39 a 0,25 · pies hasta z -0,77
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = argv[2:]

# Altura final en metros (de los pies a la coronilla) y desplazamiento de los pies.
TARGET_SCALE = 0.78
FEET_Z = 0.77

HEAD_TOP = 1.15
FACE_Y = -0.6
BACK_Y = 0.38
## Costado de la cabeza: donde se aplastan las orejas humanas.
HEAD_SIDE_X = 0.495


# --- Paletas y piezas por personaje -----------------------------------------

def _to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(r, g, b):
    """Color escrito en sRGB (como en un selector de color); Blender y glTF lo guardan lineal."""
    return (_to_linear(r), _to_linear(g), _to_linear(b), 1.0)


CHARACTERS = {
    "mochi": {  # gata calicó: orejas grandes, cola en espiral, cascabel
        "colors": {
            "fur": rgb(0.97, 0.94, 0.88), "hands": rgb(0.97, 0.94, 0.88),
            "shirt": rgb(0.93, 0.52, 0.66), "paws": rgb(0.9, 0.58, 0.3),
            "nose": rgb(0.98, 0.55, 0.62),
            "orange": rgb(0.93, 0.58, 0.25), "black": rgb(0.16, 0.14, 0.14),
            "pink": rgb(1.0, 0.68, 0.72), "gold": rgb(1.0, 0.8, 0.2), "collar": rgb(0.85, 0.2, 0.3),
        },
        "remove_side_ears": True,
    },
    "pip": {  # conejo enano: orejas largas, mochila con pala
        "colors": {
            "fur": rgb(0.9, 0.78, 0.62), "hands": rgb(0.9, 0.78, 0.62),
            "shirt": rgb(0.5, 0.76, 0.32), "paws": rgb(0.72, 0.58, 0.44),
            "nose": rgb(0.98, 0.55, 0.62),
            "pink": rgb(1.0, 0.7, 0.74), "white": rgb(0.98, 0.97, 0.94),
            "bag": rgb(0.78, 0.45, 0.22), "bag_dark": rgb(0.6, 0.33, 0.16),
            "wood": rgb(0.62, 0.42, 0.25), "metal": rgb(0.7, 0.72, 0.76),
        },
        "remove_side_ears": True,
    },
    "tofu": {  # panda: cuerpo redondo, bambú a la espalda
        "colors": {
            "fur": rgb(0.97, 0.97, 0.95), "hands": rgb(0.12, 0.12, 0.13),
            "shirt": rgb(0.16, 0.16, 0.18), "paws": rgb(0.1, 0.1, 0.11),
            "nose": rgb(0.1, 0.1, 0.11),
            "black": rgb(0.1, 0.1, 0.11), "white": rgb(0.97, 0.97, 0.95),
            "bamboo": rgb(0.48, 0.74, 0.32), "bamboo_dark": rgb(0.32, 0.56, 0.22),
        },
        "remove_side_ears": True,
        "body_scale": 1.14,
    },
    "capi": {  # capibara: hocico ancho, naranja en la cabeza
        "colors": {
            "fur": rgb(0.7, 0.49, 0.33), "hands": rgb(0.7, 0.49, 0.33),
            "shirt": rgb(0.45, 0.72, 0.95), "paws": rgb(0.4, 0.27, 0.18),
            "nose": rgb(0.22, 0.14, 0.1),
            "snout": rgb(0.56, 0.38, 0.26), "dark": rgb(0.3, 0.2, 0.14),
            "orange": rgb(1.0, 0.56, 0.1), "leaf": rgb(0.35, 0.7, 0.25),
        },
        "remove_side_ears": True,
        "remove_nose": True,
    },
}


# --- Utilidades de geometría ---------------------------------------------------

_mats = {}
## Piezas creadas para el personaje en construcción (se unen al cuerpo al final).
PARTS = []


def material(name, color):
    key = (name, tuple(color))
    if key not in _mats:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Metallic"].default_value = 0.0
        m.diffuse_color = color
        _mats[key] = m
    return _mats[key]


def _finish(bm, name, loc, rot_deg, mat, bone, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.matrix_world = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot_deg]).to_matrix().to_4x4()
    o.data.materials.append(mat)
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    PARTS.append(o)
    return o


def rbox(name, size, loc, mat, bone, rot=(0, 0, 0), bevel=0.3, segments=2):
    """Bloque redondeado como la cabeza del modelo base."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    off = min(size) * bevel * 0.5
    if off > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=off, segments=segments, profile=0.5, affect="EDGES")
    return _finish(bm, name, Vector(loc), rot, mat, bone)


def pyramid(name, base, height, loc, mat, bone, rot=(0, 0, 0), depth_scale=1.0):
    """Oreja triangular: pirámide de base cuadrada con aristas suavizadas."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=base, radius2=base * 0.12, depth=height)
    bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(math.radians(45), 3, "Z"), verts=bm.verts)
    bmesh.ops.scale(bm, vec=Vector((1.0, depth_scale, 1.0)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=base * 0.12, segments=2, profile=0.5, affect="EDGES")
    return _finish(bm, name, Vector(loc), rot, mat, bone)


def ball(name, radius, loc, mat, bone, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return _finish(bm, name, Vector(loc), rot, mat, bone)


def cylinder(name, radius, length, loc, mat, bone, rot=(0, 0, 0), segments=8):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    return _finish(bm, name, Vector(loc), rot, mat, bone)


# --- Piezas de cada personaje -----------------------------------------------

def parts_mochi(c):
    M = lambda k: material("mochi_" + k, c[k])
    # Orejas grandes de gata: izquierda naranja, derecha negra (calicó), interior rosa.
    for side, col in ((-1, "orange"), (1, "black")):
        x = 0.3 * side
        pyramid(f"Ear{side}", 0.22, 0.36, (x, -0.1, HEAD_TOP + 0.13), M(col), "Head", rot=(0, 14 * side, 0), depth_scale=0.6)
        pyramid(f"EarIn{side}", 0.13, 0.24, (x * 0.97, -0.17, HEAD_TOP + 0.1), M("pink"), "Head", rot=(0, 14 * side, 0), depth_scale=0.35)
    # Manchas calicó: naranja en la frente y la nuca, negra en un costado.
    rbox("PatchFront", (0.3, 0.04, 0.22), (-0.26, FACE_Y + 0.01, 0.98), M("orange"), "Head", bevel=0.8)
    rbox("PatchSide", (0.06, 0.45, 0.42), (HEAD_SIDE_X + 0.01, 0.05, 0.86), M("black"), "Head", bevel=0.8)
    rbox("PatchBack", (0.42, 0.06, 0.38), (-0.18, BACK_Y + 0.01, 0.62), M("orange"), "Head", bevel=0.8)
    # Collar con cascabel.
    rbox("Collar", (0.66, 0.65, 0.08), (0.0, -0.095, 0.21), M("collar"), "Body", bevel=0.6)
    ball("Bell", 0.09, (0.0, -0.45, 0.16), M("gold"), "Body")
    # Cola en espiral: sale de la espalda baja hacia atrás y se enrosca detrás de la nuca
    # (la cabeza sobresale hasta y=0,38 por encima de z=0,2).
    pts = [(0.0, 0.24, -0.3), (0.0, 0.37, -0.33), (0.0, 0.5, -0.28), (0.0, 0.62, -0.17),
           (0.0, 0.67, -0.03), (0.0, 0.63, 0.1), (0.0, 0.54, 0.15), (0.0, 0.47, 0.08), (0.0, 0.5, -0.02)]
    for i, p in enumerate(pts):
        s = 0.15 - i * 0.008
        col = "orange" if i >= 5 else "fur"
        rbox(f"Tail{i}", (s, s, s), p, M(col), "Body", bevel=0.7)


def parts_pip(c):
    M = lambda k: material("pip_" + k, c[k])
    # Orejas largas de conejo, un poco abiertas; la derecha cae hacia atrás.
    for side in (-1, 1):
        x = 0.18 * side
        tilt = 9 * side
        back = -14 if side > 0 else 0
        rbox(f"Ear{side}", (0.18, 0.1, 0.66), (x, -0.06, HEAD_TOP + 0.3), M("fur"), "Head", rot=(back, tilt, 0), bevel=0.9)
        rbox(f"EarIn{side}", (0.09, 0.03, 0.48), (x, -0.11, HEAD_TOP + 0.3), M("pink"), "Head", rot=(back, tilt, 0), bevel=0.9)
    # Dientes de conejo bajo la nariz.
    for side in (-1, 1):
        rbox(f"Tooth{side}", (0.07, 0.04, 0.09), (0.04 * side, FACE_Y - 0.015, 0.4), M("white"), "Head", bevel=0.4)
    # Mochila con pala.
    rbox("Bag", (0.5, 0.24, 0.5), (0.0, 0.33, -0.06), M("bag"), "Body", bevel=0.5)
    rbox("BagFlap", (0.52, 0.27, 0.16), (0.0, 0.33, 0.16), M("bag_dark"), "Body", bevel=0.5)
    rbox("BagPocket", (0.3, 0.06, 0.18), (0.0, 0.47, -0.12), M("bag_dark"), "Body", bevel=0.6)
    # Pala asomando sobre el hombro, con la hoja por encima de la cabeza (se ve desde la cámara).
    # Girar +16° en Y lleva el eje local +Z a (sin16°, 0, cos16°): el palo sube hacia +X
    # y la hoja va en la punta, sobre el mismo eje.
    stick_center = Vector((0.3, 0.5, 0.5))
    axis = Vector((math.sin(math.radians(16)), 0.0, math.cos(math.radians(16))))
    cylinder("ShovelStick", 0.035, 1.25, stick_center, M("wood"), "Body", rot=(0, 16, 0))
    rbox("ShovelBlade", (0.24, 0.06, 0.3), stick_center + axis * 0.75, M("metal"), "Body", rot=(0, 16, 0), bevel=0.5)
    # Colita de algodón.
    ball("Tail", 0.11, (0.0, 0.24, -0.36), M("white"), "Body")


def parts_tofu(c):
    M = lambda k: material("tofu_" + k, c[k])
    # Orejas redondas negras.
    for side in (-1, 1):
        rbox(f"Ear{side}", (0.27, 0.16, 0.25), (0.37 * side, -0.05, HEAD_TOP + 0.04), M("black"), "Head", bevel=0.9)
    # Manchas de los ojos (caídas hacia afuera) con brillo blanco para que el ojo se lea.
    for side in (-1, 1):
        rbox(f"EyePatch{side}", (0.3, 0.04, 0.37), (0.215 * side, FACE_Y + 0.005, 0.68), M("black"), "Head",
             rot=(0, 18 * side, 0), bevel=0.9)
        rbox(f"EyeShine{side}", (0.055, 0.02, 0.055), (0.17 * side, FACE_Y - 0.035, 0.76), M("white"), "Head", bevel=0.5)
    # Barriga blanca.
    rbox("Belly", (0.44, 0.05, 0.42), (0.0, -0.44, -0.08), M("white"), "Body", bevel=0.9)
    # Bambú a la espalda, en diagonal y por encima del hombro.
    a = Vector((-0.3, 0.46, -0.38))
    b = Vector((0.36, 0.5, 1.05))
    axis = (b - a).normalized()
    rot = axis.to_track_quat("Z", "Y").to_euler()
    rot_deg = tuple(math.degrees(r) for r in rot)
    n = 3
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        mid = a.lerp(b, (t0 + t1) / 2)
        cylinder(f"Bamboo{i}", 0.065, (b - a).length / n - 0.02, mid, M("bamboo"), "Body", rot=rot_deg)
        if i > 0:
            cylinder(f"BambooNode{i}", 0.08, 0.05, a.lerp(b, t0), M("bamboo_dark"), "Body", rot=rot_deg)
    for side in (-1, 1):
        pyramid(f"Leaf{side}", 0.07, 0.3, b + Vector((0.1 * side, 0.0, 0.05)), M("bamboo_dark"), "Body",
                rot=(0, 55 * side, 0), depth_scale=0.25)


def parts_capi(c):
    M = lambda k: material("capi_" + k, c[k])
    # Orejitas pequeñas arriba a los lados.
    for side in (-1, 1):
        rbox(f"Ear{side}", (0.15, 0.1, 0.13), (0.4 * side, 0.06, HEAD_TOP + 0.02), M("dark"), "Head", bevel=0.8)
    # Hocico ancho con fosas nasales.
    rbox("Snout", (0.74, 0.26, 0.3), (0.0, FACE_Y - 0.08, 0.38), M("snout"), "Head", bevel=0.6)
    for side in (-1, 1):
        rbox(f"Nostril{side}", (0.08, 0.03, 0.05), (0.13 * side, FACE_Y - 0.215, 0.44), M("dark"), "Head", bevel=0.5)
    rbox("Mouth", (0.18, 0.03, 0.025), (0.0, FACE_Y - 0.215, 0.33), M("dark"), "Head", bevel=0.5)
    # La naranja encima de la cabeza, con hojita.
    ball("Orange", 0.18, (0.0, -0.1, HEAD_TOP + 0.16), M("orange"), "Head", scale=(1, 1, 0.9))
    rbox("Leaf", (0.14, 0.05, 0.03), (0.07, -0.1, HEAD_TOP + 0.33), M("leaf"), "Head", rot=(0, -25, 0), bevel=0.6)


PART_BUILDERS = {"mochi": parts_mochi, "pip": parts_pip, "tofu": parts_tofu, "capi": parts_capi}


# --- Recoloreado del modelo base -------------------------------------------

def classify(col):
    r, g, b = col
    if r < 0.1 and g > 0.3:
        return "shirt"
    if abs(r - g) < 0.04 and abs(g - b) < 0.04 and r < 0.3:
        return "paws"
    if r > 0.7 and g < 0.33:
        return "nose"
    return "skin"


def dominant_bone(obj, me, poly):
    weights = {}
    for vi in poly.vertices:
        for g in me.vertices[vi].groups:
            n = obj.vertex_groups[g.group].name
            weights[n] = weights.get(n, 0.0) + g.weight
    return max(weights, key=weights.get) if weights else ""


def recolor_base(body, eyes, spec, cid):
    c = spec["colors"]
    img = bpy.data.images[0]
    w, h = img.size
    px = img.pixels[:]
    me = body.data
    uvl = me.uv_layers.active.data
    slots = ["fur", "hands", "shirt", "paws", "nose"]
    me.materials.clear()
    for s in slots:
        me.materials.append(material(f"{cid}_{s}", c[s]))
    to_delete = []
    for p in me.polygons:
        uv = sum((uvl[li].uv for li in p.loop_indices), Vector((0, 0))) / p.loop_total
        x = min(max(int(uv.x * w), 0), w - 1)
        y = min(max(int(uv.y * h), 0), h - 1)
        i = (y * w + x) * 4
        kind = classify(px[i:i + 3])
        bone = dominant_bone(body, me, p)
        center = body.matrix_world @ p.center
        if kind == "skin":
            kind = "fur" if bone in ("Head", "Body", "CORE") else "hands"
        if kind == "nose" and spec.get("remove_nose"):
            to_delete.append(p.index)
        p.material_index = slots.index(kind)
    if to_delete:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.faces[i] for i in to_delete], context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(me)
        bm.free()
    # Orejas humanas: son parte de la superficie de la cabeza (borrarlas deja un agujero),
    # así que se aplastan contra el costado.
    if spec.get("remove_side_ears"):
        inv = body.matrix_world.inverted()
        for v in me.vertices:
            if not v.groups:
                continue
            g = max(v.groups, key=lambda g: g.weight)
            if body.vertex_groups[g.group].name != "Head":
                continue
            wpos = body.matrix_world @ v.co
            if abs(wpos.x) > HEAD_SIDE_X and 0.3 < wpos.z < 0.95:
                wpos.x = math.copysign(HEAD_SIDE_X, wpos.x)
                v.co = inv @ wpos
    # Cuerpo más redondo (Tofu): ensancha los vértices del torso.
    k = spec.get("body_scale")
    if k:
        inv = body.matrix_world.inverted()
        for v in me.vertices:
            if not v.groups:
                continue
            g = max(v.groups, key=lambda g: g.weight)
            if body.vertex_groups[g.group].name == "Body":
                wpos = body.matrix_world @ v.co
                wpos.x *= k
                wpos.y = -0.095 + (wpos.y + 0.095) * k
                v.co = inv @ wpos
    eyes.data.materials.clear()
    eyes.data.materials.append(material("eye", rgb(0.04, 0.04, 0.05)))


# --- Construcción ----------------------------------------------------------

def build(cid):
    global PARTS
    PARTS = []
    _mats.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.parent is None:
            bpy.data.objects.remove(o)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    eyes = next(o for o in meshes if len(o.data.vertices) < 500)
    body = next(o for o in meshes if o is not eyes)
    if arm.animation_data:
        arm.animation_data.action = None
    bpy.context.view_layer.update()

    spec = CHARACTERS[cid]
    recolor_base(body, eyes, spec, cid)
    PART_BUILDERS[cid](spec["colors"])

    # Une las piezas al cuerpo (conservan su grupo de vértices = hueso).
    bpy.ops.object.select_all(action="DESELECT")
    for o in PARTS:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "Body"
    eyes.name = "Eyes"

    # Raíz: pies en el suelo, altura de juego y frente hacia +Y (= -Z en glTF/Godot).
    root = bpy.data.objects.new(cid.capitalize(), None)
    bpy.context.scene.collection.objects.link(root)
    arm.parent = root
    root.location = (0.0, 0.0, FEET_Z * TARGET_SCALE)
    root.scale = (TARGET_SCALE,) * 3
    root.rotation_euler = (0.0, 0.0, math.pi)

    out = f"{OUT}/{cid}.glb"
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                              export_apply=False, export_yup=True, export_skins=True)
    print("EXPORTED", out, "verts", len(body.data.vertices))


for cid in (ONLY or CHARACTERS.keys()):
    build(cid)
