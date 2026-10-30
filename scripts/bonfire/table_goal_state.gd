## STUB (Godot Dev, Target HUD v2.1). Systems Dev's PR1 ships the real
## TableGoalState; when it lands, DELETE this file and keep theirs. The HUD
## only uses the fields and signals below (the agreed API, Oct 30):
##   read-only: target, banked, hands_left, is_boss, seals,
##              debuff (null or {icon_id, text}), bounties [{icon_id, text}]
##   signals: target/banked/hands_left/seals/debuff_changed, then `changed` after any.
## Made with watch(run): re-reads the run on hand_finished / table_event. HUD works out to_go / passed.
class_name TableGoalState
extends RefCounted

signal target_changed
signal banked_changed
signal hands_left_changed
signal seals_changed
signal debuff_changed
signal changed

## Stub target until PR1's per-floor targets (F1 table = 300).
const STUB_TARGET: int = 300

var target: int = STUB_TARGET
var banked: int = 0
var hands_left: int = 0
var is_boss: bool = false
var seals: int = 0
var debuff = null
var bounties: Array = []

var _run: BonfireRunState


## A goal state that follows `run` (hand_finished and table_event).
static func watch(run: BonfireRunState) -> TableGoalState:
	var g := TableGoalState.new()
	g._run = run
	if run != null:
		run.hand_finished.connect(func(_r: Dictionary) -> void: g._sync())
		run.table_event.connect(func(_e: StringName, _d: Dictionary) -> void: g._sync())
	g._sync()
	return g


## STUB ONLY (shots, tests): sets fields by name, emitting the real signals.
func stub_set(values: Dictionary) -> void:
	_apply(values)


func _sync() -> void:
	if _run != null:
		_apply({"banked": _run.points, "hands_left": _run.hands_left})


# Sets each changed field, emits its signal, then `changed` once.
func _apply(values: Dictionary) -> void:
	var any := false
	for key: String in values:
		if get(key) == values[key]:
			continue
		set(key, values[key])
		any = true
		var sig := key + "_changed"
		if has_signal(sig):
			emit_signal(sig)
	if any:
		changed.emit()
