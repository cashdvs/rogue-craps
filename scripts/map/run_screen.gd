## The run's screen director: shows the map, then the screen of the node
## you picked (Event, Shop, Rest, Table / Elite / Boss, Seal reward), and
## the run's Soul / Embers / Seals on a top bar. All rules live in MapRun;
## this only displays them and forwards clicks.
##
## Tables: "Play at the table" opens Bonfire3D in run mode with a TableSetup
## (the run's dice and mods, Soul, Seal-leveled combos, this node's goal) and
## applies its finished(TableOutcome);
## "Stub: clear / miss" (resolve instantly, for quick playthroughs) only
## show with debug_table_stubs on in a debug build; never in release.
## Launch: godot --path . res://scenes/run.tscn
class_name RunScreen
extends Node

const S := MapRun.Screen
const NT := MapGenData.NodeType

@export var run_data: RunData
@export var bonfire_tuning: BonfireTuning
## Dev only: show "Stub: clear / miss" at tables. Off by default, and
## ignored outside debug builds (OS.is_debug_build()), so exported games
## never show it. Tests and capture tools switch it on.
@export var debug_table_stubs: bool = false
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
## The visual shop counter (ShopScreen); shown only on the Shop screen.
var shop_screen: ShopScreen
## Map screen: "Quit to title" (asks first; the run is lost).
var quit_button: Button
## Map screen: "Your dice" (D) and "Key" (K) on the top bar.
var bag_button: Button
var key_button: Button
var map_key: MapKey
## Boss intro sign (BossSign), or null. Tests / captures read it.
var boss_sign: TextureRect
## Tests: treat the window as this many pixels tall when picking @1x / @2x
## sign art (0 = the real window).
var sign_px_height: int = 0
const TITLE_SCENE := "res://scenes/title.tscn"


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
	shop_screen = ShopScreen.new()
	shop_screen.visible = false
	_ui.add_child(shop_screen)
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
	quit_button = RunTheme.button("Quit to title", 20)
	quit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quit_button.offset_left = -240
	quit_button.offset_right = -20
	quit_button.offset_top = 8
	quit_button.pressed.connect(ask_quit)
	_ui.add_child(quit_button)
	bag_button = _bar_button("Your dice", -480, show_dice)
	key_button = _bar_button("Key", -620, func() -> void: map_key.visible = not map_key.visible)
	map_key = MapKey.new()
	_ui.add_child(map_key)
	new_run(run_seed)


## Start a new run (seed < 0 = random) and show its map.
func new_run(seed_value: int) -> void:
	if seed_value < 0:
		seed_value = randi()
	run = MapRun.new(run_data, seed_value)
	run.screen_changed.connect(func(_s: S) -> void: refresh())
	run.progress.changed.connect(_refresh_bar)
	# Opens by itself once per profile (RunProfile), then only via Key / K.
	map_key.visible = not RunProfile.map_key_seen()
	if map_key.visible:
		RunProfile.mark_map_key_seen()
	run.screen_changed.connect(func(_s: S) -> void:
		if run.floor_index > 0 and run.screen == S.MAP and run.map.current_id == -1:
			map_key.visible = false)
	refresh()


func _bar_button(text: String, left: float, on_press: Callable) -> Button:
	var b := RunTheme.button(text, 20)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = left
	b.offset_right = left + 220 if text != "Key" else left + 120
	b.offset_top = 8
	b.pressed.connect(on_press)
	_ui.add_child(b)
	return b


## K toggles the map key, D opens / closes "Your dice" (map only).
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or run.screen != S.MAP or _table != null:
		return
	if k.keycode == KEY_K and map_view.visible:
		map_key.visible = not map_key.visible
	elif k.keycode == KEY_D:
		refresh() if not map_view.visible else show_dice()


## The read-only "Your dice" view (dice cards + Your Seals), from the map.
func show_dice() -> void:
	map_view.visible = false
	for b in [quit_button, bag_button, key_button, map_key]:
		b.visible = false
	_panel_root.visible = true
	var dp := DicePanel.new()
	dp.build(run.progress, {"combos": bonfire_tuning.combos})
	_panel("Your dice", [], [["Close", refresh]], dp)


