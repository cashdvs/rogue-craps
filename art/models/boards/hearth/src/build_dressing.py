"""Builds the Hearth set-dressing props as .glb (Blender 4.5 LTS, headless), PC and mobile LOD.

    blender -b --factory-startup --python art/models/boards/hearth/src/build_dressing.py -- [out_dir]

Spec: art/concept/bonfire_table/hearth_detail_pass.md (Art Director, Oct 19). Rule zero: the play area
and dice stay clean, so nothing here sits over the felt: every vertex is on or outside the rail
centreline (|x| >= 1.11 or |z| >= 0.61) and under y = 0.25 m, or under the table / on the floor.
All parts are authored in BOARD space (Godot axes, metres, +Y up, -Z = far rail); a part with a pivot
(chain, bell, tail) is shifted so its origin is the pivot, and the board scene puts it back there.
  dressing_corners   FL coin stack (+ cracked shot glass), FR knucklebones + finger bone + a card-sized
                     contract with a wax seal, the half-melted stub on the near-right rail, wax drips down
                     the outer rail under the four near candles, the chain end lying over the left rail.
  dressing_trinkets  (PC only) horned skull ashtray (right rail, far end), leather dice cup (near-left rail).
  dressing_bell      Smiles' brass service bell with an imp knob (far rail, beside him). Pivot = its base.
  dressing_chain     the hanging part of the chain loop + padlock (left rail, outer face). Pivot = where it
                     leaves the rail, so the sway hook rotates it.
  dressing_floor     dark floor (y -0.9, the game room's floor height), 4 turned legs on ball-and-claw feet,
                     a heavy chain running off-screen left; PC adds scattered coins and two dropped dice.
  dressing_tail_root / dressing_tail_tip   the 2-segment devil tail (pivots at its root and its joint).
"""
import math
import os
import random
import sys

import bpy  # noqa: E402
sys.dont_write_bytecode = True
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_hearth as bh  # noqa: E402  (Part, material helpers; its main() only runs as a script)

bh.MATS.update({
    "dressing_coin": ("8C6A2C", 0.4), "dressing_glass": ("2A2220", 0.1), "dressing_bone": ("C9B48A", 0.6),
    "dressing_paper": ("8A7650", 0.8), "dressing_seal": ("6E1A24", 0.4), "dressing_wax": ("E8D6B0", 0.5),
    "dressing_wax_drip": ("D8C49A", 0.5), "dressing_ink": ("0E1414", 0.9), "dressing_iron": ("34302E", 0.6),
    "dressing_brass": ("B08D3C", 0.35), "dressing_leather": ("3B1418", 0.7), "dressing_floor": ("0E0B0C", 0.9),
    "dressing_wood": ("3A2418", 0.7), "dressing_tail": ("6E1A24", 0.5),
})

RAIL_R = 0.09
RAIL_Y = 0.02
RAIL_C = 1.11      # side rail centreline |x|
RAIL_CZ = 0.61     # far / near rail centreline |z|
FLOOR_Y = -0.9     # table_3d_builder.gd room floor
TRIS = bh.TRIS


class DPart(bh.Part):
    """Part with a current placement matrix M (board space), and an optional pivot shift."""

    def __init__(self, name, slots, pivot=(0.0, 0.0, 0.0)):
        super().__init__(name, slots)
        self.M = Matrix.Identity(4)
        self.pivot = Vector(pivot)

    def v(self, p):
        return super().v((self.M @ Vector(p)) - self.pivot)

    def at(self, m):
        self.M = m
        return self


def frame(origin, up, along):
    """4x4 with local +Y = up, local +X = along (orthonormalised), origin."""
    up = Vector(up).normalized()
    x = (Vector(along) - up * Vector(along).dot(up)).normalized()
    z = x.cross(up)
    m = Matrix.Identity(4)
    for i in range(3):
        m[i][0], m[i][1], m[i][2], m[i][3] = x[i], up[i], z[i], origin[i]
    return m


