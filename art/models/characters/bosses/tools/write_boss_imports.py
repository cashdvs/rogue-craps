"""Shared import writer for the boss dealers (template for all six):
    python3 art/models/characters/bosses/tools/write_boss_imports.py <boss> <slot> [<slot> ...]
Writes <boss>/<boss>(_mobile).glb.import: every glTF material slot -> the external toon .tres in <boss>/materials,
clips at 30 fps, idle / mc_idle looped (same settings as smiles/src/write_imports.py). Keeps any existing uid.
Run after `make_<boss>.gd -- materials`, then `godot --headless --path . --import`."""
import os
import sys

# same import settings as smiles/src/write_imports.py
LOOPS = ["idle", "mc_idle"]
CLIPS = ["idle", "taunt", "grudging", "cheat", "deal", "mc_idle", "mc_cheer"]

PARAMS = """nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=0
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=false
animation/import_rest_as_RESET=true
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
"""

boss, slots = sys.argv[1], sys.argv[2:]
R = "res://art/models/characters/bosses/%s/" % boss
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", boss))
for lod in ("", "_mobile"):
    mats = ['"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}'
            % (s, R + "materials/%s.tres" % s, R + "materials/%s.tres" % s) for s in slots]
    anims = ['"%s": {\n"save_to_file/enabled": false,\n"settings/loop_mode": %d\n}' % (c, 1 if c in LOOPS else 0) for c in CLIPS]
    text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="%s%s%s.glb"\n\n[params]\n\n' % (R, boss, lod)) \
        + PARAMS + '_subresources={\n"animations": {\n' + ",\n".join(anims) + '\n},\n"materials": {\n' + ",\n".join(mats) \
        + '\n}\n}\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n'
    path = os.path.join(ROOT, "%s%s.glb.import" % (boss, lod))
    old = open(path).read() if os.path.exists(path) else ""
    if "uid=" in old:
        text = old.split("[deps]")[0] + text[text.index("[deps]"):]
    open(path, "w").write(text)
    print("wrote", os.path.basename(path))
