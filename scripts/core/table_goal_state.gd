## Read-only view of a table's goal for the Target HUD plate (Godot Dev's;
## table_goals_v1 PR1). Built by watch(run); it follows the BonfireRun's
## own signals, so the run needs no hooks for it.
##
##   var gs := TableGoalState.watch(run)            # or watch(map_run), or both
##   gs.set_for_test(300, 120, 3)                   # tests only
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


## The one entry point, for both callers. Each argument is a BonfireRun or
## a MapRun, in either order (duck-typed by class; anything else is an
## error). Pass what you have:
##   watch(run)            a table scene: target/banked/hands from the run, seals 0
##   watch(map_run)        the map: target/is_boss from map_run.goal, seals,
##                         banked 0 and hands = goal.hands until a run sits down
##   watch(run, map_run)   both (the run wins for the table numbers)
## It follows run.hand_finished, run.table_event and map_run.screen_changed.
static func watch(source: Object, other: Object = null) -> TableGoalState:
	var s := TableGoalState.new()
	for o in [source, other]:
		if o is BonfireRun:
			s.run = o
		elif o is MapRun:
			s.map_run = o
		else:
			assert(o == null, "TableGoalState.watch: expected a BonfireRun or a MapRun")
	assert(s.run != null or s.map_run != null, "TableGoalState.watch: nothing to watch")
	s._read(false)
	if s.run != null:
		s.run.hand_finished.connect(func(_res: Dictionary) -> void: s.refresh())
		s.run.table_event.connect(func(_e: StringName, _d: Dictionary) -> void: s.refresh())
	if s.map_run != null:
		s.map_run.screen_changed.connect(func(_sc: int) -> void: s.refresh())
	return s


## Test-only seam: set the fields directly and emit the signals for what
## changed (then `changed` once), as refresh() would. For HUD tests that
## need a plate state without playing a table. Detaches nothing; a later
## refresh() of a watched state re-reads its sources.
func set_for_test(p_target: int, p_banked: int, p_hands_left: int, p_debuff: Variant = null,
		p_seals: int = 0, p_is_boss: bool = false) -> void:
	_is_boss = p_is_boss
	_apply(p_target, p_banked, p_hands_left, p_seals, p_debuff, true)


## Re-read the sources; emits the signals for what changed.
func refresh() -> void:
	_read(true)


func _read(emit: bool) -> void:
	var g: TableGoal = run.goal if run != null else (map_run.goal if map_run != null else null)
	_is_boss = g != null and g.is_boss
	var t := g.target if g != null else 0
	var b := run.points if run != null else 0
	var h := run.hands_left if run != null else (g.hands if g != null else 0)
	var n := map_run.owned_seals().size() if map_run != null else 0
	_apply(t, b, h, n, _debuff, emit)


func _apply(t: int, b: int, h: int, n: int, d: Variant, emit: bool) -> void:
	var any := false
	if t != _target:
		_target = t
		any = true
		if emit:
			target_changed.emit(t)
	if b != _banked:
		_banked = b
		any = true
		if emit:
			banked_changed.emit(b)
	if h != _hands_left:
		_hands_left = h
		any = true
		if emit:
			hands_left_changed.emit(h)
	if n != _seals:
		_seals = n
		any = true
		if emit:
			seals_changed.emit(n)
	if d != _debuff:
		_debuff = d
		any = true
		if emit:
			debuff_changed.emit(d)
	if any and emit:
		changed.emit()