def rail_pt(rail, along, theta, r=RAIL_R):
    """Point + outward normal on a rail tube. theta = angle from the tube top toward the OUTSIDE (rad)."""
    s, c = math.sin(theta), math.cos(theta)
    if rail == "far":
        return Vector((along, RAIL_Y + r * c, -RAIL_CZ - r * s)), Vector((0, c, -s)), Vector((1, 0, 0))
    if rail == "near":
        return Vector((along, RAIL_Y + r * c, RAIL_CZ + r * s)), Vector((0, c, s)), Vector((-1, 0, 0))
    if rail == "left":
        return Vector((-RAIL_C - r * s, RAIL_Y + r * c, along)), Vector((-s, c, 0)), Vector((0, 0, -1))
    return Vector((RAIL_C + r * s, RAIL_Y + r * c, along)), Vector((s, c, 0)), Vector((0, 0, 1))


def on_rail(rail, along, out, sink=0.0004, yaw=0.0, level=0.0):
    """Placement frame for a small prop standing on the rail top, `out` metres outboard of the centreline.
    level 0 = stands on the surface normal, 1 = stands upright (world up)."""
    theta = math.asin(max(-1.0, min(1.0, out / RAIL_R)))
    p, n, a = rail_pt(rail, along, theta)
    up = n.lerp(Vector((0, 1, 0)), level).normalized()
    m = frame(p - up * sink, up, a)
    return m @ Matrix.Rotation(yaw, 4, "Y")


def K(k):
    """Uniform prop scale: the table is drawn at the dice's scale (0.08 m dice on a 2 m felt), so the
    trinkets are too (Oct 19 render check: real-size coins / bell vanished at the game camera)."""
    return Matrix.Scale(k, 4)


COIN_K = 1.7      # coins 3.9 cm
GLASS_K = 1.5
BONE_K = 1.6
STUB_K = 1.3
SKULL_K = 1.6
CUP_K = 1.4
BELL_K = 2.0      # service bell 7 cm across
LINK = (0.0168, 0.0099, 0.0034)          # chain link half-length, half-width, wire radius (PC)
LINK_MOBILE = (0.0195, 0.0115, 0.0036)
LOCK_K = 2.2


def finish(part, out_dir, smooth=40.0):
    part.finish(out_dir, smooth)


# ---------------------------------------------------------------- small builders (local space, +Y up)
def coin(part, slot, seg, r=0.0115, h=0.0022, bottom=True):
    prof = ([(0.0, 0.0)] if bottom else []) + [(r, 0.0), (r, h), (0.0, h)]
    part.lathe(prof, seg, (0, 0), slot)


def coin_stack(part, slot, seg, n, rng):
    for k in range(n):
        m = part.M
        part.M = m @ Matrix.Translation((rng.uniform(-0.0012, 0.0012), k * 0.0021, rng.uniform(-0.0012, 0.0012))) \
            @ Matrix.Rotation(rng.uniform(-0.05, 0.05), 4, "X")
        coin(part, slot, seg, bottom=(k == 0))
        part.M = m


def shot_glass(part, glass, ink, seg):
    rows = part.lathe([(0.0, 0.0), (0.0135, 0.0), (0.0168, 0.034), (0.0152, 0.034), (0.0118, 0.0065), (0.0, 0.0065)], seg, (0, 0), glass)
    # the crack: a chipped wedge out of the rim (outer + inner rim vertex at column 0 pulled down) ...
    for j, dy in ((2, -0.0055), (3, -0.0055)):
        rows[j][0].co.z += dy  # Blender z = Godot y
    # ... and a hairline crack running down from the chip (a thin ink sliver just off the glass wall)
    a0 = 0.0
    pts = [(0.0172, 0.0285), (0.0160, 0.020), (0.0150, 0.012)]
    vs = []
    for k, (r, y) in enumerate(pts):
        a = a0 + 0.12 * k + 0.05
        w = 0.0011 * (1.0 - 0.3 * k)
        vs.append((part.v((math.cos(a - w / r) * r, y, math.sin(a - w / r) * r)), part.v((math.cos(a + w / r) * r, y, math.sin(a + w / r) * r))))
    for k in range(len(vs) - 1):
        part.f([vs[k][0], vs[k][1], vs[k + 1][1], vs[k + 1][0]], ink)


