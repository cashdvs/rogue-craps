"""Builds the Burn Line Board A (Infernal Pit) kit meshes as .glb (Blender 4.5 LTS, headless).

    blender -b --factory-startup --python art/models/boards/infernal_pit/src/build_board_a.py -- [out_dir]

Spec: art/concept/burnline_boards/board_kit.md (sections 2-4, and section 7 confirmed by Godot Dev).
Everything is authored in GODOT space (metres, +Y up, -Z = far rail, +Z = player/near rail, felt top
at y = 0, origin = felt centre) and converted to Blender Z-up on the way in; the glTF exporter
converts back, so every .glb is in Godot space with scale 1 and an identity node.

Fixed geometry (never themed; the colliders live in code, these meshes only draw them):
  felt bed 2.04 x 1.04, rail tubes radius 0.09 centred at y = 0.02 on x = +-1.11 / z = +-0.61,
  backboard 2.04 x 0.06 x 0.03 at z = -0.505.
Decoration (studs, caps, plates, tray, body) stays on or outside the rail centreline
(|x| >= 1.11 or |z| >= 0.61), never over the felt, and under y = 0.25.

Prop meshes (plaque, dial, tray, corner cap) are authored in their ANCHOR's local space, so the
board scene just drops them on the Marker3D anchors.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

FELT_HALF = (1.02, 0.52)
RAIL_R = 0.09
RAIL_Y = 0.02
OX, OZ = FELT_HALF[0] + RAIL_R, FELT_HALF[1] + RAIL_R   # 1.11, 0.61 (rail centrelines)
BACKBOARD = (2.04, 0.06, 0.03, -0.505)


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def lin(hex_str):
    out = []
    for i in (0, 2, 4):
        c = int(hex_str[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


MATS = {  # glTF placeholder colours; the .import maps each slot to the toon .tres of the same name
    "felt": ("123A36", 0.95), "leather": ("5A1620", 0.55), "brass": ("B08D3C", 0.35),
    "plate_face": ("1A0A0C", 0.8), "flame": ("E8622A", 0.5), "backboard": ("0F312E", 0.95),
    "body_wood": ("3A2416", 0.7),
}


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = lin(MATS[name][0])
    bsdf.inputs["Roughness"].default_value = MATS[name][1]
    if name == "flame":
        bsdf.inputs["Emission Color"].default_value = lin(MATS[name][0])
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return m


class Part:
    """One mesh being built: Godot-space verts, faces with a material slot, per-loop UVs."""

    def __init__(self, name, slots):
        self.name, self.slots = name, slots
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def v(self, p):
        return self.bm.verts.new(g2b(p))

    def f(self, verts, slot=0, uvs=None):
        try:
            face = self.bm.faces.new(verts)
        except ValueError:
            return None
        face.material_index = self.slots.index(slot) if isinstance(slot, str) else slot
        if uvs:
            for loop, uv in zip(face.loops, uvs):
                loop[self.uv].uv = uv
        return face

    def grid(self, rows, slot, uv_rows=None, closed_u=False):
        """rows: list of rings (lists of verts). Quads between consecutive rings."""
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            n = len(a) if closed_u else len(a) - 1
            for i in range(n):
                i2 = (i + 1) % len(a)
                uvs = None
                if uv_rows:
                    uvs = [uv_rows[j][i], uv_rows[j][i + 1], uv_rows[j + 1][i + 1], uv_rows[j + 1][i]]
                self.f([a[i], a[i2], b[i2], b[i]], slot, uvs)

    def finish(self, out_dir, smart_uv=False, smooth=True, face_up=False):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        if face_up:  # open flat sheets: recalc can pick either side, so force +Y (Blender +Z)
            for face in self.bm.faces:
                face.normal_update()
                if face.normal.z < 0:
                    face.normal_flip()
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for s in self.slots:
            me.materials.append(material(s))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = smooth
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        if smart_uv:
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
            bpy.ops.object.mode_set(mode="OBJECT")
        path = os.path.join(out_dir, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_materials="EXPORT", export_cameras=False,
                                  export_lights=False, export_animations=False)
        tris = len(me.polygons)
        print("BUILT %-26s tris=%5d slots=%s" % (self.name, tris, self.slots))
        TRIS[self.name] = tris
        bpy.data.objects.remove(ob)
        return tris


TRIS = {}


# --- helpers ---------------------------------------------------------------------------

def rail_path(step_pad, corner_rings):
    """Samples the rounded-rect rail centreline (corner arc radius = RAIL_R, so the tube's inner
    face meets in a sharp corner exactly like the two capsule colliders). Returns a list of
    (point, outward_dir, s, is_pinch). Starts at the far rail's left end, runs clockwise from above."""
    cx, cz = FELT_HALF
    out = []
    s = 0.0
    segs = [  # straight: start, end, outward ; then the corner after it
        ((-cx, -OZ), (cx, -OZ), (0, -1), (cx, -cz), -math.pi / 2),
        ((OX, -cz), (OX, cz), (1, 0), (cx, cz), 0.0),
        ((cx, OZ), (-cx, OZ), (0, 1), (-cx, cz), math.pi / 2),
        ((-OX, cz), (-OX, -cz), (-1, 0), (-cx, -cz), math.pi),
    ]
    for (a, b, o, cc, ang0) in segs:
        length = math.dist(a, b)
        pads = max(1, round(length / 0.17))
        n = pads * step_pad
        for k in range(n):
            t = k / n
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            out.append(((p[0], RAIL_Y, p[1]), (o[0], 0, o[1]), s + length * t, k % step_pad == 0))
        s += length
        for k in range(corner_rings):
            ang = ang0 + (math.pi / 2) * k / corner_rings
            od = (math.cos(ang), math.sin(ang))
            out.append(((cc[0] + od[0] * RAIL_R, RAIL_Y, cc[1] + od[1] * RAIL_R), (od[0], 0, od[1]),
                        s + RAIL_R * (math.pi / 2) * k / corner_rings, False))
        s += RAIL_R * math.pi / 2
    return out, s


