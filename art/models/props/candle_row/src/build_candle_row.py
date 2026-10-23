"""Hand candle row (world_props_v1 §2.1, batch 4 of the 3D detail pass). Original work by Tiny Anvil Games.
Blender 4.5 LTS, run from the repo root:
  blender -b --factory-startup --python art/models/props/candle_row/src/build_candle_row.py
Writes art/models/props/candle_row/candle_row_{holder,socket,candle,ring}.glb (one LOD: the whole row
is ~290 tris, it is shared by PC and mobile). Godot axes (+Y up), metres, drawn at the dice's scale
(0.08 m dice). Origin of every part = its base centre. Hand-laid UVs (no smart project):
  wax: sides u = around (seam at angle 0), v 0..0.7 = height; cap = planar disc in u,v 0.75..1.
  holder: profile strip (u = perimeter, v = length), end caps planar in their own corner.
Material slots are placeholders; make_candle_row.gd assigns the toon_noir .tres per surface.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
TRIS = {}

# ---- row layout (keep in sync with scripts/candle_row.gd) -------------------------------------
CAP = 8              # CANDLE_CAP (display constant, world_props_v1 §2.1)
PITCH = 0.058        # socket spacing (m)
BAR_LEN = PITCH * CAP + 0.02
BAR_H = 0.009        # holder bar height
BAR_W = 0.034        # holder bar depth (z)
PLATE_R = 0.0165     # socket plate (hex) radius
PLATE_Y = 0.0012     # plate sits this far above the bar top
WAX_R = 0.0135       # candle radius (27 mm: thick enough to read at 48 px next to an 80 mm die)
WAX_H = 0.072        # candle height at height 1 (top of the wax rim)
SEG = 8              # around (v2: 6 -> 8 so the 1.4x phone row stays round; tris from the side-candle cut)
WICK_H = 0.0075
RING_R = 0.0182      # v2: ring outer radius (wall 0.0034 m off the wax)
RING_H = 0.0117      # v2: 1.3x the v1 band (0.009)
RING_BEV = 0.0016    # v2: chamfer between the outer wall and the top lip: the bevel that catches the highlight
BEAD_R = 0.0092      # v2: bust wax bead left on the holder bar
BEAD_H = 0.0055


def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    return m


class Part:
    def __init__(self, name, slots):
        self.name, self.slots = name, slots
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def v(self, p):
        return self.bm.verts.new(g2b(p))

    def f(self, vs, uvs, slot=0):
        face = self.bm.faces.new(vs)
        face.material_index = slot
        for loop, uv in zip(face.loops, uvs):
            loop[self.uv].uv = uv
        return face

    def finish(self, smooth_deg=50.0, flip=False):
        if flip:
            # the round parts (wax, ring) are laid clockwise seen from outside: flip them so the normals
            # point out (the ink hull and the toon bands need outward normals; checked in Godot)
            bmesh.ops.reverse_faces(self.bm, faces=self.bm.faces, flip_multires=False)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for s, rgb in self.slots:
            me.materials.append(mat(s, rgb))
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(smooth_deg))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, self.name + ".glb"), export_format="GLB",
                                  use_selection=True, export_yup=True, export_apply=True,
                                  export_materials="EXPORT", export_cameras=False, export_lights=False,
                                  export_animations=False)
        TRIS[self.name] = len(me.polygons)
        print("BUILT %-20s tris=%4d" % (self.name, len(me.polygons)))
        bpy.data.objects.remove(ob)


def ring(r, y, n, phase=0.0, jitter=None):
    out = []
    for i in range(n):
        a = phase + 2 * math.pi * i / n
        jy = jitter[i] if jitter else 0.0
        out.append((math.cos(a) * r, y + jy, math.sin(a) * r))
    return out


def build_candle():
    """Tall tallow candle: 8 sides (v2), a melted rim (the top ring dips where wax ran over) and a dimple,
    plus a 3-sided wick. 18 + 3 = 21 tris. The cold stub is this mesh at height 0.3 (script scale)."""
    p = Part("candle_row_candle", [("candle_wax", (0.85, 0.74, 0.55)), ("wick", (0.02, 0.02, 0.02))])
    dip = [0.0, -0.006, -0.002, 0.0, -0.0025, 0.0, -0.004, -0.001]   # melted rim: wax ran down 3 of the sides
    bot = [p.v(q) for q in ring(WAX_R, 0.0, SEG)]
    top = [p.v(q) for q in ring(WAX_R * 0.96, WAX_H, SEG, jitter=dip)]
    cap = p.v((0.0, WAX_H - 0.004, 0.0))
    for i in range(SEG):
        j = (i + 1) % SEG
        u0, u1 = i / SEG, (i + 1) / SEG
        v0, v1t, v1j = 0.0, 0.7 * (1 + dip[i] / WAX_H), 0.7 * (1 + dip[j] / WAX_H)
        p.f([bot[i], bot[j], top[j], top[i]], [(u0, v0), (u1, v0), (u1, v1j), (u0, v1t)])
    def cuv(k):
        a = 2 * math.pi * k / SEG
        return (0.875 + 0.12 * math.cos(a), 0.875 + 0.12 * math.sin(a))
    for i in range(SEG):
        j = (i + 1) % SEG
        p.f([top[j], top[i], cap], [cuv(j), cuv(i), (0.875, 0.875)])
    # wick: a thin 3-sided spike out of the dimple, bent a touch (Pit Black)
    base = [p.v((math.cos(a) * 0.0013, WAX_H - 0.0045, math.sin(a) * 0.0013)) for a in (0.0, 2.094, 4.189)]
    tip = p.v((0.0012, WAX_H + WICK_H, 0.0))
    for i in range(3):
        j = (i + 1) % 3
        p.f([base[i], base[j], tip], [(0.76 + 0.02 * i, 0.72), (0.78 + 0.02 * i, 0.72), (0.77 + 0.02 * i, 0.74)], 1)
    p.finish(55.0, flip=True)


def build_holder():
    """Iron candle rail lying on the near-rail top: a chamfered bar (6-point profile) + 2 end caps. 20 tris."""
    p = Part("candle_row_holder", [("holder_iron", (0.2, 0.19, 0.18))])
    hw, h, c = BAR_W / 2, BAR_H, 0.003
    prof = [(-hw, 0.0), (hw, 0.0), (hw, h - c), (hw - c, h), (-hw + c, h), (-hw, h - c)]  # (z, y), CCW seen from +x
    L = BAR_LEN / 2
    per = [0.0]
    for k in range(6):
        a, b = prof[k], prof[(k + 1) % 6]
        per.append(per[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    tot = per[-1]
    left = [p.v((-L, y, z)) for (z, y) in prof]
    right = [p.v((L, y, z)) for (z, y) in prof]
    for k in range(6):
        j = (k + 1) % 6
        ua, ub = 0.7 * per[k] / tot, 0.7 * per[k + 1] / tot
        p.f([left[k], right[k], right[j], left[j]], [(ua, 0.0), (ua, 1.0), (ub, 1.0), (ub, 0.0)])
    def euv(z, y, off):
        return (0.75 + 0.2 * (z + hw) / BAR_W, off + 0.2 * y / BAR_W)
    p.f(list(reversed(left)), [euv(z, y, 0.05) for (z, y) in reversed(prof)])
    p.f(right, [euv(z, y, 0.5) for (z, y) in prof])
    p.finish(30.0)


def build_socket():
    """Brass socket plate: a flat hexagon on the bar top (4 tris). Hidden when the socket is unused."""
    p = Part("candle_row_socket", [("socket_brass", (0.69, 0.55, 0.24))])
    vs = [p.v(q) for q in ring(PLATE_R, 0.0, 6, phase=math.pi / 6)]
    uvs = [(0.5 + 0.45 * math.cos(math.pi / 6 + k * math.pi / 3), 0.5 + 0.45 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)]
    p.f(list(reversed(vs)), list(reversed(uvs)))
    p.finish(10.0)


def build_ring():
    """Brass gift collar (v2): a solid 8-sided band, 1.3x the v1 height, with a chamfer bevel between the
    outer wall and the top lip (the bright highlight band), the lip and the inner wall. 4 x 16 = 64 tris."""
    p = Part("candle_row_ring", [("ring_brass", (0.89, 0.75, 0.42))])
    ri = WAX_R * 1.02
    rows = [ring(RING_R, 0.0, SEG), ring(RING_R, RING_H - RING_BEV, SEG), ring(RING_R - RING_BEV, RING_H, SEG),
            ring(ri, RING_H, SEG), ring(ri, 0.0, SEG)]
    vs = [[p.v(q) for q in r] for r in rows]
    vband = [0.0, 0.45, 0.6, 0.8, 1.0]
    for b in range(4):
        for i in range(SEG):
            j = (i + 1) % SEG
            p.f([vs[b][i], vs[b][j], vs[b + 1][j], vs[b + 1][i]],
                [(i / SEG, vband[b]), ((i + 1) / SEG, vband[b]), ((i + 1) / SEG, vband[b + 1]), (i / SEG, vband[b + 1])])
    p.finish(40.0, flip=True)


def build_bead():
    """Bust wax bead (v2): a low 6-sided dome on the bar top in front of the candle foot. 12 tris."""
    p = Part("candle_row_bead", [("bead_wax", (0.78, 0.66, 0.46))])
    rim = [p.v(q) for q in ring(BEAD_R, 0.0, 6)]
    mid = [p.v(q) for q in ring(BEAD_R * 0.62, BEAD_H * 0.8, 6, phase=math.pi / 6)]
    top = p.v((0.0, BEAD_H, 0.0))
    def uv(k, r):
        a = 2 * math.pi * k / 6
        return (0.5 + 0.45 * r * math.cos(a), 0.5 + 0.45 * r * math.sin(a))
    for i in range(6):
        j = (i + 1) % 6
        p.f([rim[i], rim[j], mid[i]], [uv(i, 1), uv(j, 1), uv(i + 0.5, 0.62)])
        p.f([mid[i], mid[j], top], [uv(i + 0.5, 0.62), uv(j + 0.5, 0.62), (0.5, 0.5)])
    p.finish(70.0, flip=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
build_candle()
build_holder()
build_socket()
build_ring()
build_bead()
row = TRIS["candle_row_holder"] + CAP * (TRIS["candle_row_socket"] + TRIS["candle_row_candle"])
print("TRIS %s" % TRIS)
print("ROW_GEOMETRY holder+%d sockets+%d candles = %d (+%d per gift ring)" % (CAP, CAP, row, TRIS["candle_row_ring"]))
