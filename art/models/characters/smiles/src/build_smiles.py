"""Smiles, the imp croupier (art/concept/bonfire_table/README.md LOCKED DIRECTION > Dealer: Smiles,
ref dealer_1_smiles.jpg). Blender 4.5, run headless:

    blender -b --factory-startup --python art/models/characters/smiles/src/build_smiles.py

Builds the upper-body model + rig + actions procedurally and exports smiles.glb (PC) and
smiles_mobile.glb (mobile LOD: same skeleton and clips, fewer segments).

Blender space: Z up, Smiles faces -Y (glTF / Godot +Z), his left = +X. Origin = waist.
Every bone points straight up (+Z) with roll 0, so in every bone the local axes read the same:
  rot X = pitch (+ tips the top of the bone forward; a hanging arm swings BACK, so raise it with -X)
  rot Y = yaw / twist about the up axis
  rot Z = roll about the forward axis (+ moves a hanging part toward +X)
Parts are rigid-skinned (one bone per vertex) with ball joints, the cheap toon way.
Separate objects so cheap bosses can swap them: Smiles_Body (costume + arms + hands), Smiles_Head,
Smiles_Visor (hat slot), Smiles_Chip (prop, bone "chip").
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
FPS = 30

MATS = ["smiles_skin", "smiles_horn", "smiles_shirt", "smiles_vest", "smiles_black", "smiles_gold",
        "smiles_visor", "smiles_eye", "smiles_mouth", "smiles_chip", "smiles_chip_edge",
        "smiles_visor_rim", "smiles_glow_gold", "smiles_glow_rim"]

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


class Part:
    """One object's bmesh with a material per face and one bone per vertex."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups = []

    def _assign(self, verts, mat, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        gi = self.groups.index(bone)
        mi = MATS.index(mat)
        for v in verts:
            v[self.dl][gi] = 1.0
        faces = set()
        for v in verts:
            faces.update(v.link_faces)
        for f in faces:
            f.material_index = mi
            f.smooth = True

    def ellipsoid(self, c, r, mat, bone, seg=(16, 10), rot=None):
        m = Matrix.Translation(Vector(c)) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((r[0], r[1], r[2], 1.0))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0, matrix=m)
        self._assign(res["verts"], mat, bone)

    def tube(self, pts, mat, bone, seg=10, flat=1.0, flat_axis=(0, 1, 0), caps=True):
        """pts = [(pos, radius)]: a tapered tube through the points; radius 0 at an end = pointed tip.
        flat squashes the cross-section along flat_axis (projected off the tube direction)."""
        P = [Vector(p) for p, _ in pts]
        rings = []
        fa = Vector(flat_axis)
        for i, (p, r) in enumerate(pts):
            d = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
            a = fa - d * fa.dot(d)
            if a.length < 1e-4:
                a = Vector((1, 0, 0)) - d * d.x
            a.normalize()
            b = d.cross(a).normalized()
            if r <= 1e-5:
                rings.append([self.bm.verts.new(P[i])])
                continue
            rings.append([self.bm.verts.new(P[i] + a * (math.cos(t) * r * flat) + b * (math.sin(t) * r))
                          for t in [2 * math.pi * k / seg for k in range(seg)]])
        verts = [v for ring in rings for v in ring]
        for r0, r1 in zip(rings, rings[1:]):
            if len(r0) == 1 and len(r1) == 1:
                continue
            if len(r0) == 1:
                for k in range(seg):
                    self.bm.faces.new((r0[0], r1[k], r1[(k + 1) % seg]))
            elif len(r1) == 1:
                for k in range(seg):
                    self.bm.faces.new((r0[(k + 1) % seg], r0[k], r1[0]))
            else:
                for k in range(seg):
                    self.bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
        if caps:
            for ring, rev in ((rings[0], True), (rings[-1], False)):
                if len(ring) > 2:
                    c = self.bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
                    verts.append(c)
                    for k in range(seg):
                        q = (ring[k], ring[(k + 1) % seg], c)
                        self.bm.faces.new(q[::-1] if rev else q)
        self._assign(verts, mat, bone)

    def box(self, c, size, mat, bone, rot=None):
        m = Matrix.Translation(Vector(c)) @ (rot.to_4x4() if rot else Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._assign(res["verts"], mat, bone)

    def finish(self, arm):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in MATS:
            me.materials.append(bpy.data.materials.get(m) or bpy.data.materials.new(m))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.collection.objects.link(ob)
        for g in self.groups:
            ob.vertex_groups.new(name=g)
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        # drop unused material slots (keeps glTF surfaces minimal; Blender shifts the face indices)
        used = {p.material_index for p in me.polygons}
        for i in reversed(range(len(me.materials))):
            if i not in used:
                me.materials.pop(index=i)
        return ob


def rot(x=0.0, y=0.0, z=0.0):
    from mathutils import Euler
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()


def build_model(arm, mobile):
    q = 0.74 if mobile else 1.25  # segment scale

    def S(n, lo=4):
        return max(lo, int(round(n * q)))

    body = Part("Smiles_Body")
    # trousers + waistcoat (spine), chest (chest)
    body.tube([((0, 0, -0.22), 0.13), ((0, 0, 0.0), 0.12)], "smiles_black", "spine", seg=S(16), flat=0.66)
    body.tube([((0, 0, -0.01), 0.122), ((0, 0, 0.11), 0.112), ((0, 0, 0.22), 0.128)], "smiles_vest", "spine", seg=S(20), flat=0.64)
    body.tube([((0, 0, 0.2), 0.127), ((0, 0, 0.31), 0.152), ((0, 0, 0.39), 0.145), ((0, 0, 0.44), 0.06)], "smiles_vest", "chest", seg=S(20), flat=0.6)
    # waistcoat points at the hem
    for sx in (-1, 1):
        body.tube([((sx * 0.03, -0.074, 0.0), 0.03), ((sx * 0.04, -0.07, -0.05), 0.0)], "smiles_vest", "spine", seg=S(6), flat=0.3)
    # shirt V bib + collar + bowtie
    v = [Vector(p) for p in ((-0.062, -0.093, 0.418), (0.062, -0.093, 0.418), (0, -0.087, 0.235))]
    bm = body.bm
    front = [bm.verts.new(p + Vector((0, -0.004, 0))) for p in v]
    back = [bm.verts.new(p + Vector((0, 0.01, 0))) for p in v]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    for k in range(3):
        bm.faces.new((front[k], front[(k + 1) % 3], back[(k + 1) % 3], back[k]))
    body._assign(front + back, "smiles_shirt", "chest")
    body.tube([((0, -0.004, 0.415), 0.056), ((0, -0.006, 0.452), 0.048)], "smiles_shirt", "chest", seg=S(14), flat=0.9)
    for sx in (-1, 1):
        body.tube([((0, -0.062, 0.428), 0.012), ((sx * 0.03, -0.064, 0.432), 0.022), ((sx * 0.052, -0.06, 0.434), 0.024), ((sx * 0.058, -0.058, 0.434), 0.0)],
                  "smiles_black", "chest", seg=S(8), flat=0.45, flat_axis=(0, 1, 0))
    body.ellipsoid((0, -0.066, 0.43), (0.012, 0.009, 0.012), "smiles_black", "chest", seg=(S(8), S(5)))
    for i, z in enumerate((0.03, 0.09, 0.15, 0.205)):
        body.ellipsoid((0.016, -0.081 if z < 0.2 else -0.084, z), (0.0085, 0.005, 0.0085), "smiles_gold", "spine" if z < 0.2 else "chest", seg=(S(8), S(5)))
    # neck
    body.tube([((0, 0.002, 0.40), 0.034), ((0, -0.004, 0.47), 0.03), ((0, -0.008, 0.54), 0.032)], "smiles_skin", "neck", seg=S(10))
    for s, sx in (("L", 1), ("R", -1)):
        # shoulder cap (shirt), sleeve, garter, elbow ball, forearm, cuff
        body.ellipsoid((sx * 0.135, 0, 0.385), (0.06, 0.055, 0.05), "smiles_shirt", "shoulder_" + s, seg=(S(12), S(8)))
        body.tube([((sx * 0.158, 0, 0.395), 0.046), ((sx * 0.172, 0.002, 0.27), 0.043), ((sx * 0.185, 0.008, 0.15), 0.036)], "smiles_shirt", "upper_arm_" + s, seg=S(12))
        body.tube([((sx * 0.167, 0.0, 0.322), 0.0465), ((sx * 0.17, 0.001, 0.296), 0.0458)], "smiles_black", "upper_arm_" + s, seg=S(12), caps=False)
        body.ellipsoid((sx * 0.185, 0.008, 0.15), (0.036, 0.036, 0.036), "smiles_shirt", "forearm_" + s, seg=(S(10), S(6)))
        body.tube([((sx * 0.185, 0.008, 0.15), 0.036), ((sx * 0.192, 0.002, 0.03), 0.041), ((sx * 0.198, 0, -0.045), 0.034)], "smiles_shirt", "forearm_" + s, seg=S(12))
        body.tube([((sx * 0.198, 0, -0.04), 0.037), ((sx * 0.2, 0, -0.082), 0.035)], "smiles_shirt", "forearm_" + s, seg=S(12))
        body.ellipsoid((sx * 0.2, -0.034, -0.062), (0.007, 0.004, 0.007), "smiles_gold", "forearm_" + s, seg=(S(6), S(4)))
        # hand: wrist, big palm, three finger groups with claws (palm faces the body: -sx X)
        H = "hand_" + s
        body.tube([((sx * 0.2, 0, -0.07), 0.021), ((sx * 0.2, 0, -0.105), 0.026)], "smiles_skin", H, seg=S(8))
        body.tube([((sx * 0.2, 0.0, -0.095), 0.03), ((sx * 0.2, -0.002, -0.135), 0.045), ((sx * 0.2, -0.004, -0.17), 0.042)], "smiles_skin", H, seg=S(10), flat=0.42, flat_axis=(1, 0, 0))
        body.tube([((sx * 0.192, -0.03, -0.11), 0.014), ((sx * 0.182, -0.05, -0.14), 0.011), ((sx * 0.175, -0.066, -0.165), 0.008), ((sx * 0.172, -0.074, -0.18), 0.0)],
                  "smiles_skin", "thumb_" + s, seg=S(7))
        body.tube([((sx * 0.2, -0.026, -0.168), 0.011), ((sx * 0.199, -0.03, -0.215), 0.0095), ((sx * 0.196, -0.034, -0.255), 0.007), ((sx * 0.194, -0.036, -0.275), 0.0)],
                  "smiles_skin", "index_" + s, seg=S(7))
        for dy, ln in ((-0.004, 0.115), (0.016, 0.105), (0.034, 0.085)):
            y = dy
            body.tube([((sx * 0.2, y, -0.17), 0.0105), ((sx * 0.199, y, -0.17 - ln * 0.5), 0.009), ((sx * 0.196, y + 0.003, -0.17 - ln * 0.85), 0.0065), ((sx * 0.194, y + 0.004, -0.17 - ln), 0.0)],
                      "smiles_skin", "fingers_" + s, seg=S(6))
    ob_body = body.finish(arm)

    head = Part("Smiles_Head")
    head.ellipsoid((0, -0.008, 0.645), (0.092, 0.095, 0.106), "smiles_skin", "head", seg=(S(20), S(14)))
    # gaunt cheeks: a hollow under each cheekbone (dark skin tone sliver)
    head.tube([((0, -0.02, 0.6), 0.07), ((0, -0.045, 0.54), 0.046), ((0, -0.068, 0.5), 0.012)], "smiles_skin", "jaw", seg=S(14), flat=0.82)
    head.ellipsoid((0, -0.074, 0.574), (0.074, 0.026, 0.026), "smiles_mouth", "head", seg=(S(12), S(8)))
    head.ellipsoid((0, -0.076, 0.556), (0.04, 0.02, 0.01), "smiles_mouth", "jaw", seg=(S(10), S(6)))
    def teeth_band(part, lower, mat, bones, grow=0.0, n=7, front_only=False):
        """One connected strip of n chunky teeth along the grin arc: each tooth bulges forward and the
        top (bottom) edge notches between teeth, so the teeth read without separate pieces."""
        bm = part.bm
        rings = []
        per = 2 if mobile else 4
        M = n * per
        for k in range(M + 1):
            u = -1 + 2 * k / M
            ph = (k % per) / per
            bump = math.sin(math.pi * ph) if k % per else 0.0
            a = math.radians(64) * u
            R = 0.0955 + 0.0022 * bump + grow
            zc = 0.583 + 0.04 * u * u
            h = 0.026 - 0.008 * abs(u)
            if lower:
                zc, h = zc - 0.022 + 0.005 * abs(u), 0.021 - 0.006 * abs(u)
            notch = 0.0045 * (1.0 - min(1.0, bump * 2.5))
            top = zc + h * 0.5 + grow - (0 if lower else notch)
            bot = zc - h * 0.5 - grow + (notch if lower else 0)
            fx, fy = math.sin(a), -math.cos(a) * (1.0 - 0.06 * u * u)
            def at(rr, z):
                return bm.verts.new((rr * fx, -0.008 + rr * fy, z))
            ring = [at(R, top), at(R, bot)] if front_only else [at(R, top), at(R, bot), at(R - 0.009, bot), at(R - 0.009, top)]
            rings.append((u, ring))
        for (_u0, r0), (_u1, r1) in zip(rings, rings[1:]):
            for j in range(1 if front_only else 4):
                bm.faces.new((r0[j], r1[j], r1[(j + 1) % 4], r0[(j + 1) % 4]))
        if not front_only:
            bm.faces.new(rings[0][1][::-1])
            bm.faces.new(rings[-1][1])
        for u, ring in rings:
            part._assign(ring, mat, bones[2] if u > 0.4 else bones[1] if u < -0.4 else bones[0])

    teeth_band(head, False, "smiles_gold", ("head", "grin_R", "grin_L"))
    teeth_band(head, True, "smiles_gold", ("jaw", "grin_R", "grin_L"))
    teeth_band(head, False, "smiles_glow_gold", ("glow_head", "glow_grin_R", "glow_grin_L"), grow=0.0011, front_only=True)
    teeth_band(head, True, "smiles_glow_gold", ("glow_jaw", "glow_grin_R", "glow_grin_L"), grow=0.0011, front_only=True)
    for sx in (-1, 1):
        head.ellipsoid((sx * 0.037, -0.083, 0.648), (0.022, 0.009, 0.0095), "smiles_eye", "head", seg=(S(10), S(6)), rot=rot(0, -sx * 18, 0))
        head.tube([((sx * 0.012, -0.093, 0.652), 0.005), ((sx * 0.04, -0.091, 0.668), 0.0065), ((sx * 0.068, -0.08, 0.678), 0.0)], "smiles_black", "head", seg=S(6))
        # ears (long, pointed, swept back) + horns (curl in)
        head.tube([((sx * 0.08, 0.004, 0.632), 0.026), ((sx * 0.14, 0.022, 0.668), 0.016), ((sx * 0.19, 0.04, 0.705), 0.0)], "smiles_skin", "head", seg=S(8), flat=0.35, flat_axis=(0, 1, 0))
        head.tube([((sx * 0.05, -0.012, 0.718), 0.021), ((sx * 0.074, 0.026, 0.742), 0.015), ((sx * 0.08, 0.066, 0.752), 0.009), ((sx * 0.07, 0.104, 0.754), 0.0)], "smiles_horn", "head", seg=S(9))
    head.tube([((0, -0.088, 0.64), 0.011), ((0, -0.106, 0.615), 0.005), ((0, -0.108, 0.605), 0.0)], "smiles_skin", "head", seg=S(6))
    # black hair: a cap swept back + spikes
    head.ellipsoid((0, 0.014, 0.67), (0.097, 0.097, 0.095), "smiles_black", "head", seg=(S(16), S(10)))
    for px, py, pz, dx, dy, dz, r in ((0, -0.03, 0.745, 0.0, 0.05, 0.03, 0.03), (-0.045, -0.02, 0.735, -0.03, 0.05, 0.025, 0.026), (0.045, -0.02, 0.735, 0.03, 0.05, 0.025, 0.026),
                                      (0, 0.05, 0.735, 0.0, 0.075, 0.01, 0.03), (-0.06, 0.04, 0.715, -0.05, 0.06, 0.005, 0.026), (0.06, 0.04, 0.715, 0.05, 0.06, 0.005, 0.026),
                                      (0, 0.085, 0.68, 0.0, 0.06, -0.01, 0.03)):
        head.tube([((px, py, pz), r), ((px + dx, py + dy, pz + dz), 0.0)], "smiles_black", "head", seg=S(7))
    ob_head = head.finish(arm)

    visor = Part("Smiles_Visor")
    # outer headband in visor green (faces the lamp + game camera: the visor's green read now the brim tips up)
    visor.tube([((0, -0.006, 0.678), 0.092), ((0, -0.006, 0.703), 0.09)], "smiles_visor", "visor", seg=S(20), flat=1.03, caps=False)
    visor.tube([((0, -0.006, 0.679), 0.0925), ((0, -0.006, 0.702), 0.0905)], "smiles_black", "visor", seg=S(20), flat=1.03, caps=False)
    BRIM_C, BRIM_R, BRIM_ROT = Vector((0, -0.098, 0.694)), (0.124, 0.078), rot(-29, 0, 0)
    visor.ellipsoid(BRIM_C, (BRIM_R[0], BRIM_R[1], 0.0075), "smiles_visor", "visor", seg=(S(20), S(8)), rot=BRIM_ROT)
    K = S(18)
    ring = [BRIM_C + BRIM_ROT @ Vector((BRIM_R[0] * math.cos(2 * math.pi * k / K), BRIM_R[1] * math.sin(2 * math.pi * k / K), 0)) for k in range(K + 1)]
    visor.tube([(p, 0.007) for p in ring], "smiles_visor_rim", "visor", seg=4, caps=False)
    visor.tube([(p, 0.008) for p in ring], "smiles_glow_rim", "glow_visor", seg=4, caps=False)
    ob_visor = visor.finish(arm)

    chip = Part("Smiles_Chip")
    c = BONES["chip"][1]
    chip.tube([((c[0] - 0.003, c[1], c[2]), 0.021), ((c[0] + 0.003, c[1], c[2]), 0.021)], "smiles_chip", "chip", seg=S(16), flat=1.0, flat_axis=(0, 1, 0))
    chip.tube([((c[0] - 0.0015, c[1], c[2]), 0.0218), ((c[0] + 0.0015, c[1], c[2]), 0.0218)], "smiles_chip_edge", "chip", seg=S(16), caps=False)
    ob_chip = chip.finish(arm)
    return [ob_body, ob_head, ob_visor, ob_chip]


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


# ---------------------------------------------------------------- poses / clips
def mirror(p):
    """Pose dict with L/R swapped (yaw / roll flip)."""
    out = {}
    for k, v in p.items():
        k2 = k.replace("_L", "_#").replace("_R", "_L").replace("_#", "_R")
        out[k2] = (v[0], -v[1], -v[2]) + tuple(v[3:])
    return out


# ---- 2-bone arm IK (authoring only: solved to plain FK rotations, nothing exported but the keys)
def _local_euler(r_arm):
    """Armature-space rotation -> euler degrees in the (shared) bone-local frame."""
    m = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).transposed()  # columns = bone X, Y(up), Z(-fwd) in armature space
    e = (m.inverted() @ r_arm @ m).to_euler("XYZ")
    return tuple(round(math.degrees(a), 2) for a in e)


