## bag5_sacrifice_v1: the bag is fixed at 5 and every die grant (shop buy,
## Elite reward, event GIVE_DIE) is a swap; F1 boss target 1400.
##   godot --headless --path . --script res://tests/test_bag5_swap.gd
extends SceneTree

const NT := MapGenData.NodeType

var _passed: int = 0
var _failed: int = 0
var _data: RunData


func _initialize() -> void:
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_test_cap()
	_test_shop_swap()
	_test_elite_swap()
	_test_event_swap()
	_test_no_extra()
	_test_swap_lines()
	await _test_event_confirm()
	_check((load("res://resources/map/floor_1.tres") as FloorData).target_boss == 1400, "F1 boss target is 1400")
	print("=== test_bag5_swap: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = MapRun.Screen.MAP
			return run.choose_node(n.id)
	return false


func _test_cap() -> void:
	var p := RunProgress.new(_data)
	_check(_data.max_dice == 5 and p.dice.size() == 5 and not p.can_add_die(), "a new run starts full at 5")
	_check(not p.can_lose_die(), "no die can be sold at 5")


func _test_shop_swap() -> void:
	var run := MapRun.new(_data, 4)
	_check(_enter(run, NT.SHOP), "shop: entered")
	var i := run.shop_dice.find_custom(func(d: SpecialDieData) -> bool: return d != null)
	_check(i >= 0, "shop: a die is on offer")
	var p := run.progress
	p.embers = 0
	_check(not run.buy_die(i, 1) and p.dice.size() == 5, "shop: can't afford, nothing changes")
	p.embers = 500
	_check(not run.buy_die(i) and not run.buy_die(i, 9) and p.embers == 500, "shop: no valid die to give up, nothing changes")
	# Give up a valued die (a Bone sells for 0, so a refund would have been invisible).
	p.swap_die(1, &"mirror")
	p.set_face(1, 0, &"wild")
	var sell := p.sell_value(1)
	_check(sell > 0, "shop: the given-up die has a sell value (Mirror, %d)" % sell)
	var old_id := p.dice[1].id
	var price := run.die_price(i)
	var want := run.shop_dice[i].id
	_check(p.die_has_mods(1), "shop: the carved die reports its mods")
	_check(run.buy_die(i, 1), "shop: a full-bag buy swaps")
	_check(p.dice.size() == 5 and p.dice[1].special_id == want and p.dice[1].id != old_id and not p.die_has_mods(1),
		"shop: the new die takes slot 2; the old die and its carved face are gone")
	_check(p.embers == 500 - price, "shop: pays the unchanged die price, no refund (would be %d if sell_value were credited)" % (500 - price + sell))


func _test_elite_swap() -> void:
	var run := MapRun.new(_data, 4)
	run.screen = MapRun.Screen.REWARD
	run.dice_options = [_data.special_dice[0]] as Array[SpecialDieData]
	_check(not run.take_die(0) and run.progress.dice.size() == 5, "elite: no die to give up, refused")
	_check(run.take_die(0, 4) and run.progress.dice.size() == 5 and run.progress.dice[4].special_id == _data.special_dice[0].id,
		"elite: the reward die swaps into the picked slot")


func _test_event_swap() -> void:
	var p := RunProgress.new(_data)
	var ch := EventChoiceData.new()
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = DiceIds.DIE_MIRROR
	ch.effects.assign([e])
	_check(EventApplier.why_not(ch, p) == "" and EventApplier.picks_needed(ch) == 1, "event: GIVE_DIE is open at 5 and needs a pick")
	EventApplier.apply(ch, p, RandomNumberGenerator.new(), [Vector2i(3, 0)])
	_check(p.dice.size() == 5 and p.dice[3].special_id == DiceIds.DIE_MIRROR, "event: GIVE_DIE swaps the picked die")
	var sell := EventChoiceData.new()
	var s := EventEffectData.new()
	s.kind = EventEffectData.Kind.SELL_DIE
	sell.effects.assign([s])
	_check(EventApplier.is_hidden(sell, p), "event: selling a die is hidden at 5")


func _test_no_extra() -> void:
	var seen := false
	for seed in 40:
		var run := MapRun.new(_data, seed)
		for d in run._dice_offers(RandomNumberGenerator.new(), 20):
			seen = seen or d.id == DiceIds.DIE_EXTRA
	_check(not seen, "pools: the plain Extra die is never offered (shop or Elite)")


func _test_swap_lines() -> void:
	var p := RunProgress.new(_data)
	var T := ShopSideCard.SWAP_TEXT
	var plain := ShopSideCard.swap_lines(p, 0, "Mirror Die")
	_check(plain[0] == "Swap Bone for Mirror Die?" and plain.has(T.shop_swap_no_refund) and not plain.has(T.shop_swap_mods_warn),
		"swap_lines: a plain die warns no refund only (%s)" % [plain])
	p.set_face(0, 2, &"wild")
	var carved := ShopSideCard.swap_lines(p, 0, "Mirror Die")
	_check(carved.has(T.shop_swap_no_refund) and carved.has(T.shop_swap_mods_warn), "swap_lines: a carved die adds the carved-faces warning")
	p.set_face(1, 0, RunDie.BLANK)
	var blank := ShopSideCard.swap_lines(p, 1, "Mirror Die")
	_check(not p.die_has_mods(1) and not blank.has(T.shop_swap_mods_warn) and blank.has(T.shop_swap_no_refund), "swap_lines: a blank face is not carved")


func _button(v: Node, text: String) -> Button:
	for b in v.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


## The event GIVE_DIE path asks SWAP/CANCEL after the pick, like the shop.
func _test_event_confirm() -> void:
	var p := RunProgress.new(_data)
	p.set_face(2, 0, &"wild")
	var ch := EventChoiceData.new()
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = DiceIds.DIE_MIRROR
	ch.effects.assign([e])
	var ev := EventData.new()
	ev.title = "Test"
	ev.choices.assign([ch])
	var view := EventView.new()
	root.add_child(view)
	await process_frame
	var got: Array = []
	view.choice_made.connect(func(i: int, picks: Array[Vector2i]) -> void: got.append(picks))
	var before := p.dice.map(func(d: RunDie) -> StringName: return d.id)
	for ok: bool in [false, true]:
		view.show_event(ev, p)
		view._on_choice(0)
		var dp: Array = view.find_children("*", "DicePanel", true, false)
		(dp[0] as DicePanel).picked.emit(Vector2i(2, 0))
		await process_frame
		var lines: Array[String] = []
		for l in view.find_children("*", "Label", true, false):
			lines.append((l as Label).text)
		_check(lines.has(ShopSideCard.SWAP_TEXT.shop_swap_no_refund) and lines.has(ShopSideCard.SWAP_TEXT.shop_swap_mods_warn),
			"event: the confirm shows both warnings for a carved die")
		_button(view, ShopSideCard.swap_btn(0) if ok else ShopSideCard.SWAP_TEXT.shop_swap_cancel).pressed.emit()
		await process_frame
		if not ok:
			_check(got.is_empty() and p.dice.map(func(d: RunDie) -> StringName: return d.id) == before, "event: CANCEL emits nothing and leaves the bag")
	_check(got.size() == 1 and got[0] == [Vector2i(2, 0)], "event: SWAP emits the choice with the pick (%s)" % [got])
	EventApplier.apply(ch, p, RandomNumberGenerator.new(), got[0])
	_check(p.dice.size() == 5 and p.dice[2].special_id == DiceIds.DIE_MIRROR and p.dice[2].id != before[2], "event: the swap lands in the same slot")
	view.queue_free()
