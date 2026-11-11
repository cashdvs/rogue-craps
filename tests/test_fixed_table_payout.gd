## Fixed table payouts (fixed_table_payout_v1): ordinary 26, Elite 42,
## non-final boss 56 (inactive in the one-floor run), final 45. A successful
## clear skips the Seal / die reward and goes to a payout summary, then the
## map (or the shop, which is still a map node). Final goes to RUN COMPLETE.
##
## Run:
##   godot --headless --path . --script res://tests/test_fixed_table_payout.gd
extends SceneTree

const NT := MapGenData.NodeType
const S := MapRun.Screen

var _passed: int = 0
var _failed: int = 0
var _data: RunData
var _tuning: BonfireTuning


func _initialize() -> void:
	print("=== Dice of the Damned: fixed table payout ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_amounts()
	_test_make_goal()
	_test_stub_flow()
	_test_conversion()
	_test_legacy()
	_test_final_score()
	_test_shop_after()
	_test_strings()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	_tuning = null
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = S.MAP
			return run.choose_node(n.id)
	return false


func _test_amounts() -> void:
	_check(_data.ordinary_table_embers == 26 and _data.elite_table_embers == 42
		and _data.boss_table_embers == 56 and _data.final_table_embers == 45,
		"data: payouts are 26 / 42 / 56 / 45")
	_check(_data.floors_in_run == 1, "data: one-floor run (56 stays defined but inactive)")
	_check(_data.boss_embers == 25, "data: unused boss_embers field left at 25")


func _test_make_goal() -> void:
	var one := MapRun.new(_data, 11)
	_enter(one, NT.TABLE)
	_check(one.goal.fixed_payout and not one.goal.is_final and one.goal.clear_embers == 26,
		"make_goal: ordinary F1 table pays 26, not final")
	_enter(one, NT.ELITE)
	_check(one.goal.clear_embers == 42 and not one.goal.is_final, "make_goal: Elite pays 42")
	_enter(one, NT.BOSS)
	_check(one.is_final_table(NT.BOSS) and one.goal.is_final and one.goal.clear_embers == 45,
		"make_goal: one-floor F1 boss is final, pays 45 (not 56)")
	# Finality is not inferred from NT.BOSS alone: a mid-run boss is not final.
	var multi := (_data.duplicate() as RunData)
	multi.floors_in_run = 0
	var mid := MapRun.new(multi, 11)
	_enter(mid, NT.BOSS)
	_check(not mid.is_final_table(NT.BOSS) and not mid.goal.is_final and mid.goal.clear_embers == 56,
		"make_goal: 3-floor F1 boss is not final, pays 56")
	mid._start_floor(2)
	_enter(mid, NT.BOSS)
	_check(mid.is_final_table(NT.BOSS) and mid.goal.is_final and mid.goal.clear_embers == 45,
		"make_goal: 3-floor last boss is final, pays 45")
	_check(mid.table_clear_embers(NT.TABLE, true) == 45,
		"payout: finality overrides type (ordinary + final = 45)")


func _test_stub_flow() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	run.quick_resolve(true)
	_check(run.screen == S.REWARD and run.seal_options.is_empty() and run.dice_options.is_empty()
		and run.progress.embers == 26, "stub ordinary: +26, payout panel, no reward choices")
	run.confirm_payout()
	_check(run.screen == S.MAP, "stub ordinary: Continue -> map")
	_enter(run, NT.ELITE)
	run.quick_resolve(true)
	_check(run.progress.embers == 26 + 42 and run.seal_options.is_empty() and run.dice_options.is_empty(),
		"stub Elite: +42, no die or Seal pick")
	run.confirm_payout()
	# Non-final boss fixture.
	var multi := (_data.duplicate() as RunData)
	multi.floors_in_run = 0
	var boss := MapRun.new(multi, 4)
	_enter(boss, NT.BOSS)
	boss.quick_resolve(true)
	_check(boss.screen == S.REWARD and boss.progress.embers == 56 and boss.progress.contract_pieces == 1
		and boss.seal_options.is_empty(), "stub non-final boss: +56, contract piece, no reward pick")
	boss.confirm_payout()
	_check(boss.floor_index == 1 and boss.screen == S.MAP, "stub non-final boss: Continue -> next floor")
	# Final one-floor boss: no payout panel.
	var fin := MapRun.new(_data, 4)
	_enter(fin, NT.BOSS)
	fin.quick_resolve(true)
	_check(fin.screen == S.RUN_WON and fin.end_reason == &"complete" and fin.progress.embers == 45
		and fin.progress.contract_pieces == 0, "stub final: +45, RUN COMPLETE, no contract, no payout panel")
	# Confirm is a no-op off the payout screen; no double pay.
	var e := fin.progress.embers
	fin.confirm_payout()
	_check(fin.progress.embers == e and fin.screen == S.RUN_WON, "confirm_payout is a no-op after the run ends")


func _bank_pair(r: BonfireRun) -> Dictionary:
	r.set_throw([4, 4, 1, 2, 6] as Array[int])
	if r.bust_pending:
		r.confirm_bust()
		return {}
	r.toggle(0)
	r.toggle(1)
	return r.bank()


func _map_goal(target: int = 1, hands: int = 8) -> TableGoal:
	var g := TableGoal.new()
	g.target = target
	g.hands = hands
	g.clear_embers = 26
	g.miss_soul = 5
	g.fixed_payout = true
	return g


func _clear_once(r: BonfireRun) -> void:
	while not r.cleared and not r.is_over():
		_bank_pair(r)


func _test_conversion() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	_check(run.goal.fixed_payout and run.goal.clear_embers == 26 and run.goal.target == 350,
		"conversion: map goal is fixed 26 / 350")
	# High scores on a cleared map table: payout stays 26, raw points intact.
	# Target 1 so one pair bank crosses; hands stay open so we can leave().
	for pts in [350, 600, 5000]:
		var r := BonfireRun.new(_tuning, _map_goal(), 30, 5)
		r.embers = 7  # independent (e.g. Gilded) already earned
		_clear_once(r)
		_check(r.cleared, "conversion: reached the target before testing %d points" % pts)
		var locked := r.embers
		r.points = pts
		_check(r.leave() and int(r.table_summary["points_embers"]) == 0 and int(r.table_summary["clear_embers"]) == 26
			and bool(r.table_summary["fixed_payout"]) and r.points == pts and r.embers == locked and locked == 33,
			"conversion: cleared map table at %d points pays no points-Embers, keeps %d (26 + independent)" % [pts, locked])
	# Miss still converts, cap 6; no fixed clear pay.
	var miss := BonfireRun.new(_tuning, _map_goal(350, 5), 30, 5)
	miss.points = 750
	_check(miss.forfeit() and not miss.cleared and int(miss.table_summary["points_embers"]) == 6
		and int(miss.table_summary["clear_embers"]) == 0 and miss.embers == 6,
		"conversion: miss still pays floor(points/100) capped at 6")
	# Forfeit after crossing is a clear: payout stays, not revoked, once only.
	var r2 := BonfireRun.new(_tuning, _map_goal(), 30, 5)
	_clear_once(r2)
	var paid := r2.embers
	_check(r2.forfeit() and r2.cleared and not r2.forfeited and r2.embers == paid
		and int(r2.table_summary["points_embers"]) == 0 and int(r2.table_summary["clear_embers"]) == 26,
		"conversion: forfeit after crossing is a clear, payout locked once")
	# Soul-out after crossing keeps the locked payout (already in embers;
	# _end_table must not revoke or convert).
	var r3 := BonfireRun.new(_tuning, _map_goal(), 30, 5)
	_clear_once(r3)
	var kept := r3.embers
	r3.soul = 0
	r3._end_table(BonfireRun.State.RUN_OVER)
	_check(r3.embers == kept and kept == 26 and int(r3.table_summary["clear_embers"]) == 26
		and int(r3.table_summary["points_embers"]) == 0,
		"conversion: Soul-out after crossing keeps the locked 26")


func _test_legacy() -> void:
	# Standalone / bounty fixtures keep floor clear + points conversion.
	var g: TableGoal = _tuning.table_goal
	_check(g != null and not g.fixed_payout, "legacy: standalone table_goal is not fixed-payout")
	var r := BonfireRun.new(_tuning, g, 30, 5)
	r.points = 500
	r.cleared = true
	r.embers = g.clear_embers
	r.state = BonfireRun.State.AIM
	r.throws_this_hand = 0
	_check(r.leave() and int(r.table_summary["points_embers"]) == 5 and r.embers == g.clear_embers + 5,
		"legacy: standalone clear still converts points (5 for 500)")


func _test_final_score() -> void:
	# Pre-fight balance 17, no independent income: final pays 45, score includes it.
	# (Nov 8: final-0 was not approved; Cash kept today's 45.)
	var run := MapRun.new(_data, 4)
	_enter(run, NT.BOSS)
	run.progress.embers = 17
	run.progress.embers_earned = 17
	var o := TableOutcome.new()
	o.cleared = true
	o.soul_after = run.progress.soul
	o.embers = run.goal.clear_embers
	o.points = run.goal.target
	run.apply_outcome(o)
	_check(run.screen == S.RUN_WON and run.progress.embers == 17 + 45 and run.run_points == 1400
		and RunSummary.final_score(run) == 1400 + 10 * (17 + 45),
		"final score: 17 + 45 Embers, money score 620, points 1400 (old package not added on top)")


func _test_shop_after() -> void:
	var run := MapRun.new(_data, 2)
	_enter(run, NT.TABLE)
	run.quick_resolve(true)
	_check(run.screen == S.REWARD and run.dice_options.is_empty() and run.seal_options.is_empty(),
		"shop path: reward-choice screen does not appear")
	run.confirm_payout()
	_check(_enter(run, NT.SHOP) and run.screen == S.SHOP and run.progress.embers == 26
		and run.shop_dice.size() == 2 and run.shop_mods.size() == 2,
		"shop path: Continue -> map, then the shop opens with the 26 Embers and stock")
	# Spend the payout on the first affordable shop die (prices unchanged).
	var bought := false
	var price := 0
	for i in run.shop_dice.size():
		if run.shop_dice[i] != null and run.die_price(i) <= run.progress.embers:
			price = run.die_price(i)
			bought = run.buy_die(i, 0)
			break
	_check(bought and run.progress.embers == 26 - price,
		"shop path: can spend the payout (die %d Embers)" % price)


func _test_strings() -> void:
	_check(EconomyStrings.table_payout_line(NT.TABLE, 26) == "Table beaten: +26 Embers."
		and EconomyStrings.table_payout_line(NT.ELITE, 42) == "Elite beaten: +42 Embers."
		and EconomyStrings.table_payout_line(NT.BOSS, 56) == "Boss beaten: +56 Embers."
		and EconomyStrings.table_payout_line(NT.BOSS, 45, true) == "Final table beaten: run complete.",
		"strings: payout lines match fixed_table_payout_v1")
	var md := FileAccess.get_file_as_string("res://design/strings_v1.md")
	var ok := true
	for id in EconomyStrings.TEXT:
		ok = ok and md.contains("| %s | (new) | %s |" % [id, EconomyStrings.TEXT[id]])
	_check(ok, "strings: EconomyStrings.TEXT matches design/strings_v1.md verbatim")
