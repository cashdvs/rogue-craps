"""Builds the Bonfire scoring-juice props as .glb (Blender 4.5 LTS, headless).

    blender -b --factory-startup --python art/models/props/bonfire/src/build_bonfire_props.py -- [out_dir]

Spec: design/bonfire_map_events_juice.md section 3 (3D/VFX list). Authored in GODOT space (metres,
+Y up, -Z far, origin = bottom centre resting on y = 0) and converted to Blender Z-up on the way in;
the glTF exporter converts back, so every .glb is in Godot space at scale 1.

  wax_stamp.glb        "CLAIMED" wax seal, 0.056 m across (slots wax, wax_letter)
  wax_stamp_shards.glb the same seal broken into 7 jagged shards (Shard0..6, origin at each
                       shard's centre so a crumble animation can tumble them in place)
  soul_flask.glb       0.094 m Soul flask (slots soul_glass, soul_liquid, cork, brass)
  ember_pile.glb       0.06 m pile of 9 coal lumps with hot faces (slots coal, ember_hot)
  mult_chip.glb        the red Mult chip, 0.068 x 0.009 m (slots mult_body, mult_inlay)
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.normpath(os.path.join(HERE, "../../../../../fonts/AlfaSlabOne-Regular.ttf"))
TRIS = {}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def lin(h):
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


MATS = {  # glTF placeholder colours; each .import maps the slot to materials/<slot>.tres
    "wax": "9E1E22", "wax_letter": "E2C06A", "soul_glass": "1E8F8B", "soul_liquid": "4FE6E0",
    "cork": "5A3A24", "brass": "B08D3C", "coal": "1A1414", "ember_hot": "E8622A",
    "mult_body": "C8281E", "mult_inlay": "3B0D14",
}


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin(MATS[name])
    return m


class Part:
    def __init__(self, name, slots):
        self.name, self.slots = name, slots
        self.bm = bmesh.new()

    def v(self, p):
        return self.bm.verts.new(g2b(p))

    def f(self, verts, slot=0):
        try:
            face = self.bm.faces.new(verts)
        except ValueError:
            return None
        face.material_index = self.slots.index(slot) if isinstance(slot, str) else slot
        return face

    def rings(self, rows, slot, closed=True):
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            n = len(a) if closed else len(a) - 1
            for i in range(n):
                i2 = (i + 1) % len(a)
                self.f([a[i], a[i2], b[i2], b[i]], slot)

    def fan(self, ring, centre, slot, flip=False):
        c = self.v(centre)
        for i in range(len(ring)):
            a, b = ring[i], ring[(i + 1) % len(ring)]
            self.f([c, b, a] if flip else [c, a, b], slot)

    def to_object(self, smooth=False, origin=None):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-7)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        if origin is not None:
            bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-g2b(origin))
        self.bm.to_mesh(me)
        self.bm.free()
        for s in self.slots:
            me.materials.append(material(s))
        for p in me.polygons:
            p.use_smooth = smooth
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if origin is not None:
            ob.location = g2b(origin)
        return ob


def export(objs, out_dir, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_animations=False)
    tris = sum(len(o.data.polygons) for o in objs)
    TRIS[name] = tris
    print("BUILT %-18s tris=%5d nodes=%d slots=%s" % (name, tris, len(objs), [m.name for m in objs[0].data.materials]))
    for o in objs:
        bpy.data.objects.remove(o)


def lathe(part, profile, seg, slot, cap_bottom=True, cap_top=False):
    """profile: [(r, y)] bottom to top. Returns the rings."""
    rows = []
    for (r, y) in profile:
        rows.append([part.v((r * math.cos(2 * math.pi * i / seg), y, r * math.sin(2 * math.pi * i / seg)))
                     for i in range(seg)])
    part.rings(rows, slot)
    if cap_bottom:
        part.fan(rows[0], (0, profile[0][1], 0), slot, flip=True)
    if cap_top:
        part.fan(rows[-1], (0, profile[-1][1], 0), slot)
    return rows


# --- wax stamp ------------------------------------------------------------------------------

STAMP_R = 0.028
STAMP_SEG = 40


def stamp_radius(t):
    return STAMP_R * (1 + 0.05 * math.sin(5 * t + 1.0) + 0.03 * math.sin(9 * t + 0.4) + 0.06 * max(0.0, math.cos(3 * t - 0.6)) ** 6)


STAMP_PROFILE = [(0.97, 0.0), (1.0, 0.0018), (0.97, 0.0050), (0.84, 0.0058), (0.76, 0.0056), (0.72, 0.0040)]
RECESS_Y = 0.0040


def letters(part, slot, y, width, height=0.0007):
    """Raised 'CLAIMED' lettering centred at the origin, reading along +X, seen from above."""
    bpy.ops.object.text_add()
    t = bpy.context.object
    t.data.body = "CLAIMED"
    t.data.font = bpy.data.fonts.load(FONT)
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.resolution_u = 2
    t.data.extrude = height * 0.5
    t.data.size = 1.0
    bpy.context.view_layer.update()
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.object
    dims = ob.dimensions
    s = width / dims.x
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    # Text is in Blender XY (reads along +X, up = +Y): Godot XZ with up = -Z (far side).
    lut = {}
    for vert in bm.verts:
        x, yy, z = vert.co.x * s, vert.co.y * s, vert.co.z
        lut[vert] = part.v((x, y + height * 0.5 + z, -yy))
    for face in bm.faces:
        part.f([lut[v] for v in face.verts], slot)
    bm.free()
    bpy.data.objects.remove(ob)
    return width / dims.x * dims.y


def build_wax_stamp(out_dir):
    p = Part("WaxStamp", ["wax", "wax_letter"])
    rows = []
    for (k, y) in STAMP_PROFILE:
        rows.append([p.v((stamp_radius(t) * k * math.cos(t), y, stamp_radius(t) * k * math.sin(t)))
                     for t in [2 * math.pi * i / STAMP_SEG for i in range(STAMP_SEG)]])
    p.rings(rows, "wax")
    p.fan(rows[0], (0, 0, 0), "wax", flip=True)
    p.fan(rows[-1], (0, RECESS_Y, 0), "wax")
    letters(p, "wax_letter", RECESS_Y, 0.036)
    export([p.to_object()], out_dir, "wax_stamp")


def build_wax_shards(out_dir, n=7, seed=7):
    rnd = random.Random(seed)
    cuts = []  # jagged radial cut lines: [(angle, r_frac)] from centre to rim
    base = [2 * math.pi * (k + rnd.uniform(-0.2, 0.2)) / n for k in range(n)]
    for a in base:
        cuts.append([(a + rnd.uniform(-0.18, 0.18), f) for f in (0.12, 0.38, 0.62, 0.86)] + [(a, 1.0)])
    top = 0.0054
    objs = []
    for k in range(n):
        a0, a1 = base[k], base[(k + 1) % n] + (2 * math.pi if k == n - 1 else 0)
        outline = [(0.0, 0.0)]
        for (a, f) in cuts[k]:
            r = stamp_radius(a) * 0.97 * f
            outline.append((r * math.cos(a), r * math.sin(a)))
        steps = 6
        for i in range(1, steps):
            a = a0 + (a1 - a0) * i / steps
            r = stamp_radius(a) * 0.97
            outline.append((r * math.cos(a), r * math.sin(a)))
        for (a, f) in reversed(cuts[(k + 1) % n]):
            r = stamp_radius(a) * 0.97 * f
            outline.append((r * math.cos(a), r * math.sin(a)))
        cx = sum(q[0] for q in outline) / len(outline)
        cz = sum(q[1] for q in outline) / len(outline)
        p = Part("Shard%d" % k, ["wax", "wax_letter"])
        bot = [p.v((x, 0.0, z)) for (x, z) in outline]
        tp = [p.v((x, top, z)) for (x, z) in outline]
        p.rings([bot, tp], "wax")
        p.f(list(reversed(bot)), "wax")
        p.f(tp, "wax")
        objs.append((p, (cx, top * 0.5, cz), a0, a1))
    # Letters go to the shard whose wedge holds each letter's centre.
    tmp = Part("tmp", ["wax", "wax_letter"])
    letters(tmp, "wax_letter", top - 0.0001, 0.036)
    tmp.bm.faces.index_update()
    islands = []
    seen = set()
    for face in tmp.bm.faces:
        if face.index in seen:
            continue
        stack, isl = [face], []
        while stack:
            fc = stack.pop()
            if fc.index in seen:
                continue
            seen.add(fc.index)
            isl.append(fc)
            for e in fc.edges:
                for lf in e.link_faces:
                    if lf.index not in seen:
                        stack.append(lf)
        islands.append(isl)
    for isl in islands:
        vs = {v for fc in isl for v in fc.verts}
        c = sum((v.co for v in vs), Vector()) / len(vs)  # Blender space: x, y(-z)
        ang = math.atan2(-c.y, c.x) % (2 * math.pi)
        best = 0
        for i, (_, _, a0, a1) in enumerate(objs):
            if (a0 % (2 * math.pi) <= ang < a1 % (2 * math.pi)) or (a1 % (2 * math.pi) < a0 % (2 * math.pi) and (ang >= a0 % (2 * math.pi) or ang < a1 % (2 * math.pi))):
                best = i
        p = objs[best][0]
        lut = {v: p.bm.verts.new(v.co.copy()) for v in vs}
        for fc in isl:
            try:
                nf = p.bm.faces.new([lut[v] for v in fc.verts])
                nf.material_index = 1
            except ValueError:
                pass
    tmp.bm.free()
    export([p.to_object(origin=o) for (p, o, _, _) in objs], out_dir, "wax_stamp_shards")


# --- soul flask -----------------------------------------------------------------------------

FLASK_SEG = 20
GLASS = [(0.0, 0.0), (0.022, 0.0), (0.029, 0.004), (0.033, 0.014), (0.034, 0.026), (0.032, 0.040),
         (0.026, 0.051), (0.016, 0.058), (0.0105, 0.063), (0.0100, 0.072), (0.0100, 0.080),
         (0.0128, 0.0815), (0.0128, 0.0850), (0.0100, 0.0860)]


def build_soul_flask(out_dir):
    p = Part("SoulFlask", ["soul_glass", "soul_liquid", "cork", "brass"])
    lathe(p, GLASS[1:], FLASK_SEG, "soul_glass", cap_bottom=True)
    liquid = [(r * 0.9, y * 0.97 + 0.0015) for (r, y) in GLASS[1:9]] + [(0.0094, 0.066)]
    lathe(p, liquid, FLASK_SEG, "soul_liquid", cap_bottom=True, cap_top=True)
    cork = [(0.0094, 0.078), (0.0098, 0.086), (0.0112, 0.0935), (0.0098, 0.0945)]
    lathe(p, cork, 10, "cork", cap_bottom=False, cap_top=True)
    collar = [(0.0104, 0.0730), (0.0118, 0.0738), (0.0118, 0.0772), (0.0104, 0.0780)]
    lathe(p, collar, 14, "brass", cap_bottom=False)
    export([p.to_object(smooth=True)], out_dir, "soul_flask")


# --- ember pile -----------------------------------------------------------------------------

def build_ember_pile(out_dir, seed=11):
    rnd = random.Random(seed)
    p = Part("EmberPile", ["coal", "ember_hot"])
    lumps = [((0, 0.011, 0), 0.013), ((0.016, 0.007, 0.006), 0.010), ((-0.015, 0.007, 0.007), 0.0105),
             ((0.004, 0.007, -0.017), 0.0095), ((-0.006, 0.006, 0.018), 0.009), ((0.019, 0.005, -0.012), 0.008),
             ((-0.020, 0.005, -0.010), 0.0085), ((0.003, 0.021, 0.003), 0.0085), ((0.011, 0.016, -0.004), 0.007)]
    for (c, r) in lumps:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        sx, sy, sz = rnd.uniform(0.9, 1.25), rnd.uniform(0.6, 0.85), rnd.uniform(0.85, 1.2)
        lut = {}
        for v in bm.verts:
            j = 1 + rnd.uniform(-0.18, 0.12)
            q = (v.co.x * sx * r * j + c[0], max(0.0, v.co.z * sy * r * j + c[1]), v.co.y * sz * r * j + c[2])
            lut[v] = p.v(q)
        for fc in bm.faces:
            up = fc.normal.z
            hot = rnd.random() < (0.45 if up < 0.3 else 0.18)
            p.f([lut[v] for v in fc.verts], "ember_hot" if hot else "coal")
        bm.free()
    export([p.to_object(smooth=False)], out_dir, "ember_pile")


# --- mult chip ------------------------------------------------------------------------------

CHIP_R = 0.034
CHIP_H = 0.009


def build_mult_chip(out_dir, seg=32):
    p = Part("MultChip", ["mult_body", "mult_inlay"])
    body = [(CHIP_R * 0.94, 0.0), (CHIP_R, 0.0012), (CHIP_R, CHIP_H - 0.0012), (CHIP_R * 0.94, CHIP_H),
            (CHIP_R * 0.70, CHIP_H)]
    rows = lathe(p, body, seg, "mult_body", cap_bottom=True)
    inlay = [(CHIP_R * 0.70, CHIP_H - 0.0008), (CHIP_R * 0.66, CHIP_H - 0.0008)]
    irows = [[p.v((r * math.cos(2 * math.pi * i / seg), y, r * math.sin(2 * math.pi * i / seg))) for i in range(seg)]
             for (r, y) in inlay]
    p.rings([rows[-1], irows[0]], "mult_body")
    p.rings(irows, "mult_inlay")
    p.fan(irows[-1], (0, CHIP_H - 0.0008, 0), "mult_inlay")
    export([p.to_object()], out_dir, "mult_chip")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[0]) if argv else os.path.normpath(os.path.join(HERE, ".."))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_wax_stamp(out_dir)
    build_wax_shards(out_dir)
    build_soul_flask(out_dir)
    build_ember_pile(out_dir)
    build_mult_chip(out_dir)
    print("TOTALS", TRIS)


main()
