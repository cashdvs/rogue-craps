## Bonfire sandbox on the 3D table: grab and flick a handful of real dice
## (seeded faces via the pre-sim remap), scoring dice CATCH FIRE, click them
## into the pot on the far rail, then BANK or THROW the cold dice again.
## Rules live in BonfireRun / BonfireScoring; numbers in bonfire_tuning.tres.
class_name Bonfire3D
extends Table3D

signal throw_resolved(faces: Array[int], lit: Array[int])
signal hand_result(result: Dictionary)

## The pot: a row of set-aside dice on the far rail, between the chip props
## and the rake (the near rail is too close to the camera).
const POT_ORIGIN := Vector3(-0.19, 0.0, -0.61)
const POT_GAP: float = 0.095
const PICK_RADIUS_PX: float = 60.0

@export var bonfire_tuning: BonfireTuning
## Seed for the dice faces (-1 = random).
@export var bonfire_seed: int = -1

var run: BonfireRun
var bhud: BonfireHud
var all_dice: Array[DieVisual] = []
## Dice of the current throw; index = run.throw_faces index.
var throw_dice: Array[DieVisual] = []
## Dice set aside by earlier throws of this hand.
var pot_dice: Array[DieVisual] = []
var _felt_pos: Array[Vector3] = []
var _brng := RandomNumberGenerator.new()
var _lights: Dictionary = {}
var _hand_tweens: Array[Tween] = []
## The last throw's launch (tests/tools): lin, spin, speed, k, flick.
var last_launch: Dictionary = {}
var _player_flick: bool = false


func _ready() -> void:
	if bonfire_tuning == null:
		bonfire_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	mode = Mode.RUNNING_TOTAL
	total_dice_per_throw = bonfire_tuning.dice_count
	super()
	total_hud.visible = false
	stack.visible = false
	info_box.visible = false
	puck.visible = false
	help_label.text = "Grab the dice and flick (Space: quick throw). Click burning dice to pot ONE combo.\nB: Bank   Space: throw the rest   T: speed 1x/2x/Instant   R: reduced motion"
	(table.felt_material as ShaderMaterial).set_shader_parameter("use_overlay", false)
	all_dice = dice.duplicate()
	bhud = BonfireHud.new()
	hud.add_child(bhud)
	bhud.bank_pressed.connect(func() -> void: bank())
	bhud.throw_pressed.connect(func() -> void: throw_again())
	bhud.restart_pressed.connect(func() -> void: new_run(-1 if bonfire_seed < 0 else bonfire_seed + 1))
	new_run(bonfire_seed)


# --- Public API (tests, captures) ----------------------------------------------

func new_run(seed_value: int = -1) -> void:
	bonfire_seed = seed_value
	if seed_value >= 0:
		restart(seed_value)
		_brng.seed = seed_value * 7919 + 3
	else:
		_brng.randomize()
	run = BonfireRun.new(bonfire_tuning)
	bhud.end_panel.visible = false
	soul_meter.setup(run.soul, bonfire_tuning.starting_soul)
	_soul_shown = run.soul
	_reset_hand_dice()
	phase = Phase.BET
	_set_why("Grab the %d dice and flick them. Scoring dice catch fire." % run.cold)
	_refresh_hud()


## Rig the next throw's faces (one per cold die).
func rig_faces(faces: Array[int]) -> void:
	_rig = faces.duplicate()


## Space / THROW: in AIM throws the dice; after a throw, pots the picked dice
## and gathers the cold ones (or all of them on a Hot Hand) into the hand.
func throw_again() -> bool:
	if phase != Phase.BET or run.is_over():
		return false
	if run.state == BonfireRun.State.AIM:
		return quick_throw()
	var potted_now: Array[DieVisual] = []
	for i in run.potted:
		potted_now.append(throw_dice[i])
	var cold_now: Array[DieVisual] = []
	for i in throw_dice.size():
		if not run.potted.has(i):
			cold_now.append(throw_dice[i])
	var rt := run.rethrow()
	if rt.is_empty():
		_refuse("Pot at least one burning die first.")
		return false
	pot_dice.append_array(potted_now)
	if rt["hot"]:
		bhud.flash("HOT HAND!  +%d MULT" % run.mult_bonus(), Palette.EMBER)
		sfx.play(&"win_big", 1.1, -4.0)
		_taunt(&"bonfire_hot")
		_reset_hand_dice()
		_set_why("Hot Hand! All %d dice back, +%d mult on every pot this hand." % [run.cold, run.mult_bonus()])
	else:
		for d in cold_now:
			_set_lit(d, false)
		_set_active(cold_now)
		_to_hand()
		_set_why("Pot %d. Flick the %d cold dice, or regret it." % [run.pot, run.cold])
	_refresh_hud()
	return true