def build_rails(out_dir, name, sides, step_pad, corner_rings, pinch=0.006):
    part = Part(name, ["leather"])
    path, total = rail_path(step_pad, corner_rings)
    rings, uvs = [], []
    up = Vector((0, 1, 0))
    for (p, o, s, is_pinch) in path + [path[0]]:
        c, outv = Vector(p), Vector(o)
        ring, ur = [], []
        for i in range(sides + 1):
            phi = 2 * math.pi * i / sides            # 0 = top, +90 deg = outward
            d = up * math.cos(phi) + outv * math.sin(phi)
            r = RAIL_R
            if is_pinch:
                # Tufting crease only on the top/outer side: the inner face keeps the collider radius.
                w = max(0.0, min(1.0, (d.dot((up + outv).normalized()) + 0.2) / 0.6))
                r -= pinch * w
            ring.append(c + d * r)
            ur.append((s / 0.5, i / sides))
        rings.append(ring)
        uvs.append(ur)
    s_last = total
    uvs[-1] = [(s_last / 0.5, i / sides) for i in range(sides + 1)]
    vrows = [[part.v(p) for p in ring] for ring in rings]
    # Close the loop: the last ring reuses the first ring's verts (the UV seam is kept per face).
    vrows[-1] = vrows[0]
    for row in vrows:
        row[-1] = row[0]
    for j in range(len(vrows) - 1):
        a, b = vrows[j], vrows[j + 1]
        for i in range(sides):
            part.f([a[i], b[i], b[i + 1], a[i + 1]], 0,
                   [uvs[j][i], uvs[j + 1][i], uvs[j + 1][i + 1], uvs[j][i + 1]])
    studs = [(Vector(p), Vector(o)) for (p, o, s, pin) in path if pin]
    return part.finish(out_dir), studs


