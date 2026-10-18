"""Builds the Bone d6 as a game-ready .glb (one mesh, two material slots: body + pips).

Run headless (Blender 4.5 LTS):
    blender -b --factory-startup --python art/models/dice/src/build_dice.py -- [out_dir] [--all]
out_dir defaults to the folder above this script (art/models/dice/). Only the dice listed in
EXPORT are built; --all also builds the parked specs (Knucklebone, parked by PM on Oct 18, 2026
while the core loop is reworked; it is not shipped).

Why a script and not a hand-made .blend: the dice must match the face convention in
scripts/table3d/die_visual.gd exactly (FACE_AXES, PIPS, PIP_STEP, the u/v pip axes), so the
geometry is generated from the same numbers. Re-run it after changing a number below.

Conventions (all in GODOT space, Y up, metres; converted to Blender Z-up on the way in, and the
glTF exporter converts back, so the .glb is in Godot space):
  slot -> local normal (DieVisual.FACE_AXES):  1:+Y  6:-Y  2:+X  5:-X  3:+Z  4:-Z
  Bone labels        [1, 2, 3, 4, 5, 6]  (slot i shows i pips; opposite faces sum to 7)
  Knucklebone labels [1, 2, 3, 3, 2, 1]  (PARKED, not exported: 1 on +-Y, 2 on +-X, 3 on +-Z)
  Pip axes per face (same as DieVisual._add_pips): u = +Y projected onto the face (+X on the
  +-Y faces), v = n x u; a pip spot (x, y) sits at n*h + u*x*PIP_STEP*edge + v*y*PIP_STEP*edge.
UVs: one 3x2 atlas (author textures at 3:2, e.g. 768x512). Tile for slot s: column (s-1)%3,
row (s-1)//3 from the top. Inside a tile, U runs along the face's u axis, V along -v.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

EDGE = 0.08            # TuningData.die_size / DieVisual.edge
PIP_STEP = 0.23        # DieVisual.PIP_STEP
BEVEL_STEPS = 2        # steps per half bevel (4 segments across each 90-degree edge), like DieVisual.rounded_cube
PIP_SEGMENTS = 12      # cavity resolution

FACE_AXES = {1: (0, 1, 0), 6: (0, -1, 0), 2: (1, 0, 0), 5: (-1, 0, 0), 3: (0, 0, 1), 4: (0, 0, -1)}
PIPS = {
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
    5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
}


def srgb_to_linear(hex_str):
    out = []
    for i in (0, 2, 4):
        c = int(hex_str[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


DICE = [
    {
        "name": "bone_d6", "node": "BoneD6",
        "labels": [1, 2, 3, 4, 5, 6],
        "bevel": 0.16,          # poc_3d.md 3: radius 0.16 x edge
        "pip_diameter": 0.18,   # dice_rarities.md Bone: 18% of the face
        "pip_depth": 0.06,      # poc_3d.md 3: drilled, depth 0.06 x edge
        "body": ("bone_body", "E8DCC0", 0.45),
        "pip": ("bone_pip", "0E1414", 0.8),
    },
    {
        "name": "knucklebone_d6", "node": "KnuckleboneD6",
        "labels": [1, 2, 3, 3, 2, 1],  # slots 1..6 = +Y, +X, +Z, -Z, -X, -Y
        "bevel": 0.16,
        "pip_diameter": 0.20,   # dice_rarities.md Knucklebone: pips >= 20% of the side
        "pip_depth": 0.07,
        "body": ("knucklebone_body", "BFAB88", 0.55),  # BurnDie.body_color in burn_line_tuning.tres
        "pip": ("knucklebone_pip", "3B0D14", 0.8),     # BurnDie.pip_color (Oxblood)
    },
]


def g2b(v):
    """Godot (x, y, z) Y-up -> Blender (x, -z, y) Z-up."""
    return Vector((v[0], -v[2], v[1]))


def face_axes(n):
    n = Vector(n)
    u = Vector((0, 1, 0)) if abs(n.y) < 0.5 else Vector((1, 0, 0))
    u = (u - n * u.dot(n)).normalized()
    v = n.cross(u)
    return n, u, v


def make_material(name, hex_col, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb_to_linear(hex_col)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    m.diffuse_color = srgb_to_linear(hex_col)
    return m


def rounded_cube_bmesh(size, radius):
    """Same construction as DieVisual.rounded_cube: per-face grids projected onto the bevel."""
    h = size * 0.5
    c = h - radius
    steps = [c + radius * math.tan(math.radians(45.0 * k / BEVEL_STEPS)) for k in range(BEVEL_STEPS + 1)]
    coords = [-s for s in reversed(steps)] + steps
    bm = bmesh.new()
    for slot, n in FACE_AXES.items():
        n, u, v = face_axes(n)
        grid = []
        for j in coords:
            row = []
            for i in coords:
                p = n * h + u * i + v * j
                inner = Vector((max(-c, min(c, p.x)), max(-c, min(c, p.y)), max(-c, min(c, p.z))))
                d = p - inner
                q = inner + d.normalized() * radius if d.length > 1e-9 else p
                row.append(bm.verts.new(g2b(q)))
            grid.append(row)
        for j in range(len(coords) - 1):
            for i in range(len(coords) - 1):
                f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
                f.normal_update()
                if f.normal.dot(g2b(n)) < 0:
                    f.normal_flip()
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median()) < 0:
            f.normal_flip()
    return bm


def build_die(spec, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body_mat = make_material(spec["body"][0], spec["body"][1], spec["body"][2])
    pip_mat = make_material(spec["pip"][0], spec["pip"][1], spec["pip"][2])

    radius = spec["bevel"] * EDGE
    h = EDGE * 0.5
    bm = rounded_cube_bmesh(EDGE, radius)
    me = bpy.data.meshes.new(spec["node"])
    bm.to_mesh(me)
    bm.free()
    body = bpy.data.objects.new(spec["node"], me)
    bpy.context.scene.collection.objects.link(body)
    me.materials.append(body_mat)
    me.materials.append(pip_mat)

    # Pip cutters: spherical caps, opening radius a, depth d -> sphere radius R = (a^2 + d^2) / 2d.
    a = spec["pip_diameter"] * EDGE * 0.5
    d = spec["pip_depth"] * EDGE
    R = (a * a + d * d) / (2.0 * d)
    cut_bm = bmesh.new()
    for slot, n in FACE_AXES.items():
        n, u, v = face_axes(n)
        shown = spec["labels"][slot - 1]
        for (sx, sy) in PIPS[shown]:
            centre = n * (h - d + R) + u * sx * PIP_STEP * EDGE + v * sy * PIP_STEP * EDGE
            res = bmesh.ops.create_uvsphere(cut_bm, u_segments=PIP_SEGMENTS, v_segments=PIP_SEGMENTS // 2, radius=R)
            bmesh.ops.translate(cut_bm, verts=res["verts"], vec=g2b(centre))
    cut_me = bpy.data.meshes.new("pip_cutters")
    cut_bm.to_mesh(cut_me)
    cut_bm.free()
    cut_me.materials.append(pip_mat)
    cutter = bpy.data.objects.new("pip_cutters", cut_me)
    bpy.context.scene.collection.objects.link(cutter)

    mod = body.modifiers.new("pips", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    mod.material_mode = "TRANSFER"
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)

    # Clean up, triangulate (so the tri count we report is what ships).
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-7)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(me)
    bm.free()

    # Normals: body = direction from the inner box (continuous, flat faces stay flat, like
    # DieVisual.rounded_cube); pip cavities = towards the cap centre (smooth bowl).
    c = h - radius
    loop_normals = []
    for poly in me.polygons:
        is_pip = me.materials[poly.material_index] == pip_mat
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if is_pip:
                loop_normals.append(None)  # filled below, once the cap centres are known
                continue
            inner = Vector((max(-c, min(c, co.x)), max(-c, min(c, co.y)), max(-c, min(c, co.z))))
            dv = co - inner
            loop_normals.append(dv.normalized() if dv.length > 1e-9 else poly.normal.copy())
    # Pip loops: point the normal from the vertex back toward the cap sphere centre (inward bowl).
    centres = []
    for slot, n in FACE_AXES.items():
        n, u, v = face_axes(n)
        for (sx, sy) in PIPS[spec["labels"][slot - 1]]:
            centres.append(g2b(n * (h - d + R) + u * sx * PIP_STEP * EDGE + v * sy * PIP_STEP * EDGE))
    idx = 0
    for poly in me.polygons:
        for li in poly.loop_indices:
            if loop_normals[idx] is None:
                co = me.vertices[me.loops[li].vertex_index].co
                cc = min(centres, key=lambda k: (k - co).length)
                loop_normals[idx] = (cc - co).normalized()
            idx += 1
    me.normals_split_custom_set(loop_normals)

    # UVs: 3x2 atlas, tile = slot of the poly's dominant axis.
    uv = me.uv_layers.new(name="UVMap")
    axes_b = {s: face_axes(nv) for s, nv in FACE_AXES.items()}
    for poly in me.polygons:
        cen = poly.center
        best = max(FACE_AXES, key=lambda s: cen.dot(g2b(FACE_AXES[s])))
        n, u, v = axes_b[best]
        ub, vb = g2b(u), g2b(v)
        col, row = (best - 1) % 3, (best - 1) // 3
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            fu = co.dot(ub) / EDGE + 0.5           # 0..1 across the face
            fv = 0.5 - co.dot(vb) / EDGE
            pad = 0.02
            fu = pad + fu * (1 - 2 * pad)
            fv = pad + fv * (1 - 2 * pad)
            uv.data[li].uv = ((col + fu) / 3.0, 1.0 - (row + fv) / 2.0)

    tris = len(me.polygons)
    path = os.path.join(out_dir, spec["name"] + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_animations=False,
    )
    print("BUILT %s tris=%d verts=%d -> %s" % (spec["name"], tris, len(me.vertices), path))
    return tris


EXPORT = ["bone_d6"]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build_all = "--all" in argv
    argv = [a for a in argv if a != "--all"]
    out_dir = os.path.abspath(argv[0]) if argv else os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    os.makedirs(out_dir, exist_ok=True)
    for spec in DICE:
        if spec["name"] not in EXPORT and not build_all:
            continue
        build_die(spec, out_dir)
        if os.environ.get("DICE_SAVE_BLEND"):
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ["DICE_SAVE_BLEND"], spec["name"] + ".blend"))


main()
