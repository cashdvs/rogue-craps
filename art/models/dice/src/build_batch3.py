"""Builds the batch-3 non-d6 special dice (Art Director brief, Oct 19, 2026) as game-ready .glb files, a PC
mesh (~600 tris) and a mobile LOD (<= 300 tris) each:

    caltrop_d4  lantern_d8  tithe_d10  midnight_d12  verdict_d20  ferryman_d2  powder_keg_d3  knucklebone_talus

Run headless (Blender 4.5 LTS):
    blender -b --factory-startup --python art/models/dice/src/build_batch3.py -- [out_dir] [name ...]
then `python3 art/models/dice/src/write_batch3.py` (face textures + toon materials) and, after one
`godot --headless --import`, `python3 art/models/dice/src/write_batch3.py --imports` (slot mapping).

Everything is built in GODOT space (metres, +Y up, -Z forward), centred on the centre of mass, one mesh, scale 1;
the vertices are turned to Blender Z-up just before export and the glTF exporter turns them back.
Numerals and pips are NOT geometry: every face is UV-mapped into a 5x5 cell atlas (1024 px) and
write_batch3.py paints the numerals / pips / veins / engraving into textures/<die>_faces.png, which the toon
shader lays over the body colour (`use_overlay`). Bevels map to the trim cell (24), keg ends to cell 23.

Outputs (besides the .glb files):
  art/models/dice/batch3_faces.json   value -> local direction table per die (what Godot Dev reads the result with)
  art/models/dice/src/batch3_layout.json   texture layout (cell, centre px, px per metre, face polygons) for write_batch3.py
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

SRC = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(SRC, ".."))
ATLAS = 1024
GRID = 5
CELL = ATLAS / GRID
TRIM, TRIM2 = 24, 23
PHI = (1.0 + 5 ** 0.5) / 2.0
D6_VOLUME = 0.08 ** 3  # the Bone d6's bounding volume (AD: match bounding volume, not edge length)
BEVEL_COMP = 1.025  # the bevels eat ~2.5% of the rest volume
# PM, Oct 19: non-d6 dice cap their max per-axis half-extent at 0.050 m (Tithe passes at 0.0507 by ruling). These three
# were over and are scaled down uniformly (PC and mobile by the same factor, computed from the PC extent).
EXTENT_CAP = {"caltrop_d4": 0.050, "knucklebone_talus": 0.050, "lantern_d8": 0.050}
# Godot Dev builds the hulls from the mobile meshes, so mobile extents must match PC within ~0.5 mm. Mobile LODs chamfer
# with 1 bevel segment, which cuts corners deeper than the PC round bevel; main() searches this multiplier on the mobile
# chamfer offset per die so the mobile extents land on the PC ones.
MOBILE_BEVEL_MULT = 1.0
BEVELLED = {"caltrop_d4", "lantern_d8", "tithe_d10", "midnight_d12", "verdict_d20"}
G2B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()  # Godot (x, y, z) -> Blender (x, -z, y)


def srgb_to_linear(h):
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def make_material(name, hex_col, rough=0.6, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb_to_linear(hex_col)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = srgb_to_linear(hex_col)
    return m


def cell_centre(cell):
    return Vector((((cell % GRID) + 0.5) * CELL, ((cell // GRID) + 0.5) * CELL))


class Frame:
    """Planar UV frame of one face: centre c, outward normal n, numeral 'up' u (in the face plane)."""

    def __init__(self, cell, c, n, up, value=None, label=None):
        self.cell, self.c, self.n = cell, Vector(c), Vector(n).normalized()
        up = Vector(up)
        up = (up - self.n * up.dot(self.n)).normalized()
        self.up = up
        self.right = up.cross(self.n).normalized()
        self.value, self.label = value, label
        self.poly = []
        self.extra = {}

    def px(self, p, s):
        d = Vector(p) - self.c
        return cell_centre(self.cell) + Vector((d.dot(self.right), -d.dot(self.up))) * s


# ------------------------------------------------------------------ polyhedra
def hull(points):
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    bmesh.ops.delete(bm, geom=[g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)], context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts[:], edges=bm.edges[:])
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    bm.normal_update()
    return bm


def rot_to(a, b):
    return Vector(a).normalized().rotation_difference(Vector(b).normalized()).to_matrix()


def rest_volume(points, down):
    """AABB volume with the die resting on the face whose outward normal is `down`."""
    r = rot_to(down, (0, -1, 0))
    q = [r @ Vector(p) for p in points]
    return math.prod(max(p[i] for p in q) - min(p[i] for p in q) for i in range(3))


def scaled(points, down, target):
    k = (target ** 3 / rest_volume(points, down)) ** (1.0 / 3.0)
    return [Vector(p) * k for p in points]


def face_list(bm):
    return [(f.normal.copy(), f.calc_center_median_weighted() if hasattr(f, "calc_center_median_weighted") else f.calc_center_median(),
             [v.co.copy() for v in f.verts]) for f in bm.faces]


def assign_opposite(faces, top):
    """Values for a polyhedron whose opposite faces sum to top + 1: highest faces first (then azimuth)."""
    order = sorted(range(len(faces)), key=lambda i: (-round(faces[i][0].y, 4), math.atan2(faces[i][0].z, faces[i][0].x)))
    vals = {}
    nxt = top
    for i in order:
        if i in vals:
            continue
        opp = min(range(len(faces)), key=lambda j: faces[j][0].dot(faces[i][0]))
        vals[i] = nxt
        vals[opp] = top + 1 - nxt
        nxt -= 1
    return vals


def poly_frames(bm, vals, labels, up_rule):
    frames = []
    for i, f in enumerate(bm.faces):
        v = vals[i]
        n = f.normal.copy()
        c = Vector((0, 0, 0))
        for vv in f.verts:
            c += vv.co
        c /= len(f.verts)
        up = up_rule(n, c, [vv.co.copy() for vv in f.verts])
        fr = Frame(v - 1, c, n, up, v, labels.get(v, str(v)))
        fr.poly = [vv.co.copy() for vv in f.verts]
        frames.append(fr)
    return frames


def up_to_vertex(n, c, verts):
    hint = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, -1))
    hint = (hint - n * hint.dot(n))
    return max(((v - c).normalized() for v in verts), key=lambda d: d.dot(hint)) - c * 0 if hint.length > 1e-6 else verts[0] - c


def up_to_apex(n, c, verts):
    return max(verts, key=lambda v: (v - c).length) - c


def up_hint(n, c, verts):
    hint = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, -1))
    return hint


def bevel(bm, offset, segs):
    if segs == 1:
        offset *= MOBILE_BEVEL_MULT  # mobile chamfer, tuned to match the PC extents (see main)
    if segs <= 0 or offset <= 0:
        return []
    res = bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=offset, offset_type="OFFSET", segments=segs, profile=0.5,
                          affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    return res["faces"]


def classify_by_normal(frames, tol=0.9995):
    def f(c, n, mat):
        best = max(frames, key=lambda fr: fr.n.dot(n))
        return frames.index(best) if best.n.dot(n) > tol else TRIM
    return f


# ------------------------------------------------------------------ the dice
def tetra_points():
    pts = [Vector((0, 1, 0))]
    for k in range(3):
        a = math.radians(90 + 120 * k)
        pts.append(Vector((math.cos(a) * math.sqrt(8 / 9), -1 / 3, math.sin(a) * math.sqrt(8 / 9))))
    return pts


def build_caltrop(pc):
    """Caltrop d4: a blackened-iron tetrahedron, chunky rusted bevels, value = the vertex on top. Every face shows
    the values of its 3 corners as bone pip clusters at the tips, so the 3 faces round the top point all show it."""
    mats = [make_material("caltrop_body", "2E2B2A", 0.55, 0.6)]
    base = tetra_points()
    pts = scaled(base, (0, -1, 0), 0.08 * 1.22)  # AD: the d4 a little larger so it doesn't get lost
    bm = hull(pts)
    tips = {i + 1: pts[i] for i in range(4)}
    frames = []
    for f in bm.faces:
        n = f.normal.copy()
        opp = min(tips, key=lambda k: tips[k].normalized().dot(n))  # the face opposite vertex `opp`
        c = sum((v.co for v in f.verts), Vector()) / 3
        fr = Frame(opp - 1, c, n, Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((0, 0, -1)), opp, "")
        fr.poly = [v.co.copy() for v in f.verts]
        fr.extra["corners"] = [(k, tips[k]) for k in tips if k != opp]
        frames.append(fr)
    edge = (pts[0] - pts[1]).length
    bevel(bm, edge * 0.055, 3 if pc else 1)
    dirs = [[k, list(tips[k].normalized())] for k in tips]
    return dict(bm=bm, mats=mats, frames=frames, classify=classify_by_normal(frames), textured=[0], read="vertex",
                dirs=dirs, sharp=35.0, node="CaltropD4", rest_down=[0, -1, 0])


def build_lantern(pc):
    """Lantern d8: smoky amber glass panes in a pewter edge frame (wide bevel + recessed panes), pale numerals."""
    mats = [make_material("lantern_body", "8A5418", 0.15), make_material("lantern_frame", "8C8A84", 0.35, 1.0)]
    base = [Vector(v) for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
    pts = scaled(base, Vector((-1, -1, -1)), 0.08 * BEVEL_COMP)
    bm = hull(pts)
    faces = face_list(bm)
    vals = assign_opposite(faces, 8)
    frames = poly_frames(bm, vals, {6: "6.", 9: "9."}, up_to_apex if False else (lambda n, c, vs: max(vs, key=lambda v: (v - c).dot((Vector((0, 1, 0)) - n * n.y) if abs(n.y) < 0.99 else Vector((0, 0, -1)))) - c))
    edge = (pts[0] - pts[2]).length
    bfaces = set(bevel(bm, edge * 0.055, 2 if pc else 1))  # a wide pewter frame (AD: frame edges must read)
    panes = [f for f in bm.faces if f not in bfaces]
    res = bmesh.ops.inset_individual(bm, faces=panes, thickness=edge * 0.028, depth=-edge * 0.012, use_even_offset=True)
    for f in bm.faces:
        f.material_index = 0 if f in panes else 1
    bm.normal_update()
    cls = classify_by_normal(frames)
    return dict(bm=bm, mats=mats, frames=frames, classify=lambda c, n, m: cls(c, n, m) if m == 0 else TRIM, textured=[0],
                read="face", dirs=[[fr.value, list(fr.n)] for fr in frames], sharp=30.0, node="LanternD8",
                rest_down=list(-frames[0].n))


def build_tithe(pc):
    """Tithe d10: midnight-navy enamel pentagonal trapezohedron, bone numerals, a coin-slot notch cut in the 10."""
    mats = [make_material("tithe_body", "1C2846", 0.35), make_material("tithe_slot", "0E1414", 0.9)]
    z0 = 0.1056
    h = z0 * (1 + math.cos(math.radians(36))) / (1 - math.cos(math.radians(36)))
    base = [Vector((0, h, 0)), Vector((0, -h, 0))]
    for k in range(10):
        a = math.radians(36 * k)
        base.append(Vector((math.cos(a), z0 if k % 2 == 0 else -z0, math.sin(a))))
    bm0 = hull(base)
    down = min(bm0.faces, key=lambda f: f.normal.y).normal.copy()
    bm0.free()
    pts = scaled(base, down, 0.08 * BEVEL_COMP)
    bm = hull(pts)
    faces = face_list(bm)
    vals = assign_opposite(faces, 10)
    frames = poly_frames(bm, vals, {6: "6.", 9: "9."}, up_to_apex)
    edge = min(e.calc_length() for e in bm.edges)
    bevel(bm, 0.0032, 2 if pc else 1)
    # coin slot: a thin box across the 10 face, between the numeral and the apex
    f10 = next(fr for fr in frames if fr.value == 10)
    apex_d = max((v - f10.c).length for v in f10.poly)
    sc = f10.c + f10.up * apex_d * 0.36
    f10.extra["slot"] = [list(sc), 0.016, 0.0028]
    f10.extra["label_shift"] = -0.10  # numeral nudged toward the wide end (fraction of the face span)
    cut = bmesh.new()
    r = bmesh.ops.create_cube(cut, size=1.0)
    m = Matrix((f10.right * 0.016, f10.up * 0.0028, f10.n * 0.006)).transposed().to_4x4()
    bmesh.ops.transform(cut, verts=r["verts"], matrix=m)
    bmesh.ops.translate(cut, verts=r["verts"], vec=sc - f10.n * 0.0)
    cls = classify_by_normal(frames)
    return dict(bm=bm, mats=mats, frames=frames, classify=lambda c, n, m: cls(c, n, m) if m == 0 else TRIM, textured=[0],
                read="face", dirs=[[fr.value, list(fr.n)] for fr in frames], sharp=30.0, node="TitheD10",
                cutters=[(cut, 1)], rest_down=list(down))


def build_midnight(pc):
    """Midnight d12: parchment-cream clock-face enamel dodecahedron in a dark bezel, charcoal Roman numerals, the XII
    face oxblood with tiny brass hands at midnight."""
    mats = [make_material("midnight_body", "E6D6B0", 0.5)]
    base = []
    for x in (-1, 1):
        for y in (-1, 1):
            for z in (-1, 1):
                base.append(Vector((x, y, z)))
    for a in (-1, 1):
        for b in (-1, 1):
            base += [Vector((0, a / PHI, b * PHI)), Vector((a / PHI, b * PHI, 0)), Vector((a * PHI, 0, b / PHI))]
    bm0 = hull(base)
    top = max(bm0.faces, key=lambda f: f.normal.y).normal.copy()
    bm0.free()
    rot = rot_to(top, (0, 1, 0))  # a face (the XII) straight up
    base = [rot @ p for p in base]
    pts = scaled(base, (0, -1, 0), 0.08 * BEVEL_COMP)
    bm = hull(pts)
    faces = face_list(bm)
    vals = assign_opposite(faces, 12)
    roman = {i: s for i, s in enumerate(["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"])}
    frames = poly_frames(bm, vals, roman, up_to_vertex)
    bevel(bm, 0.0030, 2 if pc else 1)
    return dict(bm=bm, mats=mats, frames=frames, classify=classify_by_normal(frames), textured=[0], read="face",
                dirs=[[fr.value, list(fr.n)] for fr in frames], sharp=30.0, node="MidnightD12", rest_down=[0, -1, 0])


def build_verdict(pc):
    """Verdict d20: oxblood-veined dark marble icosahedron, bone numerals, a gold wax seal pressed on the 20."""
    mats = [make_material("verdict_body", "2A1E22", 0.25), make_material("verdict_seal", "C9A23A", 0.35, 0.6)]
    base = []
    for a in (-1, 1):
        for b in (-1, 1):
            base += [Vector((0, a, b * PHI)), Vector((a, b * PHI, 0)), Vector((a * PHI, 0, b))]
    n0 = (Vector((0, 1, PHI)) + Vector((1, PHI, 0)) + Vector((-1, PHI, 0))).normalized()
    rot = rot_to(n0, (0, 1, 0))
    base = [rot @ p for p in base]
    pts = scaled(base, (0, -1, 0), 0.08 * BEVEL_COMP)
    bm = hull(pts)
    faces = face_list(bm)
    vals = assign_opposite(faces, 20)
    frames = poly_frames(bm, vals, {6: "6.", 9: "9."}, up_to_vertex)
    bevel(bm, 0.0028, 2 if pc else 1)
    # gold wax seal on the 20: a low 12/8-sided disc pressed into the face, 0.7 mm proud (not a boolean)
    f20 = next(fr for fr in frames if fr.value == 20)
    inr = min((((a + b) * 0.5) - f20.c).length for a, b in zip(f20.poly, f20.poly[1:] + f20.poly[:1]))
    rad = inr * 0.62
    segs = 12  # 12 on mobile too, so the hull keeps the face's three mirror lines
    lo, hi = [], []
    for k in range(segs):
        a = math.tau * k / segs
        d = f20.right * math.cos(a) + f20.up * math.sin(a)
        wob = 1.0 + 0.06 * math.sin(3 * a)  # a pressed wax edge, 3 soft lobes, symmetric about the face's mirror lines
        lo.append(bm.verts.new(f20.c + d * rad * wob * 1.08 - f20.n * 0.0004))
        hi.append(bm.verts.new(f20.c + d * rad * wob + f20.n * 0.0007))
    top = bm.faces.new(hi)
    top.material_index = 1
    bot = bm.faces.new(lo[::-1])
    bot.material_index = 1
    for k in range(segs):
        j = (k + 1) % segs
        f = bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
        f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f.material_index == 1])
    bm.normal_update()
    seal_frame = Frame(20, f20.c, f20.n, f20.up, 20, "20")
    seal_frame.poly = [f20.c + (f20.right * math.cos(math.tau * k / 24) + f20.up * math.sin(math.tau * k / 24)) * rad for k in range(24)]
    seal_frame.extra["seal"] = True
    frames.append(seal_frame)
    cls = classify_by_normal(frames[:-1])

    def classify(c, n, m):
        if m == 1:
            return len(frames) - 1 if n.dot(f20.n) > 0.99 else TRIM
        return cls(c, n, m)
    return dict(bm=bm, mats=mats, frames=frames, classify=classify, textured=[0, 1], read="face",
                dirs=[[fr.value, list(fr.n)] for fr in frames[:-1]], sharp=30.0, node="VerdictD20", rest_down=[0, -1, 0])


def build_ferryman(pc):
    """Ferryman's Coin d2: a thick worn-pewter obol with a ridged edge and a raised rim; heads = a grinning skull,
    tails = a moth (engraved in the texture). Heads = +Y."""
    mats = [make_material("ferryman_body", "8A8478", 0.45, 0.8)]
    r, t = 0.050, 0.024
    n = 36 if pc else 20  # even half-counts, so the alternate-vertex reeding is mirror-symmetric in X and Z
    ridge = 0.0008
    # Rounded (barrelled) edge, Oct 19: with a flat 21 mm edge band the coin stood on its edge in 2/40 sandbox throws.
    # The edge is an arc of radius 0.02 m (< the 0.05 m coin radius), so the equator is a ridge and an edge pose rolls
    # over onto a face. Heads and tails stay exact mirror images (relief, rim and edge).
    rho = 0.020
    ye = t / 2 - 0.0016
    xe = r - rho + math.sqrt(rho * rho - ye * ye)
    if pc:
        top = [(r * 0.76, t / 2 - 0.0011), (r * 0.76 + 0.0011, t / 2), (r - 0.0035, t / 2), (xe, ye)]
    else:
        top = [(r * 0.76, t / 2 - 0.0011), (r - 0.0035, t / 2), (xe, ye)]
    prof = top + [(r, 0.0)] + [(a, -b) for a, b in reversed(top)]
    edge_rings = {len(top) - 1, len(top), len(top) + 1}
    bm = bmesh.new()
    rings = []
    for i, (pr, py) in enumerate(prof):
        ring = []
        for k in range(n):
            a = math.tau * k / n
            rr = pr - (ridge if (k % 2 and i in edge_rings) else 0.0)
            ring.append(bm.verts.new(Vector((math.cos(a) * rr, py, math.sin(a) * rr))))
        rings.append(ring)
    ctop = bm.verts.new(Vector((0, t / 2 - 0.0011, 0)))
    cbot = bm.verts.new(Vector((0, -(t / 2 - 0.0011), 0)))
    for k in range(n):
        j = (k + 1) % n
        bm.faces.new((ctop, rings[0][j], rings[0][k]))
        bm.faces.new((cbot, rings[-1][k], rings[-1][j]))
        for i in range(len(rings) - 1):
            bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    bm.normal_update()
    heads = Frame(0, (0, t / 2, 0), (0, 1, 0), (0, 0, -1), 1, "heads")
    tails = Frame(1, (0, -t / 2, 0), (0, -1, 0), (0, 0, -1), 2, "tails")
    for fr in (heads, tails):
        fr.poly = [fr.c + (fr.right * math.cos(math.tau * k / 32) + fr.up * math.sin(math.tau * k / 32)) * r for k in range(32)]
        fr.extra["field_r"] = r * 0.76
    frames = [heads, tails]

    def classify(c, nn, m):
        if nn.y > 0.6:
            return 0
        if nn.y < -0.6:
            return 1
        return TRIM
    return dict(bm=bm, mats=mats, frames=frames, classify=classify, textured=[0], read="face",
                dirs=[[1, [0, 1, 0]], [2, [0, -1, 0]]], sharp=40.0, node="FerrymanD2", rest_down=[0, -1, 0],
                names={1: "heads", 2: "tails"})


def build_powder_keg(pc):
    """Powder Keg d3: a hexagonal barrel (bulged mustard staves, black iron hoops, dark recessed lids) that rolls on
    its long axis (local X). Six staves show 1, 2, 3, 1, 2, 3, so opposite staves match and the top stave is the value."""
    mats = [make_material("powder_keg_body", "C9A030", 0.8), make_material("powder_keg_hoop", "1E1C1C", 0.4, 1.0)]
    L, a_mid = 0.098, 0.0337
    bulge = 0.16
    segs = 8 if pc else 4
    sec = 1.0 / math.cos(math.radians(30))

    def apo(x):
        return a_mid * (1.0 - bulge * (2.0 * x / L) ** 2)

    def ring(bm, x, a):
        return [bm.verts.new(Vector((x, math.cos(math.radians(30 + 60 * j)) * a * sec, math.sin(math.radians(30 + 60 * j)) * a * sec))) for j in range(6)]

    bm = bmesh.new()
    # Domed lid ends (Oct 19). Flat lids stood the keg on an end in 1/10 random throws; an 8 mm chamfer (2/20) and a
    # spherical cap (5/30) made it worse, because their hex corners got *closer* to the centre of mass toward the tip,
    # leaving stable tilted rests. Here every ring's corners sit strictly *farther* from the centre than the ring
    # before it, out to a small lid at the 0.049 m half-length, so any pose on the dome rolls back onto a stave; only
    # the small lid itself (~5 deg tip margin) is still a (rare) rest.
    sec30 = 1.0 / math.cos(math.radians(30))
    xj = 0.030
    rho_j = math.hypot(xj, apo(xj) * sec30)
    psi_j = math.atan2(apo(xj) * sec30, xj)
    tip = L / 2

    def dome(f):  # f in (0, 1): fraction of the junction angle; corner distance grows linearly to the tip
        psi = psi_j * f
        rho = tip - (tip - rho_j) * f
        return rho * math.cos(psi), rho * math.sin(psi) / sec30

    xs = [-xj + 2 * xj * i / segs for i in range(segs + 1)]
    rings = [ring(bm, x, apo(x)) for x in xs]
    fr_ = [0.76, 0.52, 0.31] if pc else [0.6]
    taper = [dome(f) for f in fr_]
    lx, a_end = dome(0.09)
    end_l = [ring(bm, -x, a) for x, a in taper]
    end_r = [ring(bm, x, a) for x, a in taper]
    lid_l = ring(bm, -lx, a_end)
    lid_r = ring(bm, lx, a_end)
    lid_li = ring(bm, -lx + 0.0012, a_end * 0.55)
    lid_ri = ring(bm, lx - 0.0012, a_end * 0.55)
    chain = [lid_li, lid_l] + end_l[::-1] + rings + end_r + [lid_r, lid_ri]
    for i in range(len(chain) - 1):
        for j in range(6):
            k = (j + 1) % 6
            bm.faces.new((chain[i][j], chain[i][k], chain[i + 1][k], chain[i + 1][j]))
    bm.faces.new(lid_li[::-1])
    bm.faces.new(lid_ri)
    # hoops: hex bands proud of the staves (2 on mobile, 4 on PC)
    hx = [-0.26, -0.12, 0.12, 0.26]  # same hoops on mobile: they set the keg's outer extent (hull match)
    hoop_faces = []
    for fx in hx:
        x0 = fx * L
        w = 0.0042
        ai = apo(x0) - 0.0006
        ao = apo(x0) + 0.0013
        r_ = [ring(bm, x0 - w / 2, ai), ring(bm, x0 - w / 2, ao), ring(bm, x0 + w / 2, ao), ring(bm, x0 + w / 2, ai)]
        for i in range(4):
            for j in range(6):
                k = (j + 1) % 6
                hoop_faces.append(bm.faces.new((r_[i][j], r_[i][k], r_[(i + 1) % 4][k], r_[(i + 1) % 4][j])))
    for f in hoop_faces:
        f.material_index = 1
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.dot(c) < 0 and f.material_index == 1:
            f.normal_flip()
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f.material_index == 0])
    bm.normal_update()
    frames = []
    for j in range(6):
        ang = math.radians(60 * j)
        nrm = Vector((0, math.cos(ang), math.sin(ang)))
        v = [1, 2, 3][j % 3]
        fr = Frame(v - 1, nrm * a_mid, nrm, (1, 0, 0), v, str(v))
        side = nrm.cross(Vector((1, 0, 0)))
        hw = a_mid * math.tan(math.radians(30))
        fr.poly = [fr.c + Vector((-L / 2, 0, 0)) + side * hw, fr.c + Vector((L / 2, 0, 0)) + side * hw,
                   fr.c + Vector((L / 2, 0, 0)) - side * hw, fr.c + Vector((-L / 2, 0, 0)) - side * hw]
        fr.extra["hoops"] = [fx * L for fx in [-0.26, -0.12, 0.12, 0.26]]
        frames.append(fr)

    def classify(c, nn, m):
        if m == 1:
            return TRIM
        if abs(nn.x) > 0.5 or abs(c.x) > L / 2 - 0.0025:
            return TRIM2
        ang = math.degrees(math.atan2(c.z, c.y)) % 360.0
        return int(round(ang / 60.0)) % 6
    return dict(bm=bm, mats=mats, frames=frames, classify=classify, textured=[0], read="face",
                dirs=[[fr.value, list(fr.n)] for fr in frames], sharp=40.0, node="PowderKegD3", rest_down=[0, -1, 0])


def build_knucklebone(pc):
    """Knucklebone (talus): a lumpy aged-ivory astragalus, long along X, 4 resting sides with inked pips
    (3 = +Y wide dished side, 4 = -Y wide convex side, 1 = +Z narrow flat side, 6 = -Z narrow twisted side),
    knobbly rounded ends (X) it can't rest on."""
    mats = [make_material("knucklebone_body", "D9C48A", 0.6)]
    L, H, W = 0.112, 0.061, 0.080  # AABB a bit over the d6 (cube root ~0.084): the waist takes mass out
    nx, ny, nz = (11, 5, 6) if pc else (7, 3, 4)
    bm = bmesh.new()
    cache = {}

    def shape(p):
        x, y, z = p
        e = 3.0
        d = (abs(x) ** e + abs(y) ** e + abs(z) ** e) ** (1.0 / e)
        q = Vector((x, y, z)) / max(d, 1e-9)
        ax = abs(q.x)
        # the cross-section along the length: a hard-pinched waist between two knobbed ends (an hourglass, never a
        # block); the +X knob (the head) is bigger and rounder than the -X one (asymmetric, like a real talus)
        waist = 1.0 - 0.34 * math.exp(-(q.x / 0.36) ** 2)
        knob = 0.16 * math.exp(-((ax - 0.74) / 0.17) ** 2) * (1.15 if q.x > 0 else 0.8)
        cap = 1.0 - 0.55 * max(0.0, (ax - 0.80) / 0.20) ** 1.4  # the very ends round off: it can't stand on them
        k = (waist + knob) * cap
        y_, z_ = q.y * k, q.z * k
        # sides: +Y wide side dished (concave), -Y wide side bulged (convex), +Z narrow side flat,
        # -Z narrow side sinuous (an S along the length)
        if y_ > 0:
            y_ -= 0.16 * math.exp(-(q.x / 0.5) ** 2 - (q.z / 0.55) ** 2) * max(0.0, q.y)
        else:
            y_ -= 0.08 * math.exp(-(q.x / 0.6) ** 2 - (q.z / 0.6) ** 2) * max(0.0, -q.y)
        if z_ > 0:
            z_ = min(z_, 0.86 * k + 0.02)
        else:
            z_ -= 0.10 * math.sin(q.x * 2.6) * max(0.0, -q.z)
        # knob lumps and a twist along the length
        lump = 0.05 * math.sin(q.x * 9.0 + q.y * 4.0) * max(0.0, ax - 0.5)
        y_ *= 1.0 + lump
        tw = 0.16 * q.x
        y2 = y_ * math.cos(tw) - z_ * math.sin(tw)
        z2 = y_ * math.sin(tw) + z_ * math.cos(tw)
        return Vector((q.x * L / 2, y2 * H / 2, z2 * W / 2))

    def vert(p):
        key = tuple(round(c, 5) for c in p)
        if key not in cache:
            cache[key] = bm.verts.new(shape(p))
        return cache[key]

    tags = []
    for axis, nu, nv, ia, ib in ((0, ny, nz, 1, 2), (1, nx, nz, 0, 2), (2, nx, ny, 0, 1)):
        for sgn in (-1, 1):
            for i in range(nu):
                for j in range(nv):
                    quad = []
                    for (di, dj) in ((0, 0), (1, 0), (1, 1), (0, 1)):
                        p = [0.0, 0.0, 0.0]
                        p[axis] = sgn
                        p[ia] = -1 + 2 * (i + di) / nu
                        p[ib] = -1 + 2 * (j + dj) / nv
                        quad.append(vert(p))
                    f = bm.faces.new(quad)
                    tags.append((f, axis, sgn))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    bm.normal_update()
    sides = {3: (Vector((0, 1, 0)), Vector((1, 0, 0))), 4: (Vector((0, -1, 0)), Vector((1, 0, 0))),
             1: (Vector((0, 0, 1)), Vector((1, 0, 0))), 6: (Vector((0, 0, -1)), Vector((1, 0, 0)))}
    frames = []
    for v, (nrm, up) in sides.items():
        ext = H / 2 if nrm.y else W / 2
        fr = Frame(v - 1, nrm * ext, nrm, up, v, str(v))
        side = up.cross(nrm)
        hw = (W / 2 if nrm.y else H / 2) * 0.9
        fr.poly = [fr.c + up * (L / 2 * 0.8) + side * hw, fr.c + up * (L / 2 * 0.8) - side * hw,
                   fr.c - up * (L / 2 * 0.8) - side * hw, fr.c - up * (L / 2 * 0.8) + side * hw]
        frames.append(fr)
    order = [3, 4, 1, 6]

    def classify(c, nn, m):
        q = Vector((c.x / (L / 2), c.y / (H / 2), c.z / (W / 2)))
        ax = max(range(3), key=lambda i: abs(q[i]))
        if ax == 0 or abs(q.x) > 0.82:
            return TRIM
        if ax == 1:
            return order.index(3 if q.y > 0 else 4)
        return order.index(1 if q.z > 0 else 6)
    # Centre on the centre of mass (the asymmetric knobs pulled the solid centroid ~1.9 mm off the box centre).
    vol, cm = 0.0, Vector((0, 0, 0))
    for f in bm.faces:
        vs = [v.co for v in f.verts]
        for k in range(1, len(vs) - 1):
            v6 = vs[0].dot(vs[k].cross(vs[k + 1]))
            vol += v6
            cm += (vs[0] + vs[k] + vs[k + 1]) * v6
    cm = cm / (4.0 * vol)
    for v in bm.verts:
        v.co -= cm
    for fr in frames:
        fr.c = fr.c - cm
    frames = [frames[[3, 4, 1, 6].index(v)] for v in order]
    return dict(bm=bm, mats=mats, frames=frames, classify=classify, textured=[0], read="face",
                dirs=[[fr.value, list(fr.n)] for fr in frames], sharp=50.0, node="Knucklebone", rest_down=[0, -1, 0])


