# Renderiza un retrato cuadrado (solo la cabeza) de cada Pawtner para la selección.
#
# Uso (desde la raíz del proyecto):
#   blender -b --python tools/render_portraits.py -- <carpeta_modelos> <carpeta_salida> [id ...]
#
# Lee <id>.glb (generados por build_pawtners.py) y escribe <id>.png con fondo transparente.
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MODELS, OUT = argv[0], argv[1]
IDS = argv[2:] or ["mochi", "pip", "tofu", "capi"]

SIZE = 384
# Centro de la cabeza en el juego (m) y ancho del encuadre: la cabeza llena el cuadro y
# las orejas largas pueden salirse por arriba, como en un retrato.
HEAD_CENTER = Vector((0.04, 0.08, 1.2))
FRAME_WIDTH = 1.22
# Vista de frente, un poco girada y desde algo más arriba.
VIEW_DIR = Vector((0.3, 1.0, 0.18)).normalized()
FOV_DEG = 28.0


def setup_scene():
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.75, 0.8, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 0.45
    scene.world = world

    def area(name, loc, energy, size, color=(1, 1, 1)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = size
        data.color = color
        o = bpy.data.objects.new(name, data)
        scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (HEAD_CENTER - Vector(loc)).to_track_quat("-Z", "Y").to_euler()

    area("Key", (1.6, 2.6, 2.6), 110.0, 2.5, (1.0, 0.96, 0.9))
    area("Fill", (-2.2, 2.0, 1.4), 40.0, 3.0, (0.85, 0.9, 1.0))
    area("Rim", (0.0, -2.5, 2.4), 70.0, 2.0)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens_unit = "FOV"
    cam_data.angle = math.radians(FOV_DEG)
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    dist = (FRAME_WIDTH * 0.5) / math.tan(math.radians(FOV_DEG) * 0.5)
    cam.location = HEAD_CENTER + VIEW_DIR * dist
    cam.rotation_euler = (HEAD_CENTER - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam


for cid in IDS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    setup_scene()
    bpy.ops.import_scene.gltf(filepath=f"{MODELS}/{cid}.glb")
    for o in bpy.data.objects:
        if o.type == "ARMATURE" and o.animation_data:
            # Pose de reposo (sin la animación activa).
            o.animation_data.action = None
            for b in o.pose.bones:
                b.location = (0, 0, 0)
                b.rotation_quaternion = (1, 0, 0, 0)
                b.scale = (1, 1, 1)
    bpy.context.scene.render.filepath = f"{OUT}/{cid}.png"
    bpy.ops.render.render(write_still=True)
    print("PORTRAIT", cid)
