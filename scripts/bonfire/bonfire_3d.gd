## Bonfire sandbox on the 3D table: grab and flick a handful of real dice
## (seeded faces via the pre-sim remap), scoring dice CATCH FIRE, click them
## into the pot on the far rail, then BANK or THROW the cold dice again.
## Rules live in BonfireRun / BonfireScoring; numbers in bonfire_tuning.tres.
##
## Opened by the run: set `setup` (TableSetup: the handful as TableDie with
## faces / weights / face mods, goal, starting + max Soul, tuning, seed)
## BEFORE add_child. Run mode hides Restart / Quit to title, Esc offers
## Forfeit table, and the end panel's CONTINUE emits finished(TableOutcome);
## the table never changes scenes. No setup = the sandbox (5 Bone, Table 1).
## setup.rules (twists / boss cheats) and the handful's special dice become
## TableRule handlers on the BonfireRun; their face changes (Madame Shuffle,
## Mirror) flip the die with a tint before anything lights, a shattered
## Cracked die bursts and leaves the table, the Pit Boss lock is on the felt.
class_name Bonfire3D
extends BonfirePotBank


# This script is the top of a chain of layers, each in its own short file:
#   bonfire_table_state.gd  (BonfireTableState)  signals, constants, variables, queries
#   bonfire_table_look.gd   (BonfireTableLook)   dice looks / decals / lit glow (art seam)
#   bonfire_table_layout.gd (BonfireTableLayout) camera, screen fit, positions
#   bonfire_throw_flow.gd   (BonfireThrowFlow)   one throw: launch, settle, rules, bust
#   bonfire_pot_bank.gd     (BonfirePotBank)     pot, throw again, bank, Hot Hand, Nerve
# This file keeps setup (_ready / new_run), leaving, input and the HUD refresh.