def knucklebone(part, slot, c, size, rot, useg, vseg):
    def shape(p):
        x, y, z = p.x, p.y, p.z
        waist = 1.0 - 0.28 * math.exp(-(x / 0.35) ** 2)   # pinched middle (astragalus)
        return Vector((x * 1.25, y * waist * 0.8, z * waist))
    part.sphere(c, (size, size * 0.8, size * 0.75), useg, vseg, slot, shape, Matrix.Rotation(rot, 3, "Y"))


def finger_bone(part, slot, c, length, rot, seg):
    d = Vector((math.cos(rot), 0.0, math.sin(rot)))
    c = Vector(c)
    pts = [c - d * length * 0.5, c - d * length * 0.42, c, c + d * length * 0.42, c + d * length * 0.5]
    part.cone_path(pts, [0.0, 0.0042, 0.0028, 0.0040, 0.0], seg, slot)


def contract(part, paper, seal, segs, seal_seg, rail, along, rng):
    """Card-sized contract (63 x 88 mm) draped over the far rail's outer shoulder, wax seal on it."""
    half_l = 0.044
    t = 0.0008
    rows_top, rows_bot = [], []
    for k in range(segs + 1):
        d = 0.003 + 0.063 * k / segs
        theta = math.asin(min(0.99, d / RAIL_R)) + (0.06 * (k / segs) ** 3)  # last bit curls up a touch
        p, n, a = rail_pt(rail, along, theta, RAIL_R + 0.0012)
        lift = -0.004 * (k / segs) ** 3
        row_t, row_b = [], []
        for sx in (-1, 1):
            q = p + a * sx * half_l * (1.0 - 0.02 * k / segs) + n * lift
            row_t.append(part.v(q + n * t))
            row_b.append(part.v(q))
        rows_top.append(row_t)
        rows_bot.append(row_b)
    for k in range(segs):
        part.f([rows_top[k][0], rows_top[k][1], rows_top[k + 1][1], rows_top[k + 1][0]], paper)
        part.f([rows_bot[k][0], rows_bot[k + 1][0], rows_bot[k + 1][1], rows_bot[k][1]], paper)
        for s in (0, 1):
            part.f([rows_top[k][s], rows_top[k + 1][s], rows_bot[k + 1][s], rows_bot[k][s]], paper)
    for k in (0, segs):
        part.f([rows_top[k][0], rows_top[k][1], rows_bot[k][1], rows_bot[k][0]], paper)
    # wax seal near the outer third
    theta = math.asin(0.04 / RAIL_R)
    p, n, a = rail_pt(rail, along + 0.016, theta, RAIL_R + 0.0012 + t)
    m = part.M
    part.M = frame(p, n, a)
    part.lathe([(0.0, 0.0035), (0.0076, 0.0026), (0.0094, 0.0), (0.0, 0.0)], seal_seg, (0, 0), seal, jitter=0.08, rng=rng)
    part.M = m


def drip(part, slot, rail, along, th0, th1, r0, seg):
    """Wax drip running down the outer rail face from theta th0 to th1 (half buried in the leather)."""
    n = 3
    pts, radii = [], []
    for k in range(n + 1):
        f = k / n
        th = th0 + (th1 - th0) * f
        p, nrm, a = rail_pt(rail, along + 0.0015 * math.sin(f * 3.0), th, RAIL_R + 0.0004)
        pts.append(p)
        radii.append(r0 * (1.0 - 0.25 * f) if k < n - 1 else (r0 * 1.25 if k == n - 1 else 0.0))
    part.cone_path(pts, radii, seg, slot)


def stub(part, wax, ink, seg, rng):
    """Half-melted candle stub: a slumped, leaning stump in its own puddle, wick bent over."""
    part.lathe([(0.0, 0.0), (0.021, 0.0), (0.0135, 0.0032), (0.0112, 0.02), (0.0085, 0.027), (0.0, 0.0255)],
               seg, (0.0, 0.0), wax, jitter=0.1, rng=rng)
    part.cone_path([(0.0, 0.025, 0.0), (0.0012, 0.0295, 0.0), (0.004, 0.031, 0.0)], [0.001, 0.0009, 0.0], 3, ink)


