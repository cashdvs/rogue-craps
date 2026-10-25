#!/usr/bin/env bash
# Full Pit Boss rebuild (run from the repo root): Blender model + rig + clips -> toon materials -> .glb imports -> scenes.
set -e
GODOT="${GODOT:-godot}"
BLENDER="${BLENDER:-blender}"
P=art/models/characters/bosses/pit_boss/src
T=art/models/characters/bosses/tools
"$BLENDER" -b --factory-startup --python $P/build_pit_boss.py 2>&1 | grep -E "TRIS|WROTE|Error|Traceback" || true
rm -rf art/models/characters/smiles/src/__pycache__
"$GODOT" --headless --path . --script res://$P/make_pit_boss.gd -- materials
python3 $T/write_boss_imports.py pit_boss pitboss_skin pitboss_shirt pitboss_vest pitboss_black pitboss_brass pitboss_bone pitboss_cap pitboss_eye pitboss_cigar pitboss_ash
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://$P/make_pit_boss.gd -- scenes
