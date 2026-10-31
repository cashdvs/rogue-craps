## Loads tests/fixtures/bounty_table_1.tres (the bounty table the bounty
## suites play on) and stops the suite at once when it can't, with a clear
## message, instead of letting it hang waiting on a table that never forms.
##   sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
extends RefCounted

const PATH := "res://tests/fixtures/bounty_table_1.tres"


## The fixture goal, or null after printing why and asking `tree` to quit
## (exit code 2). Callers return straight away on null.
static func goal(tree: SceneTree, path: String = PATH) -> TableGoal:
	var g: TableGoal = null
	if ResourceLoader.exists(path):
		g = load(path) as TableGoal
	if g == null or g.required.is_empty():
		push_error("BOUNTY FIXTURE MISSING: %s did not load as a TableGoal with bounties. Restore it (PR #227) and rerun; stopping this suite." % path)
		print("FAIL  bounty fixture %s did not load; suite stopped" % path)
		tree.quit(2)
		return null
	return g
