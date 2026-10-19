## Event-system rules (Game Designer, Oct 19): EventData.floors limits where
## an event appears; an event where only Leave is enabled is skipped (another
## event, else the node opens as a Rest), seeded; a next-table twist is
## greyed out when no regular Table is left on the floor.
##   godot --headless --path . --script res://tests/test_event_rules.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType
const K := EventEffectData.Kind

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _altar: EventData
var _demo: EventData


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_altar = load("res://resources/events/altar.tres") as EventData
	_demo = load("res://tests/support/event_effects_demo.tres") as EventData
	_test_floors()
	_test_only_leave()
	_test_fallback()
	_test_table_ahead()
	_test_twist_greyed()
	test_hidden()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	_altar = null
	_demo = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## A plain event: one Soul-gain choice (or `fx`) plus Leave, on `floors`.
func _event(id: StringName, floors: Array[int] = [], fx: Array[EventEffectData] = []) -> EventData:
	var e := EventData.new()
	e.id = id
	e.floors = floors
	var take := EventChoiceData.new()
	if fx.is_empty():
		var heal := EventEffectData.new()
		heal.kind = K.EMBERS
		heal.amount = 3
		fx = [heal]
	take.effects = fx
	e.choices = [take, EventChoiceData.new()] as Array[EventChoiceData]
	return e


func _fx(kind: int, amount: int = 0) -> EventEffectData:
	var f := EventEffectData.new()
	f.kind = kind
	f.amount = amount
	return f


func _test_floors() -> void:
	_check(EventData.new().floors.is_empty(), "floors: defaults to empty (every floor)")
	var any := _event(&"any")
	var late := _event(&"late", [2, 3] as Array[int])
	_check(EventPicker.on_floor(any, 1) and EventPicker.on_floor(any, 3), "floors: empty = every floor")
	_check(not EventPicker.on_floor(late, 1) and EventPicker.on_floor(late, 2) and EventPicker.on_floor(late, 3), "floors: [2, 3] skips Floor 1")
	var pool: Array[EventData] = [any, late]
	var p := RunProgress.new(_run)
	var ok := true
	for s in 40:
		var seen: Array[StringName] = []
		ok = ok and EventPicker.pick(pool, seen, 1, p, true, _rng(s)) == any
	_check(ok, "floors: Floor 1 never draws a [2, 3] event (40 seeds)")
	var only_late: Array[EventData] = [late]
	var seen2: Array[StringName] = []
	_check(EventPicker.pick(only_late, seen2, 1, p, true, _rng(1)) == null, "floors: nothing tagged for this floor = no event")
	var data := _run.duplicate() as RunData
	data.events = [any, late] as Array[EventData]
	var run := MapRun.new(data, 3)
	run.floor_index = 1
	var drew := {}
	for s in 30:
		run.run_seed = s
		run._events_seen.clear()
		drew[run._pick_event().id] = true
	_check(drew.has(&"late") and drew.has(&"any"), "floors: MapRun on Floor 2 draws both (floor_index is 0-based)")
	var tres := _altar.duplicate() as EventData
	tres.floors = [2] as Array[int]
	_check(tres.floors == ([2] as Array[int]), "floors: Array[int] field round-trips on a real event")


func _test_only_leave() -> void:
	var p := RunProgress.new(_run)
	_check(not p.has_face_mod() and not EventPicker.worth_offering(_altar, p, true), "leave-only: Altar with no face mod isn't offered")
	p.set_face(0, 0, &"wild")
	_check(EventPicker.worth_offering(_altar, p, true), "leave-only: Altar is offered once you own a mod")
	var gd := _event(&"gravedigger", [], [_fx(K.SOUL, -9), _fx(K.GIVE_DIE)] as Array[EventEffectData])
	var full := RunProgress.new(_run)
	while full.can_add_die():
		full.add_die(DiceIds.DIE_BONE)
	_check(not EventPicker.worth_offering(gd, full, true), "leave-only: Gravedigger with a full bag isn't offered")
	_check(EventPicker.worth_offering(gd, RunProgress.new(_run), true), "leave-only: Gravedigger with room is offered")
	_check(EventPicker.is_leave(_altar.choices[2]) and not EventPicker.is_leave(_altar.choices[0]), "leave-only: Leave = the choice with no effects")
	var other := _event(&"other")
	var pool: Array[EventData] = [_altar, other]
	var bare := RunProgress.new(_run)
	var ok := true
	var same := true
	for s in 40:
		var seen: Array[StringName] = []
		var a := EventPicker.pick(pool, seen, 1, bare, true, _rng(s))
		var seen_b: Array[StringName] = []
		ok = ok and a == other
		same = same and a == EventPicker.pick(pool, seen_b, 1, bare, true, _rng(s))
	_check(ok, "leave-only: the picker falls back to a different event (40 seeds)")
	_check(same, "leave-only: the fallback is the same for the same seed")
	var seen3: Array[StringName] = [&"other"]
	_check(EventPicker.pick(pool, seen3, 1, bare, true, _rng(5)) == other and seen3 == ([&"other"] as Array[StringName]),
		"leave-only: a seen event beats a Leave-only one (the seen list restarts)")


