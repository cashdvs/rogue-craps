## One table rule: an Elite twist, a boss cheat, or a special die's ability.
## Subclass and override only the hooks you need; BonfireRun calls them (and
## emits the same moments on BonfireRun.table_event, which is where juice
## and audio subscribe). Hooks get the run as an argument (rules don't keep
## a reference, so there's no cycle). Numbers come from `params`.
class_name TableRule
extends RefCounted

enum Kind { TWIST, CHEAT, DIE }

var id: StringName = &""
var display_name: String = ""
## One line for the HUD (info_line() may add live state).
var description: String = ""
var kind: Kind = Kind.TWIST
var params: Dictionary = {}


func param(key: String, default: Variant) -> Variant:
	return params.get(key, default)


## HUD line: "Name: description" by default.
func info_line(_run: BonfireRun) -> String:
	return description


## Text shown on the felt this hand ("" = nothing), e.g. the Pit Boss lock.
func felt_text(_run: BonfireRun) -> String:
	return ""


# --- Moments (also BonfireRun.table_event) ------------------------------------
func on_table_start(_run: BonfireRun) -> void:
	pass


func on_hand_start(_run: BonfireRun) -> void:
	pass


## The throw has settled; change faces here (before lighting).
func on_throw_landed(_run: BonfireRun, _th: TableThrow) -> void:
	pass


## A pot was committed (rethrow or bank). info: {indices, result, ...}.
func on_pot(_run: BonfireRun, _info: Dictionary) -> void:
	pass


func on_bank(_run: BonfireRun, _result: Dictionary) -> void:
	pass


func on_bust(_run: BonfireRun, _result: Dictionary) -> void:
	pass


# --- Queries ----------------------------------------------------------------------
## Can a die showing `value` light (and score)?
func can_light(_run: BonfireRun, _value: int) -> bool:
	return true


## Do face mods work right now?
func mods_active(_run: BonfireRun) -> bool:
	return true


## Combo ids that don't count at this table.
func excluded_combos(_run: BonfireRun) -> Array:
	return []


## Fewest dice a pot may have (0 = no limit).
func min_pot(_run: BonfireRun) -> int:
	return 0


## Do pots right now count toward bounties?
func bounties_count(_run: BonfireRun) -> bool:
	return true


func hot_hand_allowed(_run: BonfireRun) -> bool:
	return true


## Mult each Hot Hand adds (chainable: gets the value so far).
func hot_hand_mult_bonus(_run: BonfireRun, bonus: int) -> int:
	return bonus


## Last word on a pot's score (result from BonfireScoring.score_selection).
func modify_score(_run: BonfireRun, _result: Dictionary) -> void:
	pass


## Soul a cost really takes (chainable). kind: &"bust", &"timeout", &"blood".
func soul_cost(_run: BonfireRun, amount: int, _kind: StringName) -> int:
	return amount
