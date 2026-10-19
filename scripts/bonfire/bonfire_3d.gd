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
extends Table3D

signal throw_resolved(faces: Array[int], lit: Array[int])
signal hand_result(result: Dictionary)
## Run mode: the table is done (end panel CONTINUE, or finish()). Emitted once.
signal finished(outcome: TableOutcome)

## The pot: a row of set-aside dice on the felt just inside the far rail,
## clear of the backboard (inner face z = -0.49). On the rail top they sat
## at the screen edge at 720p and off-screen in phone portrait. Potted dice
## are solid for the throw physics, so thrown dice bounce off them instead
## of passing through.
const POT_ORIGIN := Vector3(-0.19, 0.0, -0.44)
const POT_GAP: float = 0.095
const PICK_RADIUS_PX: float = 60.0
## Most dice one handful can hold (Table3D.MAX_DICE is the craps-era cap).
const MAX_HANDFUL: int = 12
## Face-mod looks (cheap decals on the die faces).
const HELLFIRE_COLOR := Color("#E2380C")
const WILD_COLOR := Color("#C88A00")
const TWIN_COLOR := Color("#2A1A10")
const RAINBOW: Array[Color] = [Color("#D7261E"), Color("#E7A400"), Color("#1E9E4A"), Color("#2266CC")]
## Tint of a die whose face a rule changed (by rule id; others use the default).
const CHANGE_TINT := {&"mirror": Color("#BFE3FF"), &"madame_shuffle": Color("#C060FF")}
const CHANGE_TINT_DEFAULT := Color("#FFFFFF")
const FLIP_TIME: float = 0.3

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
var pause_menu: PauseMenu
## How this table was opened (null before _ready = sandbox).
var setup: TableSetup
## all_dice[i] -> its TableDie.
var _die_of: Dictionary = {}
## The physical face slots of the current throw (index = throw_dice index).
var throw_slots: Array[int] = []
var _soul_before: int = 0
var _finished_sent: bool = false
## Text on the felt from the rules (e.g. "LOCKED  4").
var felt_label: Label3D
## Scoring juice adapter (sounds / VFX; art + audio branches if present).
var juice: BonfireJuice
## Tutorial: -1 = GameSettings decides (Table 1, not seen), 0 = never,
## 1 = always (tests). Set before add_child.
var tutorial_override: int = -1
## Dice of the pot being counted up, pip -> die index, its tier.
var _juice_dice: Array[DieVisual] = []
var _pip_die: Array[int] = []
var _juice_tier: int = 0
## What the lit dice of this throw could claim (no selection yet).
var _throw_claims: Array = []


func _ready() -> void:
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
	total_hud.visible = false
	stack.visible = false
	info_box.visible = false
	puck.visible = false
	help_label.text = "Grab the dice and flick (Space: quick throw). Click burning dice to pot ONE combo.\nB: Bank   Space: throw the rest   T: speed 1x/2x/Instant   R: reduced motion"
	(table.felt_material as ShaderMaterial).set_shader_parameter("use_overlay", false)
	all_dice = dice.duplicate()
	for i in all_dice.size():
		var td: TableDie = setup.dice[mini(i, setup.dice.size() - 1)]
		td.normalize()  # a faces / mods / shape mismatch warns and is padded, never a SCRIPT ERROR
		_die_of[all_dice[i]] = td
		apply_die_look(all_dice[i], td)
	bhud = BonfireHud.new()
	hud.add_child(bhud)
	bhud.bank_pressed.connect(func() -> void: bank())
	bhud.throw_pressed.connect(func() -> void: throw_again())
	bhud.restart_pressed.connect(func() -> void: new_run(-1 if bonfire_seed < 0 else bonfire_seed + 1))
	bhud.continue_pressed.connect(func() -> void: finish())
	bhud.leave_pressed.connect(func() -> void: leave())
	bhud.set_run_mode(setup.run_mode)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.set_run_mode(setup.run_mode)
	pause_menu.forfeit_confirmed.connect(func() -> void: forfeit())
	pause_menu.can_forfeit = can_forfeit_now
	juice = BonfireJuice.new()
	add_child(juice)
	juice.setup(self)
	bhud.set_combos(bonfire_tuning)
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
	if setup.max_soul > 0:
		run.max_soul = setup.max_soul
	run.owned_dice_count = setup.owned_dice_count if setup.owned_dice_count >= 0 else setup.dice.size()
	var specials: Array = []
	for td in setup.dice:
		specials.append(td.special)
	run.set_rules(TableRules.build(setup.rules, specials), seed_value)
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
	bhud.end_panel.visible = false
	soul_meter.setup(run.soul, run.max_soul)
	_soul_shown = run.soul
	_reset_hand_dice()
	pause_menu.set_forfeit_enabled(true)
	phase = Phase.BET
	_set_why("Grab the %d dice and flick them. Scoring dice catch fire." % run.cold)
	_maybe_start_tutorial()
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


var _rig_is_slots: bool = false


## Is this table opened by the run?
func is_run_mode() -> bool:
	return setup != null and setup.run_mode


## The table's result so far (final once run.is_over()).
func outcome() -> TableOutcome:
	return TableOutcome.from_run(run, _soul_before)


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
	_burn_soul(maxi(_soul_shown - run.soul, 0))
	for d in all_dice:
		_set_lit(d, false)
	_set_why("Table forfeited.")
	bhud.show_end(run)
	_refresh_hud()
	hand_result.emit(run.last_result)
	return true


## Can the table be forfeited right now? Not while a throw is in flight
## (rolling, landed, resolving): its faces are already decided, so a forfeit
## then could dodge a bust you can see (QA #60 blocker). FORFEIT comes back
## once the throw has resolved (bust or score applied) and phase is BET.
func can_forfeit_now() -> bool:
	return run != null and not run.is_over() and (phase == Phase.BET or phase == Phase.HELD)


## Is the Leave table button live right now? A cleared table, between
## hands (no throw yet this hand), not during the count-up or a throw.
func can_leave_now() -> bool:
	return run != null and run.can_leave() and phase == Phase.BET and not bhud.countup.is_playing()


## Leave a cleared table (the Leave table button or L, between hands). The
## table ends as CLEARED (no timeout penalty; points convert to Embers) and
## shows the end panel; in run mode its CONTINUE then emits finished once.
## Returns false if leaving isn't allowed right now.
func leave() -> bool:
	if not can_leave_now():
		return false
	if not run.leave():
		return false
	_kill_hand_tweens()
	pause_menu.set_forfeit_enabled(false)
	phase = Phase.OVER
	for d in all_dice:
		_set_lit(d, false)
	_taunt(&"bonfire_clear")
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


## The TableDie behind a die on the table.
func table_die(d: DieVisual) -> TableDie:
	return _die_of.get(d)


## Shows a TableDie on a die: its face values (pips) and a cheap decal per
## modded face: Hellfire red-orange rim + glowing pips, Wild rainbow rim +
## gold pips, Twin a double outline, Blank plain bone over the pips.
func apply_die_look(d: DieVisual, td: TableDie) -> void:
	if td == null:
		return
	if td.shape == &"coin":
		d.make_coin()
	elif td.faces != [1, 2, 3, 4, 5, 6]:
		# DieVisual.safe_labels pads / trims a mismatched face list to 6.
		d.set_look(Palette.BONE, Palette.PIT_BLACK, td.faces)
	var old := d.faces.get_node_or_null("FaceMods")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "FaceMods"
	d.faces.add_child(root)
	# One decal per modded slot the mesh has (a coin: heads, tails).
	for slot in range(1, mini(td.mods.size(), 2 if d.shape == &"coin" else 6) + 1):
		var m := td.mod_at(slot)
		if m != null:
			_add_mod_decal(root, d, d.mesh_face(slot), m)


func _add_mod_decal(root: Node3D, d: DieVisual, slot: int, m: FaceModData) -> void:
	var e := d.edge
	var n := DieVisual.FACE_AXES[slot] as Vector3
	var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
	u = (u - n * u.dot(n)).normalized()
	var v := n.cross(u)
	# Everything sits just above the pip tops (h + 0.01 e) so the die's ink
	# outline pass can't swallow it; fills would hide the pips, so the
	# coloured mods are a rim + tinted pips.
	var lift := d.face_half(slot) + 0.014 * e
	match m.effect:
		FaceModData.Effect.MULT_FACTOR:
			var c: Array[Color] = [HELLFIRE_COLOR, HELLFIRE_COLOR, HELLFIRE_COLOR, HELLFIRE_COLOR]
			_decal_frame(root, n, u, v, lift, e * 0.88, e * 0.08, c)
			_tint_pips(d, n, HELLFIRE_COLOR)
		FaceModData.Effect.WILD:
			_decal_frame(root, n, u, v, lift, e * 0.88, e * 0.08, RAINBOW)
			_tint_pips(d, n, WILD_COLOR)
		FaceModData.Effect.TWIN:
			var c: Array[Color] = [TWIN_COLOR, TWIN_COLOR, TWIN_COLOR, TWIN_COLOR]
			_decal_frame(root, n, u, v, lift, e * 0.84, e * 0.04, c)
			_decal_frame(root, n, u, v, lift, e * 0.70, e * 0.04, c)
		FaceModData.Effect.BLANK:
			# A plain bone face over the pips.
			_decal_quad(root, n, u, v, lift, e * 0.86, e * 0.86, Vector2.ZERO, Palette.BONE, false)


## Recolours (and lights) the pips on the face with outward normal `n`.
func _tint_pips(d: DieVisual, n: Vector3, col: Color) -> void:
	var pips := d.faces.get_node_or_null("Pips")
	if pips == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in pips.get_children():
		if p is MeshInstance3D and (p as MeshInstance3D).position.dot(n) > d.edge * 0.3:
			(p as MeshInstance3D).material_override = mat


func _decal_quad(root: Node3D, n: Vector3, u: Vector3, v: Vector3, lift: float, w: float, ht: float,
		off: Vector2, col: Color, glow: bool) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(w, ht)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	if glow:
		# Unshaded: the lit-die ember glow would wash a shaded colour out.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(u, v, n), n * lift + u * off.x + v * off.y)
	root.add_child(mi)


