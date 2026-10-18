## The run's screen director: shows the map, then the screen of the node
## you picked (Event, Shop, Rest, Table / Elite / Boss, Seal reward), and
## the run's Soul / Embers / Seals on a top bar. All rules live in MapRun;
## this only displays them and forwards clicks.
##
## Tables: "Play at the table" opens Bonfire3D in run mode with a TableSetup
## (the run's dice and mods, Soul, Seal-leveled combos, this node's goal) and
## applies its finished(TableOutcome);
## "Stub: clear / miss" resolves instantly for quick playthroughs.
## Launch: godot --path . res://scenes/run.tscn
class_name RunScreen
extends Node

const S := MapRun.Screen
const NT := MapGenData.NodeType

@export var run_data: RunData
@export var bonfire_tuning: BonfireTuning
## -1 = a random run each launch.
@export var run_seed: int = -1

var run: MapRun
var map_view: MapView
var event_view: EventView
var _ui: CanvasLayer
var _bar: Label
var _panel_root: CenterContainer
var _panel_box: VBoxContainer
var _table: Bonfire3D


func _ready() -> void:
	if run_data == null:
		run_data = load("res://resources/map/bonfire_run.tres") as RunData
	if bonfire_tuning == null:
		bonfire_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_ui = CanvasLayer.new()
	add_child(_ui)
	var bg := ColorRect.new()
	bg.color = RunTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(bg)
	map_view = MapView.new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.node_pressed.connect(func(id: int) -> void: run.choose_node(id))
	_ui.add_child(map_view)
	event_view = EventView.new()
	event_view.choice_made.connect(_on_event_choice)
	_ui.add_child(event_view)
	_panel_root = CenterContainer.new()
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel_root)
	var p := RunTheme.panel()
	p.custom_minimum_size = Vector2(900, 0)
	_panel_root.add_child(p)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	p.add_child(_panel_box)
	_bar = RunTheme.label("", 22, RunTheme.GOLD)
	_bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar.position = Vector2(20, 8)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bar)
	new_run(run_seed)


func new_run(seed_value: int) -> void:
	if seed_value < 0:
		seed_value = randi()
	run = MapRun.new(run_data, seed_value)
	run.screen_changed.connect(func(_s: S) -> void: refresh())
	run.progress.changed.connect(_refresh_bar)
	refresh()


func refresh() -> void:
	_refresh_bar()
	map_view.visible = run.screen == S.MAP
	event_view.visible = run.screen == S.EVENT
	_panel_root.visible = not (map_view.visible or event_view.visible)
	match run.screen:
		S.MAP:
			map_view.show_map(run.map, run.boss_name(), _boss_rules())
		S.EVENT:
			event_view.show_event(run.event, run.progress)
		S.TABLE:
			_show_table()
		S.REWARD:
			_show_reward()
		S.REST:
			_show_rest()
		S.SHOP:
			_show_shop()
		S.RUN_WON:
			_panel("Run Won", ["The contract is whole: %d/%d pieces. (Placeholder win screen.)" % [run.progress.contract_pieces, run_data.contract_pieces_to_win]],
				[["New run", func() -> void: new_run(-1)]])
		S.RUN_OVER:
			_panel("Your Soul Burns Out", ["The run is over on %s." % run.floor_data().display_name], [["New run", func() -> void: new_run(-1)]])


func _refresh_bar() -> void:
	var p := run.progress
	var seals: Array[String] = []
	for c in p.seal_levels.keys():
		seals.append("%s Lv%d" % [c, p.seal_levels[c] + 1])
	_bar.text = "%s   Soul %d/%d   Embers %d   Dice %d   Contract %d   Seals: %s" % [run.floor_data().display_name,
		p.soul, p.max_soul, p.embers, p.dice.size(), p.contract_pieces, "none" if seals.is_empty() else ", ".join(seals)]


