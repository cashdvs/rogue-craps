"""Smiles rig data shared by build_smiles.py and every boss build script: bone table (29 deform bones +
glow_* bones), clip frame rate, the rot() helper and the armature builder. Split out of build_smiles.py
(file-size limit); behaviour unchanged. Import it through build_smiles (bs.BONES, bs.build_armature, ...)."""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

FPS = 30

# bone: (parent, head position)
BONES = {
    "root": (None, (0, 0, -0.2)),
    "spine": ("root", (0, 0, 0.0)),
    "chest": ("spine", (0, 0, 0.2)),
    "neck": ("chest", (0, 0, 0.42)),
    "head": ("neck", (0, -0.005, 0.52)),
    "jaw": ("head", (0, -0.01, 0.6)),
    "grin_L": ("head", (0.034, -0.096, 0.585)),
    "grin_R": ("head", (-0.034, -0.096, 0.585)),
    "visor": ("head", (0, -0.03, 0.69)),
}
for s, sx in (("L", 1), ("R", -1)):
    BONES.update({
        "shoulder_" + s: ("chest", (sx * 0.05, 0, 0.40)),
        "upper_arm_" + s: ("shoulder_" + s, (sx * 0.16, 0, 0.39)),
        "forearm_" + s: ("upper_arm_" + s, (sx * 0.185, 0.008, 0.15)),
        "hand_" + s: ("forearm_" + s, (sx * 0.2, 0, -0.085)),
        "thumb_" + s: ("hand_" + s, (sx * 0.19, -0.03, -0.11)),
        "index_" + s: ("hand_" + s, (sx * 0.2, -0.026, -0.168)),
        "fingers_" + s: ("hand_" + s, (sx * 0.2, 0.012, -0.168)),
    })
BONES["chip"] = ("hand_R", (-0.212, -0.06, -0.205))
# MC-only glow shells (grin + visor rim): each glow_* bone sits on its parent's head and is keyed to
# scale 0 in every dealer clip and 1 in the MC clips, so the clips alone switch the glow (no script).
GLOW_BONES = {"glow_head": "head", "glow_jaw": "jaw", "glow_grin_L": "grin_L", "glow_grin_R": "grin_R", "glow_visor": "visor"}
for _g, _p in GLOW_BONES.items():
    BONES[_g] = (_p, BONES[_p][1])


def rot(x=0.0, y=0.0, z=0.0):
    from mathutils import Euler
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()



def build_armature():
    ad = bpy.data.armatures.new("SmilesRig")
    arm = bpy.data.objects.new("Smiles", ad)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (parent, pos) in BONES.items():
        b = ad.edit_bones.new(name)
        b.head = Vector(pos)
        b.tail = Vector(pos) + Vector((0, 0, 0.05 if name not in ("chip",) else 0.02))
        b.roll = 0.0
        if parent:
            b.parent = ad.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm
