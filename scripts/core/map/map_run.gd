## Drives a Bonfire run across its floors (map/events spec §1): travel on the
## map, then the node's screen (Table / Elite / Boss, Event, Shop, Rest), the
## Seal reward after a cleared fight, the boss re-sit, contract pieces and
## the next floor. Pure logic: RunScreen shows `screen` and calls these.
##
## Seeds: every random choice uses an RNG seeded from hash([run seed, floor,
## node id, purpose]), so a run replays identically and nothing is shared.
class_name MapRun
extends RefCounted

enum Screen { MAP, TABLE, EVENT, SHOP, REST, REWARD, RUN_WON, RUN_OVER }
const NT := MapGenData.NodeType

signal screen_changed(screen: Screen)

var data: RunData
var progress: RunProgress
var run_seed: int = 0
var floor_index: int = 0
var map: RunMap
var screen: Screen = Screen.MAP

## This floor's boss (its cheat), drawn on entering the floor and shown on the map.
var boss: RunRuleData
## Floor 3: the boss's extra Elite twist (else null).
var boss_twist: RunRuleData

## Table / Elite / Boss being played.
var goal: TableGoal
var table_type: NT = NT.TABLE
## Elite: its twist; Boss: cheat (+ twist). Passed to the table in the setup.
var rules: Array[RunRuleData] = []
var boss_misses: int = 0
## Tables finished this run (the first one gets the tutorial seeds).
var tables_played: int = 0

## Reward screen: Seal options (combo ids, or rare Seal ids) and Elite dice.
var seal_options: Array[StringName] = []
var dice_options: Array[SpecialDieData] = []

var event: EventData
var _events_seen: Array[StringName] = []

## Shop offers (bought ones become null / &"").
var shop_dice: Array[SpecialDieData] = []
var shop_mods: Array[FaceModData] = []
var shop_seals: Array[StringName] = []
var shop_seals_bought: int = 0
var shop_rerolls: int = 0
## Rest: the face mod the free carve offers.
var rest_mod: FaceModData


func _init(run_data: RunData, seed_value: int) -> void:
	data = run_data
	run_seed = seed_value
	progress = RunProgress.new(data)
	_start_floor(0)


func floor_data() -> FloorData:
	return data.floors[floor_index]


func _rng(purpose: StringName, extra: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, floor_index, map.current_id if map != null else -1, purpose, extra])
	return r


func _set_screen(s: Screen) -> void:
	screen = s
	screen_changed.emit(s)


static func _pick_rule(pool: Array[RunRuleData], rng: RandomNumberGenerator) -> RunRuleData:
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


func _start_floor(i: int) -> void:
	floor_index = i
	map = null
	map = MapGenerator.generate(floor_data().map, hash([run_seed, i, &"map"]))
	var rng := _rng(&"boss")
	boss = _pick_rule(floor_data().boss_cheats, rng)
	boss_twist = _pick_rule(floor_data().elite_twists, rng) if floor_data().boss_adds_twist else null
	boss_misses = 0
	_set_screen(Screen.MAP)


func boss_name() -> String:
	return boss.display_name if boss != null else "Boss"


## Travel to a reachable node and open its screen.
func choose_node(id: int) -> bool:
	if screen != Screen.MAP or not map.travel_to(id):
		return false
	var t: NT = map.current().type
	match t:
		NT.TABLE, NT.ELITE, NT.BOSS:
			table_type = t
			goal = make_goal(t)
			_set_screen(Screen.TABLE)
		NT.EVENT:
			event = _pick_event()
			_set_screen(Screen.EVENT)
		NT.SHOP:
			shop_seals_bought = 0
			shop_rerolls = 0
			_roll_shop()
			_set_screen(Screen.SHOP)
		NT.REST:
			var mods := data.face_mods
			rest_mod = mods[_rng(&"rest").randi_range(0, mods.size() - 1)] if not mods.is_empty() else null
			_set_screen(Screen.REST)
	return true


## Build the table goal (and `rules`) for this node from the floor's pools.
func make_goal(t: NT) -> TableGoal:
	var f := floor_data()
	var rng := _rng(&"goal", boss_misses)
	var g := TableGoal.new()
	g.clear_embers = f.clear_embers
	g.timeout_soul_per_bounty = f.timeout_soul_per_bounty
	var count: int = rng.randi_range(f.min_bounties, f.max_bounties)
	g.hands = f.hands
	g.display_name = "Table"
	rules.clear()
	if t == NT.BOSS:
		count = rng.randi_range(f.boss_min_bounties, f.boss_max_bounties)
		g.hands = f.boss_hands
		g.display_name = boss_name()
		for r in [boss, boss_twist]:
			if r != null:
				rules.append(r)
	elif t == NT.ELITE:
		g.display_name = "Elite Table"
		var tw := _pick_rule(f.elite_twists, rng)
		if tw != null:
			rules.append(tw)
	for r in rules:
		g.hands += r.hands_delta
	g.hands = maxi(g.hands, 1)
	var picks: Array[BountyData] = []
	if not f.featured_bounties.is_empty():
		picks.append(f.featured_bounties[rng.randi_range(0, f.featured_bounties.size() - 1)])
	var pool: Array[BountyData] = f.common_bounties.duplicate()
	pool.append_array(f.featured_bounties)
	if t == NT.BOSS:
		pool.append_array(f.boss_bounties)
	while picks.size() < count and not pool.is_empty():
		var b: BountyData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if not picks.has(b):
			picks.append(b)
	g.required = picks
	if not f.bonus_bounties.is_empty():
		g.bonus = [f.bonus_bounties[rng.randi_range(0, f.bonus_bounties.size() - 1)]] as Array[BountyData]
	return g