## A square outline (4 strips, one colour each) of outer size `size`.
func _decal_frame(root: Node3D, n: Vector3, u: Vector3, v: Vector3, lift: float, size: float, thick: float, cols: Array[Color]) -> void:
	var o := (size - thick) * 0.5
	_decal_quad(root, n, u, v, lift, size, thick, Vector2(0, o), cols[0], true)
	_decal_quad(root, n, u, v, lift, thick, size, Vector2(o, 0), cols[1], true)
	_decal_quad(root, n, u, v, lift, size, thick, Vector2(0, -o), cols[2], true)
	_decal_quad(root, n, u, v, lift, thick, size, Vector2(-o, 0), cols[3], true)


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
	var why := run.rethrow_block_reason()
	var sel := run.selection()
	var hot_before := run.hot_hands
	var per_hot := run.mult_bonus() / maxi(hot_before, 1)
	var faces_now := run.selection_faces()
	var hold := _display_snapshot(sel)
	var rt := run.rethrow()
	if rt.is_empty():
		_refuse(why if why != "" else "Pot at least one burning die first.")
		return false
	pot_dice.append_array(potted_now)
	# Back to the home framing (the reveal left the camera zoomed in on the
	# dice): the count-up and its fire play on the pot row, and the next
	# flick starts from the hand. On a portrait phone the pot is otherwise
	# off-screen for the whole count-up.
	camera.go_home(tuning.cam_return_time)
	_start_count_up(sel, potted_now, faces_now, hot_before, per_hot)
	_hold_display(hold)
	juice.crowd_pot(run.pot)
	_tutorial_hint(2)
	if rt["hot"]:
		_taunt(&"bonfire_hot")
		# The lists change now; the dice ignite and fly back after the count-up.
		pot_dice.clear()
		throw_dice.clear()
		_set_active(all_dice)
		_hot_hand_moment()
		_set_why("Hot Hand! All %d dice back, +%d mult on every pot this hand." % [run.cold, run.mult_bonus()])
		_tutorial_hint(4)
	else:
		for d in cold_now:
			_set_lit(d, false)
		_set_active(cold_now)
		_to_hand()
		_set_why("Pot %d. Flick the %d cold dice, or regret it." % [run.pot, run.cold])
	_refresh_hud()
	return true


## Hot Hand: after the count-up every die ignites, the banner reads
## "HOT HAND xN", and the dice fly back to the hand trailing fire.
func _hot_hand_moment() -> void:
	if bhud.countup.is_playing():
		await bhud.countup.finished
	if run.is_over() or phase != Phase.BET:
		return
	var list := all_dice.duplicate()
	juice.drop(list, true)
	for d in list:
		_set_lit(d, false)
		d.visible = true
		d.scale = Vector3.ONE
	juice.hot_hand(list)
	bhud.flash("HOT HAND x%d" % run.hot_hands if run.hot_hands > 1 else "HOT HAND!", Palette.EMBER)
	var fly := bonfire_tuning.juice_hot_hand_fly_time if not reduced_motion else 0.22
	if speed_mode == 2:
		fly = 0.05
	juice.fly_start(list, fly)
	_to_hand(fly)
	get_tree().create_timer(fly + 0.05, true, false, false).timeout.connect(func() -> void: juice.fly_stop(list))


## HUD numbers before a pot is committed (shown until its count-up lands).
func _display_snapshot(sel: Dictionary) -> Dictionary:
	return {"embers": run.embers, "points": run.points, "pot_from": run.pot, "pot_add": int(sel.get("points", 0)), "f": 0.0}


## Holds the HUD numbers while the count-up plays (not under Instant); the
## count-up landing, a fast-forward or a new hand releases them.
func _hold_display(hold: Dictionary) -> void:
	if speed_mode == 2 or not bhud.countup.is_playing():
		_release_display()
		return
	bhud.display_hold = hold
	_refresh_hud()


func _release_display() -> void:
	if bhud.display_hold.is_empty():
		return
	bhud.display_hold = {}
	_refresh_hud()


## Starts the count-up for a committed pot (sel = its score before commit).
func _start_count_up(sel: Dictionary, dice_list: Array[DieVisual], faces: Array, hot_hands: int, per_hot: int) -> void:
	if not sel.get("valid", false):
		return
	if bhud.countup.is_playing():
		bhud.countup.fast_forward()
	var t := bonfire_tuning
	var tier := JuicePlan.tier(int(sel["points"]), t)
	var chips := JuicePlan.chips(sel, hot_hands, per_hot)
	var vals: Array = sel["values"]
	_pip_die.clear()
	for k in faces.size():
		var f: Dictionary = faces[k]
		var m: FaceModData = f.get("mod")
		var n := 2 if m != null and m.effect == FaceModData.Effect.TWIN and not run.rule_ctx()["no_mods"] else 1
		for j in n:
			_pip_die.append(k)
	var plan := JuicePlan.timeline(vals.size(), chips.size() - 1, tier, speed_mode, t)
	_juice_dice = dice_list.duplicate()
	_juice_tier = tier
	juice.lift(_juice_dice, plan["big"], test_speed * (2.0 if speed_mode == 1 else 1.0) * (20.0 if speed_mode == 2 else 1.0))
	bhud.countup.play({"base": int(sel["base"]), "values": vals, "chips": chips, "points": int(sel["points"]),
		"name": str(sel["name"]), "score_tier": tier, "banner_tier": JuicePlan.banner_tier(StringName(sel["combo"]), t)},
		plan, test_speed, reduced_motion)