## Show the screen for run.screen and update the bar.
func refresh() -> void:
	_refresh_bar()
	map_view.visible = run.screen == S.MAP
	event_view.visible = run.screen == S.EVENT
	_panel_root.visible = not (map_view.visible or event_view.visible)
	shop_screen.visible = false
	_bar.visible = run.screen != S.SHOP
	quit_button.visible = map_view.visible
	bag_button.visible = map_view.visible
	key_button.visible = map_view.visible
	if not map_view.visible:
		map_key.visible = false
	match run.screen:
		S.MAP:
			map_view.show_map(run.map, run.boss_name(), TablePreview.boss_rules(run), run.pending_twist_note())
		S.EVENT:
			event_view.show_event(run.event, run.progress, run.table_ahead())
		S.TABLE:
			_show_table()
		S.REWARD:
			_show_reward()
		S.REST:
			_show_rest()
		S.SHOP:
			_show_shop()
		S.RUN_WON, S.RUN_OVER:
			var lines: Array = [RunSummary.reason_line(run)]
			lines.append_array(RunSummary.lines(run))
			_panel(RunSummary.title(run), lines, [["New run", func() -> void: new_run(-1)], ["Quit to title", quit_to_title]])


func _refresh_bar() -> void:
	var p := run.progress
	_bar.text = "%s   Soul %d/%d   Embers %d   Dice %d   Contract %d   Seals %d   Seed %d" % [run.floor_data().display_name,
		p.soul, p.max_soul, p.embers, p.dice.size(), p.contract_pieces, run.owned_seals().size(), run.run_seed]


## Fill the centre panel: a title, text lines, and [label, callable(, disabled)] buttons.
func _panel(title: String, lines: Array, buttons: Array, extra: Control = null) -> void:
	shop_screen.visible = false
	_panel_root.visible = true
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


## Confirm before leaving the run for the title screen.
func ask_quit() -> void:
	map_view.visible = false
	quit_button.visible = false
	_panel_root.visible = true
	_panel("Quit to title?", ["This run will be lost."],
		[["Quit to title", quit_to_title], ["Keep playing", refresh]])


## Leave the run for the title screen (no confirm; ask_quit asks first).
func quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


func _show_table() -> void:
	var g := run.goal
	var names: Array[String] = []
	for b in g.required:
		names.append(b.display_name)
	var lines: Array = ["Bounties: " + ", ".join(names), "Bonus: " + (g.bonus[0].display_name if not g.bonus.is_empty() else "none"),
		"Hands: %d" % g.hands, "Miss: -%d Soul per unclaimed bounty." % g.timeout_soul_per_bounty]
	for r in run.rules:
		lines.append("%s: %s - %s" % ["Cheat" if r.kind == RunRuleData.Kind.CHEAT else "Twist", r.display_name, r.text(g.hands)])
	if run.table_type == NT.BOSS:
		if run.boss_misses > 0:
			lines.append("Re-sit: one more miss ends the run.")
	var buttons: Array = [["Play at the table", _play_table]]
	if stubs_enabled():
		buttons.append(["Stub: clear", func() -> void: run.quick_resolve(true)])
		buttons.append(["Stub: miss", func() -> void: run.quick_resolve(false)])
	_panel(g.display_name, lines, buttons, TablePreview.dice_row(run.progress, show_dice))
	boss_sign = TablePreview.add_boss_sign(_panel_box, run, _px_height(), get_viewport().get_visible_rect().size.x) \
		if run.table_type == NT.BOSS else null


## Window height in pixels (for @1x / @2x sign art).
func _px_height() -> int:
	return sign_px_height if sign_px_height > 0 else get_window().size.y


## Dev stub buttons at tables: only with debug_table_stubs in a debug build.
func stubs_enabled() -> bool:
	return debug_table_stubs and OS.is_debug_build()


func _play_table() -> void:
	var t := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	t.setup = run.table_setup().to_table_setup(bonfire_tuning)
	_table = t
	_ui.visible = false
	add_child(t)
	t.finished.connect(_on_table_finished)
	if run.table_type == NT.BOSS:
		BossSign.attach_to_pause(t.pause_menu, run.boss, _px_height())


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
			else "%s Seal -> Lv%d" % [String(id).capitalize(), run.progress.seal_level(id) + 1]
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


## The shop counter (ShopScreen): goods, the bag row for selling, the reroll.
func _show_shop() -> void:
	_panel_root.visible = false
	shop_screen.visible = true
	shop_screen.build(self)


func _pick(prompt: String, done: Callable, allowed: Callable = Callable(), price: Callable = Callable()) -> void:
	var picker := DicePanel.new()
	picker.build(run.progress, {"prompt": prompt, "seals": false, "price": price,
		"allowed": allowed if allowed.is_valid() else func(at: Vector2i) -> bool: return run.free_face(at)})
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
		event_view.show_event(run.event, run.progress, run.table_ahead())
		return
	# Show the outcome over the event before going back to the map.
	map_view.visible = false
	event_view.visible = true
	event_view.show_result(text, lines, refresh)
