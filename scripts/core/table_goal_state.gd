## Read-only view of a table's goal for the Target HUD plate (Godot Dev's;
## table_goals_v1 PR1). Built by watch(run); it follows the BonfireRun's
## own signals, so the run needs no hooks for it.
##
##   var gs := TableGoalState.watch(run, map_run)  # map_run optional (seals)
##   gs.changed.connect(_redraw)
##
## Fields (read-only; set only here):
##   target: int       points to bank to pass (goal.target)
##   banked: int       points banked so far (run.points; never the live pot)
##   hands_left: int   run.hands_left
##   is_boss: bool     constant for the table (goal.is_boss)
##   seals: int        owned Seals in the run (MapRun.owned_seals().size()), 0 without a map run
##   bounties: Array   always [] in PR1 (Run Bounties, PR2); entries {icon_id, text}
##   debuff            null in PR1 (PR3); a Dictionary {icon_id, text}
## Signals: target_changed, banked_changed, hands_left_changed,
## seals_changed, debuff_changed (each with the new value), then `changed`
## once after any of them.
class_name TableGoalState
extends RefCounted

signal target_changed(value: int)
signal banked_changed(value: int)
signal hands_left_changed(value: int)
signal seals_changed(value: int)
signal debuff_changed(value: Variant)
signal changed

var target: int:
	get: return _target
var banked: int:
	get: return _banked
var hands_left: int:
	get: return _hands_left
var is_boss: bool:
	get: return _is_boss
var seals: int:
	get: return _seals
var bounties: Array:
	get: return _bounties.duplicate()
var debuff: Variant:
	get: return _debuff

var run: BonfireRun
var map_run: MapRun
var _target := 0
var _banked := 0
var _hands_left := 0
var _is_boss := false
var _seals := 0
var _bounties: Array = []
var _debuff: Variant = null


## A state that follows `r` (and, for seals, `m`) from now on.
static func watch(r: BonfireRun, m: MapRun = null) -> TableGoalState:
	var s := TableGoalState.new()
	s.run = r
	s.map_run = m
	s._target = r.goal.target if r.goal != null else 0
	s._is_boss = r.goal != null and r.goal.is_boss
	s._banked = r.points
	s._hands_left = r.hands_left
	s._seals = m.owned_seals().size() if m != null else 0
	r.hand_finished.connect(func(_res: Dictionary) -> void: s.refresh())
	r.table_event.connect(func(_e: StringName, _d: Dictionary) -> void: s.refresh())
	if m != null:
		m.screen_changed.connect(func(_sc: int) -> void: s.refresh())
	return s


## Re-read the run; emits the signals for what changed.
func refresh() -> void:
	var any := false
	var t := run.goal.target if run.goal != null else 0
	if t != _target:
		_target = t
		target_changed.emit(t)
		any = true
	if run.points != _banked:
		_banked = run.points
		banked_changed.emit(_banked)
		any = true
	if run.hands_left != _hands_left:
		_hands_left = run.hands_left
		hands_left_changed.emit(_hands_left)
		any = true
	var n := map_run.owned_seals().size() if map_run != null else 0
	if n != _seals:
		_seals = n
		seals_changed.emit(n)
		any = true
	if any:
		changed.emit()
