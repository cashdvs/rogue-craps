## Gap ledger for Smiles measurement. Every cell here is unverified acceptance.
##
## Synthetic box checks live in test_dealer_rail_oracle.gd and are not these
## cells. A partial idle t=0 note is printed and still fails: one frame is
## not a clip. Missing V188/V194 meshes fail. They are not passes and not
## stand-ins. This file does not load those assets.
##
##   godot --headless --path . --script res://tests/test_smiles_measure_gaps.gd
extends SceneTree

const CLIPS: Array[String] = ["idle", "deal", "taunt", "grudging", "cheat", "mc_idle", "mc_cheer"]
const LODS: Array[String] = ["pc", "mobile"]
const CONTEXTS: Array[String] = ["shipped_greybox", "documented_hearth_fixture", "future_hearth_at_play_seat", "documented_mc_beside_boss"]
const ASSETS: Array[String] = ["this_tree_smiles_not_v194", "v188", "v194"]

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL ", msg)


func _run() -> void:
	print("=== Smiles measure gaps (not acceptance) ===")
	print("frozen V194 %s absent on this remote" % DealerContext.FROZEN_V194)
	print("frozen V188 %s absent on this remote" % DealerContext.FROZEN_V188_CHECKPOINT)
	for asset in ASSETS:
		for lod in LODS:
			for ctx in CONTEXTS:
				for clip in CLIPS:
					var note := _partial(asset, lod, ctx, clip)
					# Partial observations stay failures. Unavailable meshes stay failures.
					_check(false, "%s | %s | %s | %s | %s" % [asset, lod, ctx, clip, note])
	for row in ["open_head_reverse_containment", "mc_collision_all_clips", "transitions_blends_resets_autoplay", "finger_support", "native_character_framing", "vulkan_skin_equivalence"]:
		_check(false, "UNVERIFIED %s" % row)
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


## What this tree has actually skinned. Still not a full-cell pass.
func _partial(asset: String, lod: String, ctx: String, clip: String) -> String:
	if asset != "this_tree_smiles_not_v194" or lod != "pc" or clip != "idle":
		if asset == "v188" or asset == "v194":
			return "UNAVAILABLE_MESH"
		return "UNVERIFIED"
	if ctx == "documented_hearth_fixture":
		return "PARTIAL head t=0 rail-containment clear only; not the clip; reverse containment unverified"
	if ctx == "future_hearth_at_play_seat":
		return "PARTIAL head t=0 rail-containment clear and body hit; not the clip; not live Hearth; reverse containment unverified"
	return "UNVERIFIED"
