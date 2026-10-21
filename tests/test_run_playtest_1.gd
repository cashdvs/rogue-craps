## QA full-run pass 1 fixes, run logic (qa/full_run_pass_1.md, repro seeds
## 4242 / 31337 / 777): M3 end reason + summary, M5 bonus never repeats a
## required bounty, Short Table text from the real hands, boss twist never
## repeats its cheat, the Altar at full Soul, Embers earned.
##   godot --headless --path . --script res://tests/test_run_playtest_1.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0
var _data: RunData


func _initialize() -> void:
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_m3_boss_resit()
	_test_m3_soul_and_won()
	_test_m5_bonus()
	_test_bonus_fallback()
	_test_m5_fallback()
	_test_short_table_text()
	_test_boss_twist()
	_test_altar()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_m3_boss_resit() -> void:
	for seed_v in [4242, 31337]:
		var run := MapRun.new(_data, seed_v)
		_enter(run, NT.TABLE)
		run.quick_resolve(true)
		run.take_seal(-1)
		_enter(run, NT.BOSS)
		run.quick_resolve(false)
		_check(run.screen == S.TABLE and run.boss_misses == 1, "M3 [%d]: first boss miss -> re-sit" % seed_v)
		run.quick_resolve(false)
		_check(run.screen == S.RUN_OVER and run.end_reason == &"boss" and run.progress.soul > 0,
			"M3 [%d]: second miss ends the run on the boss, Soul left (%d/%d)" % [seed_v, run.progress.soul, run.progress.max_soul])
		_check(RunSummary.title(run) == "The House Wins"
			and RunSummary.reason_line(run) == "You lost to %s twice, so your run ends on %s." % [run.boss_name(), run.floor_data().display_name],
			"M3 [%d]: the end screen says the boss won ('The House Wins', strings_v1)" % seed_v)
		var lines := RunSummary.lines(run)
		_check(lines.size() == 5 and lines[0].begins_with("Floor reached: 1 of 3") and lines[1] == "Tables cleared: 1"
			and lines[2] == "Embers earned: %d" % run.progress.embers_earned and lines[3].begins_with("Final bag: Bone")
			and lines[4] == "Seed: %d" % seed_v, "M3 [%d]: summary = floor, tables cleared, Embers earned, bag, seed" % seed_v)


func _test_m3_soul_and_won() -> void:
	var run := MapRun.new(_data, 999)
	_enter(run, NT.TABLE)
	run.progress.soul = 2
	run.quick_resolve(false)
	_check(run.screen == S.RUN_OVER and run.end_reason == &"soul" and RunSummary.title(run) == "Out of Soul"
		and RunSummary.reason_line(run) == "Your run ends on %s." % run.floor_data().display_name, "M3: Soul at 0 -> 'Out of Soul' / 'Your run ends on {floor}.'")
	for t: String in RunSummary.TITLES.values():
		_check(not t in ["The Contract Is Torn", "The Dealer Wins", "Your Soul Burns Out"], "end: old placeholder title '%s' is gone" % t)
	var e0 := MapRun.new(_data, 1)
	e0.progress.embers = 0
	e0.progress.change_embers(10)
	e0.progress.change_embers(-4)
	e0.progress.change_embers(5)
	_check(e0.progress.embers == 11 and e0.progress.embers_earned == 15, "summary: Embers earned counts gains only (spending doesn't lower it)")
	var won := MapRun.new(_data, 777)
	for f in 3:
		_enter(won, NT.BOSS)
		won.quick_resolve(true)
		won.take_seal(-1)
	_check(won.screen == S.RUN_WON and won.end_reason == &"won" and RunSummary.title(won) == "Run Won" and won.tables_cleared == 3,
		"M3: three boss clears -> Run Won, 3 tables cleared")


