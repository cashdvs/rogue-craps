#!/usr/bin/env bash
# Full Ashmouth rebuild (run from the repo root), same order as pit_boss/src/rebuild_pit_boss.sh:
# Blender model + rig + clips -> toon materials -> .glb imports -> scenes. SKIP_BLENDER=1 keeps the current .glb.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/ashmouth/src
T=art/models/characters/bosses/tools
if [ -z "$SKIP_BLENDER" ]; then
  "$BLENDER" -b --factory-startup --python $P/build_ashmouth.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
  rm -rf art/models/characters/smiles/src/__pycache__
fi
"$GODOT" --headless --path . --script res://$P/make_ashmouth.gd -- materials
python3 $T/write_boss_imports.py ashmouth ash_iron ash_iron_dark ash_skin ash_sleeve ash_brass ash_soot ash_coal ash_eye ash_tash
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_ashmouth.gd -- scenes