def arm(s, wrist, pole, twist=0.0, hand=(0, 0, 0), fingers=None, roll=0.0, palm=None):
    """Pose upper_arm_s / forearm_s so the wrist lands on `wrist` (armature rest coords, i.e. relative to the
    unposed chest; the chest / spine lean carries it). pole = a point the elbow bends toward.
    palm (with fingers): armature-space direction the palm should face. Without it the palm roll is whatever
    the forearm twist leaves (it depends on the elbow pole), so two hands with mirrored wrists / fingers can
    still end up rolled 180 deg apart (both thumbs to the same side). Give mirrored palms for mirrored hands."""
    S = Vector(BONES["upper_arm_" + s][1])
    E0 = Vector(BONES["forearm_" + s][1])
    W0 = Vector(BONES["hand_" + s][1])
    a, b = (E0 - S).length, (W0 - E0).length
    W = Vector(wrist)
    d = min((W - S).length, a + b - 1e-4)
    n = (W - S).normalized()
    x = (a * a - b * b + d * d) / (2 * d)
    h = math.sqrt(max(a * a - x * x, 0.0))
    pv = Vector(pole) - S
    pv = (pv - n * pv.dot(n)).normalized()
    E = S + n * x + pv * h
    Wr = S + n * d
    ru = (E0 - S).rotation_difference(E - S).to_matrix()
    fw = ru.inverted() @ (Wr - E)  # wrist direction in the upper arm's posed frame
    rf = (W0 - E0).rotation_difference(fw).to_matrix()
    if twist:
        rf = Matrix.Rotation(math.radians(twist), 3, (W0 - E0).normalized()) @ rf
    out = {"upper_arm_" + s: _local_euler(ru), "forearm_" + s: _local_euler(rf), "hand_" + s: hand}
    if fingers is not None:  # aim the hand (wrist -> knuckles) along an armature-space direction
        rest = Vector((0, -0.004, -0.085))
        want = (ru @ rf).inverted() @ Vector(fingers).normalized()
        rh = rest.rotation_difference(want).to_matrix()
        if palm is not None:  # roll about the wrist -> knuckles axis until the palm faces `palm`
            fw_w = Vector(fingers).normalized()
            cur = (ru @ rf @ rh) @ Vector((-1 if s == "L" else 1, 0, 0))  # palm faces the body at rest: -sx X
            cur = (cur - fw_w * cur.dot(fw_w)).normalized()
            tgt = Vector(palm) - fw_w * Vector(palm).dot(fw_w)
            if tgt.length > 1e-4:
                tgt.normalize()
                ang = math.atan2(fw_w.dot(cur.cross(tgt)), cur.dot(tgt))
                rh = Matrix.Rotation(ang, 3, want) @ rh
        if roll:  # spin the hand about its own wrist -> knuckles axis (palm direction)
            rh = Matrix.Rotation(math.radians(roll), 3, want) @ rh
        out["hand_" + s] = _local_euler(rh)
    return out


