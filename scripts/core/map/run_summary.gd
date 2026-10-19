## Run end screens (QA full-run pass 1, M3): the real reason the run ended
## (MapRun.end_reason) and a short summary: floor reached, tables cleared,
## Embers earned, the final bag and the seed.
class_name RunSummary
extends RefCounted

const TITLES := {&"won": "Run Won", &"soul": "Your Soul Burns Out", &"boss": "The Dealer Wins",
	&"contract": "The Contract Is Torn"}


## The end screen's title for MapRun.end_reason.
static func title(run: MapRun) -> String:
	return TITLES.get(run.end_reason, "Run Over")


## One line saying why the run ended.
static func reason_line(run: MapRun) -> String:
	var floor_name := run.floor_data().display_name
	match run.end_reason:
		&"won":
			return "The contract is whole: %d/%d pieces." % [run.progress.contract_pieces, run.data.contract_pieces_to_win]
		&"soul":
			return "Your Soul ran out on %s." % floor_name
		&"boss":
			return "%s beat you twice on %s: no re-sits left (Soul %d/%d)." % [run.boss_name(), floor_name,
				run.progress.soul, run.progress.max_soul]
		&"contract":
			return "The last boss fell, but the contract has only %d/%d pieces." % [run.progress.contract_pieces, run.data.contract_pieces_to_win]
	return "The run is over on %s." % floor_name


## Summary lines: floor reached, tables cleared, Embers earned, final bag, seed.
static func lines(run: MapRun) -> Array[String]:
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
