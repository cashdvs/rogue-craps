"""The Pit Boss (Floor 1 boss dealer) - GREY BLOCKOUT on the shared Smiles rig.

blender -b --factory-startup --python art/models/characters/bosses/pit_boss/src/build_pit_boss.py
-> ../pit_boss.glb (PC) + ../pit_boss_mobile.glb

Reuses build_smiles.py verbatim for the skeleton (29 deform bones + glow_* bones, same names, rest positions,
armature object name "Smiles" so Model/Smiles/Skeleton3D paths match), the Part helper (rigid skinning: one bone
per vertex) and every clip (idle/taunt/grudging/cheat/deal/mc_idle/mc_cheer). Same origin (waist, Blender Z up,
faces -Y) and scale, so pit_boss.tscn is a straight swap for smiles.tscn at the dealer_spot (-0.42, -0.47, -0.86).
Swap slots: PitBoss_Body (Smiles_Body), PitBoss_Head (Smiles_Head), PitBoss_Cap (Smiles_Visor, on "visor"),
PitBoss_Plaque (Smiles_Chip, on "chip").

Design (BRIEF.md, The Pit Boss): wide block, flat cap, no neck, barrel shoulders, cigar; signature prop = brass
flip-plaque showing ONE numeral (2-6) + a bone bar (AD: no oxblood). Blockout plaque: "4" on the front face, "2" on the back
(a flip plaque has two faces; each face carries one numeral - see report). Grey values only (no palette yet).
"""
import math, os, sys
import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "../../../smiles/src")))
import build_smiles as bs  # noqa: E402

# grey blockout slots: (name, grey value) - value steps only, so the forms read without a palette
GREYS = [("pitboss_skin", 0.62), ("pitboss_shirt", 0.80), ("pitboss_vest", 0.38), ("pitboss_black", 0.12),
         ("pitboss_brass", 0.70), ("pitboss_bone", 0.90), ("pitboss_cap", 0.30), ("pitboss_eye", 0.05),
         ("pitboss_cigar", 0.26), ("pitboss_ash", 0.55)]
bs.MATS = [n for n, _ in GREYS]
rot = bs.rot

# seven-segment numeral layout in the plaque's (y, z) plane, unit cell 1 x 2 (centre origin)
SEG = {"a": ((0, 1), (1, 0.18)), "d": ((0, -1), (1, 0.18)), "g": ((0, 0), (1, 0.18)),
       "f": ((-0.5, 0.5), (0.18, 1)), "b": ((0.5, 0.5), (0.18, 1)), "e": ((-0.5, -0.5), (0.18, 1)), "c": ((0.5, -0.5), (0.18, 1))}