func _test_m5_bonus() -> void:
	var dup := 0
	var tables := 0
	for seed_v in range(4200, 4300):
		var run := MapRun.new(_data, seed_v)
		for f in 3:
			run._start_floor(f)
			for t in [NT.TABLE, NT.ELITE, NT.BOSS]:
				_enter(run, t)
				tables += 1
				for b in run.goal.bonus:
					for r in run.goal.required:
						if r.kind == b.kind and r.n == b.n:
							dup += 1
	_check(dup == 0, "M5: over %d tables the bonus never repeats a required bounty (%d dups)" % [tables, dup])
	var r4242 := MapRun.new(_data, 4242)
	_enter(r4242, NT.BOSS)
	var ids: Array = []
	for b in r4242.goal.required:
		ids.append(b.id)
	_check(r4242.goal.bonus.is_empty() or not (ids.has(&"run4") and r4242.goal.bonus[0].kind == BountyData.Kind.RUN and r4242.goal.bonus[0].n == 4),
		"M5: seed 4242 Floor 1 boss no longer shows 'Run of 4, Run of 4'")


func _test_short_table_text() -> void:
	var st: RunRuleData = load("res://resources/map/rules/short_table.tres")
	_check(st.text(4) == "4 hands." and st.text(5) == "5 hands.", "Short Table: the text uses the real hands")
	var run := MapRun.new(_data, 4242)
	run._start_floor(2)
	_enter(run, NT.ELITE)
	run.rules = [st] as Array[RunRuleData]
	var setup := run.table_setup()
	var e: Dictionary = setup.rule_entries()[0]
	_check(e.get("description", "") == "%d hands." % run.goal.hands, "Short Table: the table HUD gets the filled-in text (%s)" % e.get("description", ""))
	var plain: RunRuleData = load("res://resources/map/rules/cold_sixes.tres")
	run.rules = [plain] as Array[RunRuleData]
	_check(run.table_setup().rule_entries()[0].keys().size() == 2, "Short Table: other rules still send exactly {id, params}")


func _test_boss_twist() -> void:
	var ash: RunRuleData = load("res://resources/map/rules/ashmouth.tres")
	var cold: RunRuleData = load("res://resources/map/rules/cold_hands.tres")
	_check(ash.same_effect(cold) and cold.same_effect(ash) and not ash.same_effect(load("res://resources/map/rules/cold_sixes.tres")),
		"boss twist: Ashmouth and Cold Hands share an effect group")
	var clash := 0
	var with_twist := 0
	for seed_v in range(0, 400):
		var run := MapRun.new(_data, seed_v)
		run._start_floor(2)
		if run.boss_twist != null:
			with_twist += 1
			if run.boss.same_effect(run.boss_twist):
				clash += 1
	var f3: FloorData = _data.floors[2]
	_check(clash == 0 and (with_twist > 0 or not f3.boss_adds_twist), "boss twist: never repeats the cheat's effect over 400 seeds (%d twists)" % with_twist)


func _test_altar() -> void:
	var altar: EventData = load("res://resources/events/altar.tres")
	var p := RunProgress.new(_data)
	p.set_face(0, 0, &"wild")
	_check(p.soul == p.max_soul and EventApplier.why_not(altar.choices[0], p) == "Your Soul is already full.",
		"Altar: '+15 Soul' is greyed at full Soul, with the reason")
	_check(EventApplier.can_choose(altar.choices[1], p), "Altar: the Seal offer still works at full Soul")
	p.soul -= 1
	_check(EventApplier.can_choose(altar.choices[0], p), "Altar: with any Soul missing it's allowed (heal capped at max)")
	var merchant: EventData = load("res://resources/events/ember_merchant.tres")
	var full := RunProgress.new(_data)
	var ok := true
	for c in merchant.choices:
		var heals_only := false
		for e in c.effects:
			heals_only = heals_only or (e.kind == EventEffectData.Kind.SOUL and e.amount > 0)
		if not heals_only:
			ok = ok and EventApplier.why_not(c, full) != "Your Soul is already full."
	_check(ok, "Altar rule: choices that do more than heal aren't greyed by it")


func _bounty(kind: int, n: int, id: StringName) -> BountyData:
	var b := BountyData.new()
	b.kind = kind
	b.n = n
	b.id = id
	return b


