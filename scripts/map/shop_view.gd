## The Ember Shop's lines and buttons for RunScreen (spec 1, economy_balance_v1
## P3-P5). Rules and prices live in MapRunShop; this only builds the labels
## (always the final price) and forwards clicks. Buttons are RunScreen._panel
## rows: [text, Callable, disabled?].
class_name ShopView
extends RefCounted


## The shop's header lines.
static func lines(screen: RunScreen) -> Array:
	return ["Each mod on a die makes its next mod cost more; pick the die to see its price. Dice sell for half.",
		"Your dice: " + screen.bag_text()]


## Every shop button, in order: dice, mods, Seals, Soul Draught, sells, reroll, leave.
static func buttons(screen: RunScreen) -> Array:
	var run := screen.run
	var e: int = run.progress.embers
	var out: Array = []
	for i in run.shop_dice.size():
		var d := run.shop_dice[i]
		if d != null:
			out.append(["%s - %d Embers (%s)" % [d.display_name, d.price, d.description],
				func() -> void: run.buy_die(i); screen._show_shop(), e < d.price or not run.progress.can_add_die()])
	for i in run.shop_mods.size():
		if run.shop_mods[i] != null:
			var m := run.shop_mods[i]
			var low := run.cheapest_mod_price(i)
			out.append([mod_offer_text(run, i), func() -> void:
				screen._pick("Pick a face for the %s" % m.display_name, func(at: Vector2i) -> void:
					run.buy_mod(i, at)
					screen._show_shop(), func(at: Vector2i) -> bool: return run.can_buy_mod_at(i, at),
					func(d: int) -> int: return run.progress.mod_price(m, d)), low < 0 or e < low])
	for i in run.shop_seals.size():
		if run.shop_seals[i] != &"":
			var id := run.shop_seals[i]
			out.append(["%s Seal - %d Embers" % [String(id).capitalize(), run.seal_price(id)],
				func() -> void: screen._seal_with_params(id, func(params: Dictionary) -> bool:
					var ok := run.buy_seal(i, params)
					screen._show_shop()
					return ok), e < run.seal_price(id) or not screen._seal_possible(id)])
	if run.data.shop_soul_amount > 0:
		out.append([EconomyStrings.shop_soul_button(run.data.shop_soul_amount, run.soul_price()),
			func() -> void: run.buy_soul(); screen._show_shop(), e < run.soul_price()])
	for d_i in run.progress.dice.size():
		var sd := run.progress.die_def(d_i)
		if sd != null and run.progress.sell_value(d_i) > 0:
			out.append(["Sell your %s (+%d Embers)" % [sd.display_name, run.progress.sell_value(d_i)],
				func() -> void: run.sell_die(d_i); screen._show_shop()])
	out.append(["Free reroll (%d left)" % run.progress.free_rerolls if run.progress.free_rerolls > 0 else "Reroll - %d Embers" % run.reroll_price(),
		func() -> void: run.shop_reroll(); screen._show_shop(), e < run.reroll_price()])
	out.append(["Leave", func() -> void: run.leave()])
	return out


## Shop label for mod offer i: its price range over your dice, e.g.
## "Twin Face - 9 to 27 Embers, by die" (one price: "9 Embers").
static func mod_offer_text(run: MapRun, i: int) -> String:
	var m := run.shop_mods[i]
	var r := run.mod_price_range(i)
	if r.x < 0:
		return "%s - no free face" % m.display_name
	return "%s - %d Embers" % [m.display_name, r.x] if r.x == r.y else "%s - %d to %d Embers, by die" % [m.display_name, r.x, r.y]
