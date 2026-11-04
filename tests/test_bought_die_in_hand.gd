## P0 (beta-0.1.3 playtest): every die the shop sells reaches the next
## table. Drives the player's path: RunScreen on a rolled shop, the Reroll
## button until the die is offered, ShopOffer.buy (what a card's Buy calls),
## the Leave button, a map node press, then RunScreen._play_table(). Checks
## the bag, the handful (id / body_key / faces), the hand spawn, the body
## shape (hard-coded per id) and a landed throw.
## Godot Dev's fixes flip the flags: PR A sets LOOK_FIXED (own look, not
## Bone), PR B sets SHAPES_FIXED (d10 / d12 / d20 / talus / keg bodies).
## Run: godot --headless --path . --script res://tests/test_bought_die_in_hand.gd
extends SceneTree

const LOOK_FIXED := true
const SHAPES_FIXED := true
## Every die the shop can sell (the 8 RunData.special_dice and the enabled
## shapes, shop and rare). last_breath (retired in #225) is not in RunData;
## ferryman, caltrop, lantern, tithe, midnight, verdict and knucklebone are
## enabled = false, so no shop rolls them.
const EXPECTED_SHAPE := {
	&"extra": &"d6", &"mirror": &"d6", &"cracked": &"d6", &"twin_flame": &"d6",
	&"wanderer": &"d6", &"bellows": &"d6", &"blood_pact": &"d6", &"coven": &"d6",
	&"powder_keg": &"keg", &"pyre": &"d6", &"gilt": &"d6", &"lodestone": &"d6",
	&"ossuary": &"d6", &"gallows": &"d4", &"beacon": &"d8", &"barrel": &"d6",
	&"fortune": &"d6", &"usurer": &"d6",
}
## The bodies PR B adds; until then these spawn on the d6 cube.
const PENDING_SHAPES := [&"d10", &"d12", &"d20", &"talus", &"keg"]

var _passed: int = 0
var _failed: int = 0
var _data: RunData


func _initialize() -> void:
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_data.max_dice = 6  # bag5: these checks add a die past the fixed 5
	var sellable: Array[StringName] = []
	for d in _data.special_dice:
		sellable.append(d.id)
	for s in _data.shapes:
		if s.enabled:
			sellable.append(s.id)
	_check(sellable.size() == EXPECTED_SHAPE.size(), "the shop sells exactly %d dice (%d: %s)" % [EXPECTED_SHAPE.size(), sellable.size(), sellable])
	for id in sellable:
		_check(EXPECTED_SHAPE.has(id), "%s has an expected shape" % id)
	_check(not sellable.has(&"last_breath"), "last_breath (retired in #225) is not sold")
	for id in EXPECTED_SHAPE:
		await _test_die(id)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _offer(screen: RunScreen, id: StringName) -> ShopOffer:
	for o in ShopOffer.list(screen.run):
		if o.kind == ShopOffer.Kind.DIE and o.id == id:
			return o
	return null


## A RunScreen on a rolled shop that offers [param id] (Reroll pressed as needed).
func _shop_with(id: StringName) -> RunScreen:
	for s in 40:
		var run := MapRun.new(_data, s)
		run.enter_for_sandbox(MapGenData.NodeType.SHOP, run.map.current_id)
		run.progress.embers = 99999
		var screen := (load("res://scenes/run.tscn") as PackedScene).instantiate() as RunScreen
		screen.preset_run = run
		root.add_child(screen)
		await process_frame
		screen.shop_screen.touch_override = 0
		screen.refresh()
		for r in 40:
			if _offer(screen, id) != null:
				return screen
			screen.shop_screen.reroll_button.pressed.emit()
		screen.queue_free()
		await process_frame
	return null


func _test_die(id: StringName) -> void:
	var screen: RunScreen = await _shop_with(id)
	_check(screen != null, "%s: a shop offers it" % id)
	if screen == null:
		return
	var run := screen.run
	var before := run.progress.dice.size()
	_offer(screen, id).buy(screen)
	var bag := run.progress.dice
	var last: RunDie = bag[-1]
	_check(bag.size() == before + 1 and (last.special_id == id or last.shape == id),
		"%s: bought into the bag (%d dice, last %s/%s)" % [id, bag.size(), last.shape, last.special_id])
	screen.shop_screen.leave_button.pressed.emit()
	_check(run.screen == MapRun.Screen.MAP, "%s: Leave returns to the map" % id)
	for n in run.map.reachable():
		if run.screen == MapRun.Screen.MAP and run.map.node(n).type == MapGenData.NodeType.TABLE:
			screen.map_view.node_pressed.emit(n)
	_check(run.screen == MapRun.Screen.TABLE, "%s: the map opens the next table" % id)
	screen._play_table()
	var b := screen._table
	var rs := b.setup
	var at := -1
	for i in rs.dice.size():
		if rs.dice[i].id == id: at = i
	_check(rs.dice.size() == bag.size() and at >= 0, "%s: the next table's handful has it (at %d of %d)" % [id, at, rs.dice.size()])
	if at < 0:
		screen.queue_free()
		return
	var sd: SpecialDieData = null
	for d in _data.special_dice + _data.shapes:
		if d.id == id: sd = d
	var htd: TableDie = rs.dice[at]
	_check(htd.faces == sd.faces, "%s: its %d faces reach the table (%s)" % [id, sd.faces.size(), htd.faces])
	_check(DiceIds.body_key(htd.id) == DiceIds.body_key(id) and DiceIds.body_key(id) != &"",
		"%s: body_key %s passes through" % [id, DiceIds.body_key(id)])
	b.tutorial_override = 0
	b.test_speed = 10.0
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
		var want: StringName = EXPECTED_SHAPE[id]
		if not SHAPES_FIXED and want in PENDING_SHAPES:
			want = &"d6"  # PR B: flip SHAPES_FIXED when its bodies land.
		_check(b.dice[at].shape == want, "%s: spawned on the %s body (%s)" % [id, want, b.dice[at].shape])
		if LOOK_FIXED:
			var alb: Color = b.dice[at].body_material.get_shader_parameter("albedo")
			## Bellows lost its slatted art body (AD, Nov 1): its own material instead.
			var art_ok := PolyDie.art_body_path(id) != "" or (id == &"bellows" and DieArtMaterial.body_path(id) != "")
			_check(art_ok and not alb.is_equal_approx(Palette.BONE),
				"%s: has its own look, not Bone (art '%s', albedo %s)" % [id, PolyDie.art_body_path(id), alb])
		b.quick_throw()
		await b.sequence_finished
		var lt := b.run.last_throw
		var landed: Array = lt.dice if lt != null else []
		_check(at < landed.size() and (landed[at] as TableDie).id == id and lt.values.size() == landed.size(),
			"%s: it is rollable: lands in the throw (%s)" % [id, lt.values if lt != null else []])
	screen.queue_free()
	await process_frame