## Game Designer (#106): a bonus that repeats a required bounty falls back
## to Full House; with Full House required too, there's no bonus.
func _test_bonus_fallback() -> void:
	var K := BountyData.Kind
	var run4 := _bounty(K.RUN, 4, &"bonus_run4")
	var fh := _bounty(K.FULL_HOUSE, 3, &"bonus_full_house")
	var pool: Array[BountyData] = [run4, fh]
	var req_run4: Array[BountyData] = [_bounty(K.RUN, 4, &"run4")]
	var req_both: Array[BountyData] = [_bounty(K.RUN, 4, &"run4"), _bounty(K.FULL_HOUSE, 3, &"full_house")]
	var req_none: Array[BountyData] = [_bounty(K.RUN, 3, &"run3")]
	var only_run4: Array[BountyData] = [run4]
	var ok_fb := true
	var ok_none := true
	var ok_free := true
	var drew := {}
	for s in 40:
		var r := RandomNumberGenerator.new()
		r.seed = s
		ok_fb = ok_fb and MapRun.pick_bonus(pool, req_run4, r) == fh
		r.seed = s
		ok_none = ok_none and MapRun.pick_bonus(pool, req_both, r) == null
		r.seed = s
		var b := MapRun.pick_bonus(pool, req_none, r)
		ok_free = ok_free and b != null
		drew[b] = true
	_check(ok_fb, "bonus: a Run of 4 bonus with Run of 4 required falls back to Full House")
	_check(ok_none, "bonus: with Run of 4 and Full House required, no bonus")
	_check(ok_free and drew.size() == 2, "bonus: with no clash both bonuses can be drawn")
	var r2 := RandomNumberGenerator.new()
	_check(MapRun.pick_bonus(only_run4, req_run4, r2) == null, "bonus: a clash with no Full House in the pool = no bonus")
	var empty: Array[BountyData] = []
	_check(MapRun.pick_bonus(empty, req_none, r2) == null, "bonus: an empty pool = no bonus")


func _rigged_goal(required: Array[BountyData], bonus_pool: Array[BountyData], seed_value: int) -> TableGoal:
	var rd := _data.duplicate() as RunData
	var f := (_data.floors[0] as FloorData).duplicate() as FloorData
	f.featured_bounties = [] as Array[BountyData]
	f.common_bounties = required.duplicate()
	f.min_bounties = required.size()
	f.max_bounties = required.size()
	f.bonus_bounties = bonus_pool
	var floors: Array[FloorData] = [f, _data.floors[1], _data.floors[2]]
	rd.floors = floors
	var run := MapRun.new(rd, seed_value)
	run._start_floor(0)
	_enter(run, NT.TABLE)
	return run.goal


## M5 (#106): a drawn bonus that repeats a required bounty falls back to the
## pool's Full House; with Full House required too, no bonus at all.
func _test_m5_fallback() -> void:
	var K := BountyData.Kind
	var run4 := _bounty(K.RUN, 4, &"run4")
	var fh_req := _bounty(K.FULL_HOUSE, 3, &"full_house")
	var b_run4 := _bounty(K.RUN, 4, &"bonus_run4")
	var b_fh := _bounty(K.FULL_HOUSE, 3, &"bonus_full_house")
	var only_run4_bonus: Array[BountyData] = [b_run4, b_run4, b_run4, b_fh]
	var fb_ok := true
	var none_ok := true
	for s in 12:
		var g := _rigged_goal([run4] as Array[BountyData], only_run4_bonus, s)
		fb_ok = fb_ok and g.required.size() == 1 and g.required[0] == run4 and g.bonus.size() == 1 and g.bonus[0] == b_fh
		var g2 := _rigged_goal([run4, fh_req] as Array[BountyData], only_run4_bonus, s)
		none_ok = none_ok and g2.required.size() == 2 and g2.bonus.is_empty()
	_check(fb_ok, "M5: rigged table, bonus repeats required Run of 4 -> Full House bonus")
	_check(none_ok, "M5: rigged table, Run of 4 and Full House required -> no bonus")
