## P0 (beta-0.1.3 playtest): every die bought in the shop reaches the next
## table. Data-driven over the whole catalog (RunData.special_dice + shapes,
## shop and rare) except the starting Bone d6: the shop buy puts it in the
## bag, the next table's handful carries it with its die id / body_key /
## face count, Bonfire3D spawns it in the hand on the right body shape, and
## it lands in a throw. Material / look asserts belong to Godot Dev's fix.
## Run: godot --headless --path . --script res://tests/test_bought_die_in_hand.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	var catalog: Array[SpecialDieData] = []
	catalog.append_array(_data.special_dice)
	catalog.append_array(_data.shapes)
	var seen := 0
	for sd in catalog:
		if sd != null and sd.id != DiceIds.DIE_BONE:
			seen += 1
			await _test_die(sd)
	_check(seen >= 20, "the catalog has every shop and rare die (%d)" % seen)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


## The body shape the table should give [param td] (PolyBody's d4 / d8,
## the coin, else the d6 cube).
func _want_shape(td: TableDie) -> StringName:
	if td.shape == &"coin":
		return &"coin"
	var s := PolyBody.table_shape(td)
	return s if s != &"" else &"d6"


func _test_die(sd: SpecialDieData) -> void:
	var id := sd.id
	var run := MapRun.new(_data, 7)
	run.screen = MapRun.Screen.SHOP
	run.progress.embers = 999
	run.shop_dice = [sd] as Array[SpecialDieData]
	var before := run.progress.dice.size()
	_check(run.buy_die(0), "%s: the shop sells it" % id)
	var bag := run.progress.dice
	var last: RunDie = bag[-1]
	_check(bag.size() == before + 1 and (last.special_id == id or last.shape == id),
		"%s: it is in the bag (%d dice, last %s/%s)" % [id, bag.size(), last.shape, last.special_id])
	run.screen = MapRun.Screen.MAP
	for n in run.map.reachable():
		if run.screen == MapRun.Screen.MAP and run.map.node(n).type == MapGenData.NodeType.TABLE:
			run.choose_node(n)
	_check(run.screen == MapRun.Screen.TABLE, "%s: the map opens the next table" % id)
	var rs := run.table_setup()
	var at := -1
	for i in rs.table_dice.size():
		if rs.table_dice[i].id == id: at = i
	_check(rs.table_dice.size() == bag.size() and at >= 0, "%s: the next table's handful has it (at %d of %d)" % [id, at, rs.table_dice.size()])
	if at < 0:
		return
	var htd := rs.table_dice[at]
	_check(htd.faces.size() == sd.faces.size() and htd.faces == sd.faces, "%s: its %d faces reach the table (%s)" % [id, sd.faces.size(), htd.faces])
	_check(DiceIds.body_key(htd.id) == DiceIds.body_key(id) and DiceIds.body_key(id) != &"",
		"%s: body_key %s passes through" % [id, DiceIds.body_key(id)])
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = rs.to_table_setup(_t)
	b.tutorial_override = 0
	b.test_speed = 10.0
	root.add_child(b)
	await process_frame
	await process_frame
	for k in 900:
		if b.phase == Table3D.Phase.BET and b.run.state == BonfireRun.State.AIM and not b.hand_moving(): break
		await process_frame
	var on_table := b.dice.size() == bag.size() and at < b.dice.size() and b._td(at) != null and b._td(at).id == id
	_check(on_table, "%s: it is spawned in the hand (%d dice)" % [id, b.dice.size()])
	if on_table:
		var td := b._td(at)
		_check(td.faces.size() == sd.faces.size(), "%s: the spawned die keeps %d faces (%d)" % [id, sd.faces.size(), td.faces.size()])
		_check(b.dice[at].shape == _want_shape(td), "%s: spawned on the %s body (%s)" % [id, _want_shape(td), b.dice[at].shape])
		b.quick_throw()
		await b.sequence_finished
		var lt := b.run.last_throw
		var landed: Array = lt.dice if lt != null else []
		_check(at < landed.size() and (landed[at] as TableDie).id == id and lt.values.size() == landed.size(),
			"%s: it is rollable: lands in the throw (%s)" % [id, lt.values if lt != null else []])
	b.queue_free()
	await process_frame
