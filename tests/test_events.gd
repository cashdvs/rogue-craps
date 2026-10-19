## Headless tests for events (events §2): the 5 shipped events load with
## text, art note and 3 choices; greyed-out rules; every effect kind applied
## by EventApplier (picked, random-other-on-same-die and random targets),
## seeded; and the Seal levels events grant.
##
## Run:
##   godot --headless --path . --script res://tests/test_events.gd
extends SceneTree

const IDS: Array[StringName] = [&"devils_deal", &"bone_carver", &"altar", &"ember_merchant", &"weeping_croupier"]

var _passed: int = 0
var _failed: int = 0
var _run: RunData
var _events: Dictionary = {}


func _initialize() -> void:
	print("=== Dice of the Damned: event tests ===")
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	for id in IDS:
		_events[id] = load("res://resources/events/%s.tres" % id) as EventData
	_test_content()
	_test_greying()
	_test_devil_and_carver()
	_test_altar_merchant_croupier()
	_test_progress()
	_test_duplicate_picks()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_events.clear()
	_run = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _p(embers: int = 0, soul: int = 35) -> RunProgress:
	var p := RunProgress.new(_run)
	p.embers = embers
	p.soul = soul
	return p


func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _ch(id: StringName, i: int) -> EventChoiceData:
	return (_events[id] as EventData).choices[i]


func _test_content() -> void:
	var ok: bool = true
	for id in IDS:
		var e: EventData = _events[id]
		ok = ok and e != null and e.title != "" and e.body.length() > 40 and e.art_note != "" and e.choices.size() == 3
	_check(ok, "content: 5 events, each with title, text, art note and 3 choices")
	_check(_run != null and _run.floors.size() == 3 and _run.events.size() >= 5 and IDS.all(func(id): return _run.events.any(func(e): return e.id == id)), "content: run data has 3 floors and the 5 Floor 1 events")


func _test_greying() -> void:
	_check(not EventApplier.can_choose(_ch(&"devils_deal", 0), _p(0, 8)), "grey: can't sign for 8 Soul at 8 Soul")
	_check(EventApplier.can_choose(_ch(&"devils_deal", 0), _p(0, 9)), "grey: can sign at 9 Soul")
	_check(not EventApplier.can_choose(_ch(&"devils_deal", 1), _p(14)) and EventApplier.can_choose(_ch(&"devils_deal", 1), _p(15)),
		"grey: Hellfire for coin needs 15 Embers")
	var p := _p(50, 30)
	_check(not EventApplier.can_choose(_ch(&"altar", 0), p) and not EventApplier.can_choose(_ch(&"altar", 1), p)
		and not EventApplier.can_choose(_ch(&"ember_merchant", 1), p), "grey: Altar / selling need a face mod")
	p.set_face(0, 0, &"blank")
	_check(not p.has_face_mod(), "grey: a Blank face isn't a carving you can give")
	p.set_face(1, 2, &"wild")
	_check(EventApplier.can_choose(_ch(&"altar", 0), p), "grey: owning a mod unlocks the Altar")
	_check(EventApplier.can_choose(_ch(&"devils_deal", 2), _p()), "grey: leaving is always allowed")


func _test_devil_and_carver() -> void:
	var p := _p(20)
	var c := _ch(&"devils_deal", 0)
	_check(EventApplier.picks_needed(c) == 1, "devil: one pick (die and face)")
	_check(EventApplier.apply(c, p, _rng(), [])[0].begins_with("refused") and p.soul == 35, "devil: no pick -> nothing happens")
	EventApplier.apply(c, p, _rng(), [Vector2i(2, 5)] as Array[Vector2i])
	_check(p.soul == 27 and p.dice[2].faces[5] == &"hellfire", "devil: sign in blood -> -8 Soul, Hellfire on the picked face")
	EventApplier.apply(_ch(&"devils_deal", 1), p, _rng(), [Vector2i(0, 0)] as Array[Vector2i])
	_check(p.embers == 5 and p.dice[0].faces[0] == &"hellfire", "devil: pay in coin -> -15 Embers, Hellfire")
	_check(EventApplier.apply(_ch(&"devils_deal", 1), p, _rng(), [Vector2i(1, 0)] as Array[Vector2i])[0].begins_with("refused"),
		"devil: can't pay twice with 5 Embers")
	_check(not EventApplier.pick_ok(c.effects[1], p, Vector2i(2, 5)), "pick: can't carve over a mod")
	var q := _p(10)
	EventApplier.apply(_ch(&"bone_carver", 0), q, _rng(), [Vector2i(4, 3)] as Array[Vector2i])
	_check(q.embers == 4 and q.dice[4].faces[3] == &"wild", "carver: Wild Face for 6 Embers")
	EventApplier.apply(_ch(&"bone_carver", 1), q, _rng(7), [Vector2i(1, 1)] as Array[Vector2i])
	var blanks: int = q.dice[1].faces.count(&"blank")
	_check(q.dice[1].faces[1] == &"twin" and blanks == 1 and q.dice[1].faces[1] != &"blank" and q.embers == 4,
		"carver: free Twin on the pick, Blank on another face of the same die")
	var r := _p()
	EventApplier.apply(_ch(&"bone_carver", 1), r, _rng(7), [Vector2i(1, 1)] as Array[Vector2i])
	_check(r.dice[1].faces == q.dice[1].faces, "carver: same seed -> same Blank face")