# Base standing pose: leaning in over the rail, face up toward the game camera, hands steepled.
STAND = {
    "spine": (3, 0, 0), "chest": (4, 0, 0), "neck": (-16, 0, 0), "head": (-26, 0, 0),
    **arm("L", (0.065, -0.04, 0.36), (0.35, 0.25, 0.0), fingers=(-0.35, 0.02, 1)), **arm("R", (-0.065, -0.04, 0.36), (-0.35, 0.25, 0.0), fingers=(0.35, 0.02, 1)),
    "index_L": (0, 0, -6), "fingers_L": (0, 0, -10), "thumb_L": (0, 0, -8),
    "index_R": (0, 0, 6), "fingers_R": (0, 0, 10), "thumb_R": (0, 0, 8),
}


def P(base, *more, **kw):
    d = dict(base)
    for m in more:
        d.update(m)
    for k, v in kw.items():
        d[k] = v
    return d


def curl(s, a):
    """Fist / curl toward the palm (palm faces the body)."""
    sg = -1 if s == "L" else 1
    return {"index_" + s: (0, 0, sg * a), "fingers_" + s: (0, 0, sg * a * 1.1), "thumb_" + s: (0, 0, sg * a * 0.6)}


CLIPS = {}


# Visor rim read (AD final): on these clips his head sits further back than in idle / cheat, so the brim's top and
# its pale-green rim turn away from the lamp and go dark. Tip the visor toward the camera on every key that does not
# key the visor itself (the cheat tell keeps its own, larger tip).
VISOR_TIP = {"taunt": 15, "grudging": 15, "deal": 15}


