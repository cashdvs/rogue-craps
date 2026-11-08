## Coverage ledger after the frozen-stream measurement. Not acceptance.
##
## Measured cells are native opaque Head/Visor positions from the QA bundle,
## tested with closed-rail ray parity and bidirectional triangle crossing.
## A 1 µm unresolved sample counts as bad. A zero is no detection, not clearance.
## These numbers do not waive legacy envelopes, dressing, or framing.
## Body/Chip, open-head reverse containment, yaw-90 MC, blends, and Vulkan
## re-bakes stay failures.
##
##   godot --headless --path . --script res://tests/test_smiles_measure_gaps.gd
extends SceneTree

const SUMMARY := "res://tests/data/frozen_head_rail_summary.json"
## opaque bad frames / 715. Both seats, both boards, both mesh LODs.
## Indeterminate frames are included in bad. Only these two rollups have any.
const EXPECTED_INDET := {
	"baseline|pc|fixture|hearth": 1,
	"v188|pc|production|hearth": 2,
}
const EXPECTED := {
	"baseline|mobile|fixture|greybox": 0,
	"baseline|mobile|fixture|hearth": 0,
	"baseline|mobile|production|greybox": 0,
	"baseline|mobile|production|hearth": 0,
	"baseline|pc|fixture|greybox": 0,
	"baseline|pc|fixture|hearth": 1,
	"baseline|pc|production|greybox": 0,
	"baseline|pc|production|hearth": 0,
	"v188|mobile|fixture|greybox": 715,
	"v188|mobile|fixture|hearth": 715,
	"v188|mobile|production|greybox": 14,
	"v188|mobile|production|hearth": 0,
	"v188|pc|fixture|greybox": 715,
	"v188|pc|fixture|hearth": 715,
	"v188|pc|production|greybox": 14,
	"v188|pc|production|hearth": 12,
	"v194|mobile|fixture|greybox": 715,
	"v194|mobile|fixture|hearth": 715,
	"v194|mobile|production|greybox": 0,
	"v194|mobile|production|hearth": 0,
	"v194|pc|fixture|greybox": 715,
	"v194|pc|fixture|hearth": 715,
	"v194|pc|production|greybox": 0,
	"v194|pc|production|hearth": 0,
}

var _pass := 0
var _fail := 0


func _ints(raw: Variant) -> Array:
	var out: Array = []
	for item in raw:
		out.append(int(item))
	return out


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL ", msg)


func _run() -> void:
	print("=== Smiles measured coverage vs remaining gaps (not acceptance) ===")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SUMMARY))
	_check(parsed is Dictionary, "summary json loads")
	if not parsed is Dictionary:
		print("=== %d passed, %d failed ===" % [_pass, _fail])
		quit(1)
		return
	var doc: Dictionary = parsed
	_check(String(doc["v194_commit"]) == DealerContext.FROZEN_V194, "summary is bound to frozen V194, not a later snapshot")
	_check(String(doc["v188_checkpoint"]) == DealerContext.FROZEN_V188_CHECKPOINT and doc["v188_is_active_runtime"] == false, "V188 is the inactive checkpoint, not active-runtime V147")
	_check(int(doc["custody"]["archive_sha256_mismatches"]) == 0 and int(doc["custody"]["extracted_sha256sums"].split("/")[0]) == 203, "custody: 13 archives and 203/203 extracted checksums")
	var totals: Dictionary = doc["opaque_totals"]
	_check(totals.size() == EXPECTED.size(), "24 asset/lod/seat/board totals present, got %d" % totals.size())
	for key in EXPECTED:
		var row: Dictionary = totals.get(key, {})
		var bad := int(row.get("bad", -1))
		var frames := int(row.get("frames", -1))
		var want_indet := int(EXPECTED_INDET.get(key, 0))
		print("MEASURED %s opaque_bad %d / %d indet %d (no detection is not clearance)" % [key, bad, frames, int(row.get("indet", -1))])
		_check(bad == int(EXPECTED[key]) and frames == 715 and int(row.get("indet", -1)) == want_indet, "%s bad %d frames %d" % [key, bad, frames])
	var wit: Dictionary = doc["witnesses"]
	_check(_ints(wit["v188_pc_production_greybox_taunt_bad_frames"]) == [30], "V188 production greybox taunt bad frame is 30 (t=0.500s)")
	_check(_ints(wit["v188_pc_production_greybox_mc_cheer_bad_frames"]) == [11, 12, 13, 14, 15, 33, 34, 35, 36, 37, 38, 39, 40], "V188 production greybox mc_cheer bad frames match 11-15 and 33-40")
	_check(_ints(wit["baseline_pc_fixture_hearth_idle_indeterminate_frames"]) == [49], "baseline PC fixture Hearth idle frame 49 is the unresolved sample")
	_check(_ints(wit["v188_pc_production_hearth_mc_cheer_indeterminate_frames"]) == [15, 33], "V188 production Hearth mc_cheer frames 15 and 33 are unresolved")
	_check(int(totals["v188|pc|fixture|hearth"].get("glow_bad", -1)) == 653, "V188 PC fixture Hearth glow bad is 653 after two unresolved frames")
	# Still unverified. Availability of the other bytes is not coverage.
	for row in ["open_head_reverse_containment", "body_chip_native", "mc_yaw90_seat", "transitions_blends_resets_autoplay", "finger_support_policy", "native_character_framing", "continuous_motion", "legacy_gate_replacement"]:
		_check(false, "UNVERIFIED %s" % row)
	_check(false, "HOLD these head counts are not acceptance, merge, or a waiver of legacy envelopes, dressing, or framing")
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
