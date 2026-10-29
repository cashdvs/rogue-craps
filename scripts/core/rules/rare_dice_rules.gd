## Rare dice v2 PR 2: one per owned rare's table_special. barrel: pot_factor at
## bank; fortune: Jackpot's +1 Ember (x2 is its MULT_FACTOR); usurer: +1 Soul a
## bust. on_land (land_throw's one call): Fuse/Hex on landed faces, not nudges.
class_name RareDiceRules
extends TableRule

const BOOM_CHANCE := 2.0 / 3.0

var pot_factor: float = 1.0


## A Soul cost (Bloodletter doubles) that never takes the last Soul; returns it.
static func soft_soul_loss(run: BonfireRun, amount: int, kind: StringName) -> int:
	var taken := clampi(run.soul_cost(amount, kind), 0, maxi(run.soul - 1, 0))
	run.soul -= taken
	return taken


static func barrel_rule(run: BonfireRun) -> RareDiceRules:
	for r in run.rules:
		if r is RareDiceRules and r.id == &"barrel":
			return r
	return null


static func mod_id(m: Variant) -> StringName:
	return (m as FaceModData).id if m is FaceModData else &""


static func on_land(run: BonfireRun, th: TableThrow) -> void:
	for i in th.size():
		var id := mod_id(th.mods[i] if i < th.mods.size() else null)
		if id == &"hex":
			run.table_event.emit(&"hex", {"index": i, "soul_lost": soft_soul_loss(run, 1, &"hex")})
		elif id == &"fuse":
			run.table_event.emit(&"fuse_lit", {"index": i})
			var boom := th.rng.randf() < BOOM_CHANCE
			var f := 2.0 if boom else 0.5
			var barrel := barrel_rule(run)
			if barrel != null:
				barrel.pot_factor *= f
			if boom:
				run.embers += 1
				run.table_event.emit(&"barrel_boom", {"index": i, "factor": f, "embers": 1, "nerve": 1})
			else:
				run.table_event.emit(&"barrel_misfire", {"index": i, "factor": f, "soul_lost": soft_soul_loss(run, 1, &"misfire")})


func on_hand_start(_run: BonfireRun) -> void:
	pot_factor = 1.0


func on_bank(run: BonfireRun, result: Dictionary) -> void:
	if id == &"barrel" and pot_factor != 1.0:
		var extra := int(floor(run.pot * pot_factor)) - run.pot
		run.points += extra
		result["gain"] = int(result["gain"]) + extra


func on_bust(run: BonfireRun, result: Dictionary) -> void:
	if id == &"usurer" and run.soul > 0:
		var lost := soft_soul_loss(run, 1, &"usurer")
		result["soul_lost"] = int(result["soul_lost"]) + lost
		run.table_event.emit(&"usurer_toll", {"soul_lost": lost})


## Jackpot faces among [param faces] (none under The Collector's no-mods).
static func jackpots(run: BonfireRun, faces: Array) -> int:
	if run.rule_ctx().get("no_mods", false):
		return 0
	return faces.filter(func(d: Variant) -> bool: return d is Dictionary and mod_id(d.get("mod")) == &"jackpot").size()


func modify_score(run: BonfireRun, result: Dictionary) -> void:
	if id == &"fortune":
		result["embers"] = int(result["embers"]) + jackpots(run, run.selection_faces())


func on_pot(run: BonfireRun, info: Dictionary) -> void:
	var n := jackpots(run, run.selection_faces(info["indices"])) if id == &"fortune" else 0
	if n > 0:
		run.table_event.emit(&"jackpot", {"combo": StringName(info["result"]["combo"]), "embers": n})
