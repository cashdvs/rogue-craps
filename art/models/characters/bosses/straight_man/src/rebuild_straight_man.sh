#!/usr/bin/env bash
# Full StraightMan rebuild (run from the repo root), same order as pit_boss/src/rebuild_pit_boss.sh:
# Blender model + rig + clips -> toon materials -> .glb imports -> scenes. SKIP_BLENDER=1 keeps the current .glb.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/straight_man/src
T=art/models/characters/bosses/tools
if [ -z "$SKIP_BLENDER" ]; then
  "$BLENDER" -b --factory-startup --python $P/build_straight_man.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
  rm -rf art/models/characters/smiles/src/__pycache__
fi
"$GODOT" --headless --path . --script res://$P/make_straight_man.gd -- materials
python3 $T/write_boss_imports.py straight_man sm_skin sm_suit sm_chalk sm_shirt sm_brass sm_bone sm_black sm_hair sm_eye sm_rod
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_straight_man.gd -- scenes