func bank() -> Dictionary:
	if phase != Phase.BET or not run.can_continue():
		_refuse("Pot at least one burning die to bank.")
		return {}
	var r := run.bank()
	bhud.flash("BANKED +%d" % int(r["gain"]), Palette.BRASS_HI)
	sfx.play(&"chip_collect")
	_taunt(&"bonfire_bank")
	var names: Array[String] = []
	for b: BountyData in run.all_bounties():
		if (r["ticked"] as Array).has(b.id):
			names.append(b.display_name)
	if not names.is_empty():
		sfx.play(&"win_big", 1.2, -6.0)
	bhud.flash_ticks(r["ticked"])
	_set_why("Banked %d points.%s" % [int(r["gain"]), (" Bounty: " + ", ".join(names) + "!") if not names.is_empty() else ""])
	hand_result.emit(r)
	await _after_hand()
	return r


## Clicks die `i` of the current throw (pots / unpots it; refused if it
## couldn't be part of one combo with the dice already potted).
func pick_die(i: int) -> bool:
	if phase != Phase.BET or run.state != BonfireRun.State.PICK or i < 0 or i >= throw_dice.size():
		return false
	if not run.toggle(i):
		sfx.play(&"chip_refuse")
		var d := throw_dice[i]
		var tw := d.create_tween()
		var p := d.position
		tw.tween_property(d, "position", p + Vector3(0.012, 0, 0), 0.04)
		tw.tween_property(d, "position", p - Vector3(0.012, 0, 0), 0.06)
		tw.tween_property(d, "position", p, 0.04)
		_set_why("That die can't join this combo (a pot is exactly ONE combo).")
		return false
	sfx.play(&"chip_place", 1.1, -3.0)
	_layout_throw()
	_refresh_hud()
	return true


