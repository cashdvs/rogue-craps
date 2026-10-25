#!/usr/bin/env bash
# Full Shuffle rebuild (run from the repo root), same order as pit_boss/src/rebuild_pit_boss.sh:
# Blender model + rig + clips -> toon materials -> .glb imports -> scenes. SKIP_BLENDER=1 keeps the current .glb.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/shuffle/src
T=art/models/characters/bosses/tools
if [ -z "$SKIP_BLENDER" ]; then
  "$BLENDER" -b --factory-startup --python $P/build_shuffle.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
  rm -rf art/models/characters/smiles/src/__pycache__
fi
"$GODOT" --headless --path . --script res://$P/make_shuffle.gd -- materials
python3 $T/write_boss_imports.py shuffle shuffle_skin shuffle_gown shuffle_glove shuffle_hair shuffle_trim shuffle_eye shuffle_lip shuffle_card shuffle_cardback
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_shuffle.gd -- scenes
