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

Split for the ~400-line file limit (behaviour unchanged): smiles_rig.py (bones, armature, rot),
smiles_hands.py (shared hand builder), smiles_clips.py (poses, clips, make_actions). This file keeps the
materials, Part, the Smiles mesh and the export entry point, and re-exports the rest so boss scripts keep
using bs.<name>. Boss scripts may reassign bs.MATS: Part and run() read MATS from this module.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from smiles_rig import FPS, BONES, GLOW_BONES, rot, build_armature  # noqa: E402,F401
from smiles_hands import FINGERS, PHALANX, hand_point, build_hand  # noqa: E402,F401
from smiles_clips import (CLIPS, STAND, VISOR_TIP, IDLE_PALM, mirror, arm, shd, P, curl, clip,  # noqa: E402,F401
                          make_actions)


MATS = ["smiles_skin", "smiles_horn", "smiles_shirt", "smiles_vest", "smiles_black", "smiles_gold",
        "smiles_visor", "smiles_eye", "smiles_mouth", "smiles_chip", "smiles_chip_edge",
        "smiles_visor_rim", "smiles_glow_gold", "smiles_glow_rim"]



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
        # hand: wrist, palm, four relaxed fingers + thumb, claws (palm faces the body: -sx X)
        build_hand(body, s, "smiles_skin", S)
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
