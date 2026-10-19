## Floor 2-3 events 11-17 (design/events_f23_data.md, PM-approved Oct 19):
## each loads, is in the run's event pool with its floors, has two choices
## plus Leave, and every choice resolves with the existing effect kinds.
##   godot --headless --path . --script res://tests/test_events_f23.gd
extends SceneTree

const K := EventEffectData.Kind
## id -> floors, per the data doc.
const FLOORS := {&"toll_keeper": [2, 3], &"gravedigger": [2], &"fence": [2, 3], &"shill": [2, 3],
	&"tout": [2, 3], &"bone_setter": [3], &"back_room": [3]}

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _events: Dictionary = {}


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	for id in FLOORS:
		_events[id] = load("res://resources/events/%s.tres" % id) as EventData
	_test_load()
	_test_resolve()
	_test_picks()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	_events.clear()
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## A well-off run: 50 Embers, 35 Soul, a sixth (Bone) die and a carved mod.
func _rich() -> RunProgress:
	var p := RunProgress.new(_run)
	p.change_embers(50 - p.embers)
	p.add_die(&"d6")
	p.set_face(0, 0, &"wild")
	return p


func _test_load() -> void:
	var ok := true
	var pooled := true
	for id in FLOORS:
		var e: EventData = _events[id]
		ok = ok and e != null and e.id == id and e.title != "" and e.body != "" and e.art_note != "" \
			and e.choices.size() == 3 and EventPicker.is_leave(e.choices[2]) and e.choices[2].label == "Leave." \
			and not EventPicker.is_leave(e.choices[0]) and not EventPicker.is_leave(e.choices[1])
		if e != null:
			_check(Array(e.floors) == FLOORS[id], "load: %s floors %s" % [id, FLOORS[id]])
		var found := false
		for r in _run.events:
			found = found or r.id == id
		pooled = pooled and found
	_check(ok, "load: all 7 load with title, body, art note, two choices and Leave")
	_check(pooled and _run.events.size() == 12, "load: all 7 are in the run's event pool (12 events)")
	var p := _rich()
	var f1 := true
	for s in 60:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var seen: Array[StringName] = []
		var e := EventPicker.pick(_run.events, seen, 1, p, true, r)
		f1 = f1 and e != null and not FLOORS.has(e.id)
	_check(f1, "load: Floor 1 never draws a Floor 2-3 event (60 seeds)")


func _test_resolve() -> void:
	for id in FLOORS:
		var e: EventData = _events[id]
		for i in 2:
			var c := e.choices[i]
			var known := true
			for fx in c.effects:
				known = known and fx.kind in K.values() and fx.kind != K.ADD_FACE_MOD and fx.kind != K.REMOVE_FACE_MOD
				if fx.kind == K.NEXT_TABLE_TWIST:
					known = known and fx.rule != null
			var p := _rich()
			var picks: Array[Vector2i] = []
			for fx in c.effects:
				if fx.needs_pick():
					picks.append(Vector2i(5, 0))
			var r := RandomNumberGenerator.new()
			r.seed = 7
			var lines := EventApplier.apply(c, p, r, picks)
			var good := lines.size() == c.effects.size()
			for l in lines:
				good = good and not l.begins_with("refused") and not l in ["bag full", "no die to sell", "no valid face"]
			_check(known and good, "resolve: %s/%s -> %s" % [id, "ab"[i], lines])
		var leave := EventApplier.apply(e.choices[2], _rich(), RandomNumberGenerator.new())
		_check(leave.is_empty(), "resolve: %s Leave changes nothing" % id)


func _test_picks() -> void:
	var p := _rich()
	EventApplier.apply(_events[&"gravedigger"].choices[1], p, RandomNumberGenerator.new())
	_check(p.dice.back().shape == &"lantern" and p.dice.back().faces.size() == 8, "dice: Gravedigger gives a Lantern d8")
	p = _rich()
	EventApplier.apply(_events[&"fence"].choices[1], p, RandomNumberGenerator.new())
	_check(p.dice.back().special_id == &"cracked", "dice: the Fence sells a Cracked Die")
	p = _rich()
	EventApplier.apply(_events[&"back_room"].choices[0], p, RandomNumberGenerator.new())
	_check(p.dice.back().special_id == &"coven" and p.embers == 30, "dice: the Back Room sells a Coven Die for 20")
	p = _rich()
	var max0 := p.max_soul
	EventApplier.apply(_events[&"toll_keeper"].choices[0], p, RandomNumberGenerator.new())
	_check(p.max_soul == max0 + 4 and p.embers == 38, "soul: the Toll Keeper's fare is +4 max Soul for 12 Embers")
	p = _rich()
	EventApplier.apply(_events[&"shill"].choices[1], p, RandomNumberGenerator.new())
	_check(p.seal_level(&"run4") == 1 and p.next_table_twist != null and p.next_table_twist.id == &"greedy_pot", "twist: the Shill banks Greedy Pot and a Run of 4 Seal")
	var broke := RunProgress.new(_run)
	broke.change_embers(-broke.embers)
	_check(not EventPicker.worth_offering(_events[&"fence"], broke, true), "skip: the Fence at 5 dice and 0 Embers is skipped (only Leave)")
	broke.change_embers(10)
	_check(EventPicker.worth_offering(_events[&"fence"], broke, true), "skip: with 10 Embers the Fence is offered")
	var full := RunProgress.new(_run)
	while full.can_add_die():
		full.add_die(&"d6")
	_check(not EventPicker.worth_offering(_events[&"gravedigger"], full, true), "skip: the Gravedigger is skipped with a full bag")