def chain_link(part, slot, c, d, roll, a, b, wire, seg, wseg):
    """One oval link centred at c, long axis d, rolled by `roll` around d."""
    d = Vector(d).normalized()
    up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
    s = d.cross(up).normalized()
    u = s.cross(d)
    s, u = s * math.cos(roll) + u * math.sin(roll), u * math.cos(roll) - s * math.sin(roll)
    rings = []
    for i in range(seg):
        ang = 2 * math.pi * i / seg
        centre = Vector(c) + d * math.cos(ang) * a + s * math.sin(ang) * b
        tan = (-d * math.sin(ang) * a + s * math.cos(ang) * b).normalized()
        nrm = tan.cross(u).normalized()
        rings.append([part.v(centre + (nrm * math.cos(2 * math.pi * k / wseg) + u * math.sin(2 * math.pi * k / wseg)) * wire) for k in range(wseg)])
    for i in range(seg):
        r0, r1 = rings[i], rings[(i + 1) % seg]
        for k in range(wseg):
            k2 = (k + 1) % wseg
            part.f([r0[k], r1[k], r1[k2], r0[k2]], slot)


def chain_along(part, slot, pts, pitch, a, b, wire, seg, wseg, roll0=0.0):
    """Links laid along a polyline, alternating 90 deg."""
    out = []
    dist = [0.0]
    for i in range(1, len(pts)):
        dist.append(dist[-1] + (Vector(pts[i]) - Vector(pts[i - 1])).length)
    s = pitch * 0.5
    k = 0
    while s < dist[-1] - pitch * 0.3:
        i = max(j for j in range(len(dist) - 1) if dist[j] <= s)
        f = (s - dist[i]) / max(1e-9, dist[i + 1] - dist[i])
        p = Vector(pts[i]).lerp(Vector(pts[i + 1]), f)
        d = Vector(pts[i + 1]) - Vector(pts[i])
        chain_link(part, slot, p, d, roll0 + (math.pi / 2 if k % 2 else 0.0), a, b, wire, seg, wseg)
        out.append(p)
        s += pitch
        k += 1
    return out


def padlock(part, iron, brass, c, seg):
    c = Vector(c)
    part.box(c, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.0035, 0.0085, 0.0075), iron)   # body (thin along x = faces z)
    part.box(c + Vector((-0.0037, 0.001, 0.0)), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.0005, 0.0045, 0.004), brass)  # keyhole plate
    pts = []
    for i in range(seg + 1):
        ang = math.pi * i / seg
        pts.append(c + Vector((0.0, 0.0085 + math.sin(ang) * 0.0075, math.cos(ang) * 0.005)))
    part.cone_path(pts, [0.0014] * len(pts), 3, iron)


def bell(part, brass, seg, horns):
    part.lathe([(0.0, 0.0), (0.0175, 0.0), (0.0175, 0.003), (0.0138, 0.0045), (0.0128, 0.012), (0.0072, 0.0175), (0.0, 0.019)], seg, (0, 0), brass)
    useg = 5 if horns else 4
    part.sphere((0.0, 0.0235, 0.0), (0.0052, 0.0050, 0.0050), useg, max(3, useg - 2), brass)
    if horns:
        for sx in (-1, 1):
            part.cone_path([(0.0032 * sx, 0.0262, -0.0005), (0.0058 * sx, 0.0300, -0.0012), (0.0062 * sx, 0.0335, -0.0016)], [0.0016, 0.0010, 0.0], 3, brass)


