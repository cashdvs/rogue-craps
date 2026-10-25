## Shop and Rest screens of a Bonfire run (spec 1, Game Designer prices).
## MapRun extends this; state lives in MapRunState.
class_name MapRunShop
extends MapRunState


## Rest: heal data.rest_heal Soul (capped at max) and leave.
func rest_heal() -> bool:
	if screen != Screen.REST:
		return false
	progress.change_soul(data.rest_heal)
	_set_screen(Screen.MAP)
	return true


## Rest: carve the offered mod on a free face and leave.
func rest_carve(pick: Vector2i) -> bool:
	if screen != Screen.REST or rest_mod == null or not free_face(pick):
		return false
	progress.set_face(pick.x, pick.y, rest_mod.id)
	_set_screen(Screen.MAP)
	return true



## Rest: add data.rest_seal_levels to an owned Seal and leave.
func rest_seal(combo: StringName) -> bool:
	if screen != Screen.REST or not owned_seals().has(combo):
		return false
	progress.add_seal_levels(combo, data.rest_seal_levels)
	_set_screen(Screen.MAP)
	return true


# --- Shop (spec 1, Game Designer prices) ---

## n dice offers (shop slots / Elite reward): each is a shaped die with
## RunData.shape_offer_chance (enabled shapes, equal weight), else a special
## die; no offer repeats. Rare dice are never in these pools (see _rare_offer).
func _dice_offers(rng: RandomNumberGenerator, n: int) -> Array[SpecialDieData]:
	var specials: Array[SpecialDieData] = []
	for d in data.special_dice:
		if not d.is_rare():
			specials.append(d)
	var shapes: Array[SpecialDieData] = []
	for s in data.shapes:
		if s.enabled and not s.is_rare():
			shapes.append(s)
	var out: Array[SpecialDieData] = []
	while out.size() < n and not (specials.is_empty() and shapes.is_empty()):
		var use_shape := not shapes.is_empty() and (specials.is_empty() or rng.randf() < data.shape_offer_chance)
		var pool := shapes if use_shape else specials
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func _roll_shop() -> void:
	var rng := _rng(&"shop", shop_rerolls + 1000 * shop_free_rerolls)
	shop_dice.clear()
	shop_dice = _dice_offers(rng, data.shop_dice)
	var rare := _rare_offer(_rng(&"shop_rare", shop_rerolls + 1000 * shop_free_rerolls))
	if rare != null and shop_dice.size() >= 2:
		shop_dice[1] = rare
	shop_mods.clear()
	var mpool: Array[FaceModData] = data.face_mods.duplicate()
	while shop_mods.size() < data.shop_mods and not mpool.is_empty():
		shop_mods.append(mpool.pop_at(rng.randi_range(0, mpool.size() - 1)))
	shop_seals = _seal_offers(rng, data.shop_seals)
	shop_premium_seal = _premium_offer(rng)


## This floor's rare-die chance (RunData.shop_rare_die_chance, last entry
## past its end, 0 if empty).
func rare_die_chance() -> float:
	var c := data.shop_rare_die_chance
	return c[mini(floor_index, c.size() - 1)] if not c.is_empty() else 0.0


## The shop's rare roll (rare_dice_v1 §4): with rare_die_chance(), one enabled
## rare die (equal weight) the player doesn't own yet; else null. Own rng so
## the common offers keep their seeds. All four owned: null (a miss), so
## slot 2 keeps its normal offer (GD ruling on #174).
func _rare_offer(rng: RandomNumberGenerator) -> SpecialDieData:
	if rng.randf() >= rare_die_chance():
		return null
	var owned := {}
	for d in progress.dice:
		owned[d.shape] = true
	var pool: Array[SpecialDieData] = []
	for s in data.shapes:
		if s.enabled and s.is_rare() and not owned.has(s.id):
			pool.append(s)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## The guaranteed rare Seal (P4): one of RunData.rare_seals, preferring one the
## normal slots don't already offer; &"" when the slot is off. Drawn last so
## the other offers keep their seeds.
func _premium_offer(rng: RandomNumberGenerator) -> StringName:
	if data.shop_premium_rare_price <= 0 or data.rare_seals.is_empty():
		return &""
	var pool: Array[StringName] = []
	for r in data.rare_seals:
		if not shop_seals.has(r):
			pool.append(r)
	if pool.is_empty():
		pool = data.rare_seals.duplicate()
	return pool[rng.randi_range(0, pool.size() - 1)]


## Price of the guaranteed rare Seal (P4).
func premium_seal_price() -> int:
	return floor_price(data.shop_premium_rare_price)


## Buy the guaranteed rare Seal (params as seal_usable: Transference / Ashen
## need {"from", "to"}). It doesn't raise the combo Seal step.
func buy_premium_seal(params: Dictionary = {}) -> bool:
	var id := shop_premium_seal
	if id == &"" or screen != Screen.SHOP or progress.embers < premium_seal_price() or not seal_usable(id, params):
		return false
	_pay(premium_seal_price())
	_grant_seal(id, params)
	shop_premium_seal = &""
	return true


## This floor's shop markup in % (P5): shop_floor_price_percent[floor], the
## last entry past its end, 0 if empty.
func floor_price_percent() -> int:
	var pcts := data.shop_floor_price_percent
	return pcts[mini(floor_index, pcts.size() - 1)] if not pcts.is_empty() else 0


