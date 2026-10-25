"""The Collector - GREY BLOCKOUT on the shared Smiles rig (straight scene swap, armature "Smiles").

blender -b --factory-startup --python art/models/characters/bosses/collector/src/build_collector.py
-> ../collector.glb (PC) + ../collector_mobile.glb

AD ruling: ANIMAL head on the Smiles body (overrides the BRIEF's "head TBD"). Animal = JACKAL: the board draft
(dealers_board_v1) shows a furry canid-like head with tall pointed ears; a jackal is a scavenger (fits a
confiscating hoarder) and its two tall ears + long muzzle read at 48 px. BRIEF: hunched, long neck, coat tails,
head forward; whispering hoarder, scarf over his mouth; prop = glass cloche lowered over a die.
Palette (AD): brass, bone + greys only (no oxblood; the brief's silver/verdigris read as greys here).
Slots: Collector_Body, Collector_Head, Collector_Ears (on "visor"), Collector_Cloche (on "chip").
Accent slots kept separate: col_brass, col_bone, col_glass.
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

GREYS = [("col_fur", 0.50), ("col_fur_dark", 0.30), ("col_coat", 0.22), ("col_scarf", 0.62), ("col_brass", 0.70),
         ("col_bone", 0.90), ("col_glass", 0.80), ("col_eye", 0.05), ("col_black", 0.10)]
bs.MATS = [n for n, _ in GREYS]
rot = bs.rot
E = lambda k, d: float(os.environ.get(k, d))
HEAD_DROP = E("HEAD_DROP", "0.06")   # head sits low + forward (hunch)
HEAD_FWD = E("HEAD_FWD", "0.05")
EAR_TOP = E("EAR_TOP", "0.73")       # ear tip height before HEAD_DROP
CLOCHE_OFF = Vector(tuple(float(x) for x in os.environ.get("CLOCHE_OFF", "0.0,-0.06,-0.1").split(",")))


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    b = P("Collector_Body")
    # long frock coat: narrow at the waist, tails flaring behind past the hips
    b.tube([((0, 0, -0.24), 0.12), ((0, 0, 0.0), 0.12)], "col_coat", "spine", seg=S(14), flat=0.72)
    b.tube([((0, 0.03, -0.26), 0.13), ((0, 0.02, -0.05), 0.12)], "col_coat", "spine", seg=S(14), flat=0.6)  # coat tails (back)
    b.tube([((0, 0, -0.03), 0.12), ((0, 0, 0.22), 0.13)], "col_coat", "spine", seg=S(16), flat=0.74)
    b.tube([((0, 0, 0.2), 0.13), ((0, 0.01, 0.36), 0.145), ((0, 0.02, 0.44), 0.11)], "col_coat", "chest", seg=S(16), flat=0.75)
    # HUNCH: a rounded back hump rising above the shoulder line behind the neck
    b.ellipsoid((0, 0.05, 0.43), (0.15, 0.09, 0.08), "col_coat", "chest", seg=(S(14), S(8)))
    for z in (0.08, 0.16, 0.24, 0.32):
        for x in (-0.05, 0.05):
            b.ellipsoid((x, -0.098, z), (0.008, 0.005, 0.008), "col_brass", "spine" if z < 0.2 else "chest", seg=(S(6), S(4)))
    b.box((0, -0.1, 0.0), (0.2, 0.02, 0.025), "col_black", "spine")  # belt line where the coat closes
    # long neck, angled forward
    b.tube([((0, 0.0, 0.42), 0.045), ((0, -0.04, 0.5), 0.04)], "col_fur", "neck", seg=S(10))
    # scarf wrapped high round the neck (covers the muzzle base on the head part too)
    b.tube([((0, -0.01, 0.43), 0.075), ((0, -0.035, 0.49), 0.068)], "col_scarf", "neck", seg=S(12))
    for s, sx in (("L", 1), ("R", -1)):
        b.ellipsoid((sx * 0.15, 0.01, 0.41), (0.06, 0.06, 0.05), "col_coat", "shoulder_" + s, seg=(S(10), S(6)))
        b.tube([((sx * 0.15, 0, 0.41), 0.048), ((sx * 0.17, 0.002, 0.27), 0.045), ((sx * 0.185, 0.008, 0.16), 0.042)], "col_coat", "upper_arm_" + s, seg=S(10))
        b.tube([((sx * 0.185, 0.008, 0.17), 0.043), ((sx * 0.192, 0.002, 0.03), 0.04), ((sx * 0.198, 0, -0.05), 0.04)], "col_coat", "forearm_" + s, seg=S(10))
        b.tube([((sx * 0.198, 0, -0.035), 0.044), ((sx * 0.199, 0, -0.065), 0.044)], "col_brass", "forearm_" + s, seg=S(10))  # cuff band
        H = "hand_" + s
        # furred paw-hands: same joints as Smiles, dark fur, short claws (bone)
        b.tube([((sx * 0.2, 0, -0.07), 0.024), ((sx * 0.2, 0, -0.105), 0.027)], "col_fur_dark", H, seg=S(8))
        b.tube([((sx * 0.2, 0.0, -0.095), 0.031), ((sx * 0.2, -0.002, -0.135), 0.042), ((sx * 0.2, -0.004, -0.17), 0.04)], "col_fur_dark", H, seg=S(10), flat=0.5, flat_axis=(1, 0, 0))
        b.tube([((sx * 0.192, -0.03, -0.11), 0.013), ((sx * 0.182, -0.05, -0.14), 0.012), ((sx * 0.176, -0.064, -0.162), 0.009), ((sx * 0.174, -0.068, -0.17), 0.004)], "col_fur_dark", "thumb_" + s, seg=S(6))
        b.tube([((sx * 0.2, -0.028, -0.168), 0.012), ((sx * 0.199, -0.031, -0.21), 0.011), ((sx * 0.197, -0.033, -0.24), 0.008), ((sx * 0.196, -0.034, -0.252), 0.003)], "col_fur_dark", "index_" + s, seg=S(6))
        for dy, ln in ((-0.004, 0.085), (0.016, 0.08), (0.034, 0.065)):
            b.tube([((sx * 0.2, dy, -0.17), 0.012), ((sx * 0.199, dy, -0.17 - ln * 0.6), 0.011), ((sx * 0.197, dy + 0.002, -0.17 - ln * 0.9), 0.008), ((sx * 0.196, dy + 0.002, -0.17 - ln), 0.003)], "col_bone", "fingers_" + s, seg=S(6))
    ob_body = b.finish(arm)

    h = P("Collector_Head")
    # JACKAL head: narrow skull, long tapering muzzle pointing forward, scarf pulled up over the muzzle
    h.ellipsoid((0, -0.0, 0.60), (0.08, 0.085, 0.075), "col_fur", "head", seg=(S(16), S(10)))
    h.tube([((0, -0.06, 0.575), 0.052), ((0, -0.13, 0.56), 0.035), ((0, -0.175, 0.55), 0.016)], "col_fur", "jaw", seg=S(12))  # muzzle
    h.ellipsoid((0, -0.183, 0.552), (0.014, 0.012, 0.011), "col_black", "jaw", seg=(S(8), S(5)))  # nose tip
    h.tube([((0, -0.05, 0.545), 0.062), ((0, -0.115, 0.545), 0.045)], "col_scarf", "jaw", seg=S(12))  # scarf over the mouth
    for sx in (-1, 1):
        h.ellipsoid((sx * 0.04, -0.07, 0.618), (0.014, 0.008, 0.008), "col_bone", "head", seg=(S(8), S(5)))  # pale eye
        h.ellipsoid((sx * 0.04, -0.075, 0.618), (0.006, 0.005, 0.006), "col_eye", "head", seg=(S(6), S(4)))
        h.ellipsoid((sx * 0.07, -0.01, 0.57), (0.03, 0.05, 0.035), "col_fur", "head", seg=(S(8), S(5)))  # cheek ruff
    bmesh.ops.translate(h.bm, verts=list(h.bm.verts), vec=Vector((0, -HEAD_FWD, -HEAD_DROP)))
    ob_head = h.finish(arm)

    er = P("Collector_Ears")
    # two tall pointed ears, splayed 14 deg out: the 48 px read
    for sx in (-1, 1):
        base = Vector((sx * 0.045, 0.01, 0.64))
        tip = Vector((sx * 0.07, 0.02, EAR_TOP))
        er.tube([(base, 0.032), ((base + tip) * 0.5, 0.022), (tip, 0.002)], "col_fur_dark", "visor", seg=S(8), flat=0.45, flat_axis=(0, 1, 0))
    bmesh.ops.translate(er.bm, verts=list(er.bm.verts), vec=Vector((0, -HEAD_FWD, -HEAD_DROP)))
    ob_ears = er.finish(arm)

    cl = P("Collector_Cloche")
    # glass cloche held by its brass knob, just in front of the fingertips (chip bone): bell + rim + knob
    c = Vector(bs.BONES["chip"][1]) + CLOCHE_OFF
    cl.ellipsoid(c + Vector((0, 0, -0.03)), (0.04, 0.04, 0.045), "col_glass", "chip", seg=(S(12), S(7)))
    cl.tube([(c + Vector((0, 0, -0.048)), 0.043), (c + Vector((0, 0, -0.04)), 0.043)], "col_brass", "chip", seg=S(12))
    cl.ellipsoid(c + Vector((0, 0, 0.018)), (0.011, 0.011, 0.011), "col_brass", "chip", seg=(S(8), S(5)))
    ob_cl = cl.finish(arm)
    return [ob_body, ob_head, ob_ears, ob_cl]


def run(mobile):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = bs.FPS
    for n, g in GREYS:
        m = bpy.data.materials.new(n)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (g ** 2.2, g ** 2.2, g ** 2.2, 1)
        bsdf.inputs["Roughness"].default_value = 0.85
    arm = bs.build_armature()
    objs = build_model(arm, mobile)
    bs.make_actions(arm)
    print("TRIS", "mobile" if mobile else "pc", bs.tri_count(objs), {o.name: bs.tri_count([o]) for o in objs})
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [arm]:
        o.select_set(True)
    path = os.path.join(OUT, "collector%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
