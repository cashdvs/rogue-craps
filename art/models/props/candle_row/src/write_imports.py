"""Writes the .glb.import files for the candle row: every glTF slot maps to an external .tres.
Run after make_candle_row.gd -- materials, then `godot --headless --path . --import`."""
import os
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
P = "res://art/models/props/candle_row/"
H = "res://art/models/boards/hearth/materials/"
SLOTS = {"candle_wax": P + "materials/candle_row_wax.tres", "wick": H + "dressing_ink.tres",
         "holder_iron": H + "dressing_iron.tres", "socket_brass": H + "dressing_brass.tres", "ring_brass": "res://art/models/boards/infernal_pit/materials/brass.tres"}
PARTS = {"candle_row_candle": ["candle_wax", "wick"], "candle_row_holder": ["holder_iron"],
         "candle_row_socket": ["socket_brass"], "candle_row_ring": ["ring_brass"]}
# same import params as the Hearth props
src = open(os.path.join(ROOT, "../../boards/hearth/src/write_imports.py")).read()
PARAMS = src.split('PARAMS = """', 1)[1].split('"""', 1)[0]
for name, slots in PARTS.items():
    mats = ['"%s": {\n"use_external/enabled": true,\n"use_external/fallback_path": "%s",\n"use_external/path": "%s"\n}' % (s, SLOTS[s], SLOTS[s]) for s in slots]
    text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n\n[deps]\n\nsource_file="%s%s.glb"\n\n[params]\n\n' % (P, name)) + PARAMS \
        + '_subresources={\n"materials": {\n' + ",\n".join(mats) + '\n}\n}\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n'
    path = os.path.join(ROOT, name + ".glb.import")
    old = open(path).read() if os.path.exists(path) else ""
    if "uid=" in old:
        text = old.split("[deps]")[0] + text[text.index("[deps]"):]
    open(path, "w").write(text)
    print("wrote", os.path.basename(path))
