"""Writes the .glb.import files for the Hearth props: every glTF material slot maps to an external
.tres (art/models/boards/hearth/materials, or Board A's brass / plate face). Run after
make_hearth.gd materials, then `godot --headless --path . --import`."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
H = "res://art/models/boards/hearth/"
A = "res://art/models/boards/infernal_pit/materials/"
SLOTS = {"hearth_iron": H + "materials/hearth_iron.tres", "brass": A + "brass.tres", "plate_face": A + "plate_face.tres",
         "hearth_coals": H + "materials/hearth_coals.tres", "demon_iron": H + "materials/demon_iron.tres",
         "demon_eye": H + "materials/demon_eye.tres", "candle_wax": H + "materials/candle_wax.tres"}
PARTS = {"brazier": ["hearth_iron", "brass", "hearth_coals", "plate_face"], "demon_face": ["demon_iron", "demon_eye"],
         "cauldron": ["hearth_iron", "brass"], "cauldron_fill": ["hearth_coals"], "candle": ["candle_wax", "brass", "hearth_iron"]}
OVERRIDE = {"cauldron_fill": {"hearth_coals": H + "materials/cauldron_coals.tres"}}

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
"""

for part, slots in PARTS.items():
    for lod in ("", "_mobile"):
        name = part + lod
        if part == "candle" and lod and "hearth_iron" in slots:
            pass
        mats = []
        for s in slots:
            p = OVERRIDE.get(part, {}).get(s, SLOTS[s])
            mats.append('"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}' % (s, p, p))
        text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="%s%s.glb"\n\n[params]\n\n'
                % (H, name)) + PARAMS + '_subresources={\n"materials": {\n' + ",\n".join(mats) + '\n}\n}\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n'
        path = os.path.join(ROOT, name + ".glb.import")
        old = open(path).read() if os.path.exists(path) else ""
        # keep the uid / remap path Godot assigned on a previous import
        if "uid=" in old:
            head = old.split("[deps]")[0]
            text = head + text[text.index("[deps]"):]
        open(path, "w").write(text)
        print("wrote", os.path.basename(path))

# Textures: the shaders sample with filter_linear_mipmap, so generate mipmaps, and keep them lossless
# (detect_3d/compress_to=0, so the editor never switches them to VRAM compression and blurs the flame atlas).
TEX_SET = {"compress/mode": "0", "mipmaps/generate": "true", "detect_3d/compress_to": "0"}
TEX = os.path.join(ROOT, "textures")
for f in sorted(os.listdir(TEX)):
    if not f.endswith(".png.import"):
        continue
    path = os.path.join(TEX, f)
    lines = open(path).read().split("\n")
    for i, line in enumerate(lines):
        key = line.split("=", 1)[0]
        if key in TEX_SET:
            lines[i] = key + "=" + TEX_SET[key]
    open(path, "w").write("\n".join(lines))
    print("wrote", f)
