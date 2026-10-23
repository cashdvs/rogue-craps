"""Nerve bone token + rail cradle + slide track (world_props_v1 §4). Original work by Tiny Anvil Games.
Blender 4.5 LTS, run from the repo root:
  blender -b --factory-startup --python art/models/props/nerve_token/src/build_nerve_token.py
Writes art/models/props/nerve_token/nerve_token_{tablet,tablet_mobile,chevron,notch,cradle,track}.glb.
Godot axes (+Y up), metres, at the dice's scale (0.08 m dice). Origin of every part = its base centre.
The tablet is a flat upright bone slab with a round top (not a cube: CONFLICTS_133 #10 asks for a shape
that never reads as a die); the up/down chevron is a separate raised inlay so its material can dull
(spent) and so it stays a bold shape at 48 px instead of a carved 2-3 px fleck.
Hand-laid UVs: caps planar (front u 0..0.5, back u 0.5..1), sides a perimeter strip in v 0.9..1.
Material slots are placeholders; make_nerve_token.gd assigns the toon_noir .tres per surface.
"""
import math
import os

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
TRIS = {}

# ---- dimensions (keep in sync with scripts/nerve_token.gd) --------------------------------------
TAB_W = 0.062        # tablet width
TAB_H = 0.088        # tablet height (taller than a die's 0.08 face, so it reads as a marker, not a die)
TAB_T = 0.016        # tablet thickness
INLAY = 0.0018       # chevron / notch stand-off from the front face
CHEV_W = 0.022       # chevron half-width
CHEV_H = 0.017       # chevron height
CHEV_S = 0.012       # chevron stroke (horizontal): ~9 px at 48 px tablet height
CHEV_UP_Y = 0.049    # base of the up chevron
CHEV_DN_Y = 0.041    # top of the down chevron
BASE_H = 0.008       # cradle plate height (the tablet stands on it)
BASE_W = 0.092
BASE_D = 0.040
CHEEK_W = 0.008
CHEEK_H = 0.024
CHEEK_D = 0.024
TRACK_W = 0.012
TRACK_H = 0.003
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


def ccw(poly):
    a = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return poly if a > 0 else poly[::-1]


def prism(p, poly, z0, z1, slot=0, back=True, uvbox=(0.0, 0.0, 0.5, 0.9)):
    """Extrude a 2D (x, y) polygon along z. Front cap at z1 (faces +z), back cap at z0 (optional),
    sides as quads. Caps planar-mapped into uvbox (front) / its mirror at u+0.5 (back)."""
    poly = ccw(poly)
    xs, ys = [q[0] for q in poly], [q[1] for q in poly]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    sc = min((uvbox[2] - uvbox[0]) / (x1 - x0), (uvbox[3] - uvbox[1]) / (y1 - y0))
    def puv(q, du=0.0):
        return (uvbox[0] + du + (q[0] - x0) * sc, uvbox[1] + (q[1] - y0) * sc)
    f = [p.v((q[0], q[1], z1)) for q in poly]
    b = [p.v((q[0], q[1], z0)) for q in poly]
    p.f(f, [puv(q) for q in poly], slot)
    if back:
        p.f(b[::-1], [(1.0 - puv(q)[0], puv(q)[1]) for q in poly[::-1]], slot)
    n = len(poly)
    per = [0.0]
    for i in range(n):
        j = (i + 1) % n
        per.append(per[-1] + math.dist(poly[i], poly[j]))
    for i in range(n):
        j = (i + 1) % n
        u0, u1 = per[i] / per[-1], per[i + 1] / per[-1]
        p.f([b[i], b[j], f[j], f[i]], [(u0, 0.9), (u1, 0.9), (u1, 1.0), (u0, 1.0)], slot)


def box(p, x0, x1, y0, y1, z0, z1, slot=0, uvbox=(0.0, 0.0, 0.5, 0.9)):
    """Box without a bottom (it sits on something): a prism of the (x, y) rect + top/bottom handled by sides."""
    prism(p, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z0, z1, slot, True, uvbox)


def tablet_profile(arch_seg):
    r = TAB_W / 2
    yc = TAB_H - r
    pts = [(-r, 0.0), (r, 0.0)]
    for k in range(arch_seg + 1):
        a = math.pi * k / arch_seg
        pts.append((r * math.cos(a), yc + r * math.sin(a)))
    return pts[:2] + pts[2:]


def build_tablet(name, arch_seg):
    p = Part(name, [("nerve_bone", (0.85, 0.77, 0.6))])
    prism(p, tablet_profile(arch_seg), -TAB_T / 2, TAB_T / 2)
    p.finish(40.0)


def chevron(y_base, up):
    s = 1 if up else -1
    w, h, a = CHEV_W, CHEV_H, CHEV_S
    thick = h * 0.62           # vertical stroke at the apex
    pts = [(-w, 0.0), (-w + a, 0.0), (0.0, h - thick), (w - a, 0.0), (w, 0.0), (0.0, h)]
    return [(x, y_base + s * y) for x, y in pts]


def build_chevron():
    p = Part("nerve_token_chevron", [("nerve_chevron", (0.1, 0.07, 0.06))])
    z0, z1 = TAB_T / 2 - 0.0004, TAB_T / 2 + INLAY
    prism(p, chevron(CHEV_UP_Y, True), z0, z1, back=False, uvbox=(0.0, 0.0, 0.5, 0.45))
    prism(p, chevron(CHEV_DN_Y, False), z0, z1, back=False, uvbox=(0.0, 0.45, 0.5, 0.9))
    p.finish(30.0)


def build_notch():
    """Carried-over mark: a bold wedge cut into the tablet's upper-left shoulder (front inlay)."""
    p = Part("nerve_token_notch", [("nerve_chevron", (0.1, 0.07, 0.06))])
    z0, z1 = TAB_T / 2 - 0.0004, TAB_T / 2 + INLAY
    r = TAB_W / 2
    pts = [(-r + 0.004, TAB_H - r - 0.004), (-r + 0.016, TAB_H - r + 0.004), (-r + 0.009, TAB_H - r + 0.020)]
    prism(p, pts, z0, z1, back=False)
    p.finish(30.0)


def build_cradle():
    """Iron rail cradle: a plate the tablet stands on + two cheeks either side. The iron reads as a fitting,
    the second cue (after the shape) that the bone tablet is not a die."""
    p = Part("nerve_token_cradle", [("nerve_iron", (0.2, 0.19, 0.18))])
    box(p, -BASE_W / 2, BASE_W / 2, 0.0, BASE_H, -BASE_D / 2, BASE_D / 2)
    cx = TAB_W / 2 + 0.003
    box(p, cx, cx + CHEEK_W, BASE_H - 0.001, BASE_H + CHEEK_H, -CHEEK_D / 2, CHEEK_D / 2)
    box(p, -cx - CHEEK_W, -cx, BASE_H - 0.001, BASE_H + CHEEK_H, -CHEEK_D / 2, CHEEK_D / 2)
    p.finish(30.0)


def build_track():
    """Slide track: a 1 m brass strip along the rail edge, scaled in x to the rail by the scene."""
    p = Part("nerve_token_track", [("nerve_brass", (0.55, 0.42, 0.18))])
    box(p, -0.5, 0.5, 0.0, TRACK_H, -TRACK_W / 2, TRACK_W / 2)
    p.finish(30.0)


build_tablet("nerve_token_tablet", 8)
build_tablet("nerve_token_tablet_mobile", 4)
build_chevron()
build_notch()
build_cradle()
build_track()
print("TRIS", TRIS)
