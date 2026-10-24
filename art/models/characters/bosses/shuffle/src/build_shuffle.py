"""Madame Shuffle (boss dealer) - GREY BLOCKOUT on the shared Smiles rig (same pipeline as build_pit_boss.py).

blender -b --factory-startup --python art/models/characters/bosses/shuffle/src/build_shuffle.py
-> ../shuffle.glb (PC) + ../shuffle_mobile.glb.  Straight swap for smiles.tscn.
Slots: Shuffle_Body, Shuffle_Head, Shuffle_Hair (visor bone), Shuffle_Cards (chip bone).
Design (BRIEF): towering swept-up hair, long opera gloves, high neckline, silky card sharp; prop = gloved hand
with 3 fanned cards (card-flick on the swap). Greys only; plain card backs (no suits/pips/marks).
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

GREYS = [("shuffle_skin", 0.66), ("shuffle_gown", 0.34), ("shuffle_glove", 0.86), ("shuffle_hair", 0.22),
         ("shuffle_trim", 0.55), ("shuffle_eye", 0.05), ("shuffle_lip", 0.40), ("shuffle_card", 0.92), ("shuffle_cardback", 0.48)]
bs.MATS = [n for n, _ in GREYS]
rot = bs.rot
HAIR_BACK = float(os.environ.get("HAIR_BACK", "0.03"))
HAIR_TOP = float(os.environ.get("HAIR_TOP", "0.725"))
HEAD_DROP = float(os.environ.get("HEAD_DROP", "0.03"))  # extra drop (on top of the 5 cm built in) so the tower fits the phone frame
CARD_OFF = tuple(float(x) for x in os.environ.get("CARD_OFF", "0,-0.03,-0.075").split(","))


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    body = P("Shuffle_Body")
    # long column gown: narrow waist, flared skirt to the rail, slim shoulders
    body.tube([((0, 0, -0.22), 0.16), ((0, 0, -0.08), 0.13), ((0, 0, 0.02), 0.105)], "shuffle_gown", "spine", seg=S(18), flat=0.75)
    body.tube([((0, 0, 0.0), 0.105), ((0, 0, 0.12), 0.095), ((0, 0, 0.22), 0.12)], "shuffle_gown", "spine", seg=S(18), flat=0.72)
    body.tube([((0, 0, 0.2), 0.12), ((0, 0, 0.32), 0.135), ((0, 0, 0.40), 0.12), ((0, 0, 0.44), 0.06)], "shuffle_gown", "chest", seg=S(18), flat=0.7)
    # RAISED NECKLINE: a high stand collar of gown up the neck to under the jaw, trim band at the top edge
    body.tube([((0, 0, 0.40), 0.065), ((0, -0.004, 0.45), 0.05), ((0, -0.006, 0.495), 0.052)], "shuffle_gown", "neck", seg=S(14), flat=0.9)
    body.tube([((0, -0.006, 0.488), 0.056), ((0, -0.006, 0.50), 0.057)], "shuffle_trim", "neck", seg=S(14), flat=0.9, caps=False)
    body.box((0, -0.10, 0.30), (0.02, 0.012, 0.16), "shuffle_trim", "chest")  # bodice seam (vertical break at 48 px)
    for s, sx in (("L", 1), ("R", -1)):
        body.ellipsoid((sx * 0.13, 0.0, 0.40), (0.05, 0.05, 0.045), "shuffle_gown", "shoulder_" + s, seg=(S(10), S(6)))
        body.tube([((sx * 0.14, 0, 0.40), 0.04), ((sx * 0.155, 0.002, 0.30), 0.036)], "shuffle_skin", "upper_arm_" + s, seg=S(10))
        # OPERA GLOVE from mid upper arm to the fingertips (the light grey value is her read)
        body.tube([((sx * 0.155, 0.002, 0.31), 0.038), ((sx * 0.17, 0.006, 0.16), 0.034)], "shuffle_glove", "upper_arm_" + s, seg=S(10))
        body.tube([((sx * 0.17, 0.006, 0.17), 0.034), ((sx * 0.172, 0.006, 0.13), 0.032)], "shuffle_glove", "forearm_" + s, seg=S(10))
        body.tube([((sx * 0.172, 0.006, 0.15), 0.032), ((sx * 0.185, 0.002, 0.03), 0.03), ((sx * 0.198, 0, -0.06), 0.022)], "shuffle_glove", "forearm_" + s, seg=S(10))
        H = "hand_" + s
        body.tube([((sx * 0.2, 0, -0.07), 0.019), ((sx * 0.2, 0, -0.10), 0.022)], "shuffle_glove", H, seg=S(8))
        body.tube([((sx * 0.2, 0.0, -0.095), 0.025), ((sx * 0.2, -0.002, -0.13), 0.036), ((sx * 0.2, -0.004, -0.16), 0.033)], "shuffle_glove", H, seg=S(10), flat=0.45, flat_axis=(1, 0, 0))
        body.tube([((sx * 0.194, -0.024, -0.11), 0.011), ((sx * 0.186, -0.042, -0.14), 0.009), ((sx * 0.18, -0.054, -0.16), 0.004)], "shuffle_glove", "thumb_" + s, seg=S(6))
        body.tube([((sx * 0.2, -0.02, -0.158), 0.009), ((sx * 0.199, -0.022, -0.21), 0.008), ((sx * 0.198, -0.023, -0.245), 0.003)], "shuffle_glove", "index_" + s, seg=S(6))
        for dy, ln in ((-0.002, 0.09), (0.014, 0.085), (0.028, 0.07)):  # long slim fingers
            body.tube([((sx * 0.2, dy, -0.16), 0.009), ((sx * 0.199, dy, -0.16 - ln * 0.7), 0.008), ((sx * 0.198, dy, -0.16 - ln), 0.003)], "shuffle_glove", "fingers_" + s, seg=S(6))
    ob_body = body.finish(arm)

    head = P("Shuffle_Head")
    # narrow oval face, sharp chin; geometry 5 cm low on its bones (like Pit Boss) to buy room for the hair tower
    head.ellipsoid((0, -0.012, 0.575), (0.072, 0.08, 0.088), "shuffle_skin", "head", seg=(S(18), S(12)))
    head.ellipsoid((0, -0.035, 0.515), (0.05, 0.055, 0.04), "shuffle_skin", "jaw", seg=(S(12), S(8)))
    for sx in (-1, 1):
        head.ellipsoid((sx * 0.028, -0.083, 0.585), (0.012, 0.005, 0.005), "shuffle_eye", "head", seg=(S(8), S(4)))
        head.box((sx * 0.03, -0.084, 0.598), (0.026, 0.006, 0.004), "shuffle_eye", "head", rot=rot(0, sx * -12, 0))  # arched brow
    head.ellipsoid((0, -0.093, 0.56), (0.009, 0.012, 0.016), "shuffle_skin", "head", seg=(S(8), S(5)))
    head.box((0, -0.085, 0.525), (0.026, 0.008, 0.006), "shuffle_lip", "jaw")
    bmesh.ops.translate(head.bm, verts=list(head.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_head = head.finish(arm)

    hair = P("Shuffle_Hair")
    # swept-up tower on the visor bone: crown cap, then stacked lobes rising AND sweeping back (+Y) so the top
    # stays inside the phone frame; a forward curl at the front gives the 48 px "question mark" read
    hair.ellipsoid((0, 0.0, 0.61), (0.08, 0.085, 0.06), "shuffle_hair", "visor", seg=(S(16), S(8)))
    n = 4
    for i in range(n):
        t = (i + 1) / n
        z = 0.63 + (HAIR_TOP - 0.63) * t
        y = 0.01 + HAIR_BACK * t
        r = 0.07 - 0.02 * t
        hair.ellipsoid((0, y, z), (r, r * 1.05, 0.05), "shuffle_hair", "visor", seg=(S(14), S(7)), rot=rot(-15 * t, 0, 0))
    hair.tube([((0, -0.05, 0.655), 0.03), ((0, -0.075, 0.69), 0.024), ((0, -0.06, 0.72), 0.018)], "shuffle_hair", "visor", seg=S(10))  # front curl
    hair.tube([((-0.09, -0.06, 0.53), 0.008), ((-0.10, -0.07, 0.48), 0.007), ((-0.095, -0.075, 0.45), 0.004)], "shuffle_hair", "visor", seg=S(6))  # one ringlet
    bmesh.ops.translate(hair.bm, verts=list(hair.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_hair = hair.finish(arm)

    cd = P("Shuffle_Cards")
    # 3 fanned cards held below the fingers (off the glove at rest), in the bone's Y-Z plane like the chip; plain backs
    c = Vector(bs.BONES["chip"][1]) + Vector(CARD_OFF)
    W, Hh, T = 0.040, 0.058, 0.002
    for k, ang in enumerate((-18, 0, 18)):
        cc = c + Vector((k * 0.0025 - 0.0025, 0, 0))
        cd.box(cc, (T, W, Hh), "shuffle_card", "chip", rot=rot(ang, 0, 0))
        cd.box(cc + Vector((-0.0012, 0, 0)), (0.0008, W * 0.8, Hh * 0.85), "shuffle_cardback", "chip", rot=rot(ang, 0, 0))
    ob_cd = cd.finish(arm)
    return [ob_body, ob_head, ob_hair, ob_cd]


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
    path = os.path.join(OUT, "shuffle%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
