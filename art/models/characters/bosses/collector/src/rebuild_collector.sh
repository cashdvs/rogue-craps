#!/usr/bin/env bash
# Full Collector rebuild (run from the repo root), same order as pit_boss/src/rebuild_pit_boss.sh:
# Blender model + rig + clips -> toon materials -> .glb imports -> scenes. SKIP_BLENDER=1 keeps the current .glb.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/collector/src
T=art/models/characters/bosses/tools
if [ -z "$SKIP_BLENDER" ]; then
  "$BLENDER" -b --factory-startup --python $P/build_collector.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
  rm -rf art/models/characters/smiles/src/__pycache__
fi
"$GODOT" --headless --path . --script res://$P/make_collector.gd -- materials
python3 $T/write_boss_imports.py collector col_fur col_fur_dark col_coat col_scarf col_brass col_bone col_glass col_eye col_black
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_collector.gd -- scenes
