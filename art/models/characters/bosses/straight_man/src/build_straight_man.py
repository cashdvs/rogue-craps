"""The Straight Man - GREY BLOCKOUT on the shared Smiles rig (straight scene swap, armature "Smiles").

blender -b --factory-startup --python art/models/characters/bosses/straight_man/src/build_straight_man.py
-> ../straight_man.glb (PC) + ../straight_man_mobile.glb

Design (BRIEF): tallest, thinnest rectangle; flat-top; rod held as a strict diagonal. Deadpan tailor, chalk
pinstripe + oxblood. Prop: tailor's rod with 3 oxblood-taped sections (raps the felt). Grey values only.
Slots: StraightMan_Body, StraightMan_Head, StraightMan_Hair (flat-top, on "visor"), StraightMan_Rod (on "chip").
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

GREYS = [("sm_skin", 0.62), ("sm_suit", 0.34), ("sm_chalk", 0.72), ("sm_shirt", 0.85), ("sm_oxblood", 0.22),
         ("sm_black", 0.10), ("sm_hair", 0.18), ("sm_eye", 0.05), ("sm_rod", 0.66)]
bs.MATS = [n for n, _ in GREYS]
rot = bs.rot
E = lambda k, d: float(os.environ.get(k, d))
HEAD_DROP = E("HEAD_DROP", "0.05")
FLAT_TOP = E("FLAT_TOP", "0.705")
ROD_OFF = Vector(tuple(float(x) for x in os.environ.get("ROD_OFF", "0,-0.045,-0.06").split(",")))
ROD_LEN = E("ROD_LEN", "0.30")
ROD_ANG = E("ROD_ANG", "45")
ROD_SHIFT = E("ROD_SHIFT", "-0.04")  # grip 4 cm below the rod centre (rod sits mostly above the hand): keeps the rod in frame in taunt + off the head in cheat


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    b = P("StraightMan_Body")
    # THIN RECTANGLE: straight trousers + a long, narrow, square-shouldered jacket (no taper, no flare)
    b.tube([((0, 0, -0.24), 0.105), ((0, 0, 0.0), 0.105)], "sm_suit", "spine", seg=S(14), flat=0.7)
    b.tube([((0, 0, -0.03), 0.112), ((0, 0, 0.22), 0.115)], "sm_suit", "spine", seg=S(16), flat=0.72)
    b.tube([((0, 0, 0.2), 0.115), ((0, 0, 0.40), 0.12), ((0, 0, 0.45), 0.10)], "sm_suit", "chest", seg=S(16), flat=0.72)
    b.box((0, 0.0, 0.43), (0.27, 0.15, 0.05), "sm_suit", "chest")  # square shoulder line (rectangle top corners)
    # chalk pinstripes (front), shirt V, oxblood tie + pocket square
    for x in (-0.075, -0.045, 0.045, 0.075):
        b.box((x, -0.083, 0.13), (0.004, 0.006, 0.6 if False else 0.52), "sm_chalk", "spine")
    b.box((0, -0.086, 0.38), (0.05, 0.01, 0.11), "sm_shirt", "chest")
    b.box((0, -0.093, 0.35), (0.018, 0.008, 0.14), "sm_oxblood", "chest")
    b.box((0.06, -0.088, 0.36), (0.03, 0.008, 0.015), "sm_oxblood", "chest")
    for z in (0.05, 0.13):
        b.ellipsoid((0.0, -0.087, z), (0.007, 0.005, 0.007), "sm_black", "spine", seg=(S(6), S(4)))
    # long neck column + high collar (he is the tall one)
    b.tube([((0, 0.0, 0.42), 0.042), ((0, -0.005, 0.52), 0.038)], "sm_skin", "neck", seg=S(10))
    b.tube([((0, 0.0, 0.44), 0.05), ((0, -0.004, 0.48), 0.046)], "sm_shirt", "neck", seg=S(10), caps=False)
    for s, sx in (("L", 1), ("R", -1)):
        b.tube([((sx * 0.15, 0, 0.42), 0.04), ((sx * 0.17, 0.002, 0.27), 0.038), ((sx * 0.185, 0.008, 0.16), 0.036)], "sm_suit", "upper_arm_" + s, seg=S(10))
        b.tube([((sx * 0.185, 0.008, 0.17), 0.037), ((sx * 0.192, 0.002, 0.03), 0.035), ((sx * 0.198, 0, -0.05), 0.034)], "sm_suit", "forearm_" + s, seg=S(10))
        b.tube([((sx * 0.198, 0, -0.04), 0.03), ((sx * 0.199, 0, -0.065), 0.03)], "sm_shirt", "forearm_" + s, seg=S(8))  # cuff
        H = "hand_" + s
        b.tube([((sx * 0.2, 0, -0.07), 0.022), ((sx * 0.2, 0, -0.105), 0.024)], "sm_skin", H, seg=S(8))
        b.tube([((sx * 0.2, 0.0, -0.095), 0.028), ((sx * 0.2, -0.002, -0.135), 0.038), ((sx * 0.2, -0.004, -0.17), 0.035)], "sm_skin", H, seg=S(10), flat=0.5, flat_axis=(1, 0, 0))
        b.tube([((sx * 0.192, -0.03, -0.11), 0.012), ((sx * 0.182, -0.05, -0.14), 0.011), ((sx * 0.176, -0.064, -0.162), 0.009), ((sx * 0.174, -0.068, -0.17), 0.004)], "sm_skin", "thumb_" + s, seg=S(6))
        b.tube([((sx * 0.2, -0.028, -0.168), 0.011), ((sx * 0.199, -0.031, -0.21), 0.01), ((sx * 0.197, -0.033, -0.245), 0.008), ((sx * 0.196, -0.034, -0.255), 0.003)], "sm_skin", "index_" + s, seg=S(6))
        for dy, ln in ((-0.004, 0.09), (0.016, 0.085), (0.034, 0.07)):
            b.tube([((sx * 0.2, dy, -0.17), 0.011), ((sx * 0.199, dy, -0.17 - ln * 0.6), 0.01), ((sx * 0.197, dy + 0.002, -0.17 - ln * 0.95), 0.008), ((sx * 0.196, dy + 0.002, -0.17 - ln), 0.003)], "sm_skin", "fingers_" + s, seg=S(6))
    ob_body = b.finish(arm)

    h = P("StraightMan_Head")
    # long narrow deadpan head: taller than wide, flat mouth line, level brows
    h.ellipsoid((0, -0.008, 0.60), (0.072, 0.082, 0.1), "sm_skin", "head", seg=(S(18), S(12)))
    h.ellipsoid((0, -0.02, 0.53), (0.062, 0.07, 0.045), "sm_skin", "jaw", seg=(S(14), S(8)))
    for sx in (-1, 1):
        h.ellipsoid((sx * 0.072, -0.0, 0.595), (0.01, 0.018, 0.026), "sm_skin", "head", seg=(S(6), S(5)))
        h.ellipsoid((sx * 0.028, -0.083, 0.615), (0.01, 0.005, 0.004), "sm_eye", "head", seg=(S(6), S(4)))
        h.box((sx * 0.03, -0.085, 0.632), (0.03, 0.008, 0.006), "sm_hair", "head")  # level brows
    h.ellipsoid((0, -0.093, 0.59), (0.012, 0.016, 0.022), "sm_skin", "head", seg=(S(8), S(5)))
    h.box((0, -0.083, 0.545), (0.04, 0.008, 0.004), "sm_eye", "jaw")  # dead-straight mouth
    bmesh.ops.translate(h.bm, verts=list(h.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_head = h.finish(arm)

    hr = P("StraightMan_Hair")
    # FLAT-TOP: a square brush block, vertical sides flush with the head width, dead-level top
    zt = FLAT_TOP - HEAD_DROP
    hr.box((0, 0.005, zt - 0.03), (0.15, 0.16, 0.06), "sm_hair", "visor")  # bottom edge sits above the brows
    hr.box((0, 0.035, 0.6 - HEAD_DROP), (0.13, 0.1, 0.09), "sm_hair", "visor")  # back of head / short sides
    ob_hair = hr.finish(arm)

    rd = P("StraightMan_Rod")
    # tailor's rod, a STRICT 45 deg diagonal in the picture plane (upper end out to his right, lower end in + down),
    # gripped just under the fingertips (chip bone) so it rests off the fingers; 3 oxblood tape bands
    c = Vector(bs.BONES["chip"][1]) + ROD_OFF
    a = math.radians(ROD_ANG)
    d = Vector((-math.sin(a), 0, math.cos(a)))
    c = c - d * ROD_SHIFT
    p0, p1 = c - d * (ROD_LEN * 0.5), c + d * (ROD_LEN * 0.5)
    rd.tube([(p0, 0.008), (p1, 0.008)], "sm_rod", "chip", seg=S(6))
    for f in (0.2, 0.5, 0.8):
        q0 = p0 + (p1 - p0) * (f - 0.04); q1 = p0 + (p1 - p0) * (f + 0.04)
        rd.tube([(q0, 0.0095), (q1, 0.0095)], "sm_oxblood", "chip", seg=S(6))
    ob_rd = rd.finish(arm)
    return [ob_body, ob_head, ob_hair, ob_rd]


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
    path = os.path.join(OUT, "straight_man%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