def skull_ashtray(part, bone, ink, paper, seg, vseg):
    def shape(p):
        x, y, z = p.x, p.y, p.z
        if y > 0.45:            # open cranium = the ashtray dish
            y = 0.45 - (y - 0.45) * 1.3
        if y < -0.2:            # jaw narrower and forward
            x *= 0.78
            z = z * 0.85 + 0.12
        return Vector((x, y, z))
    rows = []
    c = Vector((0.0, 0.016, 0.0))
    R = (0.0165, 0.016, 0.018)
    part.sphere(c, R, seg, vseg, bone, shape)
    # eye sockets + nose: recolour the faces whose centre is in front (+Z local) at eye height
    part.bm.faces.ensure_lookup_table()
    M = part.M
    inv = M.inverted()
    for f in part.bm.faces:
        if f.material_index != bone:
            continue
        cen = f.calc_center_median()
        g = inv @ (Vector((cen.x, cen.z, -cen.y)) + part.pivot)   # back to local Godot space
        lx, ly, lz = g.x, g.y - c.y, g.z
        if lz > 0.010 and -0.004 < ly < 0.0075 and abs(lx) < 0.012:
            f.material_index = ink
    for sx in (-1, 1):
        part.cone_path([(0.010 * sx, 0.024, -0.002), (0.016 * sx, 0.031, -0.005), (0.018 * sx, 0.039, -0.009)], [0.0028, 0.0017, 0.0], 3, bone)
    # a cigarette butt resting across the dish rim
    part.box((0.006, 0.0245, 0.002), ((0.9, 0.12, 0.42), (0, 1, 0), (-0.42, 0, 0.9)), (0.009, 0.0018, 0.0018), paper)


def dice_cup(part, leather, brass, seg):
    part.lathe([(0.0, 0.0), (0.0165, 0.0), (0.0192, 0.042), (0.0172, 0.042), (0.0150, 0.0055), (0.0, 0.0055)], seg, (0, 0), leather)
    part.lathe([(0.0194, 0.034), (0.0201, 0.0385)], seg, (0, 0), brass)


PIPS = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)], 4: [(-1, -1), (-1, 1), (1, -1), (1, 1)],
        5: [(-1, -1), (-1, 1), (0, 0), (1, -1), (1, 1)], 6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)]}