def dome(part, centre, normal, radius, height, seg, rings, slot):
    """A low brass dome (stud / rivet) sitting on `centre`, bulging along `normal`."""
    n = Vector(normal).normalized()
    t = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
    b = n.cross(t)
    rows = []
    for j in range(rings + 1):
        a = (math.pi / 2) * j / rings
        rr, hh = radius * math.cos(a), height * math.sin(a)
        if j == rings:
            rows.append([part.v(Vector(centre) + n * height)])
            break
        rows.append([part.v(Vector(centre) + n * hh + (t * math.cos(2 * math.pi * i / seg) + b * math.sin(2 * math.pi * i / seg)) * rr) for i in range(seg)])
    for j in range(len(rows) - 1):
        a, bb = rows[j], rows[j + 1]
        for i in range(seg):
            i2 = (i + 1) % seg
            if len(bb) == 1:
                part.f([a[i], a[i2], bb[0]], slot)
            else:
                part.f([a[i], a[i2], bb[i2], bb[i]], slot)


def build_studs(out_dir, name, studs, seg, rings, every=1):
    part = Part(name, ["brass"])
    up = Vector((0, 1, 0))
    for k, (c, o) in enumerate(studs):
        if k % every:
            continue
        d = (up * math.cos(math.radians(35)) + o * math.sin(math.radians(35))).normalized()
        dome(part, c + d * (RAIL_R - 0.006 - 0.001), d, 0.011, 0.007, seg, rings, 0)
    return part.finish(out_dir, smart_uv=True)


def build_felt(out_dir):
    part = Part("felt_floor", ["felt"])
    nx, nz = 16, 8
    rows, uvr = [], []
    for j in range(nz + 1):
        z = -FELT_HALF[1] + 2 * FELT_HALF[1] * j / nz
        rows.append([part.v((-FELT_HALF[0] + 2 * FELT_HALF[0] * i / nx, 0.0, z)) for i in range(nx + 1)])
        uvr.append([(i / nx, j / nz) for i in range(nx + 1)])
    part.grid(rows, 0, uvr)
    return part.finish(out_dir, smooth=False, face_up=True)