## Teleport next to the first node of `type` and travel onto it.
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_fallback() -> void:
	var data := _run.duplicate() as RunData
	data.events = [_altar] as Array[EventData]
	var run := MapRun.new(data, 11)
	var ok := _enter(run, NT.EVENT)
	_check(ok and run.screen == S.REST and run.event == null and run.map.current().type == NT.REST,
		"fallback: no event worth offering = the node opens as a Rest")
	var run2 := MapRun.new(data, 11)
	run2.progress.set_face(0, 0, &"wild")
	_check(_enter(run2, NT.EVENT) and run2.screen == S.EVENT and run2.event == _altar, "fallback: the same node opens the Altar once you own a mod")
	var a := MapRun.new(_run, 21)
	var b := MapRun.new(_run, 21)
	_enter(a, NT.EVENT)
	_enter(b, NT.EVENT)
	_check(a.screen == b.screen and a.event == b.event, "fallback: same seed, same result")


## A hand-built map: start -> mid -> boss, all on one column.
func _line(mid_type: int) -> RunMap:
	var m := RunMap.new()
	m.rows = 2
	m.columns = 1
	var types := [NT.EVENT, mid_type]
	for r in 2:
		var n := MapNode.new(r, r, 0)
		n.type = types[r]
		m.nodes[r] = n
	var boss := MapNode.new(2, 2, 0)
	boss.type = NT.BOSS
	m.nodes[2] = boss
	m.boss_id = 2
	m.nodes[0].next = [1] as Array[int]
	m.nodes[1].next = [2] as Array[int]
	m.current_id = 0
	return m


func _test_table_ahead() -> void:
	_check(EventPicker.table_ahead(_line(NT.TABLE)), "table ahead: a Table after the event counts")
	_check(not EventPicker.table_ahead(_line(NT.ELITE)), "table ahead: an Elite isn't a regular Table")
	_check(not EventPicker.table_ahead(_line(NT.REST)), "table ahead: only a Rest and the Boss left = none")
	var m := _line(NT.TABLE)
	m.current_id = 1
	_check(not EventPicker.table_ahead(m), "table ahead: the Table you stand on is played")
	var run := MapRun.new(_run, 4)
	_check(run.table_ahead(), "table ahead: a fresh floor has Tables ahead")


func _test_twist_greyed() -> void:
	var twist: EventChoiceData = _demo.choices[7]
	var p := RunProgress.new(_run)
	_check(EventApplier.why_not(twist, p, false) == "No table left on this floor.", "twist: greyed with the reason line")
	_check(EventApplier.can_choose(twist, p, true), "twist: allowed while a Table is ahead")
	var lines := EventApplier.apply(twist, p, _rng(1), [], false)
	_check(lines == (["refused: No table left on this floor."] as Array[String]) and p.next_table_twist == null, "twist: apply refuses it too")
	var run := MapRun.new(_run, 9)
	run.map = _line(NT.REST)
	run.screen = S.EVENT
	run.event = _demo
	_check(run.choose_event(7)[0].begins_with("refused") and run.screen == S.EVENT, "twist: MapRun refuses it with no Table left")
	var tw_only := _event(&"shill", [], [_fx(K.NEXT_TABLE_TWIST)] as Array[EventEffectData])
	tw_only.choices[0].effects[0].rule = load("res://resources/map/rules/cold_sixes.tres")
	_check(not EventPicker.worth_offering(tw_only, p, false), "twist: a twist-only event isn't offered with no Table left")
	var view := EventView.new()
	view._ready()
	view.show_event(_demo, p, false)
	var found := false
	for c in view._box.get_children():
		if c is Button and c.text == twist.label:
			found = c.disabled and c.tooltip_text == "No table left on this floor."
	_check(found, "twist: the event screen greys the button with the reason")
	view.free()


func _buttons(view: EventView) -> Array[String]:
	var out: Array[String] = []
	for c in view._box.get_children():
		if c is Button:
			out.append(c.text)
	return out


## Game Designer: a GIVE_DIE of a shape with enabled = false is hidden, no
## substitute; the Leave-only skip still applies.
func test_hidden() -> void:
	var gd := load("res://resources/events/gravedigger.tres") as EventData
	var lantern := _run.shapes.filter(func(s: DieShape) -> bool: return s.id == &"lantern")[0] as DieShape
	var was := lantern.enabled
	lantern.enabled = false
	var p := RunProgress.new(_run)
	_check(EventApplier.is_hidden(gd.choices[1], p) and not EventApplier.is_hidden(gd.choices[0], p) and not EventApplier.is_hidden(gd.choices[2], p),
		"hidden: only the Lantern choice is hidden")
	_check(EventApplier.apply(gd.choices[1], p, _rng(1))[0].begins_with("refused") and p.dice.size() == 5, "hidden: it can't be taken and no die is substituted")
	var view := EventView.new()
	view._ready()
	view.show_event(gd, p)
	var labels := _buttons(view)
	_check(labels == ([gd.choices[0].label, gd.choices[2].label] as Array[String]), "hidden: the Gravedigger shows Bone and Leave only (%s)" % [labels])
	view.free()
	_check(EventPicker.worth_offering(gd, p, true), "hidden: the Bone option keeps the Gravedigger offered")
	var full := RunProgress.new(_run)
	while full.can_add_die():
		full.add_die(DiceIds.DIE_BONE)
	_check(not EventPicker.worth_offering(gd, full, true), "hidden: with a full bag, only Leave is left, so it's skipped")
	var lone := EventData.new()
	lone.id = &"lone"
	lone.choices = [gd.choices[1], gd.choices[2]] as Array[EventChoiceData]
	_check(not EventPicker.worth_offering(lone, p, true), "hidden: an event whose only other choice is hidden is skipped")
	lantern.enabled = true
	p.change_embers(20)
	_check(not EventApplier.is_hidden(gd.choices[1], p) and EventPicker.worth_offering(lone, p, true), "hidden: enabling the Lantern shows it again")
	lantern.enabled = was
