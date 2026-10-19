#!/usr/bin/env bash
# Full Hearth rebuild (run from the repo root): Blender props -> materials -> .glb imports ->
# prop scenes -> board scenes. Textures: python3 art/models/boards/hearth/src/make_flame_atlas.py,
# python3 art/models/boards/hearth/src/make_felt_motif.py (both deterministic, outputs committed).
set -e
GODOT="${GODOT:-/home/box/tools/godot/godot}"
BLENDER="${BLENDER:-/home/box/tools/blender/blender-4.5.14-linux-x64/blender}"
S=art/models/boards/hearth/src
"$BLENDER" -b --factory-startup --python $S/build_hearth.py 2>&1 | grep -E "TRIS|NUMBER_ANCHOR|EYE|Error" || true
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- materials
python3 $S/write_imports.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- props
"$GODOT" --headless --path . --script res://$S/make_hearth.gd -- board
