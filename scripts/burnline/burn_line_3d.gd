## The Burn Line sandbox on the 3D table (playtest build, spec pending).
##
## Reuses Table3D for everything physical: the grab-and-flick, the real
## RigidBody3D throw, the seeded-face remap, settle timing, the speed toggle,
## camera, dealer and sound. This script only adds the Burn Line rules
## (BurnLineRun, scripts/core) and their HUD: one die on the felt at a time,
## a running total vs the Line, Stop, bets and the side bet.
## Numbers: resources/tuning/burn_line_tuning.tres (BurnLineTuning).
class_name BurnLine3D
extends Table3D

const BUST_COLOR := Color("#FF2E3E")
## The Burn Line band on the felt (board_kit.md 7): z = -0.40, 1.9 x 0.06 m.
const BAND_Z: float = -0.40
const BAND_SIZE := Vector2(1.9, 0.06)
const TARGET_PLATE_POS := Vector3(0, 0.11, -0.61)
const TOTAL_PLATE_POS := Vector3(0, 0.11, 0.61)

signal hand_result_shown(result: Dictionary)
signal run_state_shown(state: BurnLineRun.State)

@export var burn_tuning: BurnLineTuning
@export var burn_seed: int = -1

var run: BurnLineRun
var selected: int = 0
var burn_hud: BurnLineHud
var band: MeshInstance3D
var band_mat: ShaderMaterial
var target_label3d: Label3D
var total_label3d: Label3D
var _band_flash: float = 0.0


func _ready() -> void:
	mode = Mode.RUNNING_TOTAL
	total_dice_per_throw = 1
	if burn_tuning == null:
		burn_tuning = load("res://resources/tuning/burn_line_tuning.tres") as BurnLineTuning
	dealer_lines_path = "res://resources/dealer/dealer_lines.json"
	super()
	# Hide the craps-only pieces (the craps flow itself stays in Table3D).
	total_hud.visible = false
	stack.visible = false
	info_box.visible = false
	puck.visible = false
	help_label.text = "Pick a die (1 / 2), grab it and flick to throw   S / Space: Stop\nUp / Down: bet   E: Exact Hit side bet   T: speed 1x/2x/Instant   R: reduced motion"
	(table.felt_material as ShaderMaterial).set_shader_parameter("use_overlay", false)
	_build_burn_props()
	burn_hud = BurnLineHud.new()
	hud.add_child(burn_hud)
	burn_hud.die_pressed.connect(select_die)
	burn_hud.stop_pressed.connect(func() -> void: stop_hand())
	burn_hud.bet_step.connect(func(step: int) -> void: change_bet(step))
	burn_hud.side_toggled.connect(func(on: bool) -> void: set_side_bet(on))
	burn_hud.loadout_chosen.connect(_on_loadout_chosen)
	burn_hud.end_action.connect(_on_end_action)
	new_run(burn_seed)


# --- Public API (tests, captures) ---------------------------------------------

func new_run(seed_value: int = -1) -> void:
	run = BurnLineRun.new(burn_tuning, seed_value)
	if seed_value >= 0:
		restart(seed_value)
	_table_started()


func current_die() -> BurnDie:
	return run.loadout[clampi(selected, 0, run.loadout.size() - 1)]


func select_die(i: int) -> void:
	if phase != Phase.BET or i < 0 or i >= run.loadout.size():
		return
	selected = i
	_style_die()
	sfx.play(&"dice_grab", 1.2, -8.0)
	_refresh_burn()


func change_bet(step: int) -> void:
	if run.place_bet(run.bet + step * burn_tuning.bet_chip):
		sfx.play(&"chip_place", 1.0, -4.0)
	else:
		stack.refuse_shake()
	_refresh_burn()


func set_side_bet(on: bool) -> void:
	if run.set_side_bet(on):
		sfx.play(&"chip_place", 1.2, -4.0)
	_refresh_burn()


## Stop: bank the hand. Returns the result ({} if you can't stop now).
func stop_hand() -> Dictionary:
	if phase != Phase.BET or not run.can_stop():
		return {}
	var result := run.stop()
	await _show_result(result)
	return result