func _test_altar_merchant_croupier() -> void:
	var p := _p(0, 20)
	p.set_face(3, 4, &"wild")
	EventApplier.apply(_ch(&"altar", 0), p, _rng(), [Vector2i(3, 4)] as Array[Vector2i])
	_check(p.soul == 35 and p.dice[3].faces[4] == &"", "altar: give a mod -> +15 Soul (clamped to 35)")
	p.set_face(0, 1, &"twin")
	_check(EventApplier.apply(_ch(&"altar", 1), p, _rng(), [Vector2i(0, 2)] as Array[Vector2i])[0].begins_with("refused"),
		"altar: must pick a face that holds a mod")
	EventApplier.apply(_ch(&"altar", 1), p, _rng(), [Vector2i(0, 1)] as Array[Vector2i])
	_check(p.seal_level(&"trips") == 2 and not p.has_face_mod(), "altar: offer for power -> Trips Seal +2")
	var m := _p(8)
	EventApplier.apply(_ch(&"ember_merchant", 0), m, _rng())
	_check(m.embers == 0 and m.seal_level(&"run3") == 1, "merchant: 8 Embers -> Run of 3 Seal +1")
	m.set_face(2, 2, &"hellfire")
	EventApplier.apply(_ch(&"ember_merchant", 1), m, _rng(), [Vector2i(2, 2)] as Array[Vector2i])
	_check(m.embers == 12 and m.dice[2].faces[2] == &"", "merchant: sell a carving -> +12 Embers")
	var w := _p(0, 10)
	EventApplier.apply(_ch(&"weeping_croupier", 0), w, _rng())
	_check(w.soul == 5 and w.seal_level(&"two_pair") == 1, "croupier: -5 Soul -> Two Pair Seal +1")
	EventApplier.apply(_ch(&"weeping_croupier", 1), w, _rng(3))
	var blanks: int = 0
	for d in w.dice:
		blanks += d.faces.count(&"blank")
	_check(w.embers == 12 and blanks == 1, "croupier: +12 Embers, one random face goes Blank")
	_check(not EventApplier.can_choose(_ch(&"weeping_croupier", 0), w), "croupier: can't give 5 Soul at 5")


func _test_progress() -> void:
	var full := _p()
	for d in full.dice:
		for f in 6:
			d.faces[f] = &"wild"
	_check(not EventApplier.can_choose(_ch(&"bone_carver", 1), full), "grey: no free face -> can't carve")


func _fx(kind: int, mod: StringName = &"") -> EventEffectData:
	var e := EventEffectData.new()
	e.kind = kind
	e.target = EventEffectData.Target.PICKED
	if mod != &"":
		e.mod = load("res://resources/mods/%s.tres" % mod)
	return e


func _test_duplicate_picks() -> void:
	var K := EventEffectData.Kind
	var two := EventChoiceData.new()
	two.effects = [_fx(K.ADD_FACE_MOD, &"wild"), _fx(K.ADD_FACE_MOD, &"twin")] as Array[EventEffectData]
	var rng := RandomNumberGenerator.new()
	var p := _p()
	var same: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 0)]
	var lines := EventApplier.apply(two, p, rng, same)
	_check(lines.size() == 1 and lines[0].begins_with("refused") and p.dice[0].faces[0] == &"", "picks: two adds can't target the same face (nothing changes)")
	var diff: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	EventApplier.apply(two, p, rng, diff)
	_check(p.dice[0].faces[0] == &"wild" and p.dice[0].faces[1] == &"twin", "picks: different faces both apply")
	var rem := EventChoiceData.new()
	rem.effects = [_fx(K.REMOVE_FACE_MOD), _fx(K.REMOVE_FACE_MOD)] as Array[EventEffectData]
	var re: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 0)]
	lines = EventApplier.apply(rem, p, rng, re)
	_check(lines[0].begins_with("refused") and p.dice[0].faces[0] == &"wild", "picks: two removals can't target the same face either")
