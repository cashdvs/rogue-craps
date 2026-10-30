## Playtest e1cd912 bug 2: modded faces score what the table shows. Real path
## (shop / carve -> MapRun -> Bonfire3D throw -> pot -> bank) for every carved
## face mod and the rare pre-carved faces, plus The Collector vs land effects.
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_collector_stops_land_effects()
	await _test_carved_mods()
	await _test_barrel_preview_matches_bank()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _mod(id: StringName) -> FaceModData:
	return load("res://resources/mods/%s.tres" % id)


## Collector: face mods do nothing on the first throw, so Hex takes no Soul
## and Fuse neither booms nor misfires there; on the 2nd throw they fire.
func _test_collector_stops_land_effects() -> void:
	var collector := load("res://resources/map/rules/collector.tres") as RunRuleData
	for id: StringName in [&"hex", &"fuse"]:
		var r := BonfireRun.new(_t, null, 10, 6)
		r.set_rules(TableRules.build([collector], [&"fortune" if id == &"hex" else &"barrel"]), 7)
		var ev: Array = []
		r.table_event.connect(func(e: StringName, _d: Variant) -> void: ev.append(e))
		var face := 1 if id == &"hex" else 6
		r.land_throw(TableThrow.make([face, 5, 5] as Array[int], [_mod(id), null, null]))
		var fired := ev.has(&"hex") or ev.has(&"fuse_lit")
		_check(not fired and r.soul == 10 and r.embers == 0,
			"collector: %s does nothing on the first throw (events %s, soul %d)" % [id, ev, r.soul])
		r.toggle(1)
		r.toggle(2)
		r.rethrow()
		ev.clear()
		r.land_throw(TableThrow.make([face] as Array[int], [_mod(id)]))
		_check(ev.has(&"hex") or ev.has(&"fuse_lit"), "collector: %s fires on the second throw (%s)" % [id, ev])


func _map_run() -> MapRun:
	return MapRun.new(_data, 7)


func _to_table(run: MapRun) -> Bonfire3D:
	for id in run.map.reachable():
		if run.screen == MapRun.Screen.MAP and run.map.node(id).type == MapGenData.NodeType.TABLE:
			run.choose_node(id)
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = run.table_setup().to_table_setup(_t)
	b.tutorial_override = 0
	b.test_speed = 10.0
	root.add_child(b)
	await process_frame
	await process_frame
	for k in 900:
		if b.phase == Table3D.Phase.BET and b.run.state == BonfireRun.State.AIM and not b.hand_moving(): break
		await process_frame
	return b


## Throws `faces`, pots `pick`, banks. [selection, preview, bank result].
func _throw_pot_bank(b: Bonfire3D, faces: Array[int], pick: Array) -> Array:
	b.rig_faces(faces)
	b.quick_throw()
	await b.sequence_finished
	for i in pick: b.pick_die(i)
	var sel := b.run.selection()
	var pv := BonfireScoring.preview(sel)
	var rule := RareDiceRules.barrel_rule(b.run)
	var f := rule.pot_factor if rule != null else 1.0
	var r: Dictionary = await b.bank()
	return [sel, pv, r, f]


## Every carved face mod on die 1's 5 face, potted as Trips of 5: the score
## the preview shows is the score banked, and matches the mod's rule.
func _test_carved_mods() -> void:
	var want := {&"ember_pip": 225, &"gilded": 135, &"heavy": 135, &"step": 135, &"kindling": 135,
		&"blood": 315, &"wild": 135, &"twin": 640, &"stair": 135, &"hellfire": 202}
	for m: FaceModData in _data.face_mods:
		var run := _map_run()
		_check(run.progress.set_face(0, 4, m.id), "carve %s" % m.id)
		var b := await _to_table(run)
		var out := await _throw_pot_bank(b, [5, 5, 5, 2, 3] as Array[int], [0, 1, 2])
		var shown := int(out[0]["points"])
		_check(RareDiceRules.mod_id(b.run.last_throw.mods[0]) == m.id, "%s: the carved face lands with its mod" % m.id)
		_check(shown == int(out[2].get("gain", -1)), "%s: preview %d = banked %d" % [m.id, shown, int(out[2].get("gain", -1))])
		if want.has(m.id):
			_check(shown == int(want[m.id]), "%s: Trips of 5 scores %d (want %d)" % [m.id, shown, want[m.id]])
		b.queue_free()
		await process_frame


## Barrel bought in the shop: its Fuse face lands, and the preview / count-up
## (selection) already shows the Boom x2 / Misfire x0.5, so it equals the bank.
func _test_barrel_preview_matches_bank() -> void:
	var barrel: DieShape = null
	for s in _data.shapes:
		if s.id == &"barrel": barrel = s
	var seen := {}
	for sd in [7, 8, 9, 10, 11, 12]:
		var run := MapRun.new(_data, sd)
		run.screen = MapRun.Screen.SHOP
		run.progress.embers = 999
		run.shop_dice = [barrel, barrel] as Array[SpecialDieData]
		run.buy_die(1)
		run.screen = MapRun.Screen.MAP
		var b := await _to_table(run)
		var out := await _throw_pot_bank(b, [6, 6, 2, 2, 3, 6] as Array[int], [5, 0, 1, 2, 3])
		var sel: Dictionary = out[0]
		var gain := int(out[2].get("gain", -1))
		var f: float = out[3]
		seen[f] = true
		_check(RareDiceRules.mod_id(b.run.last_throw.mods[5]) == &"fuse", "barrel %d: the Fuse face lands" % sd)
		_check(int(sel["points"]) == gain, "barrel %d: preview %d = banked %d (factor %s)" % [sd, int(sel["points"]), gain, f])
		_check(not is_equal_approx(f, 1.0) and String(out[1]).contains("x%s" % str(snappedf(f, 0.01))), "barrel %d: preview shows x%s: %s" % [sd, f, out[1]])
		b.queue_free()
		await process_frame
	print("barrel factors seen: ", seen.keys())