BUILDERS = {"caltrop_d4": build_caltrop, "lantern_d8": build_lantern, "tithe_d10": build_tithe, "midnight_d12": build_midnight,
            "verdict_d20": build_verdict, "ferryman_d2": build_ferryman, "powder_keg_d3": build_powder_keg,
            "knucklebone_talus": build_knucklebone}
TITLES = {"caltrop_d4": "Caltrop", "lantern_d8": "Lantern", "tithe_d10": "Tithe", "midnight_d12": "Midnight",
          "verdict_d20": "Verdict", "ferryman_d2": "Ferryman's Coin", "powder_keg_d3": "Powder Keg", "knucklebone_talus": "Knucklebone"}


# ------------------------------------------------------------------ assemble
def px_scale(frames):
    span = 0.0
    for fr in frames:
        for p in fr.poly:
            d = p - fr.c
            span = max(span, abs(d.dot(fr.right)) * 2, abs(d.dot(fr.up)) * 2)
    return CELL * 0.94 / span


def assemble(name, spec, ks=None, fit=None):
    bm = spec["bm"]
    me = bpy.data.meshes.new(spec["node"])
    bm.to_mesh(me)
    bm.free()
    for m in spec["mats"]:
        me.materials.append(m)
    ob = bpy.data.objects.new(spec["node"], me)
    bpy.context.scene.collection.objects.link(ob)
    for cut_bm, mi in spec.get("cutters", []):
        cme = bpy.data.meshes.new("cut")
        cut_bm.to_mesh(cme)
        cut_bm.free()
        for m in spec["mats"]:
            cme.materials.append(m)
        for p in cme.polygons:
            p.material_index = mi
        cob = bpy.data.objects.new("cut", cme)
        bpy.context.scene.collection.objects.link(cob)
        mod = ob.modifiers.new("b", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cob
        mod.material_mode = "TRANSFER"
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cob)
    frames = spec["frames"]
    s = px_scale([f for f in frames if not f.extra.get("seal")])
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update()
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        c = f.calc_center_median()
        k = spec["classify"](c, f.normal, f.material_index) if f.material_index in spec["textured"] else TRIM
        for lp in f.loops:
            if k in (TRIM, TRIM2):
                p = cell_centre(k)
            else:
                p = frames[k].px(lp.vert.co, s)
            lp[uvl].uv = (p.x / ATLAS, 1.0 - p.y / ATLAS)
    tris = len(bm.faces)
    if ks is None:
        ext = max(max(abs(v.co[i]) for v in bm.verts) for i in range(3))
        ks = EXTENT_CAP[name] / ext if name in EXTENT_CAP and ext > EXTENT_CAP[name] else 1.0
    for v in bm.verts:
        v.co *= ks  # uniform: directions, UVs and the centroid at the origin are unchanged
    if fit:
        fit_extents(bm, fit)
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data
    me.transform(G2B)
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(spec["sharp"]))
    me.validate(clean_customdata=False)
    return ob, tris, s, ks