DIGIT = {"2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc"}


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    P = bs.Part
    body = P("PitBoss_Body")
    # trousers, then a barrel waistcoat: wider + deeper than Smiles (block silhouette), shirt sleeves rolled
    body.tube([((0, 0, -0.22), 0.15), ((0, 0, 0.0), 0.145)], "pitboss_black", "spine", seg=S(16), flat=0.72)
    body.tube([((0, 0, -0.02), 0.152), ((0, 0, 0.10), 0.165), ((0, 0, 0.22), 0.17)], "pitboss_vest", "spine", seg=S(20), flat=0.74)
    body.tube([((0, 0, 0.2), 0.17), ((0, 0, 0.31), 0.182), ((0, 0, 0.40), 0.17), ((0, 0, 0.46), 0.09)], "pitboss_vest", "chest", seg=S(20), flat=0.7)
    # shirt front strip + tie (vertical bar reads at 48 px as the "lapel" break)
    body.box((0, -0.118, 0.33), (0.07, 0.02, 0.19), "pitboss_shirt", "chest")
    body.tube([((0, -0.13, 0.42), 0.016), ((0, -0.132, 0.33), 0.022), ((0, -0.128, 0.24), 0.0)], "pitboss_black", "chest", seg=S(6), flat=0.4)
    for z in (0.05, 0.12, 0.19):
        body.ellipsoid((0.022, -0.124, z), (0.009, 0.006, 0.009), "pitboss_brass", "spine", seg=(S(8), S(5)))
    # watch chain across the belly
    body.tube([((-0.07, -0.118, 0.08), 0.004), ((0, -0.128, 0.05), 0.004), ((0.07, -0.118, 0.08), 0.004)], "pitboss_brass", "spine", seg=4, caps=False)
    # NO NECK: a thick collar cone fills chest -> jaw; head + cap geometry sit 5 cm low on their bones so the head rests on the shoulders
    body.tube([((0, 0.0, 0.40), 0.10), ((0, -0.01, 0.46), 0.09), ((0, -0.015, 0.50), 0.08)], "pitboss_skin", "neck", seg=S(14), flat=0.9)
    # trapezius shrug: the shoulders climb straight into the jaw line (no visible neck at 48 px)
    body.ellipsoid((0, 0.012, 0.445), (0.19, 0.1, 0.06), "pitboss_vest", "chest", seg=(S(16), S(8)))
    # v2: upper shoulder block 1.4x the head width (0.304 m vs 0.216 m) up to the jaw: head -> block -> shoulders, no neck notch
    body.ellipsoid((0, 0.0, 0.47), (0.152, 0.095, 0.085), "pitboss_vest", "chest", seg=(S(16), S(8)))
    body.tube([((0, -0.004, 0.43), 0.105), ((0, -0.008, 0.47), 0.092)], "pitboss_shirt", "chest", seg=S(16), flat=0.9)
    for s, sx in (("L", 1), ("R", -1)):
        # barrel shoulders: big vest-coloured caps sitting high, then shirt sleeves rolled to the elbow, bare forearms
        body.ellipsoid((sx * 0.15, 0.0, 0.40), (0.085, 0.078, 0.07), "pitboss_vest", "shoulder_" + s, seg=(S(12), S(8)))
        body.tube([((sx * 0.16, 0, 0.395), 0.058), ((sx * 0.172, 0.002, 0.27), 0.055), ((sx * 0.185, 0.008, 0.16), 0.05)], "pitboss_shirt", "upper_arm_" + s, seg=S(12))
        body.tube([((sx * 0.185, 0.008, 0.17), 0.056), ((sx * 0.186, 0.008, 0.13), 0.054)], "pitboss_shirt", "forearm_" + s, seg=S(12))
        body.ellipsoid((sx * 0.185, 0.008, 0.15), (0.044, 0.044, 0.044), "pitboss_skin", "forearm_" + s, seg=(S(10), S(6)))
        body.tube([((sx * 0.185, 0.008, 0.15), 0.044), ((sx * 0.192, 0.002, 0.03), 0.048), ((sx * 0.198, 0, -0.06), 0.034)], "pitboss_skin", "forearm_" + s, seg=S(12))
        # hand: same bones and joint spots as Smiles; thick blunt fingers, no claws
        # relaxed hand (shared builder, natural-hands pass): sculpted finger curl, opposed thumb
        bs.build_hand(body, s, "pitboss_skin", S, k=1.06, wrist_r=0.025, palm_r=0.041, fr=0.0124, tip=0.0045)
    ob_body = body.finish(arm)

    head = P("PitBoss_Head")
    # wide block head: broader than tall, heavy jowls on the jaw, small eyes under a hard brow shelf
    head.ellipsoid((0, -0.012, 0.590), (0.108, 0.098, 0.092), "pitboss_skin", "head", seg=(S(20), S(14)))
    head.ellipsoid((0, -0.03, 0.525), (0.104, 0.085, 0.055), "pitboss_skin", "jaw", seg=(S(16), S(10)))
    for sx in (-1, 1):
        head.ellipsoid((sx * 0.072, -0.055, 0.512), (0.056, 0.042, 0.046), "pitboss_skin", "jaw", seg=(S(10), S(6)))  # jowl (v2: low + wide, merges into the shoulder block)
        head.ellipsoid((sx * 0.105, -0.005, 0.580), (0.014, 0.024, 0.03), "pitboss_skin", "head", seg=(S(8), S(6)))  # ear
        head.ellipsoid((sx * 0.038, -0.098, 0.602), (0.012, 0.006, 0.006), "pitboss_eye", "head", seg=(S(8), S(5)))
    head.box((0, -0.098, 0.618), (0.12, 0.022, 0.016), "pitboss_skin", "head", rot=rot(8, 0, 0))  # brow shelf
    head.ellipsoid((0, -0.112, 0.575), (0.02, 0.022, 0.022), "pitboss_skin", "head", seg=(S(10), S(6)))  # nose
    head.box((0, -0.105, 0.547), (0.05, 0.01, 0.006), "pitboss_eye", "jaw")  # mouth line
    # cigar from the stage-left mouth corner, angled down + out; ash/ember tip
    c0, c1 = Vector((0.026, -0.105, 0.546)), Vector((0.165, -0.185, 0.53))  # v2: long, out past the jowl + face (breaks front and side outlines)
    head.tube([(c0, 0.010), (c1, 0.0115)], "pitboss_cigar", "jaw", seg=S(8))
    head.tube([(c1, 0.0117), (c1 + (c1 - c0).normalized() * 0.016, 0.011)], "pitboss_ash", "jaw", seg=S(8))
    ob_head = head.finish(arm)

    cap = P("PitBoss_Cap")
    # flat cap on the visor bone (the Smiles hat slot): low flat crown, short stiff peak
    cap.ellipsoid((0, -0.005, 0.650), (0.114, 0.112, 0.036), "pitboss_cap", "visor", seg=(S(18), S(8)), rot=rot(-6, 0, 0))
    cap.ellipsoid((0, -0.105, 0.642), (0.13, 0.07, 0.008), "pitboss_cap", "visor", seg=(S(14), S(6)), rot=rot(-10, 0, 0))
    cap.tube([((0, -0.006, 0.626), 0.104), ((0, -0.006, 0.640), 0.108)], "pitboss_black", "visor", seg=S(18), flat=1.0, caps=False)  # band
    # v2: whole cap tilted 7 deg to stage left about the head centre (rakish), brim now wider than the head (0.26 vs 0.216 m)
    bmesh.ops.rotate(cap.bm, verts=list(cap.bm.verts), cent=Vector((0, 0, 0.60)), matrix=rot(0, 7, 0))
    ob_cap = cap.finish(arm)

    pl = P("PitBoss_Plaque")
    # brass flip-plaque in the right hand (chip bone): plate in the bone's Y-Z plane, faces +/-X like the chip
    c = Vector(bs.BONES["chip"][1]) + Vector(tuple(float(x) for x in os.environ.get("PLAQUE_OFF", "0,-0.03,-0.08").split(",")))  # v2: held by its top edge in front of the fingers (v1 sat through the index finger)
    W, Hh, T = 0.072, 0.056, 0.008
    pl.box(c, (T, W, Hh), "pitboss_brass", "chip")
    pl.box(c + Vector((0, 0, Hh * 0.5 + 0.004)), (0.006, W * 0.7, 0.006), "pitboss_brass", "chip")  # hinge rod
    for side, digit in ((-1, "4"), (1, "2")):  # -X face = the face the game camera sees in deal/taunt
        x = c.x + side * (T * 0.5 + 0.0015)
        sw, sh = 0.013, 0.012  # numeral cell half-size (y, z): one numeral, ~60% of the plate height
        for k in DIGIT[digit]:
            (oy, oz), (ly, lz) = SEG[k]
            pl.box((x, c.y + oy * sw * 1.6 * side * -1, c.z + 0.006 + oz * sh), (0.003, ly * sw * 1.6 + 0.003, lz * sh + 0.003), "pitboss_black", "chip")
        pl.box((x, c.y, c.z - Hh * 0.5 + 0.008), (0.003, W * 0.86, 0.008), "pitboss_bone", "chip")  # bone bar (AD: no oxblood; was oxblood)
    ob_pl = pl.finish(arm)
    return [ob_body, ob_head, ob_cap, ob_pl]


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
    path = os.path.join(OUT, "pit_boss%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
