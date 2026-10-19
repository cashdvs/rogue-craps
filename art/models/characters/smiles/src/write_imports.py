"""Writes smiles.glb.import / smiles_mobile.glb.import: every glTF material slot -> an external .tres in
../materials (toon_noir + ink hull), animations imported at 30 fps, idle / mc_idle looped.
Run after `make_smiles.gd -- materials`, then `godot --headless --path . --import`."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
R = "res://art/models/characters/smiles/"
SLOTS = ["smiles_skin", "smiles_horn", "smiles_shirt", "smiles_vest", "smiles_black", "smiles_gold",
         "smiles_visor", "smiles_eye", "smiles_mouth", "smiles_chip", "smiles_chip_edge"]
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

for lod in ("", "_mobile"):
    mats = []
    for s in SLOTS:
        p = R + "materials/%s.tres" % s
        mats.append('"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}' % (s, p, p))
    anims = ['"%s": {\n"save_to_file/enabled": false,\n"settings/loop_mode": %d\n}' % (c, 1 if c in LOOPS else 0) for c in CLIPS]
    text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="%ssmiles%s.glb"\n\n[params]\n\n' % (R, lod)) \
        + PARAMS + '_subresources={\n"animations": {\n' + ",\n".join(anims) + '\n},\n"materials": {\n' + ",\n".join(mats) \
        + '\n}\n}\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n'
    path = os.path.join(ROOT, "smiles%s.glb.import" % lod)
    old = open(path).read() if os.path.exists(path) else ""
    if "uid=" in old:  # keep the uid Godot assigned on a previous import
        text = old.split("[deps]")[0] + text[text.index("[deps]"):]
    open(path, "w").write(text)
    print("wrote", os.path.basename(path))
