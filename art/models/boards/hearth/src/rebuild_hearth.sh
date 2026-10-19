#!/usr/bin/env bash
# Full Hearth rebuild (run from the repo root): Blender props + set dressing -> textures imported ->
# materials -> .glb imports -> prop scenes (+ worn studs) -> board scenes. Textures:
# python3 art/models/boards/hearth/src/make_flame_atlas.py, make_felt_motif.py (felt + worn felt) and
# make_rail_carve.py (all deterministic, outputs committed).
set -e
GODOT="${GODOT:-godot}"        # Godot 4.x on PATH, or set GODOT=/path/to/godot
BLENDER="${BLENDER:-blender}"  # Blender 4.5 LTS on PATH, or set BLENDER=/path/to/blender
S=art/models/boards/hearth/src
"$BLENDER" -b --factory-startup --python $S/build_hearth.py 2>&1 | grep -E "TRIS|NUMBER_ANCHOR|EYE|Error" || true
"$BLENDER" -b --factory-startup --python $S/build_dressing.py 2>&1 | grep -E "TRIS_TOTAL|PIVOTS|Error" || true
python3 $S/write_imports.py >/dev/null
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- materials
python3 $S/write_imports.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- props
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- board