def box(part, centre, size, slot, bevel=0.0):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    cx, cy, cz = centre
    vs = [part.v((cx + sx * hx, cy + sy * hy, cz + sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    idx = lambda sx, sy, sz: vs[(sx > 0) * 4 + (sy > 0) * 2 + (sz > 0)]
    faces = [
        [idx(-1, -1, -1), idx(-1, -1, 1), idx(-1, 1, 1), idx(-1, 1, -1)],
        [idx(1, -1, -1), idx(1, 1, -1), idx(1, 1, 1), idx(1, -1, 1)],
        [idx(-1, -1, -1), idx(1, -1, -1), idx(1, -1, 1), idx(-1, -1, 1)],
        [idx(-1, 1, -1), idx(-1, 1, 1), idx(1, 1, 1), idx(1, 1, -1)],
        [idx(-1, -1, -1), idx(-1, 1, -1), idx(1, 1, -1), idx(1, -1, -1)],
        [idx(-1, -1, 1), idx(1, -1, 1), idx(1, 1, 1), idx(-1, 1, 1)],
    ]
    return [part.f(f, slot) for f in faces]


def build_backboard(out_dir):
    part = Part("backboard", ["backboard", "brass"])
    w, h, d, z = BACKBOARD
    box(part, (0, h / 2, z), (w, h, d), 0)
    box(part, (0, h + 0.003, z), (w, 0.006, d + 0.004), 1)   # brass cap strip on top (inside the wall's footprint)
    return part.finish(out_dir, smart_uv=True, smooth=False)


def rounded_rect_ring(part, hx, hz, rc, y, seg):
    pts = []
    for (cx, cz, a0) in ((hx - rc, -(hz - rc), -math.pi / 2), (hx - rc, hz - rc, 0.0), (-(hx - rc), hz - rc, math.pi / 2), (-(hx - rc), -(hz - rc), math.pi)):
        for k in range(seg + 1):
            a = a0 + (math.pi / 2) * k / seg
            pts.append((cx + math.cos(a) * rc, y, cz + math.sin(a) * rc))
    return [part.v(p) for p in pts]


def build_body(out_dir):
    """The table body under and outside the rails (the leather sits on it). All of it is at
    |x| >= 1.11 or |z| >= 0.61 or below the felt (y <= -0.01)."""
    part = Part("body_skirt", ["body_wood"])
    ox, oz = OX + RAIL_R - 0.004, OZ + RAIL_R - 0.004   # just inside the rail's outer skin
    top = rounded_rect_ring(part, ox, oz, 0.10, RAIL_Y, 4)
    mid = rounded_rect_ring(part, ox + 0.012, oz + 0.012, 0.11, -0.10, 4)
    bot = rounded_rect_ring(part, ox - 0.03, oz - 0.03, 0.08, -0.30, 4)
    inner = rounded_rect_ring(part, FELT_HALF[0] + 0.02, FELT_HALF[1] + 0.02, 0.02, -0.012, 2)
    part.grid([top, mid, bot], 0, closed_u=True)
    # Deck under the felt edge so no gap shows between felt and rail.
    deck_out = rounded_rect_ring(part, ox, oz, 0.10, -0.012, 4)
    n_out, n_in = len(deck_out), len(inner)
    # Simple fan-free bridge: sample the inner ring at the same count by nearest index.
    inner_m = [inner[min(n_in - 1, round(i * n_in / n_out))] for i in range(n_out)]
    for i in range(n_out):
        i2 = (i + 1) % n_out
        if inner_m[i] is inner_m[i2]:
            part.f([deck_out[i], deck_out[i2], inner_m[i]], 0)
        else:
            part.f([deck_out[i], deck_out[i2], inner_m[i2], inner_m[i]], 0)
    # Bottom cap (lost in the dark, but closes the silhouette for the ink hull).
    bm = part.bm
    bmesh.ops.contextual_create(bm, geom=bot)
    for f in bm.faces:
        if not f.material_index:
            f.material_index = 0
    return part.finish(out_dir, smart_uv=True, smooth=False)


def tube_shell(part, centre, ax_u, ax_v, arc_r, tube_r, a0, a1, phi0, phi1, nu, nv, slot, up, outdir_fn):
    rows = []
    for i in range(nu + 1):
        a = a0 + (a1 - a0) * i / nu
        od = ax_u * math.cos(a) + ax_v * math.sin(a)
        c = centre + od * arc_r
        o = outdir_fn(od)
        rows.append([part.v(c + (up * math.cos(phi0 + (phi1 - phi0) * j / nv) + o * math.sin(phi0 + (phi1 - phi0) * j / nv)) * tube_r) for j in range(nv + 1)])
    part.grid(rows, slot)
    return rows


def build_corner_cap(out_dir):
    """Brass saddle over the OUTER half of the rail corner (FR corner; the board rotates it for the
    others). Local space = the Corner anchor at (1.11, 0.11, -0.61): the tube corner arc centre is
    at (-0.09, -0.09, +0.09) from it. Starts at the tube top (phi 0) so nothing sits inside the
    rail centreline."""
    part = Part("corner_cap", ["brass"])
    up = Vector((0, 1, 0))
    centre = Vector((-RAIL_R, -(0.11 - RAIL_Y), RAIL_R))
    ax_u, ax_v = Vector((1, 0, 0)), Vector((0, 0, -1))
    outer = tube_shell(part, centre, ax_u, ax_v, RAIL_R, RAIL_R + 0.007, 0.0, math.pi / 2,
                       0.0, math.radians(150), 10, 8, 0, up, lambda od: od)
    inner = tube_shell(part, centre, ax_u, ax_v, RAIL_R, RAIL_R + 0.001, 0.0, math.pi / 2,
                       0.0, math.radians(150), 10, 8, 0, up, lambda od: od)
    for row_o, row_i in ((outer[0], inner[0]), (outer[-1], inner[-1])):
        for j in range(len(row_o) - 1):
            part.f([row_o[j], row_o[j + 1], row_i[j + 1], row_i[j]], 0)
    for j in (0, -1):
        for i in range(len(outer) - 1):
            part.f([outer[i][j], outer[i + 1][j], inner[i + 1][j], inner[i][j]], 0)
    # Three rivets on the outer flank.
    for a in (0.15, math.pi / 4, math.pi / 2 - 0.15):
        od = ax_u * math.cos(a) + ax_v * math.sin(a)
        d = (up * math.cos(math.radians(60)) + od * math.sin(math.radians(60))).normalized()
        dome(part, centre + od * RAIL_R + d * (RAIL_R + 0.007), d, 0.008, 0.005, 8, 2, 0)
    return part.finish(out_dir, smart_uv=True)


def build_target_plaque(out_dir):
    """Far-rail number plate. Local space = TargetPlate anchor (0, 0.11, -0.61), face toward +Z
    (the camera), leaned back 30 degrees from upright. Everything sits at local z <= 0 (outside the
    rail centreline) and below y = 0.25 world (0.14 local)."""
    part = Part("target_plaque", ["brass", "plate_face", "flame"])
    tilt = Matrix.Rotation(math.radians(-30), 4, "X")   # lean the top back toward -Z
    W, H, T, B = 0.32, 0.095, 0.012, 0.016            # width, height, frame depth, border
    foot = 0.008
    base = Vector((0, foot, -T))                        # frame's back-bottom edge

    def P(x, y, z):  # plate-local (x right, y up the plate, z out of the face) -> anchor-local
        return tilt @ Vector((x, y, z)) + base

    def quad(pts, slot):
        part.f([part.v(p) for p in pts], slot)

    # Frame: outer box, inner recessed face.
    xo, yo = W / 2, H
    xi, yi0, yi1 = W / 2 - B, B, H - B
    front, back, recess = T, 0.0, T - 0.004
    o = [P(-xo, 0, front), P(xo, 0, front), P(xo, yo, front), P(-xo, yo, front)]
    ob = [P(-xo, 0, back), P(xo, 0, back), P(xo, yo, back), P(-xo, yo, back)]
    i_ = [P(-xi, yi0, front), P(xi, yi0, front), P(xi, yi1, front), P(-xi, yi1, front)]
    ir = [P(-xi, yi0, recess), P(xi, yi0, recess), P(xi, yi1, recess), P(-xi, yi1, recess)]
    for k in range(4):
        k2 = (k + 1) % 4
        quad([o[k], o[k2], i_[k2], i_[k]], 0)      # front border
        quad([ob[k2], ob[k], o[k], o[k2]], 0)      # outer sides
        quad([i_[k], i_[k2], ir[k2], ir[k]], 0)    # recess walls
    quad([ob[3], ob[2], ob[1], ob[0]], 0)          # back
    quad(ir, 1)                                    # number face
    # Flame crest on top: 3 tongues, flat-extruded, emissive.
    for (cx, hgt, wid) in ((-0.07, 0.026, 0.03), (0.0, 0.036, 0.04), (0.07, 0.026, 0.03)):
        prof = []
        for k in range(9):
            t = k / 8.0
            ang = math.pi * t
            x = cx - math.cos(ang) * wid / 2
            y = H + math.sin(ang) ** 1.6 * hgt * (0.55 + 0.45 * t)   # leaning tip
            prof.append((x, y))
        prof.append((cx + wid * 0.15, H + hgt * 1.15))
        f_front = [P(x, y, T * 0.7) for (x, y) in prof]
        f_back = [P(x, y, T * 0.3) for (x, y) in prof]
        vf = [part.v(p) for p in f_front]
        vb = [part.v(p) for p in f_back]
        part.f(vf, 2)
        part.f(list(reversed(vb)), 2)
        for k in range(len(vf)):
            k2 = (k + 1) % len(vf)
            part.f([vf[k], vf[k2], vb[k2], vb[k]], 2)
    # Foot: a brass bar the plate stands on (on the rail top, behind the centreline).
    fz0, fz1 = -0.045, 0.0
    box_pts = [Vector((sx * W * 0.42, sy, sz)) for sx in (-1, 1) for sy in (0.0, foot) for sz in (fz0, fz1)]
    for (a, b, c, d) in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        quad([box_pts[a], box_pts[b], box_pts[c], box_pts[d]], 0)
    face_centre = P(0, H / 2, recess + 0.002)
    normal = (tilt @ Vector((0, 0, 1, 0))).to_3d()
    return part.finish(out_dir, smart_uv=True, smooth=False), face_centre, normal


def disc_rows(part, centre, nrm, radii_depths, seg):
    n = nrm.normalized()
    t = Vector((1, 0, 0))
    b = n.cross(t).normalized()
    t = b.cross(n)
    rows = []
    for (r, dz) in radii_depths:
        if r == 0:
            rows.append([part.v(centre + n * dz)])
        else:
            rows.append([part.v(centre + n * dz + (t * math.cos(2 * math.pi * i / seg) + b * math.sin(2 * math.pi * i / seg)) * r) for i in range(seg)])
    return rows


def ring_strip(part, rows, slot):
    for j in range(len(rows) - 1):
        a, b = rows[j], rows[j + 1]
        if len(b) == 1:
            for i in range(len(a)):
                part.f([a[i], a[(i + 1) % len(a)], b[0]], slot)
        elif len(a) == 1:
            for i in range(len(b)):
                part.f([a[0], b[(i + 1) % len(b)], b[i]], slot)
        else:
            for i in range(len(a)):
                i2 = (i + 1) % len(a)
                part.f([a[i], a[i2], b[i2], b[i]], slot)


def build_total_dial(out_dir):
    """Near-rail running-total dial. Local space = TotalPlate anchor (0, 0.11, 0.61). A round brass
    dial tilted 30 degrees up from flat toward the camera (+Z). Its inner edge sits on the rail
    centreline (local z >= 0), and a bracket drops to the body outside the rail."""
    part = Part("total_dial", ["brass", "plate_face"])
    R = 0.075
    tilt = math.radians(30)
    n = Vector((0, math.cos(tilt), math.sin(tilt)))
    centre = Vector((0, 0.012 + R * math.sin(tilt), R * math.cos(tilt) + 0.004))
    seg = 32
    bezel = disc_rows(part, centre, n, [(R, -0.010), (R + 0.002, 0.0), (R - 0.004, 0.006), (R - 0.014, 0.004), (R - 0.016, 0.0)], seg)
    ring_strip(part, bezel, 0)
    face = disc_rows(part, centre, n, [(R - 0.016, 0.0), (0, 0.0)], seg)
    # Reuse the inner bezel row for the face so it is welded.
    face[0] = bezel[-1]
    ring_strip(part, face, 1)
    back = disc_rows(part, centre, n, [(R, -0.010), (0, -0.010)], seg)
    back[0] = bezel[0]
    ring_strip(part, [back[1], back[0]][::-1], 0)
    # 12 tick studs on the bezel.
    tdir = Vector((1, 0, 0))
    bdir = n.cross(tdir).normalized()
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = centre + n * 0.006 + (tdir * math.cos(a) + bdir * math.sin(a)) * (R - 0.009)
        dome(part, p, n, 0.004, 0.003, 6, 1, 0)
    # Bracket: a brass block from under the dial down onto the rail top (outside the centreline).
    box(part, (0, 0.006, 0.05), (0.05, 0.012, 0.06), 0)
    face_centre = centre + n * 0.002
    return part.finish(out_dir, smart_uv=True), face_centre, n


def build_chip_tray(out_dir):
    """Right-rail side-bet chip tray. Local space = ChipTray anchor (1.11, 0.11, 0): the tray sits
    from the rail centreline outward (local x >= 0), 0.30 m long, with a low lip."""
    part = Part("chip_tray", ["brass", "plate_face"])
    x0, x1, z0, z1 = 0.0, 0.14, -0.15, 0.15
    y0, lip, t = 0.004, 0.022, 0.006
    # Floor (dark felt inset) + brass rim walls.
    fl = [part.v(p) for p in ((x0 + t, y0, z0 + t), (x1 - t, y0, z0 + t), (x1 - t, y0, z1 - t), (x0 + t, y0, z1 - t))]
    part.f(fl, 1)
    outer_b = [(x0, 0.0, z0), (x1, 0.0, z0), (x1, 0.0, z1), (x0, 0.0, z1)]
    outer_t = [(x, lip, z) for (x, _, z) in outer_b]
    inner_t = [(x0 + t, lip, z0 + t), (x1 - t, lip, z0 + t), (x1 - t, lip, z1 - t), (x0 + t, lip, z1 - t)]
    inner_b = [(x, y0, z) for (x, _, z) in inner_t]
    ob, ot, it, ib = ([part.v(p) for p in L] for L in (outer_b, outer_t, inner_t, inner_b))
    for k in range(4):
        k2 = (k + 1) % 4
        part.f([ob[k], ob[k2], ot[k2], ot[k]], 0)
        part.f([ot[k], ot[k2], it[k2], it[k]], 0)
        part.f([it[k], it[k2], ib[k2], ib[k]], 0)
        part.f([ib[k], ib[k2], fl[k2], fl[k]], 0)
    part.f(list(reversed(ob)), 0)
    # 3 shallow stack wells (rings on the floor) where code-driven chip stacks go.
    for zc in (-0.09, 0.0, 0.09):
        rows = disc_rows(part, Vector((0.07, y0 + 0.0005, zc)), Vector((0, 1, 0)), [(0.034, 0.0), (0.030, 0.0015)], 16)
        ring_strip(part, rows, 0)
    # Support bracket down the outside of the rail onto the body.
    box(part, (0.10, -0.045, 0.0), (0.03, 0.09, 0.22), 0)
    return part.finish(out_dir, smart_uv=True, smooth=False)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[0]) if argv else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_felt(out_dir)
    build_backboard(out_dir)
    build_body(out_dir)
    _, studs = build_rails(out_dir, "rails", sides=16, step_pad=4, corner_rings=6)
    build_studs(out_dir, "trim_studs", studs, seg=8, rings=3)
    build_rails(out_dir, "rails_mobile", sides=10, step_pad=2, corner_rings=3, pinch=0.005)
    build_studs(out_dir, "trim_studs_mobile", studs, seg=6, rings=1, every=2)
    build_corner_cap(out_dir)
    _, tc, tn = build_target_plaque(out_dir)
    _, dc, dn = build_total_dial(out_dir)
    build_chip_tray(out_dir)
    print("NUMBER_ANCHOR target_plaque pos=%s normal=%s" % (tuple(round(x, 4) for x in tc), tuple(round(x, 4) for x in tn)))
    print("NUMBER_ANCHOR total_dial pos=%s normal=%s" % (tuple(round(x, 4) for x in dc), tuple(round(x, 4) for x in dn)))
    fixed = TRIS["felt_floor"] + TRIS["backboard"] + TRIS["body_skirt"]
    props = 4 * TRIS["corner_cap"] + TRIS["target_plaque"] + TRIS["total_dial"] + TRIS["chip_tray"]
    print("TOTAL_PC %d" % (fixed + props + TRIS["rails"] + TRIS["trim_studs"]))
    print("TOTAL_MOBILE %d" % (fixed + props + TRIS["rails_mobile"] + TRIS["trim_studs_mobile"]))


main()