## `base` Embers with this floor's markup, rounded half up (22.5 -> 23).
func floor_price(base: int) -> int:
	return (base * (100 + floor_price_percent()) + 50) / 100


## Final price of die offer i on this floor; -1 if there's none.
func die_price(i: int) -> int:
	if i < 0 or i >= shop_dice.size() or shop_dice[i] == null:
		return -1
	return floor_price(shop_dice[i].price)


## Final price of `mod` on die die_i: its per-die escalated price, then the floor markup.
func shop_mod_price(mod: FaceModData, die_i: int) -> int:
	return floor_price(progress.mod_price(mod, die_i))


## Shop price of Seal `id` (rare: flat; combo: rises per Seal bought this visit).
func seal_price(id: StringName) -> int:
	if is_rare_seal(id):
		return floor_price(data.shop_rare_seal_price)
	return floor_price(data.shop_seal_price + data.shop_seal_step * shop_seals_bought)


## 0 while free rerolls (events) are banked; they don't raise the step.
func reroll_price() -> int:
	if progress.free_rerolls > 0:
		return 0
	return data.reroll_base + data.reroll_step * shop_rerolls


func _pay(cost: int) -> bool:
	if screen != Screen.SHOP or cost < 0 or progress.embers < cost:
		return false
	progress.change_embers(-cost)
	return true


## Restock the shop: a banked free reroll first, else pay reroll_price().
func shop_reroll() -> bool:
	if progress.free_rerolls > 0 and screen == Screen.SHOP:
		progress.free_rerolls -= 1
		shop_free_rerolls += 1
		progress.changed.emit()
	elif _pay(reroll_price()):
		shop_rerolls += 1
	else:
		return false
	_roll_shop()
	return true


## Buy die offer i (bag not full, affordable).
func buy_die(i: int) -> bool:
	if i < 0 or i >= shop_dice.size() or shop_dice[i] == null or not progress.can_add_die() or not _pay(die_price(i)):
		return false
	progress.add_die(shop_dice[i].id)
	shop_dice[i] = null
	return true


## Can mod offer i go on face `at` right now (free face, and its die's
## escalated price is affordable)?
func can_buy_mod_at(i: int, at: Vector2i) -> bool:
	return i >= 0 and i < shop_mods.size() and shop_mods[i] != null and free_face(at) \
		and shop_mod_price(shop_mods[i], at.x) <= progress.embers


## The lowest escalated price of mod offer i over dice with a free face; -1
## if no die has one.
func cheapest_mod_price(i: int) -> int:
	if i < 0 or i >= shop_mods.size() or shop_mods[i] == null:
		return -1
	var best := -1
	for d in progress.dice.size():
		if progress.dice[d].free_faces().is_empty() and not progress.dice[d].faces.has(RunDie.BLANK):
			continue
		var price := shop_mod_price(shop_mods[i], d)
		if best < 0 or price < best:
			best = price
	return best


## Lowest and highest price of mod offer i over dice with a free face
## (x = low, y = high); (-1, -1) if no die can take it.
func mod_price_range(i: int) -> Vector2i:
	var out := Vector2i(-1, -1)
	if i < 0 or i >= shop_mods.size() or shop_mods[i] == null:
		return out
	for d in progress.dice.size():
		if progress.dice[d].free_faces().is_empty() and not progress.dice[d].faces.has(RunDie.BLANK):
			continue
		var p := shop_mod_price(shop_mods[i], d)
		out = Vector2i(p if out.x < 0 else mini(out.x, p), maxi(out.y, p))
	return out


## Buy mod offer i onto a picked face; the price escalates per mod on that die.
func buy_mod(i: int, pick: Vector2i) -> bool:
	if i < 0 or i >= shop_mods.size() or shop_mods[i] == null or not free_face(pick) \
			or not _pay(shop_mod_price(shop_mods[i], pick.x)):
		return false
	progress.set_face(pick.x, pick.y, shop_mods[i].id)
	shop_mods[i] = null
	return true


## Buy Seal offer i (rare Seals need params, see seal_usable).
func buy_seal(i: int, params: Dictionary = {}) -> bool:
	if i < 0 or i >= shop_seals.size() or shop_seals[i] == &"" or screen != Screen.SHOP \
			or progress.embers < seal_price(shop_seals[i]) or not seal_usable(shop_seals[i], params):
		return false
	_pay(seal_price(shop_seals[i]))
	if not is_rare_seal(shop_seals[i]):
		shop_seals_bought += 1
	_grant_seal(shop_seals[i], params)
	shop_seals[i] = &""
	return true


## Soul Draught price (P3): shop_soul_price + shop_soul_step per Draught
## bought this run.
func soul_price() -> int:
	return floor_price(data.shop_soul_price + data.shop_soul_step * soul_draughts_bought)


## Buy a Soul Draught: +shop_soul_amount max Soul and heal as much (any
## number per visit; each raises the next price).
func buy_soul() -> bool:
	if data.shop_soul_amount <= 0 or not _pay(soul_price()):
		return false
	soul_draughts_bought += 1
	progress.change_max_soul(data.shop_soul_amount)
	return true


## Sell a special die from the handful for half its price (floor; a 0-Ember
## sale still sells). True whenever the die left the handful.
func sell_die(die_i: int) -> bool:
	return screen == Screen.SHOP and progress.sell_die(die_i) >= 0


## Leave the Shop or Rest for the map.
func leave() -> void:
	if screen == Screen.SHOP or screen == Screen.REST:
		_set_screen(Screen.MAP)