## What the table gets for this node (dice, mods, goal, Soul, seed, rules).
func table_setup() -> RunTableSetup:
	var s := RunTableSetup.new()
	s.goal = goal
	s.dice = progress.dice.duplicate()
	s.table_dice = progress.table_dice()
	s.owned_dice_count = progress.dice.size()
	s.start_soul = progress.soul
	s.max_soul = progress.max_soul
	s.seed_value = hash([run_seed, floor_index, map.current_id, &"table", boss_misses])
	s.first_table = tables_played == 0
	s.rules = rules.duplicate()
	for r in rules:
		if r.bust_soul_loss >= 0:
			s.bust_soul_loss = r.bust_soul_loss
	for c in data.seal_combos:
		s.seal_bonus[c] = progress.seal_bonus(c)
	return s


## The table ended (3D Bonfire or the stub). soul_after = the run's Soul now;
## embers = everything the table paid; banked = combo ids banked (Black Seal).
func finish_table(cleared: bool, soul_after: int, embers: int, banked: Array[StringName] = []) -> void:
	if screen != Screen.TABLE:
		return
	tables_played += 1
	progress.change_soul(soul_after - progress.soul)
	progress.change_embers(embers)
	progress.record_banks(banked)
	if progress.is_over():
		_set_screen(Screen.RUN_OVER)
		return
	if not cleared:
		if table_type == NT.BOSS:
			boss_misses += 1
			if boss_misses > data.boss_resits:
				_set_screen(Screen.RUN_OVER)
				return
			goal = make_goal(NT.BOSS)
			_set_screen(Screen.TABLE)
			return
		_set_screen(Screen.MAP)
		return
	if table_type == NT.BOSS:
		progress.change_embers(data.boss_embers)
		progress.gain_contract_piece()
	_roll_rewards()
	_set_screen(Screen.REWARD)


## The 3D table's result (Bonfire3D.finished): Soul after it (bust, timeout
## or forfeit penalties included), every Ember it paid, cleared or not (a
## forfeit is a miss; at the boss that's a re-sit or the end of the run).
## Dice the table shattered (Cracked) leave the bag for good, mods and all;
## each banked pot's combo counts toward the Black Seal.
func apply_outcome(o: TableOutcome) -> void:
	progress.remove_dice(o.shattered_dice)
	finish_table(o.cleared and not o.forfeited, o.soul_after, o.embers, o.banked_combos)


## STUB table: resolve instantly. A clear pays the floor's clear Embers; a
## miss costs Soul for every required bounty (as if none were banked).
func quick_resolve(cleared: bool) -> void:
	if goal == null:
		return
	var lost: int = 0 if cleared else goal.required.size() * goal.timeout_soul_per_bounty
	finish_table(cleared, progress.soul - lost, goal.clear_embers if cleared else 0)


func _roll_rewards() -> void:
	var rng := _rng(&"reward", boss_misses)
	var n: int = data.elite_seal_pick_options if table_type == NT.ELITE else data.seal_pick_options
	seal_options = _seal_offers(rng, n)
	if table_type == NT.BOSS and not data.rare_seals.is_empty():
		var rares: Array[StringName] = []
		for r in data.rare_seals:
			if not seal_options.has(r):
				rares.append(r)
		if not rares.is_empty():
			seal_options.append(rares[rng.randi_range(0, rares.size() - 1)])
	dice_options.clear()
	if table_type == NT.ELITE:
		dice_options = _dice_offers(rng, data.elite_dice_options)


