"""Builds the Hearth board props as .glb (Blender 4.5 LTS, headless).

    blender -b --factory-startup --python art/models/boards/hearth/src/build_hearth.py -- [out_dir]

Spec: art/concept/bonfire_table/README.md "LOCKED DIRECTION" (Hearth + Candle Shrine progress
candles), art/concept/burnline_boards/board_kit.md sections 1-8, art/concept/fire/fire_style.md.
The Hearth reuses Board A (infernal_pit) unchanged: felt, rails, studs, backboard, body, total dial,
near corner caps, and the same node tree and anchors. This script only makes the Hearth props, each
authored in its ANCHOR's local space (Godot axes: metres, +Y up, -Z = far rail, +Z = player), PC and
mobile LOD:
  brazier        TargetPlate (0, 0.11, -0.61): iron fire bowl set behind the far rail centreline, brass
                 band + rivets, coal bed, and an iron goal plaque on its face (leaned back 30 deg).
  demon_face     Corner_FL / Corner_FR: carved iron demon mask with horns, two eye inserts (the only
                 emissive part). Authored facing +Z; the board scene yaws it toward the felt.
  cauldron       ChipTray (1.11, 0.11, 0): iron pot on 3 legs outside the right rail, brass handles.
  cauldron_fill  the ember mound inside the cauldron (unit radius; the fill script moves and scales it).
  candle         one progress candle on a brass dish (shared by all 8 candles).
Rule (board_kit.md 7): decoration stays on or outside the rail centreline (|x| >= 1.11 or |z| >= 0.61)
and under y = 0.25 m (world). Fire cards are built in Godot (src/make_hearth.gd), not here.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

TRIS = {}
MATS = {  # glTF placeholder colours; each .import maps the slot to materials/<slot>.tres
    "hearth_iron": ("2B2A2E", 0.6), "brass": ("B08D3C", 0.35), "plate_face": ("1A0A0C", 0.8),
    "hearth_coals": ("1E1B1A", 0.9), "demon_iron": ("3A3230", 0.6), "demon_eye": ("1E1B1A", 0.4),
    "candle_wax": ("E8DCC0", 0.5),
}


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def lin(h):
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(MATS[name][0])
    b.inputs["Roughness"].default_value = MATS[name][1]
    return m


class Part:
    def __init__(self, name, slots):
        self.name, self.slots = name, slots
        self.bm = bmesh.new()

    def v(self, p):
        return self.bm.verts.new(g2b(p))

    def f(self, vs, slot):
        try:
            face = self.bm.faces.new(vs)
        except ValueError:
            return None
        face.material_index = slot
        return face

    def lathe(self, profile, seg, centre=(0.0, 0.0), slot=0, jitter=0.0, rng=None, phase=0.0, axis="y"):
        """Surface of revolution of [(r, y), ...] around a vertical axis at (x, z) = centre.
        r == 0 rows collapse to a single pole vertex."""
        rows = []
        for (r, y) in profile:
            if r < 1e-6:
                rows.append([self.v((centre[0], y, centre[1]))] * seg)
                continue
            row = []
            for i in range(seg):
                a = phase + 2 * math.pi * i / seg
                jr = 1.0 + (rng.uniform(-jitter, jitter) if rng else 0.0)
                jy = (rng.uniform(-jitter, jitter) * 0.01 if rng else 0.0)
                row.append(self.v((centre[0] + math.cos(a) * r * jr, y + jy, centre[1] + math.sin(a) * r * jr)))
            rows.append(row)
        for j in range(len(rows) - 1):
            a, b = rows[j], rows[j + 1]
            for i in range(seg):
                i2 = (i + 1) % seg
                q = [a[i], a[i2], b[i2], b[i]]
                uniq = []
                for x in q:
                    if x not in uniq:
                        uniq.append(x)
                if len(uniq) >= 3:
                    self.f(uniq, slot)
        return rows

    def sphere(self, centre, radii, useg, vseg, slot, fn=None, basis=None):
        """Ellipsoid (optionally deformed by fn(unit_point) -> unit_point) around centre."""
        bm2 = bmesh.new()
        bmesh.ops.create_uvsphere(bm2, u_segments=useg, v_segments=vseg, radius=1.0)
        vmap = {}
        for vv in bm2.verts:
            # bm2 is Blender-space; read it as Godot (x, y, z) = (bx, bz, -by)
            p = Vector((vv.co.x, vv.co.z, -vv.co.y))
            if fn:
                p = fn(p)
            p = Vector((p.x * radii[0], p.y * radii[1], p.z * radii[2]))
            if basis:
                p = basis @ p
            vmap[vv] = self.v(Vector(centre) + p)
        for face in bm2.faces:
            self.f([vmap[x] for x in face.verts], slot)
        bm2.free()

    def box(self, centre, axes, half, slot):
        c = Vector(centre)
        ax = [Vector(a).normalized() for a in axes]
        pts = {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    pts[(sx, sy, sz)] = self.v(c + ax[0] * sx * half[0] + ax[1] * sy * half[1] + ax[2] * sz * half[2])
        quads = [((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1)), ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
                 ((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)), ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)),
                 ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)), ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1))]
        for q in quads:
            self.f([pts[k] for k in q], slot)

    def cone_path(self, pts, radii, seg, slot):
        """Tube along pts (Godot) with per-point radius; last radius 0 = a point (horn)."""
        rows = []
        for k, p in enumerate(pts):
            p = Vector(p)
            d = (Vector(pts[min(k + 1, len(pts) - 1)]) - Vector(pts[max(k - 1, 0)])).normalized()
            t = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
            b = d.cross(t)
            if radii[k] < 1e-6:
                rows.append([self.v(p)] * seg)
            else:
                rows.append([self.v(p + (t * math.cos(2 * math.pi * i / seg) + b * math.sin(2 * math.pi * i / seg)) * radii[k]) for i in range(seg)])
        cap = self.f(list(reversed(rows[0])), slot) if radii[0] > 0 else None
        for j in range(len(rows) - 1):
            a, c = rows[j], rows[j + 1]
            for i in range(seg):
                i2 = (i + 1) % seg
                q = [a[i], a[i2], c[i2], c[i]]
                uniq = []
                for x in q:
                    if x not in uniq:
                        uniq.append(x)
                if len(uniq) >= 3:
                    self.f(uniq, slot)

    def finish(self, out_dir, smooth_deg=40.0):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        self.bm.to_mesh(me)
        self.bm.free()
        for s in self.slots:
            me.materials.append(material(s))
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(smooth_deg))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        path = os.path.join(out_dir, self.name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                                  export_apply=True, export_materials="EXPORT", export_cameras=False,
                                  export_lights=False, export_animations=False)
        TRIS[self.name] = len(me.polygons)
        print("BUILT %-22s tris=%5d slots=%s" % (self.name, len(me.polygons), self.slots))
        bpy.data.objects.remove(ob)


# ---------------------------------------------------------------- brazier (TargetPlate)
BRAZIER_C = (0.0, -0.16)    # bowl axis (x, z), behind the rail centreline: front of the rim at z ~ -0.026
BOWL = [(0.045, -0.02), (0.05, 0.0), (0.062, 0.012), (0.07, 0.02), (0.078, 0.026), (0.104, 0.044), (0.121, 0.072),
        (0.128, 0.096), (0.134, 0.103), (0.134, 0.11), (0.12, 0.11), (0.112, 0.092), (0.09, 0.072), (0.0, 0.064)]
BAND = [(0.112, 0.052), (0.119, 0.055), (0.123, 0.063), (0.12, 0.071), (0.116, 0.074)]
COALS = [(0.0, 0.086), (0.04, 0.084), (0.075, 0.08), (0.1, 0.077), (0.113, 0.072)]
PLAQUE_TILT = math.radians(30.0)       # face normal 30 deg above horizontal (board_kit.md 8)
PLAQUE_C = (0.0, 0.06, -0.022)
PLAQUE_HALF = (0.078, 0.036)


def plaque_axes():
    n = Vector((0, math.sin(PLAQUE_TILT), math.cos(PLAQUE_TILT)))
    up = Vector((0, math.cos(PLAQUE_TILT), -math.sin(PLAQUE_TILT)))
    return Vector((1, 0, 0)), up, n


def build_brazier(out_dir, name, seg, rivets, coal_seg):
    rng = random.Random(7)
    part = Part(name, ["hearth_iron", "brass", "hearth_coals", "plate_face"])
    part.lathe(BOWL, seg, BRAZIER_C, 0)
    part.lathe(BAND, seg, BRAZIER_C, 1)
    part.lathe(COALS, coal_seg, BRAZIER_C, 2, jitter=0.12, rng=rng, phase=0.3)
    for k in range(rivets):
        a = math.pi / 2 + 2 * math.pi * (k + 0.5) / rivets
        c = (BRAZIER_C[0] + math.cos(a) * 0.123, 0.063, BRAZIER_C[1] + math.sin(a) * 0.123)
        part.sphere(c, (0.006, 0.006, 0.006), 6, 3, 1)
    # Iron goal plaque: iron back plate + dark face inset, 2 brass bolts, on a bracket to the band.
    x, up, n = plaque_axes()
    c = Vector(PLAQUE_C)
    part.box(c, (x, up, n), (PLAQUE_HALF[0], PLAQUE_HALF[1], 0.004), 0)
    part.box(c + n * 0.0035, (x, up, n), (PLAQUE_HALF[0] - 0.008, PLAQUE_HALF[1] - 0.007, 0.0012), 3)
    for sx in (-1, 1):
        part.sphere(c + x * sx * (PLAQUE_HALF[0] - 0.004) + n * 0.004, (0.004, 0.004, 0.004), 6, 3, 1)
    for sx in (-1, 1):  # two iron straps from the plaque back into the bowl band
        part.box(c + x * sx * 0.045 - n * 0.014, (x, up, n), (0.008, PLAQUE_HALF[1] * 0.7, 0.011), 0)
    part.finish(out_dir, 35.0)


def number_anchor():
    x, up, n = plaque_axes()
    return Vector(PLAQUE_C) + n * 0.0048, n


# ---------------------------------------------------------------- demon face (Corner_FL / FR)
FACE_TILT = math.radians(22.0)  # leaned back toward the camera
FACE_C = Vector((0.0, 0.05, 0.0))
FACE_R = (0.046, 0.05, 0.03)


def _gauss(dx, dy, sx, sy):
    return math.exp(-((dx / sx) ** 2 + (dy / sy) ** 2))


def demon_shape(p):
    x, y, z = p.x, p.y, p.z
    if y < 0:
        x *= 1.0 - 0.38 * (-y) ** 1.3            # narrow, pointed chin
    if z > 0:
        ax = abs(x)
        brow_y = 0.2 + 0.32 * ax                 # angry brows: low in the middle
        z += 0.22 * math.exp(-((y - brow_y) / 0.1) ** 2) * (1.0 if ax < 0.8 else 0.3)
        z -= 0.3 * (_gauss(x - 0.36, y - 0.08, 0.16, 0.11) + _gauss(x + 0.36, y - 0.08, 0.16, 0.11))
        z += 0.16 * _gauss(x, y + 0.12, 0.11, 0.16)          # nose
        z += 0.12 * (_gauss(x - 0.5, y + 0.15, 0.18, 0.15) + _gauss(x + 0.5, y + 0.15, 0.18, 0.15))  # cheekbones
        if ax < 0.75:                                          # wide grin
            z -= 0.26 * math.exp(-((y - (-0.5 + 0.38 * x * x)) / 0.065) ** 2)
    else:
        z = max(z, -0.45)
    return Vector((x, y, z))


def demon_basis():
    return Matrix.Rotation(-FACE_TILT, 3, Vector((1, 0, 0)))


def eye_pos(sx):
    q = demon_shape(Vector((0.36 * sx, 0.08, math.sqrt(max(0.0, 1 - 0.36 ** 2 - 0.08 ** 2)))))
    return FACE_C + demon_basis() @ Vector((q.x * FACE_R[0], q.y * FACE_R[1], q.z * FACE_R[2] + 0.002))


def build_demon_face(out_dir, name, useg, vseg, horn_seg, eye_seg):
    part = Part(name, ["demon_iron", "demon_eye"])
    B = demon_basis()
    part.sphere(FACE_C, FACE_R, useg, vseg, 0, demon_shape, B)
    for sx in (-1, 1):
        pts = [(0.026 * sx, 0.092, -0.006), (0.044 * sx, 0.108, -0.01), (0.054 * sx, 0.125, -0.012), (0.056 * sx, 0.138, -0.012)]
        pts = [FACE_C + B @ (Vector(p) - FACE_C) for p in pts]
        part.cone_path(pts, [0.012, 0.008, 0.0045, 0.0], horn_seg, 0)
        part.sphere(eye_pos(sx), (0.0115, 0.0068, 0.005), eye_seg, max(3, eye_seg // 2), 1, None,
                    B @ Matrix.Rotation(-0.35 * sx, 3, Vector((0, 0, 1))))
    # fangs from the grin corners
    for sx in (-1, 1):
        top = FACE_C + B @ Vector((0.017 * sx, -0.022, 0.024))
        part.cone_path([top, top + B @ Vector((0.001 * sx, -0.007, 0.002)), top + B @ Vector((0.002 * sx, -0.013, 0.003))],
                       [0.0035, 0.0022, 0.0], 3, 0)
    # carved socle: sits into the rail top (the rail surface is ~1 cm below the anchor here) and
    # carries the chin, so the mask stands on the corner instead of floating
    part.lathe([(0.0, -0.022), (0.034, -0.022), (0.036, -0.012), (0.029, -0.006), (0.019, 0.004), (0.021, 0.012),
                (0.015, 0.018), (0.0, 0.02)], eye_seg + 2, (0.0, -0.012), 0)
    part.finish(out_dir, 50.0)


# ---------------------------------------------------------------- cauldron (ChipTray)
CAUL_C = (0.106, 0.0)
CAUL = [(0.03, -0.012), (0.06, -0.004), (0.08, 0.02), (0.09, 0.05), (0.086, 0.08), (0.072, 0.098), (0.068, 0.104),
        (0.079, 0.111), (0.079, 0.12), (0.065, 0.12), (0.061, 0.106), (0.07, 0.086), (0.076, 0.05), (0.062, 0.016),
        (0.0, 0.006)]
# inner wall (y, r) for the fill mound: the fill script interpolates this
CAUL_INNER = [(0.016, 0.062), (0.05, 0.076), (0.086, 0.07), (0.104, 0.061)]


def build_cauldron(out_dir, name, seg, handle_seg):
    part = Part(name, ["hearth_iron", "brass"])
    part.lathe(CAUL, seg, CAUL_C, 0)
    for k in range(3):
        a = math.pi + 2 * math.pi * k / 3 + math.pi / 3
        top = Vector((CAUL_C[0] + math.cos(a) * 0.055, 0.0, CAUL_C[1] + math.sin(a) * 0.055))
        bot = Vector((CAUL_C[0] + math.cos(a) * 0.07, -0.088, CAUL_C[1] + math.sin(a) * 0.07))
        part.cone_path([top, (top + bot) * 0.5, bot], [0.008, 0.007, 0.009], 4, 0)
    for sz in (-1, 1):
        c = Vector((CAUL_C[0], 0.094, CAUL_C[1] + sz * 0.086))
        pts = []
        for i in range(handle_seg + 1):
            a = math.pi * i / handle_seg
            pts.append(c + Vector((math.cos(a) * 0.026, -math.sin(a) * 0.022, sz * math.sin(a) * 0.012)))
        part.cone_path(pts, [0.0035] * len(pts), 4, 1)
    part.finish(out_dir, 40.0)


def build_cauldron_fill(out_dir, name, seg, rings):
    rng = random.Random(11)
    part = Part(name, ["hearth_coals"])
    prof = [(0.0, 0.016)] + [(r / rings, 0.016 * (1 - (r / rings) ** 2) - 0.002) for r in range(1, rings + 1)]
    part.lathe(prof, seg, (0.0, 0.0), 0, jitter=0.1, rng=rng)
    part.finish(out_dir, 60.0)


# ---------------------------------------------------------------- candle (progress candles)
CANDLE_TOP = 0.066   # wick tip (flame base) above the anchor-local origin


def build_candle(out_dir, name, seg, wick):
    part = Part(name, ["candle_wax", "brass", "hearth_iron"])
    dish = [(0.0, 0.0), (0.021, 0.0), (0.023, 0.004), (0.019, 0.0065), (0.0, 0.0065)]
    if not wick:  # mobile: one ring less on the dish (~80 tris total)
        dish = [(0.0, 0.0), (0.022, 0.0), (0.019, 0.0065), (0.0, 0.0065)]
    part.lathe(dish, seg, (0, 0), 1)
    rows = part.lathe([(0.0135, 0.006), (0.014, 0.034), (0.0132, 0.058), (0.0118, 0.0625), (0.0085, 0.0595), (0.0, 0.0585)],
                      seg, (0, 0), 0, phase=0.2)
    # drips: bulge two columns of the upper wax ring outward
    for i in (1, seg // 2 + 1):
        for j, push in ((1, 0.0022), (2, 0.0028), (3, 0.0012)):
            vv = rows[j][i % seg]
            co = Vector((vv.co.x, vv.co.y, 0))
            vv.co += co.normalized() * push
            if j == 1:
                vv.co.z -= 0.004
    if wick:
        part.cone_path([(0, 0.058, 0), (0.0006, 0.063, 0), (0.0012, CANDLE_TOP, 0)], [0.0013, 0.0011, 0.0], 3, 2)
    part.finish(out_dir, 50.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[0]) if argv else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_brazier(out_dir, "brazier", 24, 6, 12)
    build_brazier(out_dir, "brazier_mobile", 12, 4, 8)
    build_demon_face(out_dir, "demon_face", 18, 12, 6, 8)
    build_demon_face(out_dir, "demon_face_mobile", 10, 7, 4, 6)
    build_cauldron(out_dir, "cauldron", 20, 6)
    build_cauldron(out_dir, "cauldron_mobile", 10, 3)
    build_cauldron_fill(out_dir, "cauldron_fill", 12, 3)
    build_cauldron_fill(out_dir, "cauldron_fill_mobile", 8, 2)
    build_candle(out_dir, "candle", 8, True)
    build_candle(out_dir, "candle_mobile", 6, False)
    na, nn = number_anchor()
    print("NUMBER_ANCHOR brazier pos=%s normal=%s" % (tuple(round(v, 4) for v in na), tuple(round(v, 4) for v in nn)))
    for sx in (-1, 1):
        print("EYE %d %s" % (sx, tuple(round(v, 4) for v in eye_pos(sx))))
    print("CANDLE_TOP %.4f" % CANDLE_TOP)
    print("TRIS %s" % TRIS)


main()
