#!/usr/bin/env bash
# Full Smiles rebuild (run from the repo root): Blender model + rig + clips -> materials -> .glb imports -> wrapper scenes.
set -e
GODOT="${GODOT:-godot}"        # Godot 4.x on PATH, or set GODOT=/path/to/godot
BLENDER="${BLENDER:-blender}"  # Blender 4.5 LTS on PATH, or set BLENDER=/path/to/blender
S=art/models/characters/smiles/src
"$BLENDER" -b --factory-startup --python $S/build_smiles.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
"$GODOT" --headless --path . --script res://$S/make_smiles.gd -- materials
python3 $S/write_imports.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$S/make_smiles.gd -- scenes
