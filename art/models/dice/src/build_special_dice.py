"""Builds the four special dice (Mirror, Cracked, Hellfire, Gilded) as game-ready .glb files.

Run headless (Blender 4.5 LTS):
    blender -b --factory-startup --python art/models/dice/src/build_special_dice.py -- [out_dir] [name ...]
out_dir defaults to art/models/dice/. With no names, all four are built. The Bone d6 has its own
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


def build_hellfire():
    """Hellfire Die: charred charcoal block (tighter bevel, heavier read) with a short spike
    on all 8 corners and an ember seam glowing along all 12 edges; ember pips."""
    body_m = make_material("hellfire_body", "1E1B1A", 0.9)
    pip_m = make_material("hellfire_pip", "E8622A", 0.6)
    seam_m = make_material("hellfire_seam", "E8622A", 0.6)
    radius = 0.10 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("HellfireD6", bm, [body_m, pip_m, seam_m])
    # Spikes: 5-sided pyramids along the corner diagonals, union'd (one hull).
    sb = bmesh.new()
    c = H - radius
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                dvec = Vector((sx, sy, sz)).normalized()
                base = Vector((sx, sy, sz)) * c + dvec * radius * 0.35
                tip_len = 0.021
                res = bmesh.ops.create_cone(sb, cap_ends=True, segments=5, radius1=0.0095, radius2=0.0,
                                            depth=tip_len, matrix=Matrix.Identity(4))
                bmesh.ops.translate(sb, verts=res["verts"], vec=Vector((0, 0, tip_len * 0.5)))
                rot = Vector((0, 0, 1)).rotation_difference(g2b(dvec)).to_matrix().to_4x4()
                bmesh.ops.transform(sb, verts=res["verts"], matrix=rot)
                bmesh.ops.translate(sb, verts=res["verts"], vec=g2b(base))
    boolean(ob, new_obj("spikes", sb, [body_m]), op="UNION", use_self=True)
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
    return ob, 30.0


def build_gilded():
    """Gilded Die: tarnished brass with a raised filigree frame (every face's centre is a
    recessed darker panel), a bead stud on every corner and edge-middle, and faceted ruby
    gem pips set in 6-sided cone settings."""
    body_m = make_material("gilded_body", "B08D3C", 0.3, 1.0)
    pip_m = make_material("gilded_pip", "C8281E", 0.1)
    panel_m = make_material("gilded_panel", "7A5E26", 0.5, 1.0)
    radius = 0.12 * EDGE
    bm = rounded_cube_bmesh(radius, 2)
    ob = new_obj("GildedD6", bm, [body_m, pip_m, panel_m])
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
    boolean(ob, new_obj("beads", bb, [body_m]), op="UNION", use_self=True)
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
    return ob, 28.0


BUILDERS = {"mirror_d6": build_mirror, "cracked_d6": build_cracked,
            "hellfire_d6": build_hellfire, "gilded_d6": build_gilded}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if argv and ("/" in argv[0] or argv[0].startswith(".")):
        out_dir = os.path.abspath(argv.pop(0))
    names = argv or list(BUILDERS)
    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        ob, sharp = BUILDERS[name]()
        tris = finish(ob, sharp)
        path = export(ob, name, out_dir)
        dims = [round(x, 4) for x in ob.dimensions]
        print("BUILT %s tris=%d verts=%d dims=%s -> %s" % (name, tris, len(ob.data.vertices), dims, path))
        if os.environ.get("DICE_SAVE_BLEND"):
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ["DICE_SAVE_BLEND"], name + ".blend"))


main()
