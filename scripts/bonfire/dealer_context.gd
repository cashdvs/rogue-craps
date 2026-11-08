## Named dealer contexts. This does not spawn Hearth and does not retire a test.
##
## Shipped play is the greybox table at the lifted seat. The Hearth scene at
## y = -0.47 is the capture fixture already in the repo. Putting that same
## Hearth mesh at the play seat is a future integration candidate: no gameplay
## script instances it. The MC seat is the documented alternate beside a boss.
## "Not called today" is not permission to delete it.
class_name DealerContext
extends RefCounted

## Documented MC anchor (Smiles README). Yaw is degrees about Y.
const MC_LOCAL := Vector3(-1.32, -0.42, -0.30)
const MC_YAW_DEG := 90.0
## Frozen art this contract must not impersonate. Absent on this remote.
const FROZEN_V194 := "61619e93b127ad64a6762fad777471d5831e7458"
const FROZEN_V188_CHECKPOINT := "c1c260c7f6b9c0344300af9c32b4deeb39859bc6"


## One row per context. `live` is true only for what Bonfire instances today.
static func contexts() -> Array:
	return [
		{"id": "shipped_greybox", "live": true,
			"actor_local": DealerPlacement.production_origin(), "yaw_deg": 0.0,
			"lift_count": 1, "board": "Table3DBuilder greybox",
			"note": "Authoring target. Parent is the table. Identity parent => world."},
		{"id": "documented_hearth_fixture", "live": false,
			"actor_local": DealerPlacement.DOCUMENTED_FIXTURE, "yaw_deg": 0.0,
			"lift_count": 0, "board": "hearth_board, identity",
			"note": "Real capture seat, not a coordinate bug. Unwaived. Not live Hearth."},
		{"id": "future_hearth_at_play_seat", "live": false,
			"actor_local": DealerPlacement.production_origin(), "yaw_deg": 0.0,
			"lift_count": 1, "board": "hearth_board, identity",
			"note": "Integration candidate only. Not a shipped Hearth composition."},
		{"id": "documented_mc_beside_boss", "live": false,
			"actor_local": MC_LOCAL, "yaw_deg": MC_YAW_DEG,
			"lift_count": 0, "board": "left rail, boss in the dealer seat",
			"note": "Retained. Not evaluated by the far-rail head matrix."},
	]


## Legacy property -> proposed successor. Nothing here is accepted.
static func successor_map() -> Array:
	return [
		{"property": "hand_skin_clearance_ge_0",
			"legacy": "tests/test_dealer_hands.gd worst_clear >= 0.0 and model rail 0.61",
			"status": "legacy_unchanged",
			"successor": "Not the physical rail. Do not adopt #259's -0.005."},
		{"property": "limb_envelope_014_dealer_and_mc",
			"legacy": "tests/test_smiles.gd DEALER_POS -0.47, MC yaw 90, RAIL_TOP 0.14, FELT 0.03",
			"status": "legacy_unchanged",
			"successor": "Must keep behind-edge / above-rail / above-felt. Not one nearest vertex."},
		{"property": "hearth_6cm_cell_pad_4mm",
			"legacy": "tests/test_hearth_dealer_clear.gd 6 cm cells, PAD 0.004, all seven clips",
			"status": "legacy_unchanged",
			"successor": "Padded occupancy is not triangle penetration. Do not delete cell failures."},
		{"property": "bell_85_and_nonoverlap",
			"legacy": "same file, MIN_VISIBLE 0.85, bell vs brazier/plaque",
			"status": "legacy_unchanged",
			"successor": "Needs the final native camera, physical and logical viewport, HUD stage."},
		{"property": "native_camera_framing",
			"legacy": "historical phone d=2.04 pivot z=0.34 in test_smiles; startup fit is separate",
			"status": "legacy_unchanged",
			"successor": "test_dealer_production_seat locks startup fit. Not a crop waiver."},
		{"property": "full_skin_vs_closed_rail",
			"legacy": "no legacy finite-solid oracle",
			"status": "proposed_not_accepted",
			"successor": "DealerRailOracle. Additive. 60 Hz samples are not continuous proof."},
		{"property": "finger_skin_contact_band",
			"legacy": "none accepted",
			"status": "proposed_not_accepted",
			"successor": "0-5 mm contact is a new policy. Not a collision or >= 0 waiver."},
	]


## Actor world pose from its real parent. One lift is already inside actor_local
## for the shipped seat; do not add GREYBOX_RAIL_LIFT again.
static func actor_world(parent: Transform3D, actor_local: Vector3, yaw_deg: float) -> Transform3D:
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), actor_local)
	return parent * local


## "ok" only for the shipped seat: parent-local position is the play origin
## and the lift was applied once. -.47 labeled as production fails. A second
## +0.12 fails. This does not move the actor.
static func production_frame_ok(actor_local: Vector3, lift_count: int) -> String:
	if lift_count != 1:
		return "lift_count"
	if not actor_local.is_equal_approx(DealerPlacement.production_origin()):
		return "not_production_seat"
	return "ok"