func can_throw() -> String:
	if run == null:
		return "..."
	if phase != Phase.BET and phase != Phase.HELD:
		return "The die is still rolling."
	return run.can_throw(current_die())


## Seeded slot for the selected die (the pre-sim remap lands it face up).
func _pick_values() -> Array[int]:
	if not _rig.is_empty():
		var v: Array[int] = [_rig[0]]
		_rig.clear()
		return v
	return [run.pick_slot(current_die())]


## Rig the next throw to land on face SLOT `slot` (1..6) of the selected die.
func rig_next_slot(slot: int) -> void:
	_rig = [slot]


# --- The throw ---------------------------------------------------------------

func _play_total_roll(values: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
	var die := current_die()
	last_values = values
	throw_started.emit()
	thrown.emit(velocity.length())
	_set_why("")
	sum_text.visible = false
	await _throw_dice(values, velocity, release_pos)
	phase = Phase.REVEAL
	dice_landed.emit(values)
	var mid := _dice_center()
	camera.follow(mid, tuning.cam_reveal_time)
	await _wait(tuning.reveal_hold)
	_punch_dice()
	sfx.play(&"dice_settle", 1.0, -3.0)
	var slot := values[0]
	var shown: int = die.faces[slot - 1]
	var hands_before := run.hands_left
	run.add_throw(die, slot)
	var burned := run.hands_left < hands_before
	sum_text.position = camera.cam.unproject_position(mid + Vector3(0, 0.16, -0.05))
	sum_text.modulate.a = 1.0
	sum_text.pop("+%d" % shown, BUST_COLOR if burned else Palette.BONE, reduced_motion)
	if burned:
		total_label3d.text = str(run.last_result["total"])
		await _show_result(run.last_result, true)
	else:
		_refresh_burn()
		var d := run.line() - run.total
		if d == 0:
			_taunt(&"burn_on_line")
		await _wait(0.35)
		phase = Phase.RESET
		await _clear_die()
	if phase != Phase.OVER:
		phase = Phase.BET
	_refresh_burn()
	_skip = false
	Engine.time_scale = 1.0
	sequence_finished.emit()


## The die on the felt sinks away; the selected die appears in the hand.
func _clear_die() -> void:
	camera.go_home(tuning.cam_return_time)
	var d := dice[0]
	var st := sum_text.create_tween()
	st.tween_property(sum_text, "modulate:a", 0.0, 0.25)
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector3.ONE * 0.01, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	if not run.can_throw(current_die()) == "" and run.loadout.size() > 1:
		# The picked die is used up (Cramped): switch to one that can throw.
		for i in run.loadout.size():
			if run.can_throw(run.loadout[i]) == "":
				selected = i
				break
	_style_die()
	d.global_transform = Transform3D(Basis.IDENTITY, hand_spot(0))
	d.faces.basis = Basis.IDENTITY
	var tw2 := d.create_tween()
	tw2.tween_property(d, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(maxf(0.16, tuning.cam_return_time * 0.5))
	_refresh_burn()


## Shows how a hand ended (burn flash, coin, taunt), then the next hand or
## the end-of-table screen.
func _show_result(r: Dictionary, die_on_felt: bool = false) -> void:
	phase = Phase.RESOLVE
	var kind: StringName = r["kind"]
	var gain := int(r["returned"]) + int(r["side_returned"])
	match kind:
		&"burn":
			_flash_band()
			_camera_shake(tuning.shake_craps_px * 1.4, 0.35)
			_burn_soul(int(r["soul_lost"]))
			soul_meter.setup(run.soul, burn_tuning.starting_soul)
			_set_why("BURN! %d is over the Line. Bet lost, -%d Soul." % [r["total"], r["soul_lost"]])
			_taunt(&"burn_bust")
		&"exact":
			_set_why("EXACT %d! Returns %d%s." % [r["total"], int(r["returned"]), (" + Exact Hit %d" % int(r["side_returned"])) if int(r["side_returned"]) > 0 else ""])
			_camera_shake(tuning.shake_natural_px, 0.2)
			sfx.play(&"win_big", 1.0, -4.0)
			_taunt(&"burn_exact")
		&"close":
			_set_why("Stopped at %d, 1 under: returns %d." % [r["total"], int(r["returned"])])
			sfx.play(&"chip_collect")
			_taunt(&"burn_close")
		&"near":
			_set_why("Stopped at %d, %d under: returns %d." % [r["total"], int(r["line"]) - int(r["total"]), int(r["returned"])])
			sfx.play(&"chip_collect", 0.9)
		_:
			_set_why("Stopped at %d: too far under. Bet lost." % r["total"])
			sfx.play(&"chip_refuse", 0.8)
			_taunt(&"burn_miss")
	burn_hud.show_result(r, gain)
	hand_result_shown.emit(r)
	_refresh_burn(true)
	await _wait(0.9 if kind == &"burn" else 0.6)
	if die_on_felt:
		phase = Phase.RESET
		await _clear_die()
	_refresh_burn()
	if run.state != BurnLineRun.State.HAND:
		phase = Phase.OVER
		_show_end()
	else:
		phase = Phase.BET
		_refresh_burn()


func _flash_band() -> void:
	_band_flash = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_band_flash", 0.0, 1.1).set_delay(0.35)


func _process(delta: float) -> void:
	super(delta)
	if band_mat != null:
		var pulse := 0.85 + 0.15 * sin(_t * 3.0)
		band_mat.set_shader_parameter("tint", run_color().lerp(BUST_COLOR, _band_flash))
		band_mat.set_shader_parameter("energy", (2.2 + 2.0 * _band_flash) * pulse)


func run_color() -> Color:
	return Palette.EMBER


# --- End of table / run --------------------------------------------------------

func _show_end() -> void:
	var st := run.state
	match st:
		BurnLineRun.State.TABLE_CLEARED:
			_taunt(&"burn_table_clear")
		BurnLineRun.State.RUN_WON:
			_taunt(&"burn_table_clear")
		_:
			_taunt(&"burn_table_fail")
	burn_hud.show_end(run)
	run_state_shown.emit(st)


func _on_end_action(action: StringName) -> void:
	match action:
		&"next":
			run.next_table()
		&"restart":
			run = BurnLineRun.new(burn_tuning, -1 if burn_seed < 0 else burn_seed + 1)
	_table_started()


func _table_started() -> void:
	selected = 0
	phase = Phase.BET
	_soul_shown = run.soul
	soul_meter.setup(run.soul, burn_tuning.starting_soul)
	burn_hud.hide_end()
	target_label3d.text = str(run.line())
	_style_die()
	_refresh_burn()
	_set_why("%s: Line %d. Reach %d coin in %d hands. Bet, then grab the die and flick." % [run.table().display_name, run.line(), run.table().coin_target, run.hands_left])


func _on_loadout_chosen(ids: Array[StringName]) -> void:
	var ds: Array[BurnDie] = []
	for id in ids:
		var d := burn_tuning.find_die(id)
		if d != null:
			ds.append(d)
	if phase == Phase.BET and run.set_loadout(ds):
		selected = 0
		_style_die()
		_set_why("Dice: %s." % ", ".join(ds.map(func(d: BurnDie) -> String: return d.display_name)))
	else:
		_set_why("Change dice before the first throw of a hand.")
	_refresh_burn()


# --- Visuals -----------------------------------------------------------------

func _style_die() -> void:
	if dice.is_empty() or run == null:
		return
	var d := current_die()
	dice[0].set_look(d.body_color, d.pip_color, d.labels())
	dice[0].material = "iron" if d.id == &"leadfoot" else "bone"


func _build_burn_props() -> void:
	var root := Node3D.new()
	root.name = "BurnLineProps"
	add_child(root)
	# The Burn Line band: a straight emissive strip in front of the far rail.
	var q := QuadMesh.new()
	q.size = BAND_SIZE
	q.orientation = PlaneMesh.FACE_Y
	band_mat = Toon.fx(Palette.EMBER, 2.2, 1, true)
	band = Toon.add_mesh(root, q, band_mat, Vector3(0, 0.002, BAND_Z))
	band.name = "BurnLine"
	var glow := OmniLight3D.new()
	glow.light_color = Palette.EMBER
	glow.light_energy = 0.4
	glow.omni_range = 0.5
	glow.position = Vector3(0, 0.08, BAND_Z)
	root.add_child(glow)
	var brass := Toon.inked(Palette.BRASS, Toon.SHADOW_BRASS, Toon.INK_TABLE * 0.6, {"spec_size": 0.92, "spec_color": Palette.BRASS_HI}, 1)
	var dark := Toon.mat(Palette.OXBLOOD.darkened(0.4), Color.BLACK)
	# Target plate on the far rail, tilted 30 degrees toward the camera.
	var tp := Node3D.new()
	tp.name = "TargetPlate"
	tp.position = TARGET_PLATE_POS
	tp.rotation_degrees = Vector3(-30, 0, 0)
	root.add_child(tp)
	Toon.add_mesh(tp, Toon.box(Vector3(0.34, 0.15, 0.025)), brass, Vector3(0, 0.075, 0))
	Toon.add_mesh(tp, Toon.box(Vector3(0.29, 0.11, 0.01)), dark, Vector3(0, 0.075, 0.012))
	target_label3d = _plate_label(tp, Vector3(0, 0.075, 0.019), 0.0011)
	# Total dial on the near rail, lying on the rail top, tilted 30 degrees.
	var dp := Node3D.new()
	dp.name = "TotalPlate"
	dp.position = TOTAL_PLATE_POS
	dp.rotation_degrees = Vector3(30, 0, 0)
	root.add_child(dp)
	Toon.add_mesh(dp, Toon.cylinder(0.08, 0.02, 32), brass, Vector3(0, 0.01, 0))
	Toon.add_mesh(dp, Toon.cylinder(0.066, 0.006, 32), dark, Vector3(0, 0.021, 0))
	total_label3d = _plate_label(dp, Vector3(0, 0.026, 0), 0.0009)
	total_label3d.rotation_degrees = Vector3(-90, 0, 0)


func _plate_label(parent: Node3D, pos: Vector3, px: float) -> Label3D:
	var l := Label3D.new()
	l.name = "NumberAnchor"
	l.font = Palette.display_font()
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 18
	l.outline_modulate = Palette.PIT_BLACK
	l.modulate = Palette.BONE
	l.position = pos
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)
	return l


func _refresh_burn(final_total: bool = false) -> void:
	if run == null or burn_hud == null:
		return
	var shown_total: int = int(run.last_result.get("total", run.total)) if final_total else run.total
	total_label3d.text = str(shown_total)
	var d := run.line() - shown_total
	total_label3d.modulate = BUST_COLOR if d < 0 else (Palette.BRASS_HI if d == 0 else (Color("#9FE08A") if d == 1 else (Palette.EMBER if d <= 3 else Palette.BONE)))
	target_label3d.text = str(run.line())
	burn_hud.refresh(run, selected, shown_total, phase == Phase.BET)


func _refresh_hud() -> void:
	_refresh_burn()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_S, KEY_SPACE:
				if run.can_stop():
					stop_hand()
				elif key.keycode == KEY_SPACE and phase == Phase.BET:
					quick_throw()
				return
			KEY_1:
				select_die(0)
				return
			KEY_2:
				select_die(1)
				return
			KEY_UP, KEY_EQUAL, KEY_KP_ADD:
				change_bet(1)
				return
			KEY_DOWN, KEY_MINUS:
				change_bet(-1)
				return
			KEY_E:
				set_side_bet(not run.side_bet)
				return
			KEY_ENTER:
				if phase == Phase.BET:
					quick_throw()
				return
	# Right-click / Pass Line clicks mean nothing here; the rest is Table3D's.
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		return
	super(event)


## Pass Line clicks / +chip mean "raise the bet" here (no craps chips).
func _add_chip() -> String:
	change_bet(1)
	return ""


func _take_down() -> String:
	change_bet(-1)
	return ""