func _seal_offers(rng: RandomNumberGenerator, n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var pool: Array[StringName] = data.seal_combos.duplicate()
	while out.size() < n and not pool.is_empty():
		if not data.rare_seals.is_empty() and rng.randf() < data.rare_seal_chance:
			var r: StringName = data.rare_seals[rng.randi_range(0, data.rare_seals.size() - 1)]
			if not out.has(r):
				out.append(r)
				continue
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func is_rare_seal(id: StringName) -> bool:
	return data.rare_seals.has(id)


## Can Seal `id` be used right now with these choices? Rare Seals take
## params: Transference {"from", "to"}, Ashen {"from", "to"}; Black none.
func seal_usable(id: StringName, params: Dictionary = {}) -> bool:
	match id:
		&"black":
			return progress.most_banked() != &""
		&"transference":
			var f: StringName = params.get("from", &"")
			return progress.seal_bonus(f).y > 0 and data.seal_combos.has(params.get("to", &"")) and params.get("to") != f
		&"ashen":
			var f: StringName = params.get("from", &"")
			var i: int = data.seal_combos.find(f)
			var j: int = data.seal_combos.find(params.get("to", &""))
			return progress.seal_level(f) > 0 and i >= 0 and j > i
	return data.seal_combos.has(id)


func _grant_seal(id: StringName, params: Dictionary) -> bool:
	if not seal_usable(id, params):
		return false
	match id:
		&"black":
			progress.black_seal()
		&"transference":
			progress.transference(params["from"], params["to"], data.transference_max_mult)
		&"ashen":
			progress.ashen_seal(params["from"], params["to"])
		_:
			progress.add_seal_levels(id, 1)
	return true


## Elite reward: take special die i (one only; then the Seal pick).
func take_die(i: int) -> bool:
	if screen != Screen.REWARD or i < 0 or i >= dice_options.size() or not progress.add_die(dice_options[i].id):
		return false
	dice_options.clear()
	return true


## Take Seal option i (rare Seals need params), or i = -1 to skip for Embers.
func take_seal(i: int, params: Dictionary = {}) -> bool:
	if screen != Screen.REWARD or i >= seal_options.size():
		return false
	if i < 0:
		progress.change_embers(data.seal_skip_embers)
	elif not _grant_seal(seal_options[i], params):
		return false
	seal_options.clear()
	dice_options.clear()
	if table_type == NT.BOSS:
		if floor_index + 1 >= data.floors.size():
			_set_screen(Screen.RUN_WON if progress.contract_pieces >= data.contract_pieces_to_win else Screen.RUN_OVER)
		else:
			_start_floor(floor_index + 1)
		return true
	_set_screen(Screen.MAP)
	return true


func _pick_event() -> EventData:
	var pool: Array[EventData] = []
	for e in data.events:
		if not _events_seen.has(e.id):
			pool.append(e)
	if pool.is_empty():
		_events_seen.clear()
		pool = data.events.duplicate()
	var e: EventData = pool[_rng(&"event").randi_range(0, pool.size() - 1)]
	_events_seen.append(e.id)
	return e


## Resolve event choice i. Returns the applier's log ([] if not allowed).
func choose_event(i: int, picks: Array[Vector2i] = []) -> Array[String]:
	if screen != Screen.EVENT or i < 0 or i >= event.choices.size():
		return []
	var lines := EventApplier.apply(event.choices[i], progress, _rng(&"event_fx", i), picks)
	if not lines.is_empty() and lines[0].begins_with("refused"):
		return lines
	_set_screen(Screen.RUN_OVER if progress.is_over() else Screen.MAP)
	return lines


# --- Rest (spec 1: pick one) ---

func rest_heal() -> bool:
	if screen != Screen.REST:
		return false
	progress.change_soul(data.rest_heal)
	_set_screen(Screen.MAP)
	return true


func rest_carve(pick: Vector2i) -> bool:
	if screen != Screen.REST or rest_mod == null or not free_face(pick):
		return false
	progress.set_face(pick.x, pick.y, rest_mod.id)
	_set_screen(Screen.MAP)
	return true


## A face a new mod can go on: unmodded, or Blank (carving over a curse).
func free_face(pick: Vector2i) -> bool:
	return pick.x >= 0 and pick.x < progress.dice.size() and pick.y >= 0 and pick.y < progress.dice[pick.x].faces.size() \
		and progress.dice[pick.x].faces[pick.y] in [&"", RunDie.BLANK]


func owned_seals() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in data.seal_combos:
		if progress.seal_level(c) > 0:
			out.append(c)
	return out


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
	var rng := _rng(&"shop", shop_rerolls)
	shop_dice.clear()
	shop_dice = _dice_offers(rng, data.shop_dice)
	shop_mods.clear()
	var mpool: Array[FaceModData] = data.face_mods.duplicate()
	while shop_mods.size() < data.shop_mods and not mpool.is_empty():
		shop_mods.append(mpool.pop_at(rng.randi_range(0, mpool.size() - 1)))
	shop_seals = _seal_offers(rng, data.shop_seals)


func seal_price(id: StringName) -> int:
	if is_rare_seal(id):
		return data.shop_rare_seal_price
	return data.shop_seal_price + data.shop_seal_step * shop_seals_bought


func reroll_price() -> int:
	return data.reroll_base + data.reroll_step * shop_rerolls


func _pay(cost: int) -> bool:
	if screen != Screen.SHOP or cost < 0 or progress.embers < cost:
		return false
	progress.change_embers(-cost)
	return true


func shop_reroll() -> bool:
	if not _pay(reroll_price()):
		return false
	shop_rerolls += 1
	_roll_shop()
	return true


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


func leave() -> void:
	if screen == Screen.SHOP or screen == Screen.REST:
		_set_screen(Screen.MAP)
