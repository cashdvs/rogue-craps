#!/usr/bin/env bash
# Full Bloodletter rebuild (run from the repo root), same order as pit_boss/src/rebuild_pit_boss.sh:
# Blender model + rig + clips -> toon materials -> .glb imports -> scenes. SKIP_BLENDER=1 keeps the current .glb.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/bloodletter/src
T=art/models/characters/bosses/tools
if [ -z "$SKIP_BLENDER" ]; then
  "$BLENDER" -b --factory-startup --python $P/build_bloodletter.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
  rm -rf art/models/characters/smiles/src/__pycache__
fi
"$GODOT" --headless --path . --script res://$P/make_bloodletter.gd -- materials
python3 $T/write_boss_imports.py bloodletter bl_skin bl_coat bl_apron bl_collar bl_brass bl_bone bl_hair bl_eye bl_glass bl_silver bl_pewter
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_bloodletter.gd -- scenes