def clip(name, length_s, keys, loop=False):
    tip = VISOR_TIP.get(name, 0)
    if tip:
        keys = [(t, p if "visor" in p else {**p, "visor": (tip, 0, 0)}) for t, p in keys]
    CLIPS[name] = (length_s, keys, loop)


# idle (3.0 s loop): leans low on the far rail, both forearms on it; the right hand rolls a chip over its
# knuckles just above the rail top (inside the phone band, clear of the brazier and plaque), grin twitch, head sway.
# Both forearms rest on the rail palms DOWN (knuckles up; the chip rolls over the back of the right hand).
# palm= pins each hand's roll so the two hands mirror (before: left palm down, right palm up = two "right hands").
IDLE_PALM = (0, -0.2, -1)
_lean = arm("L", (0.1, -0.05, 0.655), (0.17, 0.35, 0.05), fingers=(-0.35, -1, 0.26), palm=IDLE_PALM)
_chip_hand = P(STAND, _lean, arm("R", (-0.17, -0.05, 0.655), (-0.45, 0.3, 0.1), fingers=(0.3, -1, 0.24), palm=IDLE_PALM), spine=(6, 0, 0), chest=(10, 0, 0))
_chip_hand2 = P(STAND, _lean, arm("R", (-0.17, -0.055, 0.665), (-0.45, 0.3, 0.1), fingers=(0.35, -1, 0.3), palm=IDLE_PALM), spine=(6, 0, 0), chest=(10, 0, 0))
clip("idle", 3.0, [
    (0.0, P(_chip_hand, chip=(0, 0, 0, -0.025, 0, 0))),
    (0.5, P(_chip_hand2, chest=(10, 0, 0), chip=(90, 0, 0, -0.025, -0.012, 0))),
    (1.0, P(_chip_hand2, chest=(10, 0, 0), head=(-24, 0, 4), chip=(180, 0, 0, -0.025, -0.024, 0), index_R=(0, 0, 14))),
    (1.4, P(_chip_hand2, chest=(10, 0, 0), head=(-26, 0, 5), jaw=(6, 0, 0), grin_L=(0, 0, 8), grin_R=(0, 0, -8), chip=(260, 0, 0, -0.025, -0.03, 0), index_R=(0, 0, 14))),
    (1.7, P(_chip_hand2, chest=(10, 0, 0), head=(-25, 0, 3), jaw=(0, 0, 0), chip=(300, 0, 0, -0.025, -0.02, 0))),
    (2.2, P(_chip_hand, chest=(10, 0, 0), head=(-23, 0, 0), chip=(340, 0, 0, -0.025, -0.008, 0))),
    (3.0, P(_chip_hand, chip=(360, 0, 0, -0.025, 0, 0))),
], loop=True)

