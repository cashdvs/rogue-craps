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
	_run.max_dice = maxi(_run.max_dice, 7)  # room for _rich()'s sixth die plus one given die (bag cap is 6 in the economy pass)
	for id in FLOORS:
		_events[id] = load("res://resources/events/%s.tres" % id) as EventData
	_test_load()
	_test_resolve()
	_test_picks()
	_test_numbers()
	test_shill_hand()
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
	p.add_die(DiceIds.DIE_BONE)
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
	# The Lantern shape ships disabled, so its choice is hidden; resolve it enabled.
	var lantern: DieShape = _run.shapes.filter(func(s: DieShape) -> bool: return s.id == DiceIds.DIE_LANTERN)[0]
	_check(not lantern.enabled and EventApplier.is_hidden(_events[&"gravedigger"].choices[1], _rich()), "hidden: the Lantern choice is hidden while the Lantern is disabled")
	lantern.enabled = true
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
	(_run.shapes.filter(func(s: DieShape) -> bool: return s.id == DiceIds.DIE_LANTERN)[0] as DieShape).enabled = true
	var p := _rich()
	EventApplier.apply(_events[&"gravedigger"].choices[1], p, RandomNumberGenerator.new())
	_check(p.dice.back().shape == DiceIds.DIE_LANTERN and p.dice.back().faces.size() == 8, "dice: Gravedigger gives a Lantern d8")
	p = _rich()
	EventApplier.apply(_events[&"fence"].choices[1], p, RandomNumberGenerator.new())
	_check(p.dice.back().special_id == DiceIds.DIE_CRACKED, "dice: the Fence sells a Cracked Die")
	p = _rich()
	EventApplier.apply(_events[&"back_room"].choices[0], p, RandomNumberGenerator.new())
	_check(p.dice.back().special_id == DiceIds.DIE_COVEN and p.embers == 30, "dice: the Back Room sells a Coven Die for 20")
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
	broke.change_embers(13)
	_check(not EventPicker.worth_offering(_events[&"fence"], broke, true), "skip: with 13 Embers the Fence (14) is still skipped")
	broke.change_embers(1)
	_check(EventPicker.worth_offering(_events[&"fence"], broke, true), "skip: with 14 Embers the Fence is offered")
	var full := RunProgress.new(_run)
	while full.can_add_die():
		full.add_die(DiceIds.DIE_BONE)
	_check(not EventPicker.worth_offering(_events[&"gravedigger"], full, true), "skip: the Gravedigger is skipped with a full bag")


## id -> per choice [Embers, Soul, max Soul, dice, free rerolls, {seal: levels}]
## deltas from _rich() (a sold die is the plain Bone, worth 0), so changing
## any number in the data (e.g. the Fence's +6 to 0) fails here.
const NUMBERS := {
	&"toll_keeper": [[-12, 4, 4, 0, 0, {}], [12, 0, -5, 0, 0, {}]],
	&"fence": [[6, 0, 0, -1, 0, {}], [-14, 0, 0, 1, 0, {}]],
	&"gravedigger": [[0, -9, 0, 1, 0, {}], [-10, 0, 0, 1, 0, {}]],
	&"shill": [[0, 6, 0, 0, 0, {}], [0, 0, 0, 0, 0, {&"run4": 1}]],
	&"tout": [[-6, 0, 0, 0, 3, {}], [0, -4, 0, 0, 3, {}]],
	&"bone_setter": [[0, 3, 3, -1, 0, {}], [0, 0, -8, 1, 0, {}]],
	&"back_room": [[-20, 0, 0, 1, 0, {}], [0, -8, 0, 0, 0, {&"trips": 1, &"full_house": 1}]],
}


func _test_numbers() -> void:
	for id in NUMBERS:
		for i in 2:
			var p := _rich()
			p.change_soul(-10)  # room below max, so heals aren't capped
			var before := [p.embers, p.soul, p.max_soul, p.dice.size(), p.free_rerolls]
			var c: EventChoiceData = _events[id].choices[i]
			var picks: Array[Vector2i] = []
			for fx in c.effects:
				if fx.needs_pick():
					picks.append(Vector2i(5, 0))
			EventApplier.apply(c, p, RandomNumberGenerator.new(), picks)
			var want: Array = NUMBERS[id][i]
			var got := [p.embers - before[0], p.soul - before[1], p.max_soul - before[2], p.dice.size() - before[3], p.free_rerolls - before[4]]
			var seals := true
			for sid in want[5]:
				seals = seals and p.seal_level(sid) == want[5][sid]
			_check(got == want.slice(0, 5) and seals, "numbers: %s/%s deltas %s (want %s)" % [id, "ab"[i], got, want])
	var cut := EventApplier.tips(_events[&"toll_keeper"].choices[1])
	var twist := EventApplier.tips(_events[&"shill"].choices[0])
	_check(cut == (["A lower max Soul also lowers your Soul to match."] as Array[String])
		and twist == (["An event twist applies to your next Table, not Elites or Bosses.", "An unplayed event twist ends when you leave the floor."] as Array[String])
		and EventApplier.tips(_events[&"fence"].choices[1]).is_empty(), "tips: the three §10 tooltips on max-Soul cuts and twists")


## The Shill's "+1 hand": cold_sixes / greedy_pot carry hands_delta = 1, so
## the next regular Table gets one extra hand.
func test_shill_hand() -> void:
	var shill: EventData = _events[&"shill"]
	for i in 2:
		var rule: RunRuleData = shill.choices[i].effects.back().rule
		_check(rule.hands_delta == 1, "shill: %s has hands_delta = 1" % rule.id)
		var run := MapRun.new(_run, 12)
		run.progress.change_embers(50)
		EventApplier.apply(shill.choices[i], run.progress, RandomNumberGenerator.new())
		var table: MapNode = null
		for n: MapNode in run.map.nodes.values():
			if n.type == MapGenData.NodeType.TABLE and table == null:
				table = n
		run.map.current_id = table.prev[0] if not table.prev.is_empty() else -1
		run.choose_node(table.id)
		_check(run.rules.has(rule) and run.goal.hands == run.floor_data().hands + 1,
			"shill: choice %s gives the next Table +1 hand (%d)" % ["ab"[i], run.goal.hands])
