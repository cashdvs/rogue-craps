"""Writes the Godot .import files for the Bonfire prop glbs: every material slot maps to
materials/<slot>.tres (external), no LODs, no animation import. Run from the repo root."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.normpath(os.path.join(HERE, ".."))
RES = "res://art/models/props/bonfire/"
SLOTS = {
    "wax_stamp": ["wax", "wax_letter"], "wax_stamp_shards": ["wax", "wax_letter"],
    "soul_flask": ["soul_glass", "soul_liquid", "cork", "brass"], "ember_pile": ["coal", "ember_hot"],
    "mult_chip": ["mult_body", "mult_inlay"],
}
for name, slots in SLOTS.items():
    mats = ",\n".join('"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%smaterials/%s.tres",\n'
                      '"use_external/path": "%smaterials/%s.tres"\n}' % (s, RES, s, RES, s) for s in slots)
    body = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="{res}{n}.glb"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={{
"materials": {{
{mats}
}}
}}
gltf/naming_version=2
gltf/embedded_image_handling=1
""".format(res=RES, n=name, mats=mats)
    with open(os.path.join(KIT, name + ".glb.import"), "w") as f:
        f.write(body)
    print("wrote", name + ".glb.import")