# Camera v2 (Godot Dev a153087): the band above the far rail at Smiles' spot is ~0.22 m on phone landscape and
# ~0.44 m on PC. Everything is authored for the phone band: grin, visor and the key gestures read inside it, and
# nothing goes above his head; on PC he just shows more chest and waistcoat.

# taunt (1.4 s, bust): lean in, cackle (jaw chatter, head tipped back a little), jab a finger at the player at
# eye height (the hand stays at or below his head)
_point = P(STAND, arm("R", (-0.17, -0.06, 0.63), (-0.4, 0.3, 0.2), fingers=(0.15, -1, 0.38)), arm("L", (0.1, -0.08, 0.12), (0.5, 0.1, 0.2), hand=(0, 0, 0)),
           curl("L", 50), spine=(4, 0, 0), chest=(5, 0, 0), neck=(-18, 0, 0), head=(-28, 0, 0),
           index_R=(0, 0, 0), fingers_R=(0, 0, 70), thumb_R=(0, 0, 30))
_wind = arm("R", (-0.21, 0.03, 0.54), (-0.45, 0.3, 0.2), fingers=(0.1, -0.3, 1))
_wind_back = arm("R", (-0.22, 0.03, 0.47), (-0.45, 0.3, 0.2), fingers=(0.1, -0.25, 1))
clip("taunt", 1.4, [
    (0.0, STAND),
    (0.12, P(STAND, _wind, spine=(5, 0, 0), chest=(6, 0, 0), head=(-28, 0, 0), jaw=(10, 0, 0))),
    (0.19, P(STAND, arm("R", (-0.19, -0.05, 0.63), (-0.4, 0.3, 0.2), fingers=(0.12, -0.7, 0.6)), spine=(5, 0, 0), chest=(6, 0, 0), head=(-28, 0, 0), jaw=(16, 0, 0))),
    (0.25, P(_point, jaw=(24, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10))),
    (0.38, P(_point, jaw=(8, 0, 0), head=(-30, 0, 3), chest=(3, 0, 0))),
    (0.5, P(_point, jaw=(28, 0, 0), head=(-29, 0, -2), grin_L=(0, 0, 12), grin_R=(0, 0, -12))),
    (0.63, P(_point, jaw=(6, 0, 0), head=(-30, 0, 3), chest=(3, 0, 0))),
    (0.76, P(_point, jaw=(26, 0, 0), head=(-29, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10))),
    (1.0, P(_point, jaw=(10, 0, 0))),
    (1.2, P(STAND, _wind_back, head=(-27, 0, 0))),
    (1.4, STAND),
])

