## Run end screens (QA full-run pass 1, M3): the real reason the run ended
## (MapRun.end_reason) and a short summary: floor reached, tables cleared,
## Embers earned, the final bag and the seed.
class_name RunSummary
extends RefCounted

## strings_v1 run_screen rows (boss lost title, run over title); other
## reasons use "Run Over".
const TITLES := {&"won": "Run Won", &"complete": TEXT["run_complete_title"], &"soul": "Out of Soul", &"boss": "The House Wins"}


## The end screen's title for MapRun.end_reason.
static func title(run: MapRun) -> String:
	return TITLES.get(run.end_reason, "Run Over")


## One line saying why the run ended.
static func reason_line(run: MapRun) -> String:
	var floor_name := run.floor_data().display_name
	match run.end_reason:
		&"won":
			return "The contract is whole, and you win the run."
		&"complete":
			return text("run_complete_reason", {"boss": run.boss_name()})
		&"soul":
			return "Your run ends on %s." % floor_name
		&"boss":
			return "You lost to %s twice, so your run ends on %s." % [run.boss_name(), floor_name]
		&"contract":
			return "The last boss fell, but the contract has only %d/%d pieces." % [run.progress.contract_pieces, run.data.contract_pieces_to_win]
	return "Your run ends on %s." % floor_name


## Summary lines: floor reached, tables cleared, Embers earned, final bag, seed.
static func lines(run: MapRun) -> Array[String]:
	if run.end_reason == &"complete":
		return complete_lines(run)
	var bag: Array[String] = []
	for i in run.progress.dice.size():
		bag.append(run.progress.die_name(i))
	return [
		"Floor reached: %d of %d (%s)" % [run.floor_index + 1, run.data.floors.size(), run.floor_data().display_name],
		"Tables cleared: %d" % run.tables_cleared,
		"Embers earned: %d" % run.progress.embers_earned,
		"Final bag: %s" % ", ".join(bag),
		"Seed: %d" % run.run_seed,
	]


## strings_v1 run_complete_* rows (one_floor_v1), keyed by id, copied verbatim
## from design/strings_v1.md with {placeholders}.
const TEXT: Dictionary[String, String] = {
	"run_complete_title": "RUN COMPLETE",
	"run_complete_reason": "You beat {boss}, and the run is yours.",
	"run_complete_points": "Points banked: {n}",
	"run_complete_embers": "Embers left: {n} x10 = +{pts}",
	"run_complete_total": "Final score: {n}",
	"run_complete_new": "New Run",
	"run_complete_menu": "Main Menu",
}
const RUN_COMPLETE_NEW: String = TEXT["run_complete_new"]
const RUN_COMPLETE_MENU: String = TEXT["run_complete_menu"]


## strings_v1 row [param id] with [param args] filled ("" if unknown).
static func text(id: String, args: Dictionary = {}) -> String:
	return TEXT.get(id, "").format(args)


## Score from Embers left: RunData.ember_score_mult x Embers.
static func ember_points(run: MapRun) -> int:
	return run.progress.embers * run.data.ember_score_mult


## RUN COMPLETE final score: points banked this run + ember_points.
static func final_score(run: MapRun) -> int:
	return run.run_points + ember_points(run)


## RUN COMPLETE rows: points, Embers x mult, final score, then the stats.
static func complete_lines(run: MapRun) -> Array[String]:
	var best := String(run.best_combo).capitalize() if run.best_combo != &"" else "None"
	return [
		text("run_complete_points", {"n": run.run_points}),
		text("run_complete_embers", {"n": run.progress.embers, "pts": ember_points(run)}).replace("x10", "x%d" % run.data.ember_score_mult),
		text("run_complete_total", {"n": final_score(run)}),
		"Tables cleared: %d" % run.tables_cleared,
		"Souls left: %d" % run.progress.soul,
		"Best hand: %s" % best,
		"Seed: %d" % run.run_seed,
	]