func _on_count_pip(i: int) -> void:
	if speed_mode != 2:
		juice.pip_sound(i)
	var k: int = _pip_die[i] if i < _pip_die.size() else -1
	if k >= 0 and k < _juice_dice.size() and is_instance_valid(_juice_dice[k]):
		var d := _juice_dice[k]
		d.body_material.set_shader_parameter("emission_color", Palette.EMBER)
		d.body_material.set_shader_parameter("emission_energy", 1.1)


func _on_count_banner(score_tier: int, _banner_tier: int) -> void:
	if speed_mode == 2:
		juice.sfx(juice.stinger(score_tier), 1.0, 0.0, 0.0, &"rim_hit", 1.2, -6.0)
	else:
		juice.banner_sound(score_tier)
	juice.escalate(score_tier, _juice_dice, reduced_motion, speed_mode == 2)


## Tap / click / any action: finish the count-up now.
func fast_forward_juice() -> bool:
	if bhud.countup.is_playing():
		bhud.countup.fast_forward()
		return true
	return false


func bank() -> Dictionary:
	if phase != Phase.BET or not run.can_continue():
		_refuse("Pot at least one burning die to bank.")
		return {}
	fast_forward_juice()
	var sel := run.selection()
	var hot_before := run.hot_hands
	var per_hot := run.mult_bonus() / maxi(hot_before, 1)
	var faces_now := run.selection_faces()
	var potted_now: Array[DieVisual] = []
	for i in run.potted:
		potted_now.append(throw_dice[i])
	var all_pot: Array[DieVisual] = pot_dice.duplicate()
	all_pot.append_array(potted_now)
	var hold := _display_snapshot(sel)
	var r := run.bank()
	phase = Phase.RESOLVE
	_start_count_up(sel, potted_now, faces_now, hot_before, per_hot)
	_hold_display(hold)
	if bhud.countup.is_playing():
		await bhud.countup.finished
	# Bank: embers flow to the pile, each claimed bounty gets its wax stamp.
	bhud.flash("BANKED +%d" % int(r["gain"]), Palette.BRASS_HI)
	juice.bank_sound()
	juice.crowd_pot(0)
	_taunt(&"bonfire_bank")
	var flow := bonfire_tuning.juice_bank_flow_time if speed_mode != 2 else 0.05
	bhud.ember_flow(int(r["gain"]) / 25, flow, reduced_motion)
	juice.ember_pile(pot_slot(0) + Vector3(-0.12, -tuning.die_size * 0.5, 0))
	var names: Array[String] = []
	for b: BountyData in run.all_bounties():
		if (r["ticked"] as Array).has(b.id):
			names.append(b.display_name)
	bhud.flash_ticks(r["ticked"])
	for id: StringName in r["ticked"]:
		bhud.stamp_claimed(id, reduced_motion)
		juice.stamp_sound()
		if speed_mode != 2:
			await _wait(bonfire_tuning.juice_stamp_gap / test_speed)
	_tutorial_hint(3)
	juice.drop(all_pot)
	bhud.countup.clear()
	_set_why("Banked %d points.%s" % [int(r["gain"]), (" Bounty: " + ", ".join(names) + "!") if not names.is_empty() else ""])
	if r.get("cleared_now", false):
		# The clear moment: Embers locked in, the table stays open (unless
		# that was the last hand, then it ends right after this).
		bhud.show_cleared()
		_taunt(&"bonfire_clear")
		_tutorial_hint(5)
		if not run.is_over():
			_set_why("Table cleared! Chase the bonus with your remaining hands, or Leave table.")
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
	if run.can_continue():
		_tutorial_hint(1)
	_refresh_hud()
	return true


## Bounty cards the current selection could claim (or, with nothing
## selected, what the lit dice could claim).
func claimable_bounties() -> Array:
	if run == null or run.state != BonfireRun.State.PICK or not run.bounties_count():
		return []
	if run.potted.is_empty():
		return _throw_claims
	var sel := run.selection()
	if not sel["valid"]:
		return []
	return _open_ticks(sel["bounty_values"])


func _open_ticks(values: Array) -> Array:
	var open: Array = []
	for b: BountyData in run.all_bounties():
		if not run.is_ticked(b):
			open.append(b)
	return BonfireScoring.bounty_ticks(open, values)


func _compute_throw_claims() -> void:
	_throw_claims = []
	if run.state != BonfireRun.State.PICK:
		return
	var dice_now := run.throw_dice()
	var ctx := run.rule_ctx()
	for sub: Array in BonfireScoring.matching_subsets(dice_now, bonfire_tuning, ctx):
		var pick: Array = []
		for i in sub:
			pick.append(dice_now[i])
		var sc := BonfireScoring.score_selection(pick, bonfire_tuning, 0, ctx)
		for id in _open_ticks(sc["bounty_values"]):
			if not _throw_claims.has(id):
				_throw_claims.append(id)


# --- Tutorial -------------------------------------------------------------------------

func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _is_table_one() -> bool:
	return setup != null and setup.goal != null and (setup.goal == bonfire_tuning.table_goal or setup.goal.display_name == "Table 1")


