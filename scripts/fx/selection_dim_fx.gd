## Selection dim (Julian playtest bug): once dice are selected for a combo,
## lit dice that can NOT join that combo drop back to the plain (unlit) look,
## so only the dice you can still add keep their ember glow. Unselecting, or
## any change that makes them joinable again, relights them.
##
## Feel layer only: it never decides what can join. It asks the run:
##   run.can_join(i) -> bool          (Godot Dev's flag, preferred), else
##   BonfireScoring.can_extend(potted + [i], ...)  (the same pure query
##   BonfireRun.toggle already uses; read-only).
## and listens to table.events.selection_changed(potted_ids, joinable_ids)
## when that signal exists. Until then it watches run.potted each frame.
##
## Art rules: glow never fire; no tint on the die body (it only toggles the
## die's existing lit/plain material state, never cold grey, which means
## "didn't score"); no particles; reads at 48 px (glow vs no glow).
class_name SelectionDimFx
extends Node

var table: Node
## Dice currently dimmed by this listener (DieVisual -> true).
var _dimmed: Dictionary = {}
var _key: String = ""


func _ready() -> void:
	table = get_parent()
	var ev: Object = table.get("events") if table != null else null
	if ev != null and ev.has_signal(&"selection_changed"):
		ev.connect(&"selection_changed", func(_p: Array, _j: Array) -> void: refresh())
	if ev != null and ev.has_signal(&"table_cleared"):
		ev.connect(&"table_cleared", clear)


func _process(_dt: float) -> void:
	var run: Object = _run()
	if run == null:
		return
	var k := "%d|%s|%s" % [int(run.get("state")), str(run.get("potted")), str(run.get("throw_faces"))]
	if k != _key:
		_key = k
		refresh()


func _run() -> Object:
	if table == null or not ("run" in table):
		return null
	return table.get("run")


## True if die index i (not potted) can still join the current selection.
static func joinable(run: Object, i: int) -> bool:
	if run.has_method(&"can_join"):
		return bool(run.call(&"can_join", i))
	var potted: Array = run.get("potted")
	if potted.is_empty():
		return true
	var next: Array = potted.duplicate()
	next.append(i)
	return BonfireScoring.can_extend(next, run.call(&"throw_dice"), run.get("tuning"), run.call(&"rule_ctx"))


## Indices of lit, unpotted dice that should be dimmed now.
func dim_indices() -> Array[int]:
	var out: Array[int] = []
	var run: Object = _run()
	if run == null or int(run.get("state")) != BonfireRun.State.PICK:
		return out
	var potted: Array = run.get("potted")
	if potted.is_empty():
		return out
	var dice: Array = table.get("throw_dice")
	for i in dice.size():
		if potted.has(i) or not table.call(&"is_lit", dice[i]):
			continue
		if not joinable(run, i):
			out.append(i)
	return out


## Re-evaluates every die: dims the unjoinable lit ones, relights the rest.
func refresh() -> void:
	var run: Object = _run()
	if run == null:
		return
	var want: Dictionary = {}
	var dice: Array = table.get("throw_dice")
	for i in dim_indices():
		want[dice[i]] = true
	for d in _dimmed.keys():
		if not want.has(d):
			_restore(d)
	for d in want:
		if not _dimmed.has(d):
			(d as DieVisual).set_glow_state(false, false)
			_dimmed[d] = true


func _restore(d: Variant) -> void:
	_dimmed.erase(d)
	if is_instance_valid(d) and table.call(&"is_lit", d):
		(d as DieVisual).set_glow_state(true, false)


## Drops every dim (table cleared / new throw).
func clear() -> void:
	for d in _dimmed.keys():
		_restore(d)
	_key = ""


func is_dimmed(d: DieVisual) -> bool:
	return _dimmed.has(d)
