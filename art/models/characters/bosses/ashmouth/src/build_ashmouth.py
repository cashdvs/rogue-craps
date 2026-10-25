"""Ashmouth (F1 boss dealer) - GREY BLOCKOUT on the shared Smiles rig (same pipeline as build_pit_boss.py).

blender -b --factory-startup --python art/models/characters/bosses/ashmouth/src/build_ashmouth.py
-> ../ashmouth.glb (PC) + ../ashmouth_mobile.glb.  Straight swap for smiles.tscn.
BRIEF lists him as a Hero (Stoker) rig; the boss-dealer rule here is the shared Smiles rig, so this is the Stoker
silhouette (round stove body, short stovepipe, walrus moustache) on Smiles' bones. Rig gaps are listed in the README.
Prop: the board's own Hearth brazier, unlit (BoardTheme state), so there is NO hand prop and no duplicated brazier.
Slots: Ashmouth_Body, Ashmouth_Head, Ashmouth_Pipe (visor bone). The chip bone stays empty.
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

GREYS = [("ash_iron", 0.28), ("ash_iron_dark", 0.14), ("ash_skin", 0.58), ("ash_sleeve", 0.45), ("ash_brass", 0.66),
         ("ash_soot", 0.20), ("ash_coal", 0.50), ("ash_eye", 0.05), ("ash_tash", 0.78)]
bs.MATS = [n for n, _ in GREYS]
rot = bs.rot
PIPE_TOP = float(os.environ.get("PIPE_TOP", "0.75"))  # v2: brim at 0.64 -> 11 cm pipe
HEAD_DROP = float(os.environ.get("HEAD_DROP", "0.04"))  # v2: extra drop (on top of the built-in 5 cm) so the taller pipe fits the phone frame

# v2 RIG FORK (AD): Smiles' skeleton + exactly ONE extra bone, the firebox door hinge (vertical axis at the door's
# stage-left edge, child of spine). Added in-process only; build_smiles.py is untouched, so Smiles is unaffected.
DOOR_HINGE = (0.075, -0.19, 0.12)
bs.BONES["firebox_door"] = ("spine", DOOR_HINGE)
DOOR_OPEN = float(os.environ.get("DOOR_OPEN", "105"))
# taunt: door flings open on the wind-up -> roar, holds while he points, slams shut on the wind-back
_DOOR = {0.0: 0, 0.12: 0, 0.19: DOOR_OPEN * 1.08, 0.25: DOOR_OPEN, 1.0: DOOR_OPEN, 1.2: 0, 1.4: 0}
_L, _keys, _loop = bs.CLIPS["taunt"]
bs.CLIPS["taunt"] = (_L, [(t, {**p, "firebox_door": (0, 0, _DOOR.get(t, DOOR_OPEN if 0.19 <= t <= 1.0 else 0))}) for t, p in _keys], _loop)


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    body = P("Ashmouth_Body")
    # ROUND STOVE BODY: one big pot-belly sphere from the rail to the chin, iron feet ring, firebox door + grate
    body.tube([((0, 0, -0.22), 0.17), ((0, 0, -0.10), 0.19)], "ash_iron_dark", "spine", seg=S(18), flat=0.8)
    body.ellipsoid((0, 0.0, 0.14), (0.23, 0.19, 0.24), "ash_iron", "spine", seg=(S(22), S(14)))
    body.ellipsoid((0, 0.0, 0.36), (0.20, 0.165, 0.13), "ash_iron", "chest", seg=(S(20), S(10)))
    body.tube([((0, 0, 0.24), 0.222), ((0, 0, 0.26), 0.222)], "ash_brass", "chest", seg=S(22), flat=0.84, caps=False)  # brass belly band
    body.box((0, -0.212, 0.12), (0.15, 0.012, 0.13), "ash_iron_dark", "firebox_door")  # firebox door (cold), on the v2 hinge bone
    body.box((0, -0.18, 0.12), (0.13, 0.03, 0.11), "ash_soot", "spine")  # firebox mouth (dark, seen when the door is open)
    for i in range(4):
        body.box((-0.045 + i * 0.03, -0.199, 0.12), (0.008, 0.01, 0.09), "ash_coal", "spine")  # grate bars (dull coal, unlit)
    body.ellipsoid((-0.06, -0.222, 0.12), (0.012, 0.01, 0.012), "ash_brass", "firebox_door", seg=(S(8), S(5)))  # door latch
    # no neck: a squat collar ring of iron straight under the jaw
    body.tube([((0, 0, 0.44), 0.11), ((0, -0.01, 0.50), 0.095)], "ash_iron_dark", "neck", seg=S(16), flat=0.9)
    for s, sx in (("L", 1), ("R", -1)):
        # barrel shoulders: big vest-coloured caps sitting high, then shirt sleeves rolled to the elbow, bare forearms
        body.ellipsoid((sx * 0.15, 0.0, 0.40), (0.085, 0.078, 0.07), "ash_iron", "shoulder_" + s, seg=(S(12), S(8)))
        body.tube([((sx * 0.16, 0, 0.395), 0.058), ((sx * 0.172, 0.002, 0.27), 0.055), ((sx * 0.185, 0.008, 0.16), 0.05)], "ash_sleeve", "upper_arm_" + s, seg=S(12))
        body.tube([((sx * 0.185, 0.008, 0.17), 0.056), ((sx * 0.186, 0.008, 0.13), 0.054)], "ash_sleeve", "forearm_" + s, seg=S(12))
        body.ellipsoid((sx * 0.185, 0.008, 0.15), (0.044, 0.044, 0.044), "ash_skin", "forearm_" + s, seg=(S(10), S(6)))
        body.tube([((sx * 0.185, 0.008, 0.15), 0.044), ((sx * 0.192, 0.002, 0.03), 0.048), ((sx * 0.198, 0, -0.06), 0.034)], "ash_skin", "forearm_" + s, seg=S(12))
        # hand: same bones and joint spots as Smiles; thick blunt fingers, no claws
        H = "hand_" + s
        body.tube([((sx * 0.2, 0, -0.07), 0.026), ((sx * 0.2, 0, -0.105), 0.03)], "ash_skin", H, seg=S(8))
        body.tube([((sx * 0.2, 0.0, -0.095), 0.034), ((sx * 0.2, -0.002, -0.135), 0.048), ((sx * 0.2, -0.004, -0.17), 0.045)], "ash_skin", H, seg=S(10), flat=0.5, flat_axis=(1, 0, 0))
        body.tube([((sx * 0.192, -0.03, -0.11), 0.016), ((sx * 0.182, -0.05, -0.14), 0.014), ((sx * 0.176, -0.064, -0.162), 0.011), ((sx * 0.174, -0.068, -0.17), 0.005)],
                  "ash_skin", "thumb_" + s, seg=S(7))
        body.tube([((sx * 0.2, -0.028, -0.168), 0.0135), ((sx * 0.199, -0.031, -0.21), 0.012), ((sx * 0.197, -0.033, -0.24), 0.01), ((sx * 0.196, -0.034, -0.25), 0.004)],
                  "ash_skin", "index_" + s, seg=S(7))
        for dy, ln in ((-0.004, 0.085), (0.017, 0.08), (0.036, 0.065)):
            body.tube([((sx * 0.2, dy, -0.17), 0.0135), ((sx * 0.199, dy, -0.17 - ln * 0.6), 0.012), ((sx * 0.197, dy + 0.002, -0.17 - ln * 0.95), 0.009), ((sx * 0.196, dy + 0.002, -0.17 - ln), 0.004)],
                      "ash_skin", "fingers_" + s, seg=S(6))
    ob_body = body.finish(arm)

    head = P("Ashmouth_Head")
    # round grumpy head 5 cm low on its bones; WALRUS MOUSTACHE droops past the jaw on both sides (48 px key)
    head.ellipsoid((0, -0.01, 0.575), (0.092, 0.088, 0.088), "ash_skin", "head", seg=(S(18), S(12)))
    head.ellipsoid((0, -0.03, 0.52), (0.08, 0.07, 0.045), "ash_skin", "jaw", seg=(S(14), S(8)))
    for sx in (-1, 1):
        head.ellipsoid((sx * 0.032, -0.088, 0.592), (0.011, 0.005, 0.006), "ash_eye", "head", seg=(S(8), S(4)))
        head.box((sx * 0.034, -0.088, 0.607), (0.034, 0.012, 0.01), "ash_soot", "head", rot=rot(0, sx * 14, 0))  # scowl brow
        head.tube([((sx * 0.01, -0.098, 0.548), 0.016), ((sx * 0.055, -0.098, 0.53), 0.02), ((sx * 0.105, -0.075, 0.49), 0.014), ((sx * 0.118, -0.06, 0.46), 0.006)],
                  "ash_tash", "jaw", seg=S(8))
    head.ellipsoid((0, -0.102, 0.565), (0.02, 0.02, 0.02), "ash_skin", "head", seg=(S(10), S(6)))  # nose
    bmesh.ops.translate(head.bm, verts=list(head.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_head = head.finish(arm)

    pipe = P("Ashmouth_Pipe")
    # SHORT STOVEPIPE hat on the visor bone: flat iron brim, straight pipe, rolled rim, soot band. Straight up (no back sweep)
    pipe.tube([((0, 0, 0.635), 0.115), ((0, 0, 0.645), 0.115)], "ash_iron_dark", "visor", seg=S(18), flat=1.0)
    pipe.tube([((0, 0, 0.64), 0.072), ((0, 0, PIPE_TOP), 0.068)], "ash_iron", "visor", seg=S(14), flat=1.0)
    pipe.tube([((0, 0, PIPE_TOP - 0.004), 0.076), ((0, 0, PIPE_TOP + 0.006), 0.076)], "ash_iron_dark", "visor", seg=S(14), flat=1.0)
    pipe.tube([((0, 0, 0.655), 0.0725), ((0, 0, 0.67), 0.0715)], "ash_soot", "visor", seg=S(14), flat=1.0, caps=False)
    bmesh.ops.translate(pipe.bm, verts=list(pipe.bm.verts), vec=Vector((0, 0, -HEAD_DROP)))
    ob_pipe = pipe.finish(arm)
    return [ob_body, ob_head, ob_pipe]


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
    path = os.path.join(OUT, "ashmouth%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
