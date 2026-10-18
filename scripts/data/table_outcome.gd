## What a Bonfire table hands back to the run (Bonfire3D.finished).
class_name TableOutcome
extends RefCounted

var cleared: bool = false
var forfeited: bool = false
## Soul change at this table (negative = lost) and Soul after it.
var soul_delta: int = 0
var soul_after: int = 0
## Every Ember the table paid: points / points_per_ember + clear + bonus bounties.
var embers: int = 0
var points: int = 0
## Ids of the bounties banked (required and bonus).
var bounties_claimed: Array[StringName] = []
var hands_used: int = 0


static func from_run(r: BonfireRun, soul_before: int) -> TableOutcome:
	var o := TableOutcome.new()
	o.cleared = r.state == BonfireRun.State.CLEARED
	o.forfeited = r.forfeited
	o.soul_after = r.soul
	o.soul_delta = r.soul - soul_before
	o.embers = r.embers
	o.points = r.points
	o.bounties_claimed = r.claimed_bounties()
	o.hands_used = r.goal.hands - r.hands_left
	return o