def die(part, bone, ink, c, basis, faces):
    """A plain dropped die (0.08 m) with square ink pips on the given (face value, local normal) list."""
    h = 0.04
    ax = [basis @ Vector(v) for v in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
    part.box(c, ax, (h, h, h), bone)
    for val, nrm in faces:
        n = basis @ Vector(nrm)
        t = basis @ Vector((0, 1, 0) if abs(nrm[1]) < 0.5 else (1, 0, 0))
        b = n.cross(t)
        for (px, py) in PIPS[val]:
            q = Vector(c) + n * (h + 0.0004) + t * px * 0.021 + b * py * 0.021
            s = 0.0058
            vs = [part.v(q + t * s + b * s), part.v(q - t * s + b * s), part.v(q - t * s - b * s), part.v(q + t * s - b * s)]
            if part.f(vs, ink) is not None:
                pass


def leg(part, wood, seg, claws, foot_seg):
    """Turned table leg from the skirt bottom (y -0.3) to a ball-and-claw foot on the floor (local origin = floor)."""
    top = -0.3 - FLOOR_Y
    prof = [(0.047, top), (0.036, top - 0.12), (0.042, top - 0.2), (0.029, 0.11)] if seg > 4 else [(0.045, top), (0.03, 0.1)]
    part.lathe(prof, seg, (0, 0), wood)
    ball = 0.038
    part.sphere((0.0, ball, 0.0), (ball, ball * 0.95, ball), foot_seg, max(3, foot_seg - 2), wood)
    for k in range(claws):
        a = 2 * math.pi * k / claws + 0.5
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        part.cone_path([Vector((0, 0.1, 0)) + d * 0.026, Vector((0, 0.05, 0)) + d * 0.045, Vector((0, 0.004, 0)) + d * 0.05],
                       [0.011, 0.011, 0.0], 3, wood)


def tail_root(part, slot, seg):
    part.cone_path([(0.0, -0.01, 0.0), (0.0, 0.05, 0.006), (0.0, 0.11, 0.004), (0.0, 0.16, 0.0)], [0.0125, 0.0115, 0.0095, 0.0085], seg, slot)


TAIL_JOINT = Vector((0.0, 0.16, 0.0))


def tail_tip(part, slot, seg):
    pts = [(0.0, -0.006, 0.0), (0.004, 0.045, 0.0), (0.016, 0.09, 0.0), (0.034, 0.12, 0.0)]
    part.cone_path(pts, [0.0088, 0.0072, 0.0052, 0.0028], seg, slot)
    # the spade: a flat arrowhead pointing along the last segment
    d = (Vector(pts[-1]) - Vector(pts[-2])).normalized()
    s = Vector((0, 0, 1)).cross(d).normalized()
    base = Vector(pts[-1]) - d * 0.004
    tip = base + d * 0.042
    wl, wr = base + d * 0.012 + s * 0.019, base + d * 0.012 - s * 0.019
    th = Vector((0, 0, 0.0035))
    ring = [base, wl, tip, wr]
    top = [part.v(p + th) for p in ring]
    bot = [part.v(p - th) for p in ring]
    part.f(top, slot)
    part.f(list(reversed(bot)), slot)
    for i in range(4):
        j = (i + 1) % 4
        part.f([top[i], bot[i], bot[j], top[j]], slot)


# ---------------------------------------------------------------- the parts
CHAIN_Z = (-0.02, 0.105)  # left-rail span of the chain loop (between Candle3 z -0.24 and Candle5 z 0.24)
CHAIN_PIVOT = Vector((-1.203, 0.028, 0.04))
BELL_AT = ("far", -0.205, 0.043)       # rail, along, outboard offset: between Smiles' right hand and the brazier
TAIL_PIVOT = Vector((-1.19, -0.315, -0.6))  # make_hearth.gd TAIL_PIVOT (the tail meshes are authored at their own pivots)


def build_corners(out_dir, name, mobile):
    rng = random.Random(5)
    slots = ["dressing_coin", "dressing_glass", "dressing_bone", "dressing_paper", "dressing_seal", "dressing_wax",
             "dressing_wax_drip", "dressing_ink", "dressing_iron"]
    S = {s: i for i, s in enumerate(slots)}
    p = DPart(name, slots)
    # FL: the coin stack (and on PC the cracked shot glass), on the far rail by the left demon face
    p.at(on_rail("far", -0.955, 0.025, level=0.35) @ K(COIN_K))
    coin_stack(p, S["dressing_coin"], 6 if mobile else 8, 3 if mobile else 4, rng)
    p.at(on_rail("far", -0.905, 0.028, level=0.3) @ Matrix.Rotation(0.5, 4, "Z") @ Matrix.Translation((0.0, 0.002, 0.0)) @ K(COIN_K))
    coin(p, S["dressing_coin"], 6 if mobile else 8, bottom=False)   # one coin fallen flat beside the stack (tipped toward it)
    if not mobile:
        p.at(on_rail("far", -0.858, 0.03, level=0.85, yaw=2.2) @ K(GLASS_K))
        shot_glass(p, S["dressing_glass"], S["dressing_ink"], 8)
    # FR: knucklebones + a finger bone, and the contract
    p.at(on_rail("far", 0.79, 0.034, level=0.4) @ K(BONE_K))
    kb = [((-0.012, 0.0055, 0.0), 0.0085, 0.4), ((0.004, 0.0055, 0.003), 0.008, 1.9)]
    if not mobile:
        kb.append(((-0.002, 0.0125, -0.0015), 0.0075, 2.8))
    for (c, s, r) in kb:
        knucklebone(p, S["dressing_bone"], c, s, r, 5 if mobile else 6, 3 if mobile else 4)
    finger_bone(p, S["dressing_bone"], (0.022, 0.0035, 0.002), 0.032, 0.35, 3 if mobile else 4)
    p.at(Matrix.Identity(4))
    contract(p, S["dressing_paper"], S["dressing_seal"], 3 if mobile else 5, 5 if mobile else 6, "far", 0.9, rng)
    # NR: half-melted stub on the near rail, with a wax drip of its own down the near rail
    p.at(on_rail("near", 0.93, 0.036, level=0.7) @ K(STUB_K))
    stub(p, S["dressing_wax"], S["dressing_ink"], 6 if mobile else 7, rng)
    p.at(Matrix.Identity(4))
    drip(p, S["dressing_wax_drip"], "near", 0.928, math.radians(26), math.radians(78), 0.0026, 3)
    # wax drips down the outer rail face under the four near progress candles (x +-1.135, z 0.24 / 0.42)
    for side in ("left", "right"):
        for z in (0.24, 0.42):
            sz = 1.0 if side == "right" else -1.0
            drip(p, S["dressing_wax_drip"], side, z + 0.006 * sz, math.radians(30), math.radians(rng.uniform(80, 98)), 0.0028, 3)
            if not mobile:
                drip(p, S["dressing_wax_drip"], side, z - 0.008 * sz, math.radians(31), math.radians(rng.uniform(58, 70)), 0.0024, 3)
    # the chain end lying over the left rail top (static); the hanging part is dressing_chain
    pts = []
    for k in range(5):
        th = math.radians(14 + 72 * k / 4)
        q, n, a = rail_pt("left", CHAIN_Z[0] + (CHAIN_PIVOT.z - CHAIN_Z[0]) * k / 4, th, RAIL_R + LINK[2] + 0.0005)
        pts.append(q)
    link = LINK if not mobile else LINK_MOBILE
    chain_along(p, S["dressing_iron"], pts, link[0] * 1.55, link[0], link[1], link[2], 4, 3)
    finish(p, out_dir, 50.0)


def build_chain(out_dir, name, mobile):
    p = DPart(name, ["dressing_iron", "dressing_brass"], pivot=CHAIN_PIVOT)
    link = LINK if not mobile else LINK_MOBILE
    c = CHAIN_PIVOT
    # hangs down the left rail's outer face and the body skirt, swinging out a little, the padlock at the bottom
    pts = [c + Vector((-0.004, 0.0, 0.0)), c + Vector((-0.014, -0.06, 0.012)), c + Vector((-0.022, -0.12, 0.03)),
           c + Vector((-0.024, -0.17, 0.05))]
    if mobile:
        pts = pts[:3] + [c + Vector((-0.024, -0.15, 0.045))]
    ends = chain_along(p, 0, pts, link[0] * 1.55, link[0], link[1], link[2], 4, 3)
    p.at(Matrix.Translation(Vector(pts[-1]) + Vector((-0.004, -0.036, 0.012))) @ K(LOCK_K))
    padlock(p, 0, 1, (0.0, 0.0, 0.0), 3 if mobile else 4)
    finish(p, out_dir, 50.0)


def build_bell(out_dir, name, mobile):
    rail, along, out = BELL_AT
    m = on_rail(rail, along, out, level=0.6)
    piv = m.translation
    p = DPart(name, ["dressing_brass"], pivot=piv)
    p.at(m @ K(BELL_K))
    bell(p, 0, 6 if mobile else 8, not mobile)
    finish(p, out_dir, 50.0)


def build_trinkets(out_dir, name):
    slots = ["dressing_bone", "dressing_ink", "dressing_paper", "dressing_leather", "dressing_brass"]
    p = DPart(name, slots)
    # horned skull ashtray on the right rail between Candle2 (z -0.42) and the right demon face
    p.at(on_rail("right", -0.5, 0.04, level=0.85) @ Matrix.Rotation(math.radians(-90 - 25), 4, "Y") @ K(SKULL_K))
    skull_ashtray(p, 0, 1, 2, 8, 6)
    # leather dice cup on the near-left rail
    p.at(on_rail("near", -0.93, 0.034, level=0.9) @ K(CUP_K))
    dice_cup(p, 3, 4, 8)
    finish(p, out_dir, 50.0)


def build_floor(out_dir, name, mobile):
    rng = random.Random(23)
    slots = ["dressing_floor", "dressing_wood", "dressing_iron", "dressing_coin", "dressing_bone", "dressing_ink"]
    p = DPart(name, slots)
    # the floor: one quad, the game room's floor height
    vs = [p.v((x, FLOOR_Y, z)) for (x, z) in ((-3.2, -2.8), (3.2, -2.8), (3.2, 2.2), (-3.2, 2.2))]
    p.f(list(reversed(vs)), 0)
    # legs on ball-and-claw feet under the four corners of the body skirt
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.at(Matrix.Translation((sx * 1.12, FLOOR_Y, sz * 0.62)) @ Matrix.Rotation(math.atan2(sx, sz), 4, "Y"))
            leg(p, 1, 4 if mobile else 5, 0 if (mobile or sz < 0) else 3, 4 if mobile else 5)
    p.at(Matrix.Identity(4))
    # a heavy chain from under the far-left of the table running off-screen left
    y = FLOOR_Y + 0.006
    pts = [(-1.2, y, -0.48), (-1.45, y, -0.36), (-1.78, y, -0.42), (-2.25, y, -0.27)]
    if mobile:
        pts = pts[1:]
    chain_along(p, 2, pts, 0.13, 0.082, 0.046, 0.013, 4, 3, roll0=0.0)
    if not mobile:
        # scattered coins and two dropped dice at the screen edges (the floor is in the table's shadow:
        # the materials carry a faint glint so they still catch the eye)
        spots = [(-1.42, 0.12, 0.0), (-1.55, 0.38, 0.6), (1.38, 0.3, 0.2), (1.52, -0.05, 0.0), (1.47, 0.52, 0.9)]
        for (x, z, tilt) in spots:
            p.at(Matrix.Translation((x, FLOOR_Y + 0.0002 + tilt * 0.008, z)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Y") @ Matrix.Rotation(tilt * 0.35, 4, "X"))
            coin(p, 3, 6, bottom=False)
        p.at(Matrix.Identity(4))
        die(p, 4, 5, (-1.5, FLOOR_Y + 0.04, 0.16), Matrix.Rotation(0.6, 3, "Y"), [(5, (0, 1, 0)), (3, (1, 0, 0)), (1, (-1, 0, 0)), (2, (0, 0, 1)), (6, (0, 0, -1))])
        die(p, 4, 5, (1.46, FLOOR_Y + 0.04, 0.42), Matrix.Rotation(-0.35, 3, "Y"), [(2, (0, 1, 0)), (4, (-1, 0, 0)), (6, (0, 0, 1)), (3, (1, 0, 0)), (1, (0, 0, -1))])
    finish(p, out_dir, 45.0)


def build_tail(out_dir, mobile):
    lod = "_mobile" if mobile else ""
    seg = 4 if mobile else 5
    r = DPart("dressing_tail_root" + lod, ["dressing_tail"])
    tail_root(r, 0, seg)
    finish(r, out_dir, 60.0)
    t = DPart("dressing_tail_tip" + lod, ["dressing_tail"])
    tail_tip(t, 0, seg)
    finish(t, out_dir, 60.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[0]) if argv else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for mobile in (False, True):
        lod = "_mobile" if mobile else ""
        build_corners(out_dir, "dressing_corners" + lod, mobile)
        build_chain(out_dir, "dressing_chain" + lod, mobile)
        build_bell(out_dir, "dressing_bell" + lod, mobile)
        build_floor(out_dir, "dressing_floor" + lod, mobile)
        build_tail(out_dir, mobile)
    build_trinkets(out_dir, "dressing_trinkets")
    bell_m = on_rail(*BELL_AT, level=0.6)
    print("PIVOTS chain=%s bell=%s tail=%s joint=%s" % (tuple(round(v, 4) for v in CHAIN_PIVOT), tuple(round(v, 4) for v in bell_m.translation),
                                                       tuple(round(v, 4) for v in TAIL_PIVOT), tuple(round(v, 4) for v in TAIL_JOINT)))
    pc = sum(v for k, v in TRIS.items() if not k.endswith("_mobile"))
    mo = sum(v for k, v in TRIS.items() if k.endswith("_mobile"))
    print("TRIS %s" % TRIS)
    print("TRIS_TOTAL pc=%d mobile=%d" % (pc, mo))


main()