func die_at_screen(p: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS_PX
	for i in throw_dice.size():
		var sp := camera.cam.unproject_position(throw_dice[i].global_position)
		var dist := sp.distance_to(p)
		if dist < best_d:
			best_d = dist
			best = i
	return best


# --- Table3D hooks ----------------------------------------------------------------

func can_throw() -> String:
	if run == null:
		return "..."
	if phase != Phase.BET and phase != Phase.HELD:
		return "The dice are still rolling."
	if run.is_over():
		return "The table is over. Restart."
	if run.state != BonfireRun.State.AIM:
		return "Pot your burning dice, then Throw again or Bank."
	return ""


func _pick_values() -> Array[int]:
	var v: Array[int] = []
	if _rig.size() >= dice.size():
		v = _rig.slice(0, dice.size())
		_rig.clear()
		return v
	for i in dice.size():
		v.append(_brng.randi_range(1, 6))
	return v


func _play_total_roll(values: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
	last_values = values
	# Throw from the hand ring even if the gather tween hasn't finished.
	_kill_hand_tweens()
	for i in dice.size():
		dice[i].global_transform = Transform3D(dice[i].global_transform.basis, hand_spot(i))
	throw_dice = dice.duplicate()
	for d in throw_dice:
		_set_lit(d, false)
	throw_started.emit()
	thrown.emit(velocity.length())
	_set_why("")
	await _throw_dice(values, velocity, release_pos)
	phase = Phase.REVEAL
	dice_landed.emit(values)
	camera.follow(_dice_center(), tuning.cam_reveal_time)
	await _wait(tuning.reveal_hold)
	_punch_dice()
	sfx.play(&"dice_settle", 1.0, -3.0)
	_felt_pos.clear()
	for d in throw_dice:
		_felt_pos.append(d.global_position)
	var ok := run.set_throw(values)
	var lit := BonfireScoring.lit_indices(values, bonfire_tuning)
	throw_resolved.emit(values, lit)
	if ok:
		for i in lit:
			_set_lit(throw_dice[i], true)
			_embers(throw_dice[i].global_position, 8, 2)
		sfx.play(&"rim_hit", 0.8, -6.0)
		_set_why("%d burning. Click dice into the pot: one combo per throw." % lit.size())
		phase = Phase.BET
	else:
		await _bust()
	_skip = false
	Engine.time_scale = 1.0
	_refresh_hud()
	sequence_finished.emit()


## Throw momentum: the flick's speed scales the launch speed, its arc and
## the spin (bonfire_tuning "Throw momentum"). Direction is Table3D's (flick
## direction kept in the aim cone).
func launch_for(velocity: Vector2, release_pos: Vector2) -> Dictionary:
	var base := super(velocity, release_pos)
	var bt := bonfire_tuning
	var k := launch_k(velocity.length())
	var speed := lerpf(bt.launch_speed_min_mps, bt.launch_speed_max_mps, k)
	var up := lerpf(bt.launch_up_min_mps, bt.launch_up_max_mps, k)
	var spin_mag := lerpf(bt.spin_min_rad_s, bt.spin_max_rad_s, k)
	var lin: Array[Vector3] = []
	var spin: Array[Vector3] = []
	var n := dice.size()
	var dir := Vector2(base["lin"][0].x, base["lin"][0].z).normalized()
	if n > 1:
		# Undo Table3D's 4-degree fan on die 0 to get the aim direction back.
		var c := Vector2.ZERO
		for v: Vector3 in base["lin"]:
			c += Vector2(v.x, v.z).normalized()
		dir = c.normalized()
	for i in n:
		var f := 0.0 if n == 1 else (float(i) - float(n - 1) * 0.5) / (float(n - 1) * 0.5)
		var d := dir.rotated(deg_to_rad(bt.fan_deg * f))
		var s := speed * (1.0 + 0.04 * f)
		lin.append(Vector3(d.x * s, up, d.y * s))
		var axis: Vector3 = base["spin"][i]
		axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
		spin.append(axis * spin_mag * (1.0 + _fx_rng.randf_range(-bt.spin_jitter, bt.spin_jitter)))
	last_launch = {"lin": lin, "spin": spin, "speed": speed, "k": k, "flick": velocity.length()}
	return last_launch


## 0..1 strength of a flick (after the curve).
func launch_k(flick_speed: float) -> float:
	var bt := bonfire_tuning
	var k := clampf((flick_speed - bt.flick_speed_min) / maxf(bt.flick_speed_max - bt.flick_speed_min, 1.0), 0.0, 1.0)
	return pow(k, maxf(bt.launch_exponent, 0.01))


## Options > Throw sensitivity multiplies the flick speed (keyboard quick
## throws stay a fixed medium throw).
func throw(velocity: Vector2, release_pos: Vector2 = Vector2.INF, drag: float = -1.0) -> bool:
	return super(velocity * (sensitivity() if _player_flick else 1.0), release_pos, drag)


func sensitivity() -> float:
	var gs := get_node_or_null("/root/GameSettings")
	return float(gs.get("throw_sensitivity")) if gs != null else 1.0


func _refresh_hud() -> void:
	if bhud != null and run != null:
		bhud.refresh(run, phase == Phase.BET)


func _add_chip() -> String:
	return ""


func _take_down() -> String:
	return ""


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and run != null \
			and run.state == BonfireRun.State.PICK and phase == Phase.BET:
		var i := die_at_screen(mb.position)
		if i >= 0:
			pick_die(i)
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_B:
				bank()
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
	if hand_label.text == "BET FIRST":
		hand_label.text = ""  # no bets here
	for d: DieVisual in _lights:
		var l: OmniLight3D = _lights[d]
		if l.visible:
			l.light_energy = 0.9 + 0.35 * sin(_t * 9.0 + d.die_id)
			d.body_material.set_shader_parameter("emission_energy", 0.55 + 0.2 * sin(_t * 7.0 + d.die_id * 1.7))


## A handful in the hand: a tight ring around HAND (a 5-wide row would
## start the outer dice in the rail).
func hand_spot(i: int) -> Vector3:
	var n := maxi(dice.size(), 1)
	if n == 1:
		return HAND + Vector3(0, tuning.die_size * 0.5, 0)
	var r := tuning.die_size * 0.6 / sin(PI / float(n))
	r = maxf(r, tuning.die_size * 0.65)
	var a := TAU * float(i) / float(n) + 0.3
	return HAND + Vector3(cos(a) * r, tuning.die_size * 0.5, sin(a) * r * 0.9)


# --- Internals ----------------------------------------------------------------------

func _bust() -> void:
	phase = Phase.RESOLVE
	var r := run.last_result
	bhud.flash("BUST!  -%d SOUL" % int(r["soul_lost"]), Color("#FF2E3E"))
	_burn_soul(int(r["soul_lost"]))
	_camera_shake(tuning.shake_craps_px, 0.3)
	sfx.play(&"seven_out")
	_embers(_dice_center(), 24, 10)
	_taunt(&"bonfire_bust")
	_set_why("Nothing caught fire. BUST: pot of %d lost, -%d Soul." % [int(r["lost_pot"]), int(r["soul_lost"])])
	hand_result.emit(r)
	await _wait(1.0)
	await _after_hand()


func _after_hand() -> void:
	if run.is_over():
		phase = Phase.OVER
		_taunt(&"bonfire_clear" if run.state == BonfireRun.State.CLEARED else &"bonfire_fail")
		bhud.show_end(run)
		_refresh_hud()
		return
	phase = Phase.RESET
	camera.go_home(tuning.cam_return_time)
	await _wait(0.25)
	_reset_hand_dice()
	phase = Phase.BET
	_refresh_hud()


## Every die back in the hand, unlit, all of them in the next throw.
func _reset_hand_dice() -> void:
	pot_dice.clear()
	throw_dice.clear()
	for d in all_dice:
		_set_lit(d, false)
		d.visible = true
		d.scale = Vector3.ONE
	_set_active(all_dice)
	_to_hand()


func _to_hand() -> void:
	_kill_hand_tweens()
	for i in dice.size():
		var d := dice[i]
		var tw := d.create_tween()
		_hand_tweens.append(tw)
		tw.tween_method(_arc_die.bind(d, d.global_position, hand_spot(i)), 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _kill_hand_tweens() -> void:
	for tw in _hand_tweens:
		if tw.is_valid():
			tw.kill()
	_hand_tweens.clear()


## The dice the next throw uses (also resizes the per-die playback state).
func _set_active(list: Array[DieVisual]) -> void:
	dice = list.duplicate()
	var n := dice.size()
	for i in n:
		dice[i].die_id = i
	_remap_from.resize(n)
	_remap_to.resize(n)
	_last_impact.resize(n)
	_rest_sent.resize(n)
	_tumble_sent.resize(n)
	_remap_from.fill(Quaternion.IDENTITY)
	_remap_to.fill(Quaternion.IDENTITY)
	if sim != null:
		sim.ensure_bodies(n)


## Potted dice of this throw slide to the pot (after earlier throws' dice);
## the rest sit where they landed.
func _layout_throw() -> void:
	var slot := pot_dice.size()
	for i in throw_dice.size():
		var d := throw_dice[i]
		var to := _felt_pos[i]
		if run.potted.has(i):
			to = pot_slot(slot)
			slot += 1
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func pot_slot(k: int) -> Vector3:
	return POT_ORIGIN + Vector3(k * POT_GAP, Table3DBuilder.RAIL_Y + Table3DBuilder.RAIL_RADIUS + tuning.die_size * 0.5, 0)


func _set_lit(d: DieVisual, on: bool) -> void:
	var l: OmniLight3D = _lights.get(d)
	if l == null and on:
		l = OmniLight3D.new()
		l.light_color = Palette.EMBER
		l.omni_range = 0.22
		l.position = Vector3(0, tuning.die_size * 0.9, 0)
		l.shadow_enabled = false
		d.add_child(l)
		_lights[d] = l
	if l != null:
		l.visible = on
	d.body_material.set_shader_parameter("emission_color", Palette.EMBER if on else Palette.BONE)
	d.body_material.set_shader_parameter("emission_energy", 0.6 if on else 0.0)


func is_lit(d: DieVisual) -> bool:
	return _lights.has(d) and (_lights[d] as OmniLight3D).visible


func _refuse(why: String) -> void:
	sfx.play(&"chip_refuse")
	_set_why(why)
