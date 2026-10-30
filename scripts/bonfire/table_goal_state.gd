## STUB until Systems Dev's PR1 TableGoalState lands (then DELETE this file).
## Same fields and signals as the agreed API (Oct 30); watch(run) re-reads the
## run on table_event. debuff: null or {icon_id, text}; bounties [{icon_id, text}].
class_name TableGoalState
extends RefCounted

signal target_changed
signal banked_changed
signal hands_left_changed
signal seals_changed
signal debuff_changed
signal changed

var target: int = 300  # F1 table until PR1's per-floor targets
var banked: int = 0
var hands_left: int = 0
var is_boss: bool = false
var seals: int = 0
var debuff = null
var bounties: Array = []

var _run: BonfireRunState


## A goal state that follows `run` (table_event fires after every hand).
static func watch(run: BonfireRunState) -> TableGoalState:
	var g := TableGoalState.new()
	g._run = run
	if run != null:
		run.table_event.connect(func(_e: StringName, _d: Dictionary) -> void: g._sync())
	g._sync()
	return g


func _sync() -> void:
	if _run != null:
		stub_set({"banked": _run.points, "hands_left": _run.hands_left})


## STUB ONLY (shots, tests): sets each changed field, emits its signal, then `changed`.
func stub_set(values: Dictionary) -> void:
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