func _ready() -> void:
	# Hints and tutorial seeds live in their own node (BonfireOnboarding).
	onboarding = BonfireOnboarding.new()
	onboarding.name = "Onboarding"
	onboarding.table = self
	add_child(onboarding)
	if setup != null and setup.tuning != null:
		bonfire_tuning = setup.tuning
	if bonfire_tuning == null:
		bonfire_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	if setup == null:
		setup = TableSetup.sandbox(bonfire_tuning, bonfire_tuning.dice_count)
	if setup.dice.is_empty():
		for i in bonfire_tuning.dice_count:
			setup.dice.append(TableDie.new())
	if setup.goal == null:
		setup.goal = bonfire_tuning.table_goal
	if setup.table_seed >= 0:
		bonfire_seed = setup.table_seed
	mode = Mode.RUNNING_TOTAL
	total_dice_per_throw = clampi(setup.dice.size(), 1, MAX_HANDFUL)
	_apply_camera_tuning()
	super()
	# Smiles, or this boss's dealer in his place (BonfireDealerArt).
	dealer_art = BonfireDealerArt.new()
	dealer_art.name = "DealerArtSwap"
	add_child(dealer_art)
	dealer_art.setup(self, setup.rules)
	taunted.connect(func(_e: StringName, _l: String) -> void: dealer_art.taunt())
	# The status line sits between x 520 and 1400, clear of the bottom-left
	# THROW / BANK column (ends at x 494) and the hand at the bottom right.
	why_label.position = Vector2(520, 990)
	why_label.size = Vector2(880, 80)
	total_hud.visible = false
	stack.visible = false
	info_box.visible = false
	puck.visible = false
	help_label.text = "Grab the dice and flick (Space: quick throw). Click lit dice to pot ONE combo.\nB: Bank   Space: throw the rest   T: speed 1x/2x/Instant   R: reduced motion"
	(table.felt_material as ShaderMaterial).set_shader_parameter("use_overlay", false)
	all_dice = dice.duplicate()
	for i in all_dice.size():
		var td: TableDie = setup.dice[mini(i, setup.dice.size() - 1)]
		td.normalize()  # a faces / mods / shape mismatch warns and is padded, never a SCRIPT ERROR
		_die_of[all_dice[i]] = td
		all_dice[i].set_meta(&"handful_id", i)
		apply_die_look(all_dice[i], td)
		PolyBody.dress(all_dice[i], td)  # Gallows / Beacon: d4 / d8 body + hull
	bhud = BonfireHud.new()
	hud.add_child(bhud)
	# Top-left help: the text only on the first table, plus the "?" button
	# (AD spec Addendum A, G1; see help_corner.gd).
	help_corner = HelpCorner.new()
	bhud.add_child(help_corner)
	# A finished count-up ("TRIPS!" / "117") must not stay up while the
	# next throw is picked (QA #160): it fades when the next throw leaves
	# the hand, or as soon as it finishes if it's still counting then.
	thrown.connect(func(_speed: float) -> void: _clear_count_up_when_done())
	bhud.bank_pressed.connect(func() -> void: bank())
	bhud.throw_pressed.connect(func() -> void: throw_again())
	bhud.restart_pressed.connect(func() -> void: new_run(-1 if bonfire_seed < 0 else bonfire_seed + 1))
	bhud.continue_pressed.connect(func() -> void: finish())
	bhud.leave_pressed.connect(func() -> void: leave())
	bhud.set_run_mode(setup.run_mode)
	# Portrait goal readout: follow the screen shape (taller than wide = on).
	get_viewport().size_changed.connect(_update_portrait_hud)
	_update_portrait_hud()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.set_run_mode(setup.run_mode)
	pause_menu.forfeit_confirmed.connect(func() -> void: forfeit())
	pause_menu.can_forfeit = can_forfeit_now
	juice = BonfireJuice.new()
	add_child(juice)
	juice.setup(self)
	# The combo table printed on the felt (replaces the old side panel).
	felt_combos = FeltComboTable.new()
	add_child(felt_combos)
	felt_combos.setup(table.felt_material as ShaderMaterial, bonfire_tuning)
	bhud.cleared_banner.impact.connect(func() -> void:
		if not reduced_motion:
			_camera_shake(tuning.shake_craps_px * 0.25, 0.1))
	_build_throw_debug()
	_update_portrait_hud()
	var cu := bhud.countup
	cu.pip.connect(_on_count_pip)
	cu.slam.connect(func(k: int) -> void:
		if speed_mode != 2:
			juice.slam_sound(k))
	cu.count_tick.connect(func(f: float) -> void:
		bhud.hold_count(f)
		if speed_mode != 2:
			juice.count_sound(f))
	cu.banner.connect(_on_count_banner)
	cu.finished.connect(func() -> void:
		juice.drop(_juice_dice)
		_release_display())
	felt_label = Label3D.new()
	felt_label.name = "RuleFeltText"
	felt_label.font_size = 96
	felt_label.pixel_size = 0.0011
	felt_label.outline_size = 18
	felt_label.modulate = Color("#FF4A3A")
	felt_label.outline_modulate = Color(Palette.PIT_BLACK, 0.85)
	felt_label.rotation_degrees = Vector3(-90, 0, 0)
	felt_label.position = Vector3(0.05, 0.004, -0.33)
	felt_label.shaded = false
	add_child(felt_label)
	new_run(bonfire_seed)


# --- Public API (tests, captures) ----------------------------------------------

