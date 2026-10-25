"""The Bloodletter - GREY BLOCKOUT on the shared Smiles rig (straight scene swap, armature "Smiles").

blender -b --factory-startup --python art/models/characters/bosses/bloodletter/src/build_bloodletter.py
-> ../bloodletter.glb (PC) + ../bloodletter_mobile.glb

Design (BRIEF): polite barber-surgeon. Very tall stiff collar, round spectacles, apron bib; a silver lancet held over a
twin-spout bowl, held low and wide. Silhouette = a BELL (round dome head, flared collar, wide apron hem) vs the Straight
Man's narrow flat-top column. AD palette: brass, bone, greys only - no red, no blood imagery.
Slots: Bloodletter_Body, Bloodletter_Head, Bloodletter_Specs (on "visor"), Bloodletter_Lancet (bowl + lancet, on "chip").
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

GREYS = [("bl_skin", 0.62), ("bl_coat", 0.30), ("bl_apron", 0.80), ("bl_collar", 0.90), ("bl_brass", 0.70), ("bl_bone", 0.88),
         ("bl_black", 0.10), ("bl_hair", 0.45), ("bl_eye", 0.05), ("bl_glass", 0.55), ("bl_silver", 0.82), ("bl_pewter", 0.58)]
bs.MATS = [n for n, _ in GREYS]
E = lambda k, d: float(os.environ.get(k, d))
HEAD_DROP = E("HEAD_DROP", "0.02")
BOWL_OFF = Vector(tuple(float(x) for x in os.environ.get("BOWL_OFF", "0.0,-0.09,-0.12").split(",")))
BOWL_R = E("BOWL_R", "0.06")


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    b = P("Bloodletter_Body")
    # BELL: stout trousers, a waistcoat torso, and an apron that flares to a wide hem
    b.tube([((0, 0, -0.24), 0.11), ((0, 0, 0.0), 0.12)], "bl_coat", "spine", seg=S(14), flat=0.75)
    b.tube([((0, 0, -0.02), 0.13), ((0, 0, 0.2), 0.135)], "bl_coat", "spine", seg=S(16), flat=0.75)
    b.tube([((0, 0, 0.18), 0.135), ((0, 0, 0.36), 0.125), ((0, 0, 0.42), 0.09)], "bl_coat", "chest", seg=S(16), flat=0.75)
    # apron skirt (front half-cone, wide hem) + bib up to the chest, bone ties + brass buckles
    b.tube([((0, -0.03, 0.16), 0.13), ((0, -0.03, -0.05), 0.17), ((0, -0.03, -0.24), 0.21)], "bl_apron", "spine", seg=S(16), flat=0.55, caps=False)
    b.box((0, -0.105, 0.29), (0.15, 0.012, 0.2), "bl_apron", "chest")
    for sx in (-1, 1):
        b.box((sx * 0.07, -0.1, 0.4), (0.014, 0.01, 0.05), "bl_bone", "chest")
        b.box((sx * 0.07, -0.113, 0.375), (0.022, 0.006, 0.016), "bl_brass", "chest")
    b.box((0, -0.115, 0.26), (0.07, 0.006, 0.04), "bl_pewter", "chest")  # bib pocket
    # VERY TALL STIFF COLLAR: a starched funnel flaring out from neck to under the ears
    col = [((0, 0.0, 0.40), 0.05), ((0, 0.0, 0.46), 0.056), ((0, 0.0, 0.51), 0.066), ((0, 0.004, 0.545 - HEAD_DROP), 0.088)]
    b.tube(col, "bl_collar", "neck", seg=S(14), caps=False)
    b.tube(col[::-1], "bl_collar", "neck", seg=S(14), caps=False)  # reversed winding = double-sided open funnel (else culled)
    b.tube([((0, 0.0, 0.40), 0.05), ((0, 0.0, 0.44), 0.05)], "bl_brass", "neck", seg=S(10), caps=False)  # collar stud band
    for s, sx in (("L", 1), ("R", -1)):
        b.tube([((sx * 0.15, 0, 0.40), 0.045), ((sx * 0.17, 0.002, 0.27), 0.042), ((sx * 0.185, 0.008, 0.16), 0.038)], "bl_coat", "upper_arm_" + s, seg=S(10))
        b.tube([((sx * 0.185, 0.008, 0.17), 0.038), ((sx * 0.192, 0.002, 0.03), 0.036), ((sx * 0.198, 0, -0.05), 0.034)], "bl_apron", "forearm_" + s, seg=S(10))  # rolled shirt sleeves
        b.tube([((sx * 0.198, 0, -0.04), 0.03), ((sx * 0.199, 0, -0.065), 0.03)], "bl_bone", "forearm_" + s, seg=S(8))
        H = "hand_" + s
        b.tube([((sx * 0.2, 0, -0.07), 0.022), ((sx * 0.2, 0, -0.105), 0.024)], "bl_skin", H, seg=S(8))
        b.tube([((sx * 0.2, 0.0, -0.095), 0.028), ((sx * 0.2, -0.002, -0.135), 0.038), ((sx * 0.2, -0.004, -0.17), 0.035)], "bl_skin", H, seg=S(10), flat=0.5, flat_axis=(1, 0, 0))
        b.tube([((sx * 0.192, -0.03, -0.11), 0.012), ((sx * 0.182, -0.05, -0.14), 0.011), ((sx * 0.176, -0.064, -0.162), 0.009), ((sx * 0.174, -0.068, -0.17), 0.004)], "bl_skin", "thumb_" + s, seg=S(6))
        b.tube([((sx * 0.2, -0.028, -0.168), 0.011), ((sx * 0.199, -0.031, -0.21), 0.01), ((sx * 0.197, -0.033, -0.245), 0.008), ((sx * 0.196, -0.034, -0.255), 0.003)], "bl_skin", "index_" + s, seg=S(6))
        for dy, ln in ((-0.004, 0.09), (0.016, 0.085), (0.034, 0.07)):
            b.tube([((sx * 0.2, dy, -0.17), 0.011), ((sx * 0.199, dy, -0.17 - ln * 0.6), 0.01), ((sx * 0.197, dy + 0.002, -0.17 - ln * 0.95), 0.008), ((sx * 0.196, dy + 0.002, -0.17 - ln), 0.003)], "bl_skin", "fingers_" + s, seg=S(6))
    ob_body = b.finish(arm)

    h = P("Bloodletter_Head")
    # ROUND dome head (bald crown, grey side tufts), polite small smile
    h.ellipsoid((0, -0.005, 0.60), (0.082, 0.085, 0.085), "bl_skin", "head", seg=(S(18), S(12)))
    h.ellipsoid((0, -0.018, 0.545), (0.066, 0.07, 0.04), "bl_skin", "jaw", seg=(S(14), S(8)))
    for sx in (-1, 1):
        h.ellipsoid((sx * 0.08, 0.0, 0.59), (0.011, 0.018, 0.024), "bl_skin", "head", seg=(S(6), S(5)))
        h.ellipsoid((sx * 0.07, 0.025, 0.615), (0.025, 0.05, 0.03), "bl_hair", "head", seg=(S(8), S(6)))  # side tufts
        h.ellipsoid((sx * 0.03, -0.082, 0.605), (0.008, 0.005, 0.006), "bl_eye", "head", seg=(S(6), S(4)))
        h.box((sx * 0.03, -0.083, 0.632), (0.026, 0.008, 0.005), "bl_hair", "head")
    h.ellipsoid((0, -0.092, 0.585), (0.012, 0.015, 0.018), "bl_skin", "head", seg=(S(8), S(5)))
    h.box((0, -0.082, 0.552), (0.03, 0.008, 0.004), "bl_eye", "jaw")
    bmesh.ops.translate(h.bm, verts=list(h.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_head = h.finish(arm)

    sp = P("Bloodletter_Specs")
    # ROUND SPECTACLES: brass rims (short tubes facing camera) + glass discs + bridge + arms
    z = 0.605 - HEAD_DROP
    for sx in (-1, 1):
        sp.tube([((sx * 0.03, -0.088, z), 0.022), ((sx * 0.03, -0.094, z), 0.022)], "bl_brass", "visor", seg=S(14), caps=False)
        sp.tube([((sx * 0.03, -0.09, z), 0.018), ((sx * 0.03, -0.092, z), 0.018)], "bl_glass", "visor", seg=S(12))
        sp.box((sx * 0.075, -0.05, z + 0.005), (0.004, 0.07, 0.004), "bl_brass", "visor")
    sp.box((0, -0.093, z + 0.006), (0.02, 0.004, 0.004), "bl_brass", "visor")
    ob_specs = sp.finish(arm)

    pr = P("Bloodletter_Lancet")
    # twin-spout bowl (pewter, brass rim) held low under the hand; silver lancet resting across the rim
    c = Vector(bs.BONES["chip"][1]) + BOWL_OFF
    r = BOWL_R
    pr.ellipsoid(c, (r, r * 0.8, r * 0.42), "bl_pewter", "chip", seg=(S(14), S(6)))
    pr.tube([(c + Vector((0, 0, r * 0.3)), r * 1.02), (c + Vector((0, 0, r * 0.4)), r * 1.0)], "bl_brass", "chip", seg=S(14), caps=False)
    for sx in (-1, 1):
        pr.tube([(c + Vector((sx * r * 0.85, 0, r * 0.15)), 0.012), (c + Vector((sx * r * 1.45, 0, r * 0.4)), 0.007)], "bl_pewter", "chip", seg=S(6))
    lz = c.z + r * 0.48
    pr.tube([(Vector((c.x - r * 0.9, c.y - 0.01, lz)), 0.006), (Vector((c.x - r * 0.1, c.y - 0.01, lz)), 0.006)], "bl_bone", "chip", seg=S(6))  # bone handle
    pr.tube([(Vector((c.x - r * 0.1, c.y - 0.01, lz)), 0.005), (Vector((c.x + r * 0.7, c.y - 0.01, lz)), 0.0015)], "bl_silver", "chip", seg=S(6))  # silver blade
    ob_pr = pr.finish(arm)
    return [ob_body, ob_head, ob_specs, ob_pr]


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
    path = os.path.join(OUT, "bloodletter%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
