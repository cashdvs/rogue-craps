## ColdRuleText: the short note shown when a table rule keeps a face dark
## (P1 from the 0.1.6 playtest: under Cold Sixes the player expected 6s to
## score). Works for every rule whose can_light() says no: Cold Sixes,
## Mister Wick, The Pit Boss and Madame Shuffle's stopgap.
##   ColdRuleText.note("Cold Sixes", 6) -> "Cold Sixes: 6s can't score."
class_name ColdRuleText
extends RefCounted

## id -> text ({rule} = the rule's name, {face} = the dark number).
const TEXT: Dictionary[String, String] = {
	"cold_face_note": "{rule}: {face}s can't score.",
}


## The text for [param id] ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")


## The filled note, e.g. "Cold Sixes: 6s can't score.".
static func note(rule_name: String, face: int) -> String:
	return get_text("cold_face_note").format({"rule": rule_name, "face": face})


## True when no table rule keeps a die showing [param value] from lighting.
## This is TableRule.can_light (Cold Sixes, the Pit Boss lock, and every
## other rule that overrides it). The dead-face look uses the same answer
## as scoring, so the two cannot disagree.
static func can_score(run: BonfireRun, value: int) -> bool:
	return blocker(run, value) == null


## The first table rule that keeps a die showing [param value] dark, or
## null when no rule does (then the die is just an ordinary cold die).
static func blocker(run: BonfireRun, value: int) -> TableRule:
	if run == null:
		return null
	for r: TableRule in run.rules:
		if not r.can_light(run, value):
			return r
	return null


## The note for the first die in [param values] a rule keeps dark ("" when
## none is): shown on the why line after a throw settles.
static func note_for(run: BonfireRun, values: Array) -> String:
	for v in values:
		var r := blocker(run, int(v))
		if r != null:
			return note(r.display_name, int(v))
	return ""