func new_run(seed_value: int = -1) -> void:
	bonfire_seed = seed_value
	if seed_value >= 0:
		restart(seed_value)
		_brng.seed = seed_value * 7919 + 3
	else:
		_brng.randomize()
	# Starting Soul never exceeds max Soul.
	var start := setup.starting_soul
	if setup.max_soul > 0:
		start = mini(start, setup.max_soul)
	run = BonfireRun.new(bonfire_tuning, setup.goal, start, setup.dice.size())
	run.seal_steps = setup.seal_steps
	_start_nerve()
	if setup.max_soul > 0:
		run.max_soul = setup.max_soul
	run.owned_dice_count = setup.owned_dice_count if setup.owned_dice_count >= 0 else setup.dice.size()
	var specials: Array = []
	for td in setup.dice:
		specials.append(td.special)
	run.set_rules(TableRules.build(setup.rules, specials), seed_value)
	RareDiceRules.attach_nerve(run, nerve.state)  # Barrel Boom: +1 Nerve this hand (rare_dice_v2 PR 2b)
	run.table_event.connect(_on_table_event)
	if bhud.countup.is_playing():
		bhud.countup.fast_forward()
	bhud.countup.clear(0.0)
	bhud.display_hold = {}
	bhud.pulse_cards([])
	_throw_claims = []
	juice.crowd_start()
	_soul_before = run.soul
	_finished_sent = false
	_cleared_emitted = false
	events.table_started.emit()
	bhud.end_panel.visible = false
	soul_meter.setup(run.soul, run.max_soul)  # hidden; kept as a data mirror
	reliquary.sync(run, false)
	_soul_shown = run.soul
	_reset_hand_dice()
	pause_menu.set_forfeit_enabled(true)
	phase = Phase.BET
	_set_why("Grab the %d dice and flick them. Dice that can score glow." % run.cold)
	help_corner.start_table(help_label, setup.first_table, reduced_motion)
	onboarding.on_table_start()
	_refresh_hud()


## Rig the next throw's faces (one VALUE per cold die; each die shows the
## first face slot carrying that value).
func rig_faces(faces: Array[int]) -> void:
	_rig = faces.duplicate()
	_rig_is_slots = false


## Rig the next throw by physical face SLOT (1..6) per cold die (to land a
## specific modded face).
func rig_slots(slots: Array[int]) -> void:
	_rig = slots.duplicate()
	_rig_is_slots = true


## Run mode: give up the table (Pause > Forfeit table > confirm). Ends it
## like a timeout (see BonfireRun.forfeit) and shows the end panel; CONTINUE
## then emits finished. Returns false if the table was already over.
func forfeit() -> bool:
	if not can_forfeit_now():
		return false
	if not run.forfeit():
		return false
	_kill_hand_tweens()
	phase = Phase.OVER
	juice.crowd_stop()
	_burn_soul(maxi(_soul_shown - run.soul, 0))
	for d in all_dice:
		_set_lit(d, false)
	bhud.countup.clear()  # no count-up row left over the end panel
	_set_why("Table forfeited.")
	bhud.show_end(run)
	_refresh_hud()
	hand_result.emit(run.last_result)
	return true


## Leave a cleared table (the Leave table button or L, between hands). The
## table ends as CLEARED (no timeout penalty; points convert to Embers) and
## shows the end panel; in run mode its CONTINUE then emits finished once.
## Returns false if leaving isn't allowed right now.
func leave() -> bool:
	if not can_leave_now():
		return false
	if not run.leave():
		return false
	bhud.tutorial.on_action(&"leave")
	_kill_hand_tweens()
	pause_menu.set_forfeit_enabled(false)
	phase = Phase.OVER
	juice.crowd_stop()
	for d in all_dice:
		_set_lit(d, false)
	_emit_table_cleared()
	_taunt(&"bonfire_clear")
	bhud.countup.clear()
	_set_why("You left the table. Cleared!")
	bhud.show_end(run)
	_refresh_hud()
	hand_result.emit(run.last_result)
	return true


## Run mode: hand the outcome back (once). The table never changes scenes;
## the run frees it. Returns the outcome, or null if not over / already sent.
func finish() -> TableOutcome:
	if run == null or not run.is_over() or _finished_sent:
		return null
	_finished_sent = true
	var o := outcome()
	finished.emit(o)
	return o


