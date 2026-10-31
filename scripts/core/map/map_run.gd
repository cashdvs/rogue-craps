## Drives a Bonfire run across its floors (map/events spec §1): travel on the
## map, then the node's screen (Table / Elite / Boss, Event, Shop, Rest), the
## Seal reward after a cleared fight, the boss re-sit, contract pieces and
## the next floor. Pure logic: RunScreen shows `screen` and calls these.
##
## Seeds: every random choice uses an RNG seeded from hash([run seed, floor,
## node id, purpose]), so a run replays identically and nothing is shared.
## State: MapRunState; Shop / Rest: MapRunShop.
class_name MapRun
extends MapRunShop


func _init(run_data: RunData, seed_value: int) -> void:
	data = run_data
	run_seed = seed_value
	progress = RunProgress.new(data)
	_start_floor(0)


func _start_floor(i: int) -> void:
	floor_index = i
	map = null
	map = MapGenerator.generate(floor_data().map, hash([run_seed, i, &"map"]))
	var rng := _rng(&"boss")
	boss = _pick_rule(floor_data().boss_cheats, rng)
	boss_twist = null
	if floor_data().boss_adds_twist:
		var twists: Array[RunRuleData] = []
		for t in floor_data().elite_twists:
			if boss == null or not boss.same_effect(t):
				twists.append(t)
		boss_twist = _pick_rule(twists, rng)
	boss_misses = 0
	progress.next_table_twist = null  # an unplayed event twist expires with the floor
	_set_screen(Screen.MAP)


## The floor boss's name (its cheat), or "Boss".
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
			if event == null:
				_open_event_fallback()
			else:
				_set_screen(Screen.EVENT)
		NT.SHOP:
			shop_seals_bought = 0
			shop_rerolls = 0
			shop_free_rerolls = 0
			_roll_shop()
			_set_screen(Screen.SHOP)
		NT.REST:
			var mods := data.face_mods
			rest_mod = mods[_rng(&"rest").randi_range(0, mods.size() - 1)] if not mods.is_empty() else null
			_set_screen(Screen.REST)
	return true


## Map preview for the next regular Table: "Next Table: <twist> (<text>)"
## while an event twist is pending, else "".
func pending_twist_note() -> String:
	var r := progress.next_table_twist
	return "Next Table: %s (%s)" % [r.display_name, r.description] if r != null else ""


## Build the table goal (and `rules`) for this node from the floor's pools.
func make_goal(t: NT) -> TableGoal:
	var f := floor_data()
	var rng := _rng(&"goal", boss_misses)
	var g := TableGoal.new()
	g.clear_embers = f.clear_embers
	g.timeout_soul_per_bounty = f.timeout_soul_per_bounty
	g.hands = f.hands
	g.display_name = "Table"
	rules.clear()
	if t == NT.BOSS:
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
	# An event twist rides on the next regular Table only, then clears.
	if t == NT.TABLE and progress.next_table_twist != null:
		if not rules.has(progress.next_table_twist):
			rules.append(progress.next_table_twist)
		progress.next_table_twist = null
	for r in rules:
		g.hands += r.hands_delta
	g.hands = maxi(g.hands, 1)
	# table_goals_v1 PR1: target-only, no bounties rolled (keeps the rule
	# RNG draws above stable).
	g.target = f.target_boss if t == NT.BOSS else (f.target_elite if t == NT.ELITE else f.target_table)
	g.miss_soul = f.miss_soul
	g.is_boss = t == NT.BOSS
	return g


## What the table gets for this node (dice, mods, goal, Soul, seed, rules).
func table_setup() -> RunTableSetup:
	var s := RunTableSetup.new()
	s.goal = goal
	s.dice = progress.dice.duplicate()
	s.table_dice = progress.table_dice()
	s.owned_dice_count = progress.dice.size()
	s.run_embers = progress.embers
	s.start_soul = progress.soul
	s.max_soul = progress.max_soul
	s.seed_value = hash([run_seed, floor_index, map.current_id, &"table", boss_misses])
	s.first_table = tables_played == 0
	s.nerve_uses = data.nerve_uses
	s.seal_steps = NonStdDice.seal_steps(data)
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
		_end(&"soul")
		return
	if not cleared:
		if table_type == NT.BOSS:
			boss_misses += 1
			if boss_misses > data.boss_resits:
				_end(&"boss")
				return
			goal = make_goal(NT.BOSS)
			_set_screen(Screen.TABLE)
			return
		_set_screen(Screen.MAP)
		return
	tables_cleared += 1
	if table_type == NT.BOSS and data.is_last_floor(floor_index):
		progress.change_embers(data.boss_embers)
		_end(&"complete")
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
	_record_score(o.points, o.banked_combos)
	finish_table(o.cleared and not o.forfeited, o.soul_after, o.embers, o.banked_combos)


## STUB table: resolve instantly. A clear pays the floor's clear Embers; a
## miss costs the goal's flat miss Soul.
func quick_resolve(cleared: bool) -> void:
	if goal == null:
		return
	var lost: int = 0 if cleared else goal.miss_soul
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
			_end(&"won" if progress.contract_pieces >= data.contract_pieces_to_win else &"contract")
		else:
			_start_floor(floor_index + 1)
		return true
	_set_screen(Screen.MAP)
	return true


## A floor event worth offering here (EventPicker), or null.
func _pick_event() -> EventData:
	return EventPicker.pick(data.events, _events_seen, floor_index + 1, progress, table_ahead(), _rng(&"event"))


## No event is worth offering: the node becomes a Rest (shown as one on the map).
func _open_event_fallback() -> void:
	map.current().type = NT.REST
	var mods := data.face_mods
	rest_mod = mods[_rng(&"rest").randi_range(0, mods.size() - 1)] if not mods.is_empty() else null
	_set_screen(Screen.REST)


## Is a regular Table still reachable (so unplayed) on this floor?
func table_ahead() -> bool:
	return EventPicker.table_ahead(map)


## Resolve event choice i. Returns the applier's log ([] if not allowed).
func choose_event(i: int, picks: Array[Vector2i] = []) -> Array[String]:
	if screen != Screen.EVENT or i < 0 or i >= event.choices.size():
		return []
	var lines := EventApplier.apply(event.choices[i], progress, _rng(&"event_fx", i), picks, table_ahead())
	if not lines.is_empty() and lines[0].begins_with("refused"):
		return lines
	if progress.is_over():
		_end(&"soul")
	else:
		_set_screen(Screen.MAP)
	return lines


func _end(reason: StringName) -> void:
	end_reason = reason
	_set_screen(Screen.RUN_WON if reason in [&"won", &"complete"] else Screen.RUN_OVER)