# grudging (1.6 s, big score tier 3+): two slow sarcastic claps at the centre of his body, hands at chin height
# just in front of the face, so on screen the cracking grin sits right above the clapping hands.
_crack = {"jaw": (4, 0, 0), "grin_L": (0, 0, -16), "grin_R": (0, 0, 16)}
_up = {"head": (-25, 0, 0)}
# Clap (AD final): held keys keep the hands a palm-width apart, palms facing, fingers up and slightly splayed,
# wrists never crossing; the palms meet for only 2-3 frames per clap. Elbows tucked down/back (clear of the brazier).
_splay = {'index_L': (-6, 0, 0), 'fingers_L': (5, 0, 0), 'thumb_L': (-14, 0, 0), 'index_R': (-6, 0, 0), 'fingers_R': (5, 0, 0), 'thumb_R': (-14, 0, 0)}
CW = (-0.25, 0.66)  # held clap wrist (y, z)
FY = -0.5  # fingers up, tipped a little toward the camera
PALM_ROLL = 145.0  # spins the hands so the palms face each other (fingers stay up)
def _clap(hx, wy=None, wz=None, fs=0.12, roll=None):
    wy = CW[0] if wy is None else wy
    wz = CW[1] if wz is None else wz
    roll = PALM_ROLL if roll is None else roll
    return {**arm("L", (hx, wy, wz), (0.17, 0.35, 0.35), fingers=(fs, FY, 1), roll=roll),
            **arm("R", (-hx, wy, wz), (-0.17, 0.35, 0.35), fingers=(-fs, FY, 1), roll=-roll), **_splay}