func _refresh_hud() -> void:
	_update_portrait_hud()
	if bhud != null:
		bhud.leave_button.visible = can_leave_now()
	if reliquary != null and run != null:
		reliquary.sync(run)
	if bhud != null and run != null:
		bhud.rethrow_prompt = rethrow_prompt() if phase == Phase.BET else ""
		bhud.refresh(run, phase == Phase.BET)
		# The rethrow risk line and the table's status line share the bottom
		# row: while the risk shows, the status line steps aside (QA #63).
		# G3: it also hides when it only repeats the orange prompt.
		why_label.visible = bhud.risk_label.text == "" \
				and not HelpCorner.repeats_prompt(why_label.text, bhud.throw_label.text)
		bhud.pulse_cards(claimable_bounties())
	if felt_label != null and run != null:
		var lines: Array[String] = []
		for r in run.rules:
			var ft := r.felt_text(run)
			if ft != "":
				lines.append(ft)
		felt_label.text = "\n".join(lines)
		felt_label.visible = not lines.is_empty() and not run.is_over()


## Dice come first (QA M1, #103 F1): a press on the dice in the hand is a
## grab, and a press on a thrown die while picking is a pick, even where a
## HUD button (THROW / BANK) overlaps them. _input runs before the GUI, so
## the press (and a grab's drag and release) go straight to the table's
## normal input and no button ever sees them.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var left := mb != null and mb.button_index == MOUSE_BUTTON_LEFT
	var holding := phase == Phase.HELD and (event is InputEventMouseMotion or (left and not mb.pressed))
	var on_dice := left and mb.pressed and (hand_grab_at(mb.position) or die_pick_at(mb.position))
	if holding or on_dice:
		get_viewport().set_input_as_handled()
		_unhandled_input(event)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var tap := event as InputEventScreenTouch
	if ((mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed) or (tap != null and tap.pressed)) and fast_forward_juice():
		get_viewport().set_input_as_handled()
		return
	if nerve != null and run != null and nerve.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and run != null \
			and run.state == BonfireRun.State.PICK and phase == Phase.BET:
		var i := die_at_screen(mb.position)
		if i >= 0:
			pick_die(i)
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		help_corner.toggle_card()  # the controls card (not the sandbox debug panel)
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE:
				if phase == Phase.HELD:
					phase = Phase.BET
				pause_menu.open()
				get_viewport().set_input_as_handled()
				return
			KEY_B:
				bank()
				return
			KEY_L:
				bhud.press_leave()  # a second L within 2 s leaves
				return
			KEY_F3:
				# Debug builds only (editor / debug export); a release
				# build keeps F3 free. `-- --throw-debug` still works.
				if OS.is_debug_build():
					throw_debug = not throw_debug
					get_viewport().set_input_as_handled()
					return
			KEY_SPACE, KEY_ENTER:
				if phase == Phase.BET:
					throw_again()
					return
			KEY_S, KEY_UP, KEY_DOWN, KEY_EQUAL, KEY_MINUS, KEY_KP_ADD, KEY_BACKSPACE:
				return
	# A mouse/touch release is the player's flick: sensitivity applies.
	_player_flick = mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	super(event)
	_player_flick = false


func _process(delta: float) -> void:
	super(delta)
	# The pause menu's FORFEIT follows can_forfeit_now() every frame, so it
	# is already greyed out when Esc pauses the tree mid-throw.
	pause_menu.set_forfeit_enabled(can_forfeit_now())
	if hand_label.text == "BET FIRST":
		hand_label.text = ""  # no bets here


## A throw finished playing after the table was forfeited mid-roll.
func _end_sequence_after_forfeit() -> void:
	phase = Phase.OVER
	juice.crowd_stop()
	_skip = false
	Engine.time_scale = 1.0
	_refresh_hud()
	sequence_finished.emit()


## Fades the count-up row and banner (BonfireCountUp.clear, 0.25 s) now,
## or right after it finishes if it is still counting.
func _clear_count_up_when_done() -> void:
	if bhud.countup.is_playing():
		bhud.countup.finished.connect(func() -> void: bhud.countup.clear(), CONNECT_ONE_SHOT)
	else:
		bhud.countup.clear()