## Fill the centre panel: a title, text lines, and [label, callable(, disabled)] buttons.
func _panel(title: String, lines: Array, buttons: Array, extra: Control = null) -> void:
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()
	_panel_box.add_child(RunTheme.label(title, 40, RunTheme.EMBER, true))
	for l in lines:
		_panel_box.add_child(RunTheme.label(str(l), 24))
	if extra != null:
		_panel_box.add_child(extra)
	for spec: Array in buttons:
		var b := RunTheme.button(spec[0])
		b.disabled = spec.size() > 2 and bool(spec[2])
		b.pressed.connect(spec[1])
		_panel_box.add_child(b)


## The floor boss's cheat (and Floor 3's extra twist), for the map.
func _boss_rules() -> String:
	var out: Array[String] = []
	if run.boss != null:
		out.append(run.boss.description)
	if run.boss_twist != null:
		out.append("Twist: %s - %s" % [run.boss_twist.display_name, run.boss_twist.description])
	return " / ".join(out)


func _show_table() -> void:
	var g := run.goal
	var names: Array[String] = []
	for b in g.required:
		names.append(b.display_name)
	var lines: Array = ["Bounties: " + ", ".join(names), "Bonus: " + (g.bonus[0].display_name if not g.bonus.is_empty() else "none"),
		"Hands: %d" % g.hands]
	for r in run.rules:
		lines.append("%s: %s - %s" % ["Cheat" if r.kind == RunRuleData.Kind.CHEAT else "Twist", r.display_name, r.description])
	if not run.rules.is_empty():
		lines.append("(Rules are passed to the table; enforcement is Godot Dev's setup-driven table.)")
	if run.table_type == NT.BOSS:
		if run.boss_misses > 0:
			lines.append("Re-sit: one more miss ends the run.")
	_panel(g.display_name, lines, [["Play at the table", _play_table],
		["Stub: clear", func() -> void: run.quick_resolve(true)], ["Stub: miss", func() -> void: run.quick_resolve(false)]])


func _play_table() -> void:
	var t := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	t.setup = run.table_setup().to_table_setup(bonfire_tuning)
	_table = t
	_ui.visible = false
	add_child(t)
	t.finished.connect(_on_table_finished)


## Bonfire3D.finished (CONTINUE on its end panel): apply the outcome, free
## the table (run mode never changes scenes) and go on.
func _on_table_finished(o: TableOutcome) -> void:
	if _table != null:
		_table.queue_free()
		_table = null
	_ui.visible = true
	run.apply_outcome(o)


func _show_reward() -> void:
	var buttons: Array = []
	var lines: Array = ["Cleared! Take a free Seal, or skip for %d Embers." % run_data.seal_skip_embers]
	if not run.dice_options.is_empty():
		lines.append("Elite spoils: take one special die.")
		for i in run.dice_options.size():
			buttons.append(["Take the %s (%s)" % [run.dice_options[i].display_name, run.dice_options[i].description], func() -> void:
				run.take_die(i)
				_show_reward(), not run.progress.can_add_die()])
	for i in run.seal_options.size():
		var id := run.seal_options[i]
		var txt: String = ("%s (rare Seal)" % String(id).capitalize()) if run.is_rare_seal(id) \
			else "%s Seal -> Lv%d" % [String(id).capitalize(), run.progress.seal_level(id) + 2]
		buttons.append([txt, func() -> void: _seal_with_params(id, func(params: Dictionary) -> bool: return run.take_seal(i, params)),
			not _seal_possible(id)])
	buttons.append(["Skip (+%d Embers)" % run_data.seal_skip_embers, func() -> void: run.take_seal(-1)])
	_panel("Seal Reward", lines, buttons)


func _show_rest() -> void:
	var buttons: Array = [["Heal %d Soul" % run_data.rest_heal, func() -> void: run.rest_heal()]]
	if run.rest_mod != null:
		buttons.append(["Carve a free %s" % run.rest_mod.display_name, func() -> void:
			_pick("Pick a face for the %s" % run.rest_mod.display_name, func(at: Vector2i) -> void: run.rest_carve(at))])
	for c in run.owned_seals():
		buttons.append(["%s Seal +%d" % [String(c).capitalize(), run_data.rest_seal_levels], func() -> void: run.rest_seal(c)])
	if run.owned_seals().is_empty():
		buttons.append(["+1 Seal level (you own none yet)", func() -> void: pass, true])
	_panel("The Lounge", ["Rest a moment. Pick one."], buttons)


