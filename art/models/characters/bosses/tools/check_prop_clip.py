# Prop clip check: blender -b --factory-startup --python check_prop_clip.py -- <file.glb> [tol_mm]
# Every non-prop mesh is split into closed shells (islands); a prop vertex is "inside" when it sits
# under the surface of a shell (nearest-point normal test per shell; shells are near-convex blobs/tubes).
import bpy, bmesh, sys
from mathutils.bvhtree import BVHTree
args = sys.argv[sys.argv.index("--") + 1:]
glb = args[0]; tol = float(args[1]) / 1000 if len(args) > 1 else 0.002
bpy.ops.gltf_import = None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
is_prop = lambda o: any(k in o.name for k in ("Plaque", "Chip", "Cards", "Rod", "Cloche", "Lancet"))
props = [o for o in meshes if is_prop(o)]; others = [o for o in meshes if not is_prop(o)]
def islands(o):
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        st, comp = [v], []
        seen.add(v.index)
        while st:
            x = st.pop(); comp.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
        out.append(set(comp))
    faces = [[f.verts[i].index for i in range(len(f.verts))] for f in bm.faces]
    bm.free()
    return [(c, [f for f in faces if f[0] in c]) for c in out]
shells = {o.name: islands(o) for o in others}
dg = bpy.context.evaluated_depsgraph_get()
total = 0
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    bad, deep, who = [], 0.0, {}
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f); dg = bpy.context.evaluated_depsgraph_get()
        pv = []
        for p in props:
            m = p.evaluated_get(dg).to_mesh(); pv += [p.matrix_world @ v.co for v in m.vertices]; p.evaluated_get(dg).to_mesh_clear()
        if not pv: continue
        lo = min(v.z for v in pv); hi = max(v.z for v in pv)
        if (hi - lo) < 0.005: continue  # prop scaled to 0 (palmed/hidden)
        n_in = 0
        for o in others:
            m = o.evaluated_get(dg).to_mesh(); W = o.matrix_world
            vs = [W @ v.co for v in m.vertices]
            for comp, faces in shells[o.name]:
                bvh = BVHTree.FromPolygons(vs, faces)
                for q in pv:
                    loc, nrm, _, d = bvh.find_nearest(q)
                    if loc is not None and d < 0.05 and (q - loc).dot(nrm) < 0 and d > tol:
                        n_in += 1; deep = max(deep, d)
                        c = sum((vs[i] for i in comp), vs[0]*0) / len(comp); k = f"{o.name}@({c.x:.2f},{c.y:.2f},{c.z:.2f})"; who[k] = max(who.get(k, 0), d)
            o.evaluated_get(dg).to_mesh_clear()
        if n_in: bad.append(f"@{(f - f0) / 30:.2f}: {n_in}")
    total += len(bad)
    print(f"PROPCLIP2 {act.name:9s} {len(bad):3d} bad frames, deepest {deep*1000:.1f} mm {bad[:5]}")
    for k, d in sorted(who.items(), key=lambda kv: -kv[1])[:3]: print(f"PROPCLIP2     into {k} {d*1000:.0f} mm")
print(f"PROPCLIP2 TOTAL {total} (tolerance {tol*1000:.0f} mm) {glb.split('/')[-1]}")