def centroid(bm):
    vol, cm = 0.0, Vector((0, 0, 0))
    for f in bm.faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            v6 = vs[0].dot(vs[i].cross(vs[i + 1]))
            vol += v6
            cm += (vs[0] + vs[i] + vs[i + 1]) * v6
    return cm / (4.0 * vol)


def fit_extents(bm, target):
    """Mobile LOD: coarser sampling (knucklebone grid, 1-segment chamfers) falls a little short of or past the PC
    extremes. Scale each half-axis (+x, -x, ...) onto the PC extent and re-centre on the centroid, a few rounds. With
    mirror-symmetric PC targets this keeps a symmetric mesh symmetric."""
    for _ in range(4):
        for i in range(3):
            hi = max(v.co[i] for v in bm.verts)
            lo = min(v.co[i] for v in bm.verts)
            for v in bm.verts:
                v.co[i] *= (target[i][1] / hi) if v.co[i] > 0 else (target[i][0] / lo)
        c = centroid(bm)
        for v in bm.verts:
            v.co -= c


def extents(ob):
    """Per-axis (min, max) in Godot space."""
    lo, hi, _ = godot_bounds(ob)
    return [(lo[i], hi[i]) for i in range(3)]


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False, export_animations=False)


def godot_bounds(ob):
    vs = [Vector((v.co.x, v.co.z, -v.co.y)) for v in ob.data.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]
    hi = [max(v[i] for v in vs) for i in range(3)]
    return lo, hi, vs


