## Rare dice v2 PR 2b: a lone Fuse 6 lights (a plain lone 6 still busts), a
## Boom on the real table grants +1 Nerve, and the Barrel is on sale.
##   godot --headless --path . --script res://tests/test_rare_dice_v2_barrel.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_go.call_deferred()


func _check(c: bool, name: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", name)


func _go() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var fuse := load("res://resources/mods/fuse.tres") as FaceModData
	var lone := BonfireScoring.score_selection([BonfireScoring.make_die(6, fuse)], t)
	_check(lone["valid"] and lone["combo"] == BonfireScoring._single(t, [])["id"], "a lone Fuse 6 lights as a Single")
	_check(BonfireScoring.best_points([BonfireScoring.make_die(6, fuse)], t) > 0, "a lone Fuse 6 isn't a bust")
	_check(BonfireScoring.best_points([6], t) == 0, "a plain lone 6 still busts")
	_check(not BonfireScoring.score_selection([BonfireScoring.make_die(6, fuse)], t, 0, {"no_mods": true})["valid"], "under The Collector a lone Fuse 6 busts")
	_check(RareDiceRules.lights_alone(&"fuse") and not RareDiceRules.lights_alone(&"jackpot") and not RareDiceRules.lights_alone(&""), "lights_alone is data: Fuse only")
	var run := BonfireRun.new(t, null, 10, 1)
	run.set_rules(TableRules.build([], [&"barrel"]), 3)
	var busts := [0]
	run.table_event.connect(func(e: StringName, _d: Dictionary) -> void: busts[0] += int(e == &"bust"))
	_check(run.land_throw(TableThrow.make([6] as Array[int], [fuse])) and busts[0] == 0 and run.lit() == [0], "real run: a lone Fuse 6 lands lit, no bust")
	var plain := BonfireRun.new(t, null, 10, 1)
	plain.set_rules(TableRules.build([], [&"barrel"]), 3)
	var pb := [0]
	plain.table_event.connect(func(e: StringName, _d: Dictionary) -> void: pb[0] += int(e == &"bust"))
	_check(not plain.land_throw(TableThrow.make([6] as Array[int], [null])) and pb[0] == 1, "real run: a plain lone 6 busts via land_throw")
	var cold := BonfireRun.new(t, null, 10, 1)
	cold.set_rules(TableRules.build([{"id": &"cold_sixes", "params": {"face": 6}}], [&"barrel"]), 3)
	var cb := [0]
	cold.table_event.connect(func(e: StringName, _d: Dictionary) -> void: cb[0] += int(e == &"bust"))
	_check(not cold.land_throw(TableThrow.make([6] as Array[int], [fuse])) and cold.lit().is_empty() and cb[0] == 1, "Cold Sixes: a lone Fuse 6 stays dark and busts")
	var data := load("res://resources/map/bonfire_run.tres") as RunData
	var barrel: DieShape = data.shapes.filter(func(s: DieShape) -> bool: return s.id == &"barrel")[0]
	_check(barrel.enabled and barrel.is_rare(), "the Barrel is an enabled rare")
	var granted := false
	var cleared := false
	for sd in range(1, 20):
		var s := await _table(t, fuse, sd)
		var before := s.nerve.state.uses_left()
		var boomed := [false]
		s.run.table_event.connect(func(e: StringName, _d: Dictionary) -> void: boomed[0] = boomed[0] or e == &"barrel_boom")
		s.rig_faces([6, 2, 2, 3, 4] as Array[int])
		if s.quick_throw():
			await s.sequence_finished
		if boomed[0]:
			granted = s.nerve.state.uses_left() == before + 1
			for i in s.run.lit(): s.pick_die(i)
			s.bank()
			for f in 30: await process_frame
			cleared = s.nerve.state.uses_left() == before
			s.queue_free()
			break
		s.queue_free()
	_check(granted, "real table: a Boom grants +1 Nerve")
	_check(granted and cleared, "real table: the Boom's Nerve grant clears at the next hand")
	await process_frame
	await process_frame
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _table(t: BonfireTuning, fuse: FaceModData, sd: int) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 5)
	st.table_seed = sd
	st.starting_soul = 9
	var td := TableDie.new()
	td.special = &"barrel"
	td.mods = [null, null, null, null, null, fuse]
	st.dice[0] = td
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	s.reduced_motion = true
	return s
