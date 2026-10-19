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
## die; no offer repeats.
func _dice_offers(rng: RandomNumberGenerator, n: int) -> Array[SpecialDieData]:
	var specials: Array[SpecialDieData] = data.special_dice.duplicate()
	var shapes: Array[SpecialDieData] = []
	for s in data.shapes:
		if s.enabled:
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
	shop_mods.clear()
	var mpool: Array[FaceModData] = data.face_mods.duplicate()
	while shop_mods.size() < data.shop_mods and not mpool.is_empty():
		shop_mods.append(mpool.pop_at(rng.randi_range(0, mpool.size() - 1)))
	shop_seals = _seal_offers(rng, data.shop_seals)


## Shop price of Seal `id` (rare: flat; combo: rises per Seal bought this visit).
func seal_price(id: StringName) -> int:
	if is_rare_seal(id):
		return data.shop_rare_seal_price
	return data.shop_seal_price + data.shop_seal_step * shop_seals_bought


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
	if i < 0 or i >= shop_dice.size() or shop_dice[i] == null or not progress.can_add_die() or not _pay(shop_dice[i].price):
		return false
	progress.add_die(shop_dice[i].id)
	shop_dice[i] = null
	return true


## Can mod offer i go on face `at` right now (free face, and its die's
## escalated price is affordable)?
func can_buy_mod_at(i: int, at: Vector2i) -> bool:
	return i >= 0 and i < shop_mods.size() and shop_mods[i] != null and free_face(at) \
		and progress.mod_price(shop_mods[i], at.x) <= progress.embers


## The lowest escalated price of mod offer i over dice with a free face; -1
## if no die has one.
func cheapest_mod_price(i: int) -> int:
	if i < 0 or i >= shop_mods.size() or shop_mods[i] == null:
		return -1
	var best := -1
	for d in progress.dice.size():
		if progress.dice[d].free_faces().is_empty() and not progress.dice[d].faces.has(RunDie.BLANK):
			continue
		var price := progress.mod_price(shop_mods[i], d)
		if best < 0 or price < best:
			best = price
	return best


## Buy mod offer i onto a picked face; the price escalates per mod on that die.
func buy_mod(i: int, pick: Vector2i) -> bool:
	if i < 0 or i >= shop_mods.size() or shop_mods[i] == null or not free_face(pick) \
			or not _pay(progress.mod_price(shop_mods[i], pick.x)):
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


## Sell a special die from the handful for half its price (floor; a 0-Ember
## sale still sells). True whenever the die left the handful.
func sell_die(die_i: int) -> bool:
	return screen == Screen.SHOP and progress.sell_die(die_i) >= 0


## Leave the Shop or Rest for the map.
func leave() -> void:
	if screen == Screen.SHOP or screen == Screen.REST:
		_set_screen(Screen.MAP)