func tutorial_wanted() -> bool:
	if tutorial_override >= 0:
		return tutorial_override == 1
	# Only the real game, never tests / tools: the table is the current
	# scene (sandbox) or inside it (a run's RunScreen; QA M2).
	var scene := get_tree().current_scene
	if scene == null or not (scene == self or scene.is_ancestor_of(self)):
		return false
	var gs := _settings()
	if gs == null or not _is_first_table():
		return false
	return bool(gs.get("tutorial_enabled")) and not bool(gs.get("tutorial_seen"))


## The run's first table (setup.first_table; the sandbox counts as one), and
## it's Table 1. In a run every goal passes _is_table_one(), so first_table
## is what keeps the tutorial off the later tables.
func _is_first_table() -> bool:
	return setup != null and setup.first_table and _is_table_one()


func _maybe_start_tutorial() -> void:
	var tut := bhud.tutorial
	tut.visible = false
	tut.active = false
	if not tutorial_wanted():
		return
	tut.start()
	var gs := _settings()
	if gs != null and gs.has_method("set_option"):
		gs.set_option(&"tutorial_seen", true)
	# The first throw lands a pair + a run of 3 (if the handful allows).
	var want: Array[int] = bonfire_tuning.tutorial_first_throw.duplicate()
	if setup.dice.size() >= want.size():
		while want.size() < setup.dice.size():
			want.append(3)
		rig_faces(want)


func _tutorial_hint(k: int) -> void:
	if bhud != null and bhud.tutorial.active:
		bhud.tutorial.hint(k)


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
		return "The table is over. Continue." if is_run_mode() else "The table is over. Restart."
	if run.state != BonfireRun.State.AIM:
		return "Pot your burning dice, then Throw again or Bank."
	return ""


## Table3D throws by physical face SLOT, so this returns one slot (1..6)
## per active die: rigged, or rolled with the die's face weights.
func _pick_values() -> Array[int]:
	var v: Array[int] = []
	if _rig.size() >= dice.size():
		for i in dice.size():
			var td := _td(i)
			var slot := _rig[i] if _rig_is_slots else td.slot_for_value(_rig[i])
			v.append(clampi(slot if slot > 0 else _rig[i], 1, td.face_count()))
		_rig.clear()
		return v
	for i in dice.size():
		v.append(_td(i).roll_slot(_brng))
	return v


func _td(i: int) -> TableDie:
	var td: TableDie = _die_of.get(dice[i])
	return td if td != null else TableDie.new()