def dirs_with_up(spec):
    """[value, local direction(, numeral-up on that face)] per readable direction, sorted by value."""
    out = []
    face_frames = [f for f in spec["frames"] if not f.extra.get("seal")]
    for v, d in spec["dirs"]:
        e = [int(v), [round(c, 5) for c in d]]
        if spec["read"] == "face":
            fr = max(face_frames, key=lambda f: f.n.dot(Vector(d)) if f.value == v else -9)
            e.append([round(c, 5) for c in fr.up])
        out.append(e)
    return sorted(out, key=lambda e: e[0])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = ROOT
    if argv and ("/" in argv[0] or argv[0].startswith(".")):
        out_dir = os.path.abspath(argv.pop(0))
    names = argv or list(BUILDERS)
    faces_path = os.path.join(out_dir, "batch3_faces.json")
    layout_path = os.path.join(SRC, "batch3_layout.json") if out_dir == ROOT else os.path.join(out_dir, "batch3_layout.json")
    table = json.load(open(faces_path)) if os.path.exists(faces_path) else {}
    layout = json.load(open(layout_path)) if os.path.exists(layout_path) else {}
    global MOBILE_BEVEL_MULT
    for name in names:
        k_pc, ext_pc = 1.0, None
        for pc in (True, False):
            MOBILE_BEVEL_MULT = 1.0
            u_mob = 1.0
            if not pc and name in BEVELLED:
                # Search the mobile chamfer depth (and a uniform scale, which keeps every mirror symmetry) so all six
                # half-axis extents land on the PC ones (minimax error).
                want = [h for a, b in ext_pc for h in (-a, b)]

                def trial(m):
                    global MOBILE_BEVEL_MULT
                    MOBILE_BEVEL_MULT = m
                    bpy.ops.wm.read_factory_settings(use_empty=True)
                    ob_, _t, _s, _k = assemble(name, BUILDERS[name](pc), k_pc)
                    got = [h for a, b in extents(ob_) for h in (-a, b)]
                    lo_u, hi_u = 0.95, 1.05
                    for _ in range(40):
                        u1, u2 = lo_u + (hi_u - lo_u) / 3, hi_u - (hi_u - lo_u) / 3
                        e1 = max(abs(u1 * g - w) for g, w in zip(got, want))
                        e2 = max(abs(u2 * g - w) for g, w in zip(got, want))
                        if e1 < e2:
                            hi_u = u2
                        else:
                            lo_u = u1
                    u = (lo_u + hi_u) / 2
                    return max(abs(u * g - w) for g, w in zip(got, want)), u
                best = min(((trial(m / 40.0), m / 40.0) for m in range(8, 49)), key=lambda t: t[0][0])
                (err, u_mob), m0 = best
                for m in [m0 + d / 400.0 for d in range(-12, 13)]:
                    (e, u) = trial(m)
                    if e < err:
                        err, u_mob, m0 = e, u, m
                MOBILE_BEVEL_MULT = m0
            bpy.ops.wm.read_factory_settings(use_empty=True)
            spec = BUILDERS[name](pc)
            # The organic knucklebone LOD gets a per-half-axis touch-up onto the PC extents (re-centred on the centroid),
            # so a hull built from the mobile mesh matches the PC silhouette's extents (Godot Dev, Oct 19).
            fit = ext_pc if (not pc and name == "knucklebone_talus") else None
            ob, tris, s, k = assemble(name, spec, None if pc else k_pc * u_mob, fit)
            if pc:
                k_pc, ext_pc = k, extents(ob)
            fname = name + ("" if pc else "_mobile") + ".glb"
            export(ob, os.path.join(out_dir, fname))
            lo, hi, vs = godot_bounds(ob)
            down = Vector(spec["rest_down"]).normalized()
            rv = rest_volume(vs, down)
            half = [round(max(-a, b), 5) for a, b in extents(ob)]
            print("BUILT %s tris=%d verts=%d aabb=%s rest_vol_cuberoot=%.4f scale=%.4f half_extent=%s mobile_bevel_mult=%.4f mobile_u=%.4f -> %s" % (
                fname, tris, len(ob.data.vertices), [round(h - l, 4) for l, h in zip(lo, hi)], rv ** (1 / 3), k, half,
                MOBILE_BEVEL_MULT, u_mob, fname))
            if pc:
                frames = spec["frames"]
                table[name] = {
                    "title": TITLES[name], "file": name + ".glb", "mobile": name + "_mobile.glb", "read": spec["read"],
                    "dirs": dirs_with_up(spec),
                    "names": {str(k): v for k, v in spec.get("names", {}).items()},
                    "tris_pc": tris, "aabb": [round(h - l, 4) for l, h in zip(lo, hi)],
                    "rest_volume_cuberoot": round(rv ** (1 / 3), 4), "slots": [m.name for m in spec["mats"]],
                    "scale": round(k, 4), "half_extent_pc": half,
                }
                cells = []
                for fr in frames:
                    e = {"cell": fr.cell, "value": fr.value, "label": fr.label, "centre": list(cell_centre(fr.cell)),
                         "px_per_m": s, "poly": [list(fr.px(p, s)) for p in fr.poly]}
                    if "corners" in fr.extra:
                        e["corners"] = [[k, list(fr.px(p, s))] for k, p in fr.extra["corners"]]
                    if "slot" in fr.extra:
                        c, ln, wd = fr.extra["slot"]
                        e["slot"] = [list(fr.px(Vector(c), s)), ln * s, wd * s]
                    if "label_shift" in fr.extra:
                        e["label_shift"] = fr.extra["label_shift"]
                    if "field_r" in fr.extra:
                        e["field_r"] = fr.extra["field_r"] * s
                    if "hoops" in fr.extra:
                        e["hoops"] = [(cell_centre(fr.cell).y - x * s) for x in fr.extra["hoops"]]
                    if fr.extra.get("seal"):
                        e["seal"] = True
                    cells.append(e)
                layout[name] = {"cells": cells, "px_per_m": s}
            else:
                table[name]["tris_mobile"] = tris
                table[name]["half_extent_mobile"] = half
    with open(faces_path, "w") as f:
        json.dump(table, f, indent=1, sort_keys=True)
    with open(layout_path, "w") as f:
        json.dump(layout, f, indent=1, sort_keys=True)
    print("wrote", faces_path, layout_path)


main()