func _show_shop() -> void:
	var e: int = run.progress.embers
	var buttons: Array = []
	for i in run.shop_dice.size():
		var d := run.shop_dice[i]
		if d != null:
			buttons.append(["%s - %d Embers (%s)" % [d.display_name, d.price, d.description],
				func() -> void: run.buy_die(i); _show_shop(), e < d.price or not run.progress.can_add_die()])
	for i in run.shop_mods.size():
		if run.shop_mods[i] != null:
			var m := run.shop_mods[i]
			buttons.append(["%s - from %d Embers (+%d%% per mod on the die)" % [m.display_name, m.price, run_data.mod_price_step_percent], func() -> void:
				_pick("Pick a face for the %s" % m.display_name, func(at: Vector2i) -> void:
					run.buy_mod(i, at)
					_show_shop()), e < m.price])
	for i in run.shop_seals.size():
		if run.shop_seals[i] != &"":
			var id := run.shop_seals[i]
			buttons.append(["%s Seal - %d Embers" % [String(id).capitalize(), run.seal_price(id)],
				func() -> void: _seal_with_params(id, func(params: Dictionary) -> bool:
					var ok := run.buy_seal(i, params)
					_show_shop()
					return ok), e < run.seal_price(id) or not _seal_possible(id)])
	for d_i in run.progress.dice.size():
		var sd := run.progress.special_die(run.progress.dice[d_i].special_id)
		if sd != null and run.progress.sell_value(d_i) > 0:
			buttons.append(["Sell your %s (+%d Embers)" % [sd.display_name, run.progress.sell_value(d_i)],
				func() -> void: run.sell_die(d_i); _show_shop()])
	buttons.append(["Reroll - %d Embers" % run.reroll_price(), func() -> void: run.shop_reroll(); _show_shop(), e < run.reroll_price()])
	buttons.append(["Leave", func() -> void: run.leave()])
	_panel("The Ember Shop", ["A mod costs more for each mod already on that die. Dice sell for half."], buttons)


func _pick(prompt: String, done: Callable) -> void:
	var picker := FacePicker.new()
	picker.build(run.progress, prompt, func(at: Vector2i) -> bool: return run.free_face(at))
	picker.picked.connect(done)
	_panel("Carve", [], [["Back", refresh]], picker)


## Could rare Seal `id` be used with some choice right now?
func _seal_possible(id: StringName) -> bool:
	if not run.is_rare_seal(id) or id == &"black":
		return run.seal_usable(id)
	for f in run_data.seal_combos:
		for t in run_data.seal_combos:
			if run.seal_usable(id, {"from": f, "to": t}):
				return true
	return false


## Transference / Ashen ask "from" then "to"; everything else applies at once.
func _seal_with_params(id: StringName, apply: Callable) -> void:
	if id != &"transference" and id != &"ashen":
		apply.call({})
		return
	var froms: Array = []
	for f in run_data.seal_combos:
		var ok := false
		for t in run_data.seal_combos:
			ok = ok or run.seal_usable(id, {"from": f, "to": t})
		if ok:
			froms.append([String(f).capitalize(), func() -> void:
				var tos: Array = []
				for t in run_data.seal_combos:
					if run.seal_usable(id, {"from": f, "to": t}):
						tos.append([String(t).capitalize(), func() -> void: apply.call({"from": f, "to": t})])
				tos.append(["Back", refresh])
				_panel("%s Seal: to which combo?" % String(id).capitalize(), ["From %s." % String(f).capitalize()], tos)])
	froms.append(["Back", refresh])
	_panel("%s Seal: from which combo?" % String(id).capitalize(), [], froms)


func _on_event_choice(i: int, picks: Array[Vector2i]) -> void:
	var text := run.event.choices[i].result_text
	var lines := run.choose_event(i, picks)
	if run.screen == S.EVENT:
		event_view.show_event(run.event, run.progress)
		return
	# Show the outcome over the event before going back to the map.
	map_view.visible = false
	event_view.visible = true
	event_view.show_result(text, lines, refresh)
