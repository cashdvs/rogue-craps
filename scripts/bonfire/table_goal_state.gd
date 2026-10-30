## STUB of #213's TableGoalState (same watch/fields/signals/set_for_test API);
## DELETE when #213 lands. Bounties: [] in PR1; tests fill `_bounties`.
class_name TableGoalState
extends RefCounted

signal target_changed(value: int)
signal banked_changed(value: int)
signal hands_left_changed(value: int)
signal seals_changed(value: int)
signal debuff_changed(value: Variant)
signal changed

var target: int = 300  # F1 table until PR1's per-floor targets
var banked: int = 0
var hands_left: int = 0
var is_boss: bool = false
var seals: int = 0
var debuff: Variant = null
var bounties: Array:
	get: return _bounties.duplicate()
var run: BonfireRun
var _bounties: Array = []

## Follows a BonfireRun (either argument; a MapRun is ignored by the stub).
static func watch(source: Object, other: Object = null) -> TableGoalState:
	var s := TableGoalState.new()
	s.run = source as BonfireRun if source is BonfireRun else other as BonfireRun
	if s.run != null:
		s.run.table_event.connect(func(_e: StringName, _d: Dictionary) -> void: s.refresh())
	s.refresh()
	return s


## Re-reads the run; emits the signals for what changed.
func refresh() -> void:
	if run != null:
		_apply({"banked": run.points, "hands_left": run.hands_left})


## Test-only seam (#213): sets the fields, emits what changed, then `changed`.
func set_for_test(p_target: int, p_banked: int, p_hands_left: int, p_debuff: Variant = null,
		p_seals: int = 0, p_is_boss: bool = false) -> void:
	is_boss = p_is_boss
	_apply({"target": p_target, "banked": p_banked, "hands_left": p_hands_left, "seals": p_seals, "debuff": p_debuff}, true)


func _apply(values: Dictionary, force: bool = false) -> void:
	var any := force
	for key: String in values:
		if get(key) == values[key]:
			continue
		set(key, values[key])
		any = true
		emit_signal(key + "_changed", values[key])
	if any:
		changed.emit()
