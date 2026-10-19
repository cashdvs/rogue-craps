## Headless tests for the economy pass (design/economy_balance_v1.md, fixes
## QA M6): P1 points pay at most points_embers_cap Embers per table, P6 price
## fixes (anything that adds a die costs >= 18), P2 bag cap, P3 Soul Draught,
## P4 the guaranteed rare Seal slot and P5 floor price scaling.
##
## Run:
##   godot --headless --path . --script res://tests/test_economy_v1.gd
extends SceneTree

const NT := MapGenData.NodeType
## Economy v1 P6: the floor price of any die that adds a body to the bag.
const MIN_DIE_PRICE := 18

var _passed: int = 0
var _failed: int = 0
var _data: RunData
var _tuning: BonfireTuning


func _initialize() -> void:
	print("=== Dice of the Damned: economy v1 tests ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_points_cap()
	_test_prices()
	_test_bag_cap()
	_test_soul_draught()
	_test_premium_seal()
	_test_floor_prices()
	await _test_shop_ui()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	_tuning = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## Embers a table pays for `points` (forfeited, so no clear bonus).
func _points_embers(t: BonfireTuning, points: int) -> int:
	var r := BonfireRun.new(t, _tuning.table_goal, 30, 5)
	r.points = points
	r.forfeit()
	return int(r.table_summary["points_embers"])


## Jump straight into a node of `type` on the current floor (test shortcut).
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = MapRun.Screen.MAP
			return run.choose_node(n.id)
	return false


# --- P1: points -> Embers cap ---

func _test_points_cap() -> void:
	_check(_tuning.points_embers_cap == 5 and _tuning.points_per_ember == 100, "P1 data: cap 5 per table, 1 Ember per 100")
	_check(_points_embers(_tuning, 900) == 5, "P1: 900 points pay 5 Embers (capped)")
	_check(_points_embers(_tuning, 300) == 3, "P1: 300 points pay 3 Embers (under the cap)")
	_check(_points_embers(_tuning, 60000) == 5, "P1: a 60k Floor 3 score still pays 5")
	var bare := BonfireTuning.new()
	bare.table_goal = _tuning.table_goal
	_check(bare.points_embers_cap == 0 and _points_embers(bare, 900) == 9, "P1: no cap set (field absent) = uncapped, 900 pays 9")
	var lev := RunProgress.new(_data).leveled_tuning(_tuning)
	_check(lev.points_embers_cap == 5, "P1: the run's Seal-levelled tuning copy keeps the cap")
	var r := BonfireRun.new(_tuning, _tuning.table_goal, 30, 5)
	r.points = 900
	r.forfeit()
	_check(r.embers == 5, "P1: the table's Embers total uses the capped amount")
	_check(EconomyStrings.table_points_embers(_tuning) == "Points: 1 Ember per 100, up to 5 per table.", "P1 string: table_points_embers matches strings_v1")


# --- P6: price fixes ---

func _test_prices() -> void:
	var by_id: Dictionary = {}
	for d in _data.special_dice:
		by_id[d.id] = d.price
	for s in _data.shapes:
		by_id[s.id] = s.price
	_check(by_id.get(&"mirror") == 18 and by_id.get(&"cracked") == 18 and by_id.get(&"extra") == 18, "P6: Mirror, Cracked and Extra Die 18")
	_check(by_id.get(&"lantern") == 18 and by_id.get(&"tithe") == 18 and by_id.get(&"midnight") == 18, "P6: Lantern d8, Tithe d10, Midnight d12 18")
	var cheap: Array[String] = []
	for d in _data.special_dice:
		if d.price < MIN_DIE_PRICE:
			cheap.append(String(d.id))
	for s in _data.shapes:
		if s.id != &"d6" and s.price < MIN_DIE_PRICE:
			cheap.append(String(s.id))
	_check(cheap.is_empty(), "P6 rule: every die that adds to the bag costs >= %d (too cheap: %s)" % [MIN_DIE_PRICE, ", ".join(cheap)])
	var wild: FaceModData = load("res://resources/mods/wild.tres")
	_check(wild.price == 14, "P6: Wild Face 14")
	_check(_data.shop_seal_step == 2 and _data.reroll_step == 2, "P6 data: shop_seal_step 2, reroll_step 2 (bonfire_run.tres)")
	var run := MapRun.new(_data, 3)
	_check(_enter(run, NT.SHOP), "shop: entered")
	run.progress.embers = 100
	_check(run.reroll_price() == 3 and run.shop_reroll() and run.reroll_price() == 5, "P6: reroll 3, then 5")
	run.shop_seals = [&"pair", &"trips"] as Array[StringName]
	_check(run.buy_seal(0) and run.seal_price(&"trips") == 7, "P6: Seal 5, then 7")


# --- P2: bag cap 6, read from data everywhere ---

## A Gravedigger-style event choice that gives `die`.
func _give_choice(die: StringName) -> EventChoiceData:
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = die
	var c := EventChoiceData.new()
	c.effects = [e] as Array[EventEffectData]
	return c


func _test_bag_cap() -> void:
	_check(_data.max_dice == 6, "P2 data: max_dice 6 (bonfire_run.tres)")
	var give := _give_choice(&"mirror")
	var p := RunProgress.new(_data)
	_check(EventApplier.why_not(give, p) == "" and p.add_die(&"coven"), "P2: room for a 6th die")
	_check(not p.can_add_die() and not p.add_die(&"extra") and p.dice.size() == 6, "P2: no 7th die")
	_check(EventApplier.why_not(give, p) == "Your bag is full (6 dice).", "P2: event give_die greys out at 6")
	var run := MapRun.new(_data, 4)
	run.progress.add_die(&"coven")
	_check(_enter(run, NT.SHOP), "shop: entered")
	run.progress.embers = 500
	_check(not run.buy_die(0) and run.progress.embers == 500 and run.progress.dice.size() == 6, "P2: the shop won't sell a 7th die")
	run.screen = MapRun.Screen.REWARD
	run.dice_options = [_data.special_dice[0]] as Array[SpecialDieData]
	_check(not run.take_die(0) and run.progress.dice.size() == 6, "P2: an Elite die reward is refused on a full bag")
	# Nothing hard-codes the cap: a 7-die RunData allows a 7th everywhere.
	var roomy := _data.duplicate() as RunData
	roomy.max_dice = 7
	var q := RunProgress.new(roomy)
	q.add_die(&"coven")
	_check(EventApplier.why_not(give, q) == "" and q.add_die(&"extra") and q.dice.size() == 7, "P2: the cap is max_dice, not a constant")
	var panel := DicePanel.new()
	panel.build(p, {})
	var titled := false
	for l in panel.find_children("*", "Label", true, false):
		titled = titled or (l as Label).text == "Your dice · 6/6"
	_check(titled, "P2: the Your dice panel reads 6/6")
	panel.free()


# --- P3: Soul Draught ---

func _test_soul_draught() -> void:
	_check(_data.shop_soul_amount == 4 and _data.shop_soul_price == 12 and _data.shop_soul_step == 4, "P3 data: +4 max Soul for 12, +4 per buy")
	var run := MapRun.new(_data, 5)
	_check(_enter(run, NT.SHOP), "shop: entered")
	run.progress.embers = 11
	_check(run.soul_price() == 12 and not run.buy_soul() and run.progress.max_soul == 35, "P3: 11 Embers can't buy a 12-Ember Draught")
	run.progress.embers = 100
	run.progress.change_soul(-15)
	_check(run.buy_soul() and run.progress.max_soul == 39 and run.progress.soul == 24 and run.progress.embers == 88, "P3: +4 max Soul and heals 4 (20 -> 24), for 12")
	_check(run.soul_price() == 16 and run.buy_soul() and run.progress.embers == 72 and run.soul_price() == 20, "P3: 12, 16, 20 (any number per visit)")
	run.leave()
	_check(_enter(run, NT.SHOP) and run.soul_price() == 20, "P3: the price rises per Draught bought this run, not per visit")
	run.progress.change_soul(100)
	_check(run.buy_soul() and run.progress.max_soul == 47 and run.progress.soul == 47, "P3: at full Soul it still raises and heals to the new max")
	run.screen = MapRun.Screen.MAP
	run.progress.embers = 100
	_check(not run.buy_soul() and run.progress.embers == 100, "P3: only in the shop")


# --- P4: guaranteed rare Seal slot ---

func _test_premium_seal() -> void:
	_check(_data.shop_premium_rare_price == 12 and _data.shop_rare_seal_price == 10, "P4 data: rare slot 12; the 10% rare roll stays 10")
	var every := true
	for seed_v in 20:
		var r := MapRun.new(_data, seed_v)
		every = every and _enter(r, NT.SHOP) and _data.rare_seals.has(r.shop_premium_seal)
	_check(every, "P4: every shop has a rare Seal in its guaranteed slot (20 seeds)")
	var run := MapRun.new(_data, 6)
	_enter(run, NT.SHOP)
	run.progress.embers = 100
	run.shop_premium_seal = &"black"
	_check(not run.buy_premium_seal() and run.progress.embers == 100, "P4: Black Seal refused with nothing banked yet")
	run.progress.record_banks([&"pair"])
	_check(run.premium_seal_price() == 12 and run.buy_premium_seal() and run.progress.embers == 88 and run.progress.seal_level(&"pair") == 1,
		"P4: buy the rare Seal for 12; it's used at once (Black: +1 most-banked)")
	_check(run.shop_premium_seal == &"" and not run.buy_premium_seal() and run.shop_seals_bought == 0, "P4: one per stock; doesn't raise the Seal step")
	_check(run.shop_reroll() and _data.rare_seals.has(run.shop_premium_seal), "P4: a reroll restocks the rare slot")


# --- P5: floor price scaling ---

## A run on floor f (0-based) standing in a fresh shop.
func _shop_on_floor(f: int, seed_v: int = 8) -> MapRun:
	var run := MapRun.new(_data, seed_v)
	run._start_floor(f)
	_enter(run, NT.SHOP)
	return run


func _test_floor_prices() -> void:
	_check(_data.shop_floor_price_percent == ([0, 25, 50] as Array[int]), "P5 data: +0 / +25 / +50% by floor")
	var mirror: SpecialDieData = load("res://resources/dice/special/mirror.tres")
	var wild: FaceModData = load("res://resources/mods/wild.tres")
	var want := [[0, 18, 14, 5, 10, 12, 12], [25, 23, 18, 6, 13, 15, 15], [50, 27, 21, 8, 15, 18, 18]]
	for f in 3:
		var run := _shop_on_floor(f)
		var w: Array = want[f]
		run.shop_dice[0] = mirror
		run.shop_mods[0] = wild
		_check(run.floor_price_percent() == w[0] and run.die_price(0) == w[1] and run.shop_mod_price(wild, 0) == w[2],
			"P5 floor %d: +%d%%, Mirror %d, Wild %d (rounded half up)" % [f + 1, w[0], w[1], w[2]])
		_check(run.seal_price(&"pair") == w[3] and run.seal_price(&"black") == w[4] and run.premium_seal_price() == w[5] and run.soul_price() == w[6],
			"P5 floor %d: Seal %d, rolled rare %d, rare slot %d, Soul Draught %d" % [f + 1, w[3], w[4], w[5], w[6]])
		_check(run.reroll_price() == 3 and run.progress.sell_value(0) == 0, "P5 floor %d: rerolls don't scale" % (f + 1))
	var run := _shop_on_floor(1)
	run.shop_dice[0] = mirror
	run.shop_mods[0] = wild
	run.progress.embers = 22
	_check(not run.buy_die(0) and run.progress.embers == 22, "P5: 22 Embers can't buy a 23-Ember Mirror on Floor 2")
	run.progress.embers = 100
	_check(run.buy_die(0) and run.progress.embers == 77, "P5: the Mirror charges its Floor 2 price (23)")
	_check(run.cheapest_mod_price(0) == 18 and run.mod_price_range(0) == Vector2i(18, 18) and run.buy_mod(0, Vector2i(0, 0)) and run.progress.embers == 59,
		"P5: Wild shows and charges 18 on Floor 2")
	_check(run.progress.sell_value(5) == 9, "P5: sell values don't scale (Mirror sells for 9)")
	_check(run.buy_soul() and run.progress.embers == 44 and run.soul_price() == 20, "P5: Soul Draught 15, then (12 + 4) x 1.25 = 20")
	var tk: EventData = null
	for ev in _data.events:
		if ev.id == &"bone_carver":
			tk = ev
	var e0 := run.progress.embers
	EventApplier.apply(tk.choices[0], run.progress, RandomNumberGenerator.new(), [Vector2i(1, 0)] as Array[Vector2i])
	_check(run.progress.embers == e0 - 6, "P5: event prices don't scale (Bone Carver's Wild is still 6 on Floor 2)")


# --- Shop UI: final prices on the buttons ---

func _ui_buttons(node: Node, out: Array[Button] = []) -> Array[Button]:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_ui_buttons(c, out)
	return out


func _ui_labels(node: Node, out: Array[String] = []) -> Array[String]:
	for c in node.get_children():
		if c is Label:
			out.append((c as Label).text)
		_ui_labels(c, out)
	return out


func _ui_button(scene: RunScreen, prefix: String) -> Button:
	for b in _ui_buttons(scene._panel_box):
		if b.text.begins_with(prefix):
			return b
	return null


func _test_shop_ui() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 21
	root.add_child(scene)
	await process_frame
	var run := scene.run
	_enter(run, NT.SHOP)
	await process_frame
	run.progress.embers = 11
	scene._show_shop()
	var soul := _ui_button(scene, "Soul Draught")
	_check(soul != null and soul.text == "Soul Draught: +4 max Soul, heals 4. 12 Embers" and soul.disabled, "P3 UI: shop_soul_button, greyed when short")
	run.progress.embers = 40
	scene._show_shop()
	soul = _ui_button(scene, "Soul Draught")
	soul.pressed.emit()
	await process_frame
	soul = _ui_button(scene, "Soul Draught")
	_check(run.progress.max_soul == 39 and soul != null and soul.text.ends_with("16 Embers"), "P3 UI: buying shows the next price (16)")
	run.shop_premium_seal = &"black"
	run.progress.record_banks([&"pair"])
	run.progress.embers = 12
	scene._show_shop()
	var rare := _ui_button(scene, "Rare Seal")
	_check(rare != null and rare.text == "Rare Seal: 12 Embers (Black)" and not rare.disabled, "P4 UI: shop_premium_seal_button names the Seal")
	rare.pressed.emit()
	await process_frame
	_check(run.progress.embers == 0 and _ui_button(scene, "Rare Seal") == null, "P4 UI: bought; the slot is gone")
	var lines := _ui_labels(scene._panel_box)
	_check(not lines.any(func(t: String) -> bool: return t.begins_with("Prices on this floor")), "P5 UI: no price note on Floor 1")
	run._start_floor(2)
	_enter(run, NT.SHOP)
	await process_frame
	run.shop_dice[0] = load("res://resources/dice/special/mirror.tres")
	run.progress.embers = 26
	scene._show_shop()
	lines = _ui_labels(scene._panel_box)
	_check(lines.has("Prices on this floor: 50% above Floor 1."), "P5 UI: shop_floor_price_note on Floor 3")
	var die := _ui_button(scene, "Mirror Die - ")
	_check(die != null and die.text.begins_with("Mirror Die - 27 Embers") and die.disabled, "P5 UI: the die button shows the final price (27) and greys on it")
	_check(_ui_button(scene, "Soul Draught").text.ends_with("24 Embers") and _ui_button(scene, "Reroll - 3") != null,
		"P5 UI: Soul Draught (12 + 4) x 1.5 = 24; reroll stays 3")
	scene.queue_free()
	await process_frame
