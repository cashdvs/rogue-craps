"""Builds the special dice (batch 1: Mirror, Cracked, Hellfire, Gilded; batch 2: Twin Flame, Wanderer,
Bellows, Blood Pact, Coven, Last Breath) as game-ready .glb files.

Run headless (Blender 4.5 LTS):
    blender -b --factory-startup --python art/models/dice/src/build_special_dice.py -- [out_dir] [name ...]
out_dir defaults to art/models/dice/. With no names, all ten are built. The Bone d6 has its own
script (build_dice.py) and is reused as is.

Same conventions as build_dice.py / scripts/table3d/die_visual.gd (GODOT space, Y up, metres;
converted to Blender Z-up on the way in, the glTF exporter converts back):
  slot -> local normal (DieVisual.FACE_AXES):  1:+Y  6:-Y  2:+X  5:-X  3:+Z  4:-Z
  labels [1, 2, 3, 4, 5, 6] on every die (bonfire_build_content.md: all special dice use plain
  Bone faces 1-6, so opposite faces sum to 7), pips at DieVisual.PIPS * PIP_STEP * edge.
  Pip axes: u = +Y projected onto the face (+X on the +-Y faces), v = n x u.
Every die is one mesh (one outline hull), centred, 0.08 m between opposite face planes.
Material slots: <die>_body, <die>_pip, then one optional accent slot (crack / seam / panel).
UVs: the 3x2 face atlas of build_dice.py (slot s: column (s-1)%3, row (s-1)//3 from the top).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

EDGE = 0.08
H = EDGE * 0.5
PIP_STEP = 0.23
FACE_AXES = {1: (0, 1, 0), 6: (0, -1, 0), 2: (1, 0, 0), 5: (-1, 0, 0), 3: (0, 0, 1), 4: (0, 0, -1)}
PIPS = {
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
}
LABELS = [1, 2, 3, 4, 5, 6]


# ---------------------------------------------------------------- helpers
def srgb_to_linear(hex_str):
    out = []
    for i in (0, 2, 4):
        c = int(hex_str[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def g2b(v):
    """Godot (x, y, z) Y-up -> Blender (x, -z, y) Z-up."""
    return Vector((v[0], -v[2], v[1]))


def face_axes(n):
    n = Vector(n)
    u = Vector((0, 1, 0)) if abs(n.y) < 0.5 else Vector((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    return n, u, n.cross(u)


def make_material(name, hex_col, rough=0.6, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb_to_linear(hex_col)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = srgb_to_linear(hex_col)
    return m


def rounded_cube_bmesh(radius, steps):
    """DieVisual.rounded_cube construction: per-face grids projected onto the bevel.
    steps=1 gives a faceted chamfer (2 flat facets per edge), steps=2 a smooth round."""
    c = H - radius
    st = [c + radius * math.tan(math.radians(45.0 * k / steps)) for k in range(steps + 1)]
    coords = [-s for s in reversed(st)] + st
    bm = bmesh.new()
    for n in FACE_AXES.values():
        n, u, v = face_axes(n)
        grid = []
        for j in coords:
            row = []
            for i in coords:
                p = n * H + u * i + v * j
                inner = Vector([max(-c, min(c, x)) for x in p])
                d = p - inner
                q = inner + d.normalized() * radius if d.length > 1e-9 else p
                row.append(bm.verts.new(g2b(q)))
            grid.append(row)
        for j in range(len(coords) - 1):
            for i in range(len(coords) - 1):
                bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    return bm


def pip_spots(face_h):
    """(slot, n, u, v, centre-on-face) for every pip, Godot space."""
    out = []
    for slot, nv in FACE_AXES.items():
        n, u, v = face_axes(nv)
        for (sx, sy) in PIPS[LABELS[slot - 1]]:
            out.append((slot, n, u, v, n * face_h + u * sx * PIP_STEP * EDGE + v * sy * PIP_STEP * EDGE))
    return out


def basis_to(n, u, v):
    """Blender-space matrix whose local X,Y,Z = Godot u, v, n."""
    bu, bv, bn = g2b(u), g2b(v), g2b(n)
    return Matrix((bu, bv, bn)).transposed().to_4x4()


def new_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def boolean(body, cutter, op="DIFFERENCE", use_self=False):
    mod = body.modifiers.new("b", "BOOLEAN")
    mod.operation = op
    mod.solver = "EXACT"
    mod.object = cutter
    mod.material_mode = "TRANSFER"
    mod.use_self = use_self
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


# Visual mesh extent vs the 0.08 m BoxShape3D every die uses (Godot Dev, Oct 19). The collider never changes; this is
# how far the decoration may poke past the face planes, as a scale of the half edge (max |x|, |y|, |z| = H * scale).
# Default 1.045 (0.0418 m, <= 1.8 mm into the felt); Hellfire's spikes and Wanderer's fins may go to 1.08 (0.0432 m,
# Godot Dev's felt-sink ruling) because they taper to thin tips, so what sinks is a sliver.
VISUAL_EXTENT_SCALE = 1.045
EXTENT_SCALE = {"hellfire_d6": 1.08, "wanderer_d6": 1.08}
BOX_HALF = H * VISUAL_EXTENT_SCALE  # set per die by main() before its builder runs


def clamp_to_box(ob, half=None):
    """Flatten whatever pokes past +-half on any axis (the wax seals press flat where they would touch the felt):
    bisect the 6 planes, drop the outside, cap each hole and give the cap the material of the faces around it."""
    half = BOX_HALF if half is None else half
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for axis in range(3):
        for sgn in (1.0, -1.0):
            co = [0.0, 0.0, 0.0]
            no = [0.0, 0.0, 0.0]
            co[axis], no[axis] = sgn * half, sgn
            if max(v.co[axis] * sgn for v in bm.verts) <= half + 1e-7:
                continue
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            res = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=co, plane_no=no, clear_outer=True)
            cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_boundary]
            if not cut:
                continue
            new = bmesh.ops.holes_fill(bm, edges=cut, sides=0)["faces"]
            for f in new:
                mats = [lf.material_index for e in f.edges for lf in e.link_faces if lf is not f]
                f.material_index = max(set(mats), key=mats.count) if mats else 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def cutter_caps(spots, a, d, segs, mat, face_h):
    """Spherical-cap pip drills (opening radius a, depth d)."""
    R = (a * a + d * d) / (2.0 * d)
    bm = bmesh.new()
    for (_s, n, u, v, c) in spots:
        res = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=max(4, segs // 2), radius=R)
        bmesh.ops.translate(bm, verts=res["verts"], vec=g2b(c - n * (d - R)))
    return new_obj("caps", bm, [mat])


def cutter_cones(spots, a, d, segs, mat):
    """Faceted cone drills (gem settings): a segs-sided pyramid, apex d below the face."""
    bm = bmesh.new()
    lift = 0.0006
    for (_s, n, u, v, c) in spots:
        # cone along local -Z: base (radius grows past a at the lifted top) to the apex
        top_r = a * (d + lift) / d
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=0.0, radius2=top_r,
                                    depth=d + lift, matrix=Matrix.Identity(4))
        m = basis_to(n, u, v) @ Matrix.Rotation(math.pi / segs, 4, "Z")
        bmesh.ops.transform(bm, verts=res["verts"], matrix=m)
        bmesh.ops.translate(bm, verts=res["verts"], vec=g2b(c + n * ((lift - d) * 0.5)))
    return new_obj("cones", bm, [mat])


def box_along(bm, centre, axis, side, length, w, depth):
    """A box centred at `centre` (Godot), long along `axis`, `w` wide along `side`, `depth`
    along axis x side. Used for cracks and seams."""
    axis = axis.normalized()
    side = side.normalized()
    up = axis.cross(side).normalized()
    res = bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix((g2b(axis) * length, g2b(side) * w, g2b(up) * depth)).transposed().to_4x4()
    bmesh.ops.transform(bm, verts=res["verts"], matrix=m)
    bmesh.ops.translate(bm, verts=res["verts"], vec=g2b(centre))


def finish(ob, sharp_deg):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-7)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.validate(clean_customdata=False)
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    # UVs: 3x2 face atlas by dominant axis (same layout as build_dice.py).
    uv = me.uv_layers.new(name="UVMap")
    axes_b = {s: face_axes(nv) for s, nv in FACE_AXES.items()}
    for poly in me.polygons:
        best = max(FACE_AXES, key=lambda s: poly.center.dot(g2b(FACE_AXES[s])))
        n, u, v = axes_b[best]
        ub, vb = g2b(u), g2b(v)
        col, row = (best - 1) % 3, (best - 1) // 3
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            fu = min(1.0, max(0.0, co.dot(ub) / EDGE + 0.5))
            fv = min(1.0, max(0.0, 0.5 - co.dot(vb) / EDGE))
            fu, fv = 0.02 + fu * 0.96, 0.02 + fv * 0.96
            uv.data[li].uv = ((col + fu) / 3.0, 1.0 - (row + fv) / 2.0)
    return len(me.polygons)


def export(ob, name, out_dir):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_materials="EXPORT", export_cameras=False,
                              export_lights=False, export_animations=False)
    return path


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-12)))
    return (p - (a + ab * t)).length


# ---------------------------------------------------------------- dice
def build_mirror():
    """Mirror Die: obsidian mirror. Faceted 2-step chamfer (flat planes, crisp octagon profile
    instead of Bone's round), flat-shaded so every facet flips its own reflection band;
    bone pips in faceted 8-sided drills."""
    body_m = make_material("mirror_body", "1A2226", 0.05, 1.0)
    pip_m = make_material("mirror_pip", "E8DCC0", 0.5)
    bm = rounded_cube_bmesh(0.24 * EDGE, 1)
    ob = new_obj("MirrorD6", bm, [body_m, pip_m])
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    return ob, 20.0


CRACK_CHIPS = [  # corner sign (Godot), extra break depth past the pip-safe plane (m)
    ((1, 1, 1), 0.000),
    ((-1, -1, 1), 0.0),
    ((1, -1, -1), 0.0),
    ((-1, 1, -1), 0.0),
]
# Faces that get a crack, each starting from the chipped corner it touches.
CRACK_FACES = [(1, (1, 1, 1), 5), (2, (1, 1, 1), 3), (3, (1, 1, 1), 3), (5, (-1, -1, 1), 4), (1, (-1, 1, -1), 3),
               (4, (1, -1, -1), 4)]


def build_cracked():
    """Cracked Die: aged bone, three chunks bitten out of corners (irregular silhouette) and
    deep dark oxblood cracks (a faint ember smoulder) running from the chips across the faces,
    routed between the pips so every value stays readable."""
    rng = random.Random(1666)
    body_m = make_material("cracked_body", "DCCDA6", 0.5)
    pip_m = make_material("cracked_pip", "0E1414", 0.8)
    crack_m = make_material("cracked_crack", "3B0D14", 0.9)
    bm = rounded_cube_bmesh(0.16 * EDGE, 2)
    ob = new_obj("CrackedD6", bm, [body_m, pip_m, crack_m])
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    spots = pip_spots(H)
    # Chips: each chipped corner is broken off by 2 slightly different tilted planes (a stepped,
    # irregular break that notches the silhouette), cut as deep as the pips allow.
    rims = []
    for (_s, n, u, v, c) in spots:
        for k in range(12):
            ang = k * math.tau / 12
            rims.append(c + (u * math.cos(ang) + v * math.sin(ang)) * a)
    cb = bmesh.new()
    for sgn, extra in CRACK_CHIPS:
        sg = Vector(sgn)
        for j in range(2):
            jit = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5)))
            nrm = Vector([sg[i] * (1.0 + jit[i]) for i in range(3)]).normalized()
            k = max(nrm.dot(r) for r in rims) + 0.0011 + extra * (1.0 if j else 0.45)
            res = bmesh.ops.create_cube(cb, size=0.2)
            side = nrm.cross(Vector((0, 1, 0)) if abs(nrm.y) < 0.9 else Vector((1, 0, 0))).normalized()
            m = Matrix((g2b(side), g2b(nrm.cross(side)), g2b(nrm))).transposed().to_4x4()
            bmesh.ops.transform(cb, verts=res["verts"], matrix=m)
            bmesh.ops.translate(cb, verts=res["verts"], vec=g2b(nrm * (k + 0.1)))
    boolean(ob, new_obj("chips", cb, [crack_m]), use_self=True)  # dark broken facets
    # Cracks: random walks from the chip, clear of every pip, as thin V-ish grooves.
    clear = a + 0.0026
    width, depth = 0.003, 0.005
    kb = bmesh.new()
    for slot, sgn, nseg in CRACK_FACES:
        n, u, v = face_axes(FACE_AXES[slot])
        sg = Vector(sgn)
        pips = [c for (s, _n, _u, _v, c) in spots if s == slot]
        cu, cv = (1 if sg.dot(u) > 0 else -1), (1 if sg.dot(v) > 0 else -1)
        p = n * H + u * cu * 0.026 + v * cv * 0.026
        heading = math.atan2(-cv, -cu) + rng.uniform(-0.5, 0.5)
        pts = [p]
        for _k in range(nseg):
            ok = False
            for tries in range(24):
                ang = heading + rng.uniform(-0.6, 0.6) * (1 + tries * 0.15)
                step = rng.uniform(0.0065, 0.0095)
                q = p + (u * math.cos(ang) + v * math.sin(ang)) * step
                qu, qv = q.dot(u), q.dot(v)
                if abs(qu) > 0.033 or abs(qv) > 0.033:
                    continue
                if all(seg_dist(c, p, q) > clear for c in pips):
                    ok = True
                    break
            if not ok:
                break
            heading = ang
            pts.append(q)
            p = q
        # start segment reaches back into the chip so the crack visibly leaves it
        pts.insert(0, n * H + u * cu * 0.036 + v * cv * 0.036)
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            w = width * (1.0 - 0.45 * i / max(1, len(pts) - 1))
            box_along(kb, (p0 + p1) * 0.5, p1 - p0, n.cross(p1 - p0), (p1 - p0).length + w, w, depth * 2)
    boolean(ob, new_obj("cracks", kb, [crack_m]), use_self=True)
    boolean(ob, cutter_caps(spots, a, d, 8, pip_m, H))
    return ob, 30.0


# (fraction of the length, radius m): base -> neck -> needle tip
SPIKE_PROFILE = [(0.0, 0.0084), (0.42, 0.0050), (0.72, 0.0020), (1.0, 0.0)]  # rings stay inside the face planes; only the needle passes them


def spike(bm, base, d, length, profile, segs):
    """A segs-sided spike from `base` along unit `d` (Godot), radius following `profile`, closed at both ends."""
    d = Vector(d).normalized()
    a = d.cross(Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))).normalized()
    b = d.cross(a)
    rings = []
    tip = None
    for f, r in profile:
        p = base + d * length * f
        if r <= 0.0:
            tip = bm.verts.new(g2b(p))
            continue
        rings.append([bm.verts.new(g2b(p + (a * math.cos(k * math.tau / segs) + b * math.sin(k * math.tau / segs)) * r))
                      for k in range(segs)])
    fs = [bm.faces.new(rings[0][::-1])]
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(segs):
            j = (k + 1) % segs
            fs.append(bm.faces.new((r0[k], r0[j], r1[j], r1[k])))
    for k in range(segs):
        fs.append(bm.faces.new((rings[-1][k], rings[-1][(k + 1) % segs], tip)))
    bmesh.ops.recalc_face_normals(bm, faces=fs)


def build_hellfire():
    """Hellfire Die: charred charcoal block (tighter bevel, heavier read) with a bone spike on all 8 corners,
    tapering to a needle tip, and an ember seam glowing along all 12 edges; ember pips."""
    body_m = make_material("hellfire_body", "1E1B1A", 0.9)
    pip_m = make_material("hellfire_pip", "E8622A", 0.6)
    seam_m = make_material("hellfire_seam", "E8622A", 0.6)
    spike_m = make_material("hellfire_spike", "E8DCC0", 0.5)
    radius = 0.10 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("HellfireD6", bm, [body_m, pip_m, seam_m, spike_m])
    # Spikes: 5-sided, along the corner diagonals, union'd (one hull). A stout base that necks in to a needle, so
    # the part past the face planes (what can sink into the felt on the box collider) is a thin sliver.
    sb = bmesh.new()
    c = H - radius
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                dvec = Vector((sx, sy, sz)).normalized()
                base = Vector((sx, sy, sz)) * c + dvec * radius * 0.35
                tip_len = (BOX_HALF - 0.0002 - base.x * sx) * math.sqrt(3.0)  # tip per axis = BOX_HALF - 0.2 mm
                spike(sb, base, dvec, tip_len, SPIKE_PROFILE, 5)
    boolean(ob, new_obj("spikes", sb, [spike_m]), op="UNION", use_self=True)
    # Seams: a square groove along the middle of each edge bevel, stopping short of the spikes.
    kb = bmesh.new()
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        others = [e for e in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))) if e != axis]
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                outv = (others[0] * s1 + others[1] * s2)
                centre = outv * c + outv.normalized() * radius
                box_along(kb, centre, axis, outv.cross(axis), EDGE * 0.62, 0.0032, 0.005)
    boolean(ob, new_obj("seams", kb, [seam_m]), use_self=True)
    a, d = 0.20 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 10, pip_m, H))
    clamp_to_box(ob)
    return ob, 30.0


def build_gilded():
    """Gilded Die: tarnished brass with a raised filigree frame (every face's centre is a
    recessed darker panel), a bead stud on every corner and edge-middle, and faceted ruby
    gem pips set in 6-sided cone settings."""
    body_m = make_material("gilded_body", "B08D3C", 0.3, 1.0)
    pip_m = make_material("gilded_pip", "C8281E", 0.1)
    panel_m = make_material("gilded_panel", "7A5E26", 0.5, 1.0)
    bead_m = make_material("gilded_bead", "E2C06A", 0.25, 1.0)  # polished bright brass studs on the tarnished body
    radius = 0.12 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("GildedD6", bm, [body_m, pip_m, panel_m, bead_m])
    c = H - radius
    # Beads (union): corners + edge middles, on the bevel surface.
    bb = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                dvec = Vector((sx, sy, sz))
                res = bmesh.ops.create_uvsphere(bb, u_segments=6, v_segments=4, radius=0.0072)
                bmesh.ops.translate(bb, verts=res["verts"], vec=g2b(dvec * c + dvec.normalized() * (radius + 0.0012)))
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        others = [e for e in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))) if e != axis]
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                outv = others[0] * s1 + others[1] * s2
                res = bmesh.ops.create_uvsphere(bb, u_segments=5, v_segments=3, radius=0.0042)
                bmesh.ops.translate(bb, verts=res["verts"], vec=g2b(outv * c + outv.normalized() * (radius + 0.0008)))
    boolean(ob, new_obj("beads", bb, [bead_m]), op="UNION", use_self=True)
    # Recessed panels.
    depth = 0.0016
    pb = bmesh.new()
    for nv in FACE_AXES.values():
        n, u, v = face_axes(nv)
        res = bmesh.ops.create_cube(pb, size=1.0)
        m = Matrix((g2b(u) * 0.0556, g2b(v) * 0.0556, g2b(n) * 0.006)).transposed().to_4x4()
        bmesh.ops.transform(pb, verts=res["verts"], matrix=m)
        bmesh.ops.translate(pb, verts=res["verts"], vec=g2b(n * (H - depth + 0.003)))
    boolean(ob, new_obj("panels", pb, [panel_m]))
    a, d = 0.20 * EDGE * 0.5, 0.075 * EDGE
    boolean(ob, cutter_cones(pip_spots(H - depth), a, d, 6, pip_m))
    clamp_to_box(ob)  # corner beads flattened where they would poke past the 0.08 m box collider (Godot Dev)
    return ob, 28.0


# ---------------------------------------------------------------- batch 2
def recolor(ob, pick):
    """Reassign polygon materials by position: pick(centre_godot, mat_index) -> mat_index."""
    me = ob.data
    for poly in me.polygons:
        c = poly.center
        poly.material_index = pick(Vector((c.x, c.z, -c.y)), poly.material_index)


def on_face_plane(p, flat):
    """True when p lies on one of the 6 face planes, inside the flat (un-decorated) square."""
    for i in range(3):
        if abs(abs(p[i]) - H) < 2e-4 and all(abs(p[j]) <= flat for j in range(3) if j != i):
            return True
    return False


EDGES = []  # (axis, outward vector) for the 12 edges
for _ax in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
    _o = [e for e in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))) if e != _ax]
    for _s1 in (-1, 1):
        for _s2 in (-1, 1):
            EDGES.append((_ax, _o[0] * _s1 + _o[1] * _s2))


def octahedron(bm, centre, axes):
    """A convex octahedron: 6 tips at centre +- each of the 3 (scaled) axes."""
    vs = []
    for ax in axes:
        vs.append(bm.verts.new(g2b(centre + ax)))
        vs.append(bm.verts.new(g2b(centre - ax)))
    px, nx, py, ny, pz, nz = vs
    for a, b in ((px, py), (py, nx), (nx, ny), (ny, px)):
        bm.faces.new((a, b, pz))
        bm.faces.new((b, a, nz))
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if all(v in vs for v in f.verts)])  # mirrored axes flip winding


LINE_W = 0.0016  # half-width of Twin Flame's ember waist line (3.2 mm, ~2 px at the game camera)


def build_twin_flame():
    """Twin Flame Die: two dice fused at the waist. The x = 0 plane splits it into a bone half and a charcoal
    half with a thin ember line round the seam; V-notches bite the 4 edges that cross it (a pinched waist at
    48 px). Pips flip colour with the half (dark on bone, bone on charcoal), so the centre pips on the seam are
    split twins."""
    body_m = make_material("twin_flame_body", "EDE3CF", 0.55)
    pip_m = make_material("twin_flame_pip", "0E1414", 0.8)
    half_m = make_material("twin_flame_half", "2A2426", 0.6)
    pipl_m = make_material("twin_flame_pip_light", "EDE3CF", 0.6)
    cleft_m = make_material("twin_flame_cleft", "0E1414", 0.8)
    line_m = make_material("twin_flame_line", "E8622A", 0.5)
    bm = rounded_cube_bmesh(0.15 * EDGE, 2)
    ob = new_obj("TwinFlameD6", bm, [body_m, pip_m, half_m, pipl_m, cleft_m, line_m])
    nb = bmesh.new()
    for sy in (-1, 1):
        for sz in (-1, 1):
            d = Vector((0, -sy, -sz)).normalized()
            p = Vector((0, sy, -sz)).normalized()
            octahedron(nb, Vector((0, sy * H, sz * H)), (Vector((0.02, 0, 0)), d * 0.0178, p * 0.0178))
    boolean(ob, new_obj("notches", nb, [half_m]), use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    # a clean seam: split every polygon that straddles x = 0 before recolouring by side
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for x0 in (0.0, -LINE_W, LINE_W):  # the seam + both edges of the thin ember line along it
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=(x0, 0, 0), plane_no=(1, 0, 0))
    bm.to_mesh(ob.data)
    bm.free()

    def pick(c, m):
        if m in (1, 3):
            return 1 if c.x >= 0 else 3
        sy, sz = (1 if c.y > 0 else -1), (1 if c.z > 0 else -1)
        dy, dz = c.y - sy * H, c.z - sz * H
        l1 = abs(c.x) / 0.02 + (abs(dy + dz) + abs(dy - dz)) / (math.sqrt(2) * 0.0178)
        if 0.85 < l1 < 1.08:
            return 4  # the notch clefts (on the octahedra's surface) are inked dark on both halves
        if abs(c.x) < LINE_W:
            return 5  # the thin ember line round the waist
        return 0 if c.x >= 0 else 2
    recolor(ob, pick)
    return ob, 30.0


# Wanderer corner fins: (fraction of the length, half-width in the blade plane, half-thickness) from the root (inside
# the bevel) to the point. Every ring stays inside the face planes (<= 0.042 m) except the last, 4.6 mm from the tip.
FIN_PROFILE = [(0.0, 0.0110, 0.0080), (0.45, 0.0075, 0.0058), (0.8, 0.0030, 0.0026), (1.0, 0.0, 0.0)]
FIN_TIP_FROM = 0.8  # the segment past this fraction is the bright brass tip (the glint)


def blade(bm, base, d, e, length, profile, tip_from):
    """A flat diamond-section blade from `base` along unit `d`, wide along unit `e` (Godot), closed at both ends.
    Faces past `tip_from` of the length get material index 1 (the tip), the rest 0."""
    d = Vector(d).normalized()
    e = Vector(e).normalized()
    n = d.cross(e)
    rings = []
    fr = []
    tip = None
    for f, w, t in profile:
        p = base + d * length * f
        if w <= 0.0:
            tip = bm.verts.new(g2b(p))
            continue
        rings.append([bm.verts.new(g2b(p + q)) for q in (e * w, n * t, -e * w, -n * t)])
        fr.append(f)
    fs = [bm.faces.new(rings[0][::-1])]
    for i, (r0, r1) in enumerate(zip(rings, rings[1:])):
        for k in range(4):
            j = (k + 1) % 4
            fs.append(bm.faces.new((r0[k], r0[j], r1[j], r1[k])))
            fs[-1].material_index = 1 if fr[i] >= tip_from - 1e-6 else 0
    for k in range(4):
        fs.append(bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 4], tip)))
        fs[-1].material_index = 1 if fr[-1] >= tip_from - 1e-6 else 0
    bmesh.ops.recalc_face_normals(bm, faces=fs)


def build_wanderer():
    """Wanderer Die: a mid steel-blue block with a compass point on each of the 8 corners: a flat dark-iron blade
    (diamond section, wide in the plane of the corner diagonal and the die's Y axis) tapering to a small bright
    brass tip that glints. Cream pips. (Fin read v2, AD Oct 19: dark fins on the mid body, bright tips.)"""
    body_m = make_material("wanderer_body", "5C7894", 0.6)
    pip_m = make_material("wanderer_pip", "F2E6C8", 0.6)
    fin_m = make_material("wanderer_fin", "34302E", 0.45, 1.0)
    tip_m = make_material("wanderer_fin_tip", "E2C06A", 0.25, 1.0)
    radius = 0.16 * EDGE  # a rounder edge leaves the fins more room inside the 0.08 m box
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("WandererD6", bm, [body_m, pip_m, fin_m, tip_m])
    c = H - radius
    fb = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                dvec = Vector((sx, sy, sz)).normalized()
                base = Vector((sx, sy, sz)) * c + dvec * radius * 0.35
                tip_len = (BOX_HALF - 0.0002 - base.x * sx) * math.sqrt(3.0)  # tip per axis = BOX_HALF - 0.2 mm
                e = Vector((0, 1, 0)) - dvec * dvec.y  # blade plane = the diagonal + the die's Y axis
                blade(fb, base, dvec, e, tip_len, FIN_PROFILE, FIN_TIP_FROM)
    boolean(ob, new_obj("fins", fb, [fin_m, tip_m]), op="UNION", use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    clamp_to_box(ob)
    return ob, 30.0


def build_bellows():
    """Bellows Die: tan leather with every edge folded into a 3-step staircase (accordion pleats, dark leather
    risers), so the outline corners are stepped."""
    body_m = make_material("bellows_body", "B88A5A", 0.75)
    pip_m = make_material("bellows_pip", "3B0D14", 0.8)
    pleat_m = make_material("bellows_pleat", "3A2418", 0.85)
    bm = rounded_cube_bmesh(0.05 * EDGE, 2)
    ob = new_obj("BellowsD6", bm, [body_m, pip_m, pleat_m])
    kb = bmesh.new()
    steps = ((0.003, 0.0095), (0.0062, 0.0062), (0.0095, 0.003))
    for axis, outv in EDGES:
        e1 = Vector([abs(x) for x in outv])
        for k, (s1, s2) in enumerate(steps):
            o = [e for e in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))) if e.dot(e1) > 0.5]
            d1, d2 = o[0] * outv.dot(o[0]), o[1] * outv.dot(o[1])
            centre = d1 * (H - s1 + 0.05) + d2 * (H - s2 + 0.05)
            res = bmesh.ops.create_cube(kb, size=1.0)
            m = Matrix((g2b(axis) * 0.12, g2b(d1) * 0.1, g2b(d2) * 0.1)).transposed().to_4x4()
            bmesh.ops.transform(kb, verts=res["verts"], matrix=m)
            bmesh.ops.translate(kb, verts=res["verts"], vec=g2b(centre))
    boolean(ob, new_obj("pleats", kb, [pleat_m]), use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    recolor(ob, lambda c, m: m if m == 1 else (0 if on_face_plane(c, H - 0.0095) else 2))
    return ob, 30.0


STAMP_R = 0.0084  # bone disc radius round the corner diagonal; the rest of the pressed seal is the black wax ring


def build_blood_pact():
    """Blood Pact Die: glossy crimson with two blood-black wax seals pressed onto opposite corners (the pact's
    two parties: a wide black disc with a bone stamp boss); bone pips (the signature)."""
    body_m = make_material("blood_pact_body", "7E1626", 0.3)
    pip_m = make_material("blood_pact_pip", "E8DCC0", 0.6)
    seal_m = make_material("blood_pact_seal", "141012", 0.2)
    stamp_m = make_material("blood_pact_stamp", "E8DCC0", 0.5)
    radius = 0.14 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("BloodPactD6", bm, [body_m, pip_m, seal_m, stamp_m])
    c = H - radius
    sb = bmesh.new()
    gb = bmesh.new()
    for sgn in (1, -1):
        dv = Vector((sgn, sgn, sgn))
        dn = dv.normalized()
        corner = dv * c + dn * radius
        rot = Vector((0, 0, 1)).rotation_difference(g2b(dn)).to_matrix().to_4x4()
        # a pressed black wax seal (a wide flattened disc) with a bone stamp boss in its middle
        res = bmesh.ops.create_uvsphere(sb, u_segments=12, v_segments=6, radius=1.0)
        bmesh.ops.transform(sb, verts=res["verts"], matrix=rot @ Matrix.Diagonal((0.0148, 0.0148, 0.0058, 1.0)))
        bmesh.ops.translate(sb, verts=res["verts"], vec=g2b(corner + dn * 0.0004))
        res = bmesh.ops.create_uvsphere(gb, u_segments=10, v_segments=5, radius=1.0)
        bmesh.ops.transform(gb, verts=res["verts"], matrix=rot @ Matrix.Diagonal((0.0108, 0.0108, 0.0056, 1.0)))  # a wide bone boss: most of the seal reads bone, a black wax ring round it
        bmesh.ops.translate(gb, verts=res["verts"], vec=g2b(corner + dn * 0.0042))
    boolean(ob, new_obj("seals", sb, [seal_m]), op="UNION", use_self=True)
    boolean(ob, new_obj("stamps", gb, [stamp_m]), op="UNION", use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    clamp_to_box(ob)  # the seals press flat against the three faces (wax squashed onto the corner)
    # The flat pressed tops (the caps clamp_to_box left on the three corner faces) become a full-value bone disc in
    # a black wax ring: cut the caps along an 8-sided prism of radius STAMP_R round the corner diagonal, the inside
    # is the bone stamp, the outside the wax (fin read, AD Oct 19)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for sgn in (1, -1):
        dn = g2b(Vector((sgn, sgn, sgn)).normalized())
        w0 = dn.cross(Vector((0, 0, 1))).normalized()
        for k in range(8):
            w = Matrix.Rotation(k * math.tau / 8, 3, dn) @ w0
            caps = [f for f in bm.faces if f.material_index in (2, 3) and f.calc_center_median().dot(dn) > 0]
            geom = list({e for f in caps for e in f.edges}) + list({v for f in caps for v in f.verts}) + caps
            bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=w * STAMP_R, plane_no=w)
    for f in bm.faces:
        if f.material_index in (2, 3):
            c = f.calc_center_median()
            dn = g2b(Vector((1, 1, 1)).normalized()) * (1 if c.dot(g2b(Vector((1, 1, 1)))) > 0 else -1)
            f.material_index = 3 if (c - dn * c.dot(dn)).length < STAMP_R else 2
    bm.to_mesh(ob.data)
    bm.free()
    return ob, 30.0


def build_coven():
    """Coven Die: matte dusty-plum block (no glow / emission) with all 12 edges scooped into concave coves (wax-pale), leaving pointed
    three-way corners: a cross-like outline with concave corners at 48 px."""
    body_m = make_material("coven_body", "6E4A6E", 0.95)
    pip_m = make_material("coven_pip", "E8DCC0", 0.6)
    cove_m = make_material("coven_cove", "D9CBA8", 0.6)
    bm = rounded_cube_bmesh(0.04 * EDGE, 1)
    ob = new_obj("CovenD6", bm, [body_m, pip_m, cove_m])
    kb = bmesh.new()
    off, R = 0.0042, 0.0136
    for axis, outv in EDGES:
        centre = outv * (H + off)
        res = bmesh.ops.create_cone(kb, cap_ends=True, segments=14, radius1=R, radius2=R, depth=0.12,
                                    matrix=Matrix.Identity(4))
        rot = Vector((0, 0, 1)).rotation_difference(g2b(axis)).to_matrix().to_4x4()
        bmesh.ops.transform(kb, verts=res["verts"], matrix=rot)
        bmesh.ops.translate(kb, verts=res["verts"], vec=g2b(centre))
    boolean(ob, new_obj("coves", kb, [cove_m]), use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    return ob, 25.0


def build_last_breath():
    """Last Breath Die: a pale ash-stone urn block with a dark iron collar hoop round BOTH ends (outside the
    side pips), so it reads as a banded urn from any side; charcoal pips."""
    body_m = make_material("last_breath_body", "9AA0A6", 0.85)
    pip_m = make_material("last_breath_pip", "2A2426", 0.8)
    collar_m = make_material("last_breath_collar", "34302E", 0.4, 1.0)
    radius = 0.14 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("LastBreathD6", bm, [body_m, pip_m, collar_m])
    a_flat = BOX_HALF - 0.0002  # collar face 1.6 mm proud of the side faces (was 5.2 mm)
    d_flat = 0.0568 * a_flat / 0.0452
    k = d_flat * math.sqrt(2) - a_flat
    ring = [(a_flat, -k), (a_flat, k), (k, a_flat), (-k, a_flat), (-a_flat, k), (-a_flat, -k), (-k, -a_flat), (k, -a_flat)]
    cb = bmesh.new()
    for y0, y1 in ((0.0270, 0.0345), (-0.0345, -0.0270)):  # a collar on BOTH ends (outside the side pips)
        lo = [cb.verts.new(g2b(Vector((x, y0, z)))) for x, z in ring]
        hi = [cb.verts.new(g2b(Vector((x, y1, z)))) for x, z in ring]
        cb.faces.new(lo[::-1])
        cb.faces.new(hi)
        for i in range(8):
            j = (i + 1) % 8
            cb.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(cb, faces=cb.faces)
    boolean(ob, new_obj("collar", cb, [collar_m]), op="UNION", use_self=True)
    a, d = 0.18 * EDGE * 0.5, 0.06 * EDGE
    boolean(ob, cutter_caps(pip_spots(H), a, d, 8, pip_m, H))
    clamp_to_box(ob)
    return ob, 30.0


BUILDERS = {"mirror_d6": build_mirror, "cracked_d6": build_cracked,
            "hellfire_d6": build_hellfire, "gilded_d6": build_gilded,
            "twin_flame_d6": build_twin_flame, "wanderer_d6": build_wanderer, "bellows_d6": build_bellows,
            "blood_pact_d6": build_blood_pact, "coven_d6": build_coven, "last_breath_d6": build_last_breath}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if argv and ("/" in argv[0] or argv[0].startswith(".")):
        out_dir = os.path.abspath(argv.pop(0))
    names = argv or list(BUILDERS)
    os.makedirs(out_dir, exist_ok=True)
    global BOX_HALF
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        BOX_HALF = H * EXTENT_SCALE.get(name, VISUAL_EXTENT_SCALE)
        ob, sharp = BUILDERS[name]()
        tris = finish(ob, sharp)
        path = export(ob, name, out_dir)
        dims = [round(x, 4) for x in ob.dimensions]
        ext = [round(max(abs(v.co[i]) for v in ob.data.vertices), 4) for i in range(3)]
        print("BUILT %s tris=%d verts=%d dims=%s max_extent=%s cap=%.4f -> %s" % (name, tris, len(ob.data.vertices), dims, ext, BOX_HALF, path))
        if os.environ.get("DICE_SAVE_BLEND"):
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ["DICE_SAVE_BLEND"], name + ".blend"))


main()