## Active dice i -> (value, mod) for the slots it landed on.
func _values_for(slots: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		out.append(_td(i).value_at(slots[i]))
	return out


func _mods_for(slots: Array[int]) -> Array:
	var out: Array = []
	for i in slots.size():
		out.append(_td(i).mod_at(slots[i]))
	return out


func _play_total_roll(slots: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
	# A throw ends any count-up still running; lifted / trailing dice let go.
	fast_forward_juice()
	juice.drop(all_dice, true)
	juice.fly_stop(all_dice)
	bhud.pulse_cards([])
	throw_slots = slots.duplicate()
	var values := _values_for(slots)
	var mods := _mods_for(slots)
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
	await _throw_dice(slots, velocity, release_pos)
	if run.is_over():
		_end_sequence_after_forfeit()
		return
	phase = Phase.REVEAL
	dice_landed.emit(values)
	camera.follow(_dice_center(), tuning.cam_reveal_time)
	await _wait(tuning.reveal_hold)
	if run.is_over():
		_end_sequence_after_forfeit()
		return
	_punch_dice()
	sfx.play(&"dice_settle", 1.0, -3.0)
	_felt_pos.clear()
	for d in throw_dice:
		_felt_pos.append(d.global_position)
	var tds: Array = []
	for i in throw_dice.size():
		tds.append(_td(i))
	var th := TableThrow.make(values, mods, tds, run.rng)
	th.slots = slots.duplicate()
	th.positions = _felt_pos.duplicate()
	var ok := run.land_throw(th)
	_compute_throw_claims()
	if not th.changes.is_empty():
		await _show_face_changes(th)
		if run.is_over():
			_end_sequence_after_forfeit()
			return
	values = run.throw_faces.duplicate()
	last_values = values
	var lit := run.lit()
	throw_resolved.emit(values, lit)
	if not ok and run.free_rethrow:
		# Nonstandard dice: a full throw that lit nothing is thrown again free.
		bhud.flash("NOTHING BURNED  FREE THROW", Palette.BONE)
		_set_why("A full throw can't bust. Throw the %d dice again." % run.cold)
		_to_hand()
		phase = Phase.BET
	elif not ok and run.kindling_saved:
		# A Kindling face: nothing lit, but no bust. Same dice, throw again.
		bhud.flash("KINDLING!  NO BUST", Palette.EMBER)
		sfx.play(&"rim_hit", 1.3, -4.0)
		_embers(_dice_center(), 14, 6)
		_set_why("Kindling caught it: nothing burned, but no bust. Throw the %d dice again." % run.cold)
		_to_hand()
		phase = Phase.BET
	elif ok:
		for i in lit:
			_set_lit(throw_dice[i], true)
			_embers(throw_dice[i].global_position, 8, 2)
		sfx.play(&"rim_hit", 0.8, -6.0)
		_set_why("%d burning. Click dice into the pot: one combo per throw." % lit.size())
		phase = Phase.BET
		_tutorial_hint(0)
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
		if i < n and dice[i].shape == &"coin":
			# Ferryman's Coin: a hard end-over-end flip about a diameter plus
			# extra lift, both growing with the flick, so it visibly flips.
			var cn := dice[i].global_transform.basis.orthonormalized() * Vector3.UP
			var flip := CoinPhysics.flip_axis(cn, lin[i], _fx_rng, deg_to_rad(bt.coin_axis_jitter_deg))
			spin[i] = flip * lerpf(bt.coin_flip_min_rad_s, bt.coin_flip_max_rad_s, k) * (1.0 + _fx_rng.randf_range(-bt.spin_jitter, bt.spin_jitter))
			lin[i].y += lerpf(bt.coin_lift_min_mps, bt.coin_lift_max_mps, k)
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
	if bhud != null:
		bhud.leave_button.visible = can_leave_now()
	if bhud != null and run != null:
		bhud.refresh(run, phase == Phase.BET)
		bhud.pulse_cards(claimable_bounties())
	if felt_label != null and run != null:
		var lines: Array[String] = []
		for r in run.rules:
			var ft := r.felt_text(run)
			if ft != "":
				lines.append(ft)
		felt_label.text = "\n".join(lines)
		felt_label.visible = not lines.is_empty() and not run.is_over()


## Rule moments the table shows (juice / audio hook the same
## BonfireRun.table_event).
func _on_table_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"die_shattered":
			var i: int = data.get("index", -1)
			if i >= 0 and i < throw_dice.size():
				_shatter_die(throw_dice[i])
		&"pot":
			# Blood faces pay Soul as the pot scores.
			_burn_soul(int(data.get("soul_cost", 0)))
		&"hand_start":
			_refresh_hud()


## Rule face changes (Madame Shuffle's reroll, a Mirror's copy): each changed
## die flips to its new face with a tint, before anything lights.
func _show_face_changes(th: TableThrow) -> void:
	var seen: Dictionary = {}
	for ch: Dictionary in th.changes:
		seen[int(ch["index"])] = ch
	for i: int in seen:
		if i >= throw_dice.size():
			continue
		var ch: Dictionary = seen[i]
		var d := throw_dice[i]
		var slot := int(th.slots[i])
		if i < throw_slots.size():
			throw_slots[i] = slot
		var phys := DieVisual.value_up(d.global_transform.basis)
		var to := DieVisual.remap_basis(phys, d.mesh_face(slot)).get_rotation_quaternion()
		if i < _remap_to.size() and dice.has(d):
			var k := dice.find(d)
			_remap_from[k] = to
			_remap_to[k] = to
		var from := d.faces.quaternion
		var base := d.faces.position
		var tint: Color = CHANGE_TINT.get(StringName(ch.get("by", &"")), CHANGE_TINT_DEFAULT)
		d.body_material.set_shader_parameter("emission_color", tint)
		var tw := d.create_tween()
		tw.tween_method(func(k: float) -> void:
			d.faces.quaternion = from.slerp(to, k)
			d.faces.position = base + Vector3(0, sin(k * PI) * d.edge * 0.7, 0)
			d.body_material.set_shader_parameter("emission_energy", 0.9 * (1.0 - k * 0.6)), 0.0, 1.0, FLIP_TIME)
		tw.tween_callback(func() -> void: d.faces.position = base)
	sfx.play(&"chip_place", 0.7, -2.0)
	await _wait(FLIP_TIME + 0.08)
	for i: int in seen:
		if i < throw_dice.size():
			_set_lit(throw_dice[i], false)


## A Cracked die shatters: burst, gone for the rest of the table.
func _shatter_die(d: DieVisual) -> void:
	all_dice.erase(d)
	bhud.flash("CRACKED DIE SHATTERED", Color("#FF2E3E"))
	sfx.play(&"rim_hit", 0.55, 0.0)
	_camera_shake(tuning.shake_craps_px * 0.5, 0.2)
	_embers(d.global_position, 30, 12)
	_set_lit(d, false)
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector3.ONE * 1.25, 0.06)
	tw.tween_property(d, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: d.visible = false)


## Dice still on this table (a shattered die is gone).
func dice_left() -> int:
	return all_dice.size()


func _add_chip() -> String:
	return ""


func _take_down() -> String:
	return ""


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


## True if a press at screen point p would grab the dice waiting in the hand.
func hand_grab_at(p: Vector2) -> bool:
	return phase == Phase.BET and can_throw() == "" and _hand_contains(p)


## True if a press at screen point p lands on a thrown die while picking
## (it pots the die, or shakes it if it can't score).
func die_pick_at(p: Vector2) -> bool:
	return phase == Phase.BET and run != null and run.state == BonfireRun.State.PICK and die_at_screen(p) >= 0


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var tap := event as InputEventScreenTouch
	if ((mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed) or (tap != null and tap.pressed)) and fast_forward_juice():
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
	# Big handfuls: keep the whole ring on the felt.
	var margin := tuning.die_size * 0.75
	var c := HAND
	c.x = minf(c.x, Table3DBuilder.FELT_HALF.x - r - margin)
	c.z = minf(c.z, Table3DBuilder.FELT_HALF.y - r * 0.9 - margin)
	var a := TAU * float(i) / float(n) + 0.3
	return c + Vector3(cos(a) * r, tuning.die_size * 0.5, sin(a) * r * 0.9)


## Bonfire handfuls aren't capped at Table3D.MAX_DICE (runs grow to 7+).
func dice_per_throw() -> int:
	return 2 if mode == Mode.CRAPS else clampi(total_dice_per_throw, 1, MAX_HANDFUL)


# --- Internals ----------------------------------------------------------------------

## A throw finished playing after the table was forfeited mid-roll.
func _end_sequence_after_forfeit() -> void:
	phase = Phase.OVER
	_skip = false
	Engine.time_scale = 1.0
	_refresh_hud()
	sequence_finished.emit()


func _bust() -> void:
	phase = Phase.RESOLVE
	var r := run.last_result
	bhud.flash("BUST!  -%d SOUL" % int(r["soul_lost"]), Color("#FF2E3E"))
	_burn_soul(int(r["soul_lost"]))
	_camera_shake(tuning.shake_craps_px, 0.3)
	# Flames snuff, dice ash over, the Soul flask cracks, pending stamps crumble.
	juice.bust(throw_dice, reduced_motion)
	bhud.crumble_pending(reduced_motion)
	bhud.flask_crack(soul_meter.get_global_rect(), reduced_motion)
	juice.crowd_pot(0)
	bhud.countup.clear()
	_tutorial_hint(3)
	_embers(_dice_center(), 24, 10)
	_taunt(&"bonfire_bust")
	_set_why("Nothing caught fire. BUST: pot of %d lost, -%d Soul." % [int(r["lost_pot"]), int(r["soul_lost"])])
	hand_result.emit(r)
	await _wait(1.0)
	await _after_hand()


func _after_hand() -> void:
	if run.is_over():
		# Out of hands uncleared: the Soul meter drops by the table's
		# penalty, like a bust or forfeit (QA M4). A cleared table costs no
		# Soul here, so nothing burns. Only the part not shown yet burns: a
		# final-hand bust already burned its Soul in _bust(), and maxi()
		# keeps this from going negative.
		_burn_soul(maxi(_soul_shown - run.soul, 0))
		pause_menu.set_forfeit_enabled(false)
		phase = Phase.OVER
		_taunt(&"bonfire_clear" if run.state == BonfireRun.State.CLEARED else &"bonfire_fail")
		bhud.show_end(run)
		_refresh_hud()
		return
	phase = Phase.RESET
	camera.go_home(tuning.cam_return_time)
	await _wait(0.25)
	if run.is_over():  # forfeited meanwhile
		phase = Phase.OVER
		return
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


func _to_hand(seconds: float = 0.22) -> void:
	_kill_hand_tweens()
	# A juice lift / settle tween must not pull a die back while it flies home.
	if juice != null:
		juice.drop(dice, true)
	for i in dice.size():
		var d := dice[i]
		var tw := d.create_tween()
		_hand_tweens.append(tw)
		tw.tween_method(_arc_die.bind(d, d.global_position, hand_spot(i)), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## True while any die is still flying back to the hand.
func hand_moving() -> bool:
	for tw in _hand_tweens:
		if tw != null and tw.is_valid() and tw.is_running():
			return true
	return false


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
			_clear_slot(to, d)
			slot += 1
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func pot_slot(k: int) -> Vector3:
	return POT_ORIGIN + Vector3(k * POT_GAP, tuning.die_size * 0.5, 0)


## Board A's near-rail total dial (art kit anchor TotalPlate, top edge) and
## the top of a tier-4 pillar over the pot: both must be on screen.
const NEAR_DIAL_TOP := Vector3(0.0, 0.2, 0.68)
const PILLAR_HEIGHT: float = 0.3


## Phone framing: Table3D's fit (dice >= min_die_px, hand + landing zone in
## view), then the view slides across the table so the pot row (both ends,
## with its pillar) is in view. The near dial is kept in view too when both
## fit; at portrait phone sizes they don't, and the pot row wins.
## Returns the smallest die size (px) like Table3D.fit_phone.
var phone_dial_visible: bool = true


## Bonfire's own home framing (BonfireTuning "Game camera") over the shared
## TuningData (a copy, so the PoC table keeps the spec camera).
func _apply_camera_tuning() -> void:
	if tuning == null or bonfire_tuning == null:
		return
	tuning = tuning.duplicate() as TuningData
	tuning.cam_pitch_deg = bonfire_tuning.cam_pitch_deg
	tuning.cam_distance = bonfire_tuning.cam_distance
	tuning.cam_pivot = bonfire_tuning.cam_pivot
	tuning.cam_look_up_deg = bonfire_tuning.cam_look_up_deg


func fit_phone(size: Vector2) -> float:
	if size.x >= size.y:
		return _fit_phone_landscape()
	var px := super(size)
	var n := maxi(setup.dice.size() if setup != null else 5, 1)
	var must: Array[Vector3] = [pot_slot(0) + Vector3(0, PILLAR_HEIGHT, 0), pot_slot(n - 1) + Vector3(0, tuning.die_size, 0),
		pot_slot(0) + Vector3(0, tuning.die_size, 0), hand_spot(0), hand_spot(1)]
	var with_dial := must.duplicate()
	with_dial.append(NEAR_DIAL_TOP)
	var base := camera.home_pivot
	var r := _slide_for(base, with_dial)
	phone_dial_visible = r[1] >= 0.0
	if not phone_dial_visible:
		r = _slide_for(base, must)
	# Still hugging an edge (under the HUD bar)? Dolly out a little while
	# the dice stay >= min_die_px.
	for step in 40:
		if r[1] >= PHONE_EDGE_PX:
			break
		var d := camera.home_distance
		camera.home_distance = d * 1.03
		camera.distance = camera.home_distance
		var r2 := _slide_for(base, with_dial if phone_dial_visible else must)
		var die_px := _smallest_die_px(must)
		if r2[1] <= r[1] or die_px < tuning.min_die_px:
			camera.home_distance = d
			camera.distance = d
			break
		r = r2
		px = minf(px, die_px)
	camera.home_pivot = base + Vector3(0, 0, r[0])
	camera.position = camera.home_pivot
	camera._apply()
	return px


## Phone landscape: the home framing's pitch and tilt, closer in and
## centred (BonfireTuning cam_phone_landscape_*), so the whole felt, the
## near rail and the TotalPlate are in frame with dice as big as the old
## hand-centred phone framing. Dollies out a little if a must-see point
## (or the pot row) still touches an edge. Returns the smallest die (px).
func _fit_phone_landscape() -> float:
	camera.fit_viewport(Vector2(get_viewport().get_visible_rect().size))
	camera.home_distance = bonfire_tuning.cam_phone_landscape_distance
	camera.distance = camera.home_distance
	camera.home_pivot = bonfire_tuning.cam_phone_landscape_pivot
	camera.position = camera.home_pivot
	camera._apply()
	var n := maxi(setup.dice.size() if setup != null else 5, 1)
	var pts := CameraFraming.must_points()
	pts.append_array([pot_slot(0) + Vector3(0, PILLAR_HEIGHT, 0), pot_slot(n - 1) + Vector3(0, tuning.die_size, 0)])
	for step in 20:
		if CameraFraming.margin(camera.cam, pts) >= bonfire_tuning.cam_edge_margin_px:
			break
		camera.home_distance *= 1.02
		camera.distance = camera.home_distance
		camera._apply()
	phone_dial_visible = true
	return _smallest_die_px(CameraFraming.rest_spots(tuning.die_size))


## How far (px) the pot row / hand points want to stay from the viewport
## edges on a phone (clear of the HUD bar).
const PHONE_EDGE_PX: float = 80.0


## Smallest on-screen die (px) at the given points, current camera.
func _smallest_die_px(pts: Array[Vector3]) -> float:
	camera._apply()
	var smallest := INF
	for p in pts:
		var at := Vector3(p.x, tuning.die_size * 0.5, p.z)
		var sz := DieVisual.projected_size(camera.cam, Transform3D(Basis.IDENTITY, at), tuning.die_size)
		smallest = minf(smallest, minf(sz.x, sz.y))
	return smallest


## Best z offset of the pivot (within +-0.3 m) for the points: [offset, the
## smallest distance (px) of any point inside the viewport edge].
func _slide_for(base: Vector3, pts: Array[Vector3]) -> Array[float]:
	# unproject_position works in the viewport's (stretched) coordinates.
	var vs := get_viewport().get_visible_rect().size
	var best := 0.0
	var best_margin := -INF
	for k in range(-30, 31):
		var off := k * 0.01
		camera.home_pivot = base + Vector3(0, 0, off)
		camera.position = camera.home_pivot
		camera._apply()
		var margin := INF
		for p in pts:
			var sp := camera.cam.unproject_position(p)
			margin = minf(margin, minf(minf(sp.x, vs.x - sp.x), minf(sp.y, vs.y - sp.y)))
		if margin > best_margin + 0.5 or (absf(margin - best_margin) <= 0.5 and absf(off) < absf(best)):
			best_margin = margin
			best = off
	return [best, best_margin]


## Throw physics: one solid box per potted die (the dice on the pot row).
var _pot_bodies: Array[StaticBody3D] = []


func _sync_colliders() -> void:
	super()
	while _pot_bodies.size() < MAX_HANDFUL:
		var b := StaticBody3D.new()
		b.name = "PotDie%d" % _pot_bodies.size()
		b.set_meta("surface", &"pot_die")
		var mat := PhysicsMaterial.new()
		mat.friction = 0.5
		mat.bounce = 0.3
		b.physics_material_override = mat
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * tuning.die_size
		cs.shape = box
		b.add_child(cs)
		add_child(b)
		_pot_bodies.append(b)
	for k in _pot_bodies.size():
		var on := k < pot_dice.size() and is_instance_valid(pot_dice[k])
		(_pot_bodies[k].get_child(0) as CollisionShape3D).disabled = not on
		_pot_bodies[k].global_position = pot_slot(k) if on else Vector3(0, -5, 0)


## Free pot slots can hold a cold die that came to rest there; when a die is
## potted into that slot the cold die is nudged toward the middle.
func _clear_slot(at: Vector3, except: DieVisual) -> void:
	for j in throw_dice.size():
		var o := throw_dice[j]
		if o == except or run.potted.has(j):
			continue
		var p := _felt_pos[j] if j < _felt_pos.size() else o.global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < tuning.die_size * 1.15:
			var to := Vector3(p.x, p.y, at.z + tuning.die_size * 1.3)
			_felt_pos[j] = to
			var tw := o.create_tween()
			tw.tween_property(o, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