_clap_open = P(STAND, _crack, _up, _clap(0.075))
_clap_shut = P(_clap_open, _clap(0.017, fs=0.0))
# The way up / down: dense keys along a wrist path (straight up behind the rail, then forward over it) with the palm
# roll ramped, so the FK in-betweens never swing the wrists across each other or out toward the brazier.
_CLAP_PATH = [(0.08, -0.04, 0.47, 30.0), (0.08, -0.03, 0.58, 70.0), (0.078, -0.07, 0.66, 100.0),
              (0.077, -0.13, 0.67, 125.0), (0.075, -0.2, 0.665, 140.0)]
_clap_way = [P(STAND, _up if k >= 3 else {}, _clap(hx, wy=wy, wz=wz, roll=r), head=(-14 - 3 * k, 0, 0)) for k, (hx, wy, wz, r) in enumerate(_CLAP_PATH)]
_hide = {"chip": (0, 0, 0, 0, 0, 0, 0.0)}
clip("grudging", 1.6, [
    (0.0, STAND),
    *[(0.05 * (k + 1), P(w, _hide)) for k, w in enumerate(_clap_way)],
    (0.3, P(_clap_open, _hide)),
    (0.44, P(_clap_open, _hide, grin_L=(0, 0, -18), grin_R=(0, 0, 18))),
    (0.5, P(_clap_shut, _hide, head=(-25, 0, 3), grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (0.534, P(_clap_shut, _hide, head=(-25, 0, 3), grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (0.6, P(_clap_open, _hide, grin_L=(0, 0, -18), grin_R=(0, 0, 18))),
    (0.94, P(_clap_open, _hide, grin_L=(0, 0, -20), grin_R=(0, 0, 20))),
    (1.0, P(_clap_shut, _hide, head=(-25, 0, 3), jaw=(2, 0, 0), grin_L=(0, 0, -24), grin_R=(0, 0, 24))),
    (1.034, P(_clap_shut, _hide, head=(-25, 0, 3), jaw=(2, 0, 0), grin_L=(0, 0, -24), grin_R=(0, 0, 24))),
    (1.1, P(_clap_open, _hide, grin_L=(0, 0, -16), grin_R=(0, 0, 16))),
    (1.25, P(_clap_open, _hide, grin_L=(0, 0, -14), grin_R=(0, 0, 14))),
    *[(1.35 + 0.05 * k, P(w, _hide)) for k, w in enumerate(reversed(_clap_way))],
    (1.6, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])
# cheat (1.2 s, boss tell; AD final): swung to screen-left, his own side, away from the brazier. Shifty glance
# that way, visor tipped down, and the right hand palms the chip low by his right shoulder and flicks it up the
# cuff (hand at or below head height; left hand stays down behind the rail), then a smug grin.
_glance = P(STAND, head=(-14, -16, 8), neck=(-12, -7, 0), visor=(12, 0, 0))
_cuff = lambda wx, wy, wz, f: arm("R", (wx, wy, wz), (-0.3, 0.35, -0.1), fingers=f)
clip("cheat", 1.2, [
    (0.0, STAND),
    (0.1, P(STAND, _cuff(-0.13, -0.03, 0.47, (0.15, -0.1, 1)), head=(-12, -10, 4), neck=(-8, -4, 0), visor=(6, 0, 0))),
    (0.2, P(_glance, _cuff(-0.2, -0.03, 0.545, (0.25, -0.3, 1)))),
    (0.45, P(_glance, _cuff(-0.22, -0.01, 0.565, (-0.25, -0.2, 1)), chip=(40, 0, 0, 0, 0.0, 0, 0.6))),
    (0.6, P(_glance, _cuff(-0.215, -0.01, 0.545, (-0.3, -0.15, 1)), head=(-18, 10, 0), chip=(80, 0, 0, 0, 0.0, 0, 0.0))),
    (0.72, P(STAND, _cuff(-0.15, 0.03, 0.5, (0.15, 0.1, 1)), head=(-20, -4, 4), visor=(7, 0, 0), grin_L=(0, 0, 10), grin_R=(0, 0, -10),
             chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.79, P(STAND, _cuff(-0.12, 0.03, 0.42, (0.25, 0.08, 1)), head=(-21, -2, 5), visor=(5, 0, 0), grin_L=(0, 0, 12), grin_R=(0, 0, -12),
             chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.85, P(STAND, head=(-22, 0, 6), visor=(4, 0, 0), grin_L=(0, 0, 14), grin_R=(0, 0, -14), chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.1, P(STAND, chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.2, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])

# deal (1.0 s): right hand flicks a chip out across the felt, low over the rail (inside the phone band)
clip("deal", 1.0, [
    (0.0, STAND),
    (0.25, P(STAND, arm("R", (-0.17, -0.02, 0.5), (-0.5, 0.35, 0.0), fingers=(0.1, 0.0, 1)), chest=(2, -3, 0))),
    (0.42, P(STAND, arm("R", (-0.15, -0.2, 0.675), (-0.45, 0.4, 0.4), fingers=(0.1, -1, 0.12)), chest=(4, 6, 0), chip=(0, 0, 0, 0, 0, 0.0, 1.0))),
    (0.5, P(STAND, arm("R", (-0.15, -0.2, 0.68), (-0.45, 0.4, 0.4), fingers=(0.1, -1, 0.12)), chest=(4, 6, 0), chip=(0, 0, 0, 0, 0, 0.03, 0.0))),
    (0.7, P(STAND, arm("R", (-0.19, -0.04, 0.58), (-0.45, 0.4, 0.3), fingers=(0.1, -0.2, 1)), chest=(3, 2, 0), chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (0.9, P(STAND, chip=(0, 0, 0, 0, 0, 0, 0.0))),
    (1.0, P(STAND, chip=(0, 0, 0, 0, 0, 0, 1.0))),
])

# MC variant (boss in the dealer spot, Smiles on the left rail): upright, fist on hip, chip held up
_mc = P({"spine": (0, 0, 0), "chest": (2, 0, 0), "neck": (-6, 0, 0), "head": (-14, 0, -4)},
        arm("L", (0.2, 0.0, 0.02), (0.6, 0.3, 0.2), hand=(0, 0, -10)), curl("L", 60),
        arm("R", (-0.3, 0.0, 0.62), (-0.5, 0.1, 0.3), hand=(0, -30, 0)), index_R=(0, 0, 6))
clip("mc_idle", 2.4, [
    (0.0, _mc),
    (0.6, P(_mc, chest=(4, 0, 2), head=(-16, 0, 2), jaw=(4, 0, 0))),
    (1.2, P(_mc, chest=(2, 0, 0), head=(-14, 0, -6))),
    (1.8, P(_mc, chest=(4, 0, -2), head=(-16, 0, 4), grin_L=(0, 0, 6), grin_R=(0, 0, -6))),
    (2.4, _mc),
], loop=True)
_cheer = P(_mc, arm("L", (0.3, -0.05, 0.82), (0.6, 0.2, 0.4)), arm("R", (-0.3, -0.05, 0.82), (-0.6, 0.2, 0.4)), curl("L", 80), curl("R", 80),
           spine=(-4, 0, 0), chest=(-6, 0, 0), head=(-26, 0, 0), jaw=(26, 0, 0), grin_L=(0, 0, 12), grin_R=(0, 0, -12))
_cheer2 = P(_cheer, arm("L", (0.26, -0.05, 0.74), (0.6, 0.2, 0.4)), arm("R", (-0.26, -0.05, 0.74), (-0.6, 0.2, 0.4)), jaw=(10, 0, 0))
clip("mc_cheer", 1.2, [
    (0.0, _mc),
    (0.2, _cheer),
    (0.4, _cheer2),
    (0.6, _cheer),
    (0.8, _cheer2),
    (1.2, _mc),
])


def make_actions(arm):
    arm.animation_data_create()
    for name, (length_s, keys, loop) in CLIPS.items():
        keys = sorted(keys, key=lambda k: k[0])  # quaternion sign continuity runs in time order
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        prev = {}
        for t, pose in keys:
            f = 1 + round(t * FPS)
            for pb in arm.pose.bones:
                v = pose.get(pb.name, (0, 0, 0))
                # quaternion keys: in-betweens take the short way (euler in-betweens swing limbs through the rail)
                q = Euler([math.radians(a) for a in v[:3]], "XYZ").to_quaternion()
                if pb.name in prev and prev[pb.name].dot(q) < 0:
                    q.negate()
                prev[pb.name] = q
                pb.rotation_quaternion = q
                loc = v[3:6] if len(v) >= 6 else (0, 0, 0)
                pb.location = loc
                sc = v[6] if len(v) >= 7 else 1.0
                if pb.name in GLOW_BONES:
                    sc = 1.0 if name.startswith("mc_") else 0.0  # grin + visor-rim glow: MC only
                pb.scale = (max(sc, 0.001),) * 3
                pb.keyframe_insert("rotation_quaternion", frame=f)
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("scale", frame=f)
        act.frame_range = (1, 1 + round(length_s * FPS))
        act.use_frame_range = True
        # stepped scale (prop pops) and a gentle ease on everything else
        for fc in act.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT" if fc.data_path.endswith("scale") else "BEZIER"
                kp.easing = "AUTO"
        if loop:
            for fc in act.fcurves:
                fc.modifiers.new("CYCLES")
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


def tri_count(objs):
    n = 0
    for ob in objs:
        for p in ob.data.polygons:
            n += len(p.vertices) - 2
    return n


def run(mobile):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    for m in MATS:
        bpy.data.materials.new(m)
    arm = build_armature()
    objs = build_model(arm, mobile)
    make_actions(arm)
    print("TRIS", "mobile" if mobile else "pc", tri_count(objs), {o.name: tri_count([o]) for o in objs})
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs + [arm]:
        o.select_set(True)
    path = os.path.join(OUT, "smiles%s.glb" % ("_mobile" if mobile else ""))
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_range=True, export_anim_slide_to_zero=True, export_def_bones=False, export_skins=True,
                              export_morph=False, export_materials="PLACEHOLDER" if False else "EXPORT", export_yup=True,
                              export_optimize_animation_size=False, export_reset_pose_bones=True)
    print("WROTE", path)


if __name__ == "__main__":
    run(False)
    run(True)
