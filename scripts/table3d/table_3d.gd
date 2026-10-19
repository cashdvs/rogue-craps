## The 3D POC table (art/concept/poc_3d.md): the same one-Pass-Line table
## loop as the 2D TableScene, now seen from an angled overhead camera, with
## REAL physics dice.
##
## Loop: click the Pass Line (or the bankroll box, bottom-left) to stack 5-25
## Coin, grab the two bone dice from your hand (bottom-right of the felt),
## drag and FLICK them. The flick's speed and direction throw two
## RigidBody3D dice at the dealer's backboard; they tumble, bounce off the
## rails and settle. The faces still come from the seeded DiceRoller at the
## moment of release (see DiceSim for how live physics lands on them).
## Then the reveal, the moment, chips paid or raked, Soul burned, and the
## Dealer has something to say.
##
## The rules live in PocTable (pure logic, tested). UI that is 2D in the
## spec (Soul meter, banners, sum, bankroll counter, why-line) is reused
## from the 2D table on a CanvasLayer.
class_name Table3D
extends Node3D

signal throw_started
## Audio: the dice left the hand; flick_speed = release speed in px/s.
signal thrown(flick_speed: float)
signal dropped_back
signal dice_landed(values: Array[int])
signal outcome_shown(report: PocRollReport)
signal sequence_finished
signal table_finished(status: PocTable.Status)
signal taunted(event: StringName, line: String)
## Running-total mode: the player stopped at `total`.
signal total_stopped(total: int)

enum Phase { BET, HELD, ROLL, REVEAL, RESOLVE, RESET, OVER }
## CRAPS = the POC Pass Line table (2 dice). RUNNING_TOTAL = groundwork for
## Burn Line: throw N dice (default 1) into a running total, Stop any time.
## How a stop pays is not built yet (spec pending).
enum Mode { CRAPS, RUNNING_TOTAL }

## Where the two dice wait in your hand (felt, near-right corner).
const HAND := Vector3(0.86, 0.0, 0.36)
const DIE_SPREAD := Vector3(0.06, 0.0, 0.0)
## Gap between dice waiting in the hand (2 dice sit at +-DIE_SPREAD).
const HAND_GAP: float = 0.12
## Most dice one throw can hold (the dice bag holds 5).
const MAX_DICE: int = 5
## Held dice float this high above the felt.
const HOLD_Y: float = 0.10
## Throws aim at the dealer's backboard, around here.
const AIM_AT := Vector3(0.0, 0.0, -0.42)
const BANNER_POS := Vector2(960, 300)
## A "good default" flick in screen px/s (keyboard throw, tests).
const QUICK_THROW := Vector2(-1500, -2300)

@export var starting_dice: Array[DieData] = []
@export var bet_catalog: BetCatalog
@export var tuning: TuningData
@export var dealer_lines_path: String = "res://resources/dealer/dealer_lines.json"
## -1 = random each launch (see DiceRoller.RANDOM_SEED).
@export var rng_seed: int = DiceRoller.RANDOM_SEED
## Debug: faces forced for the next throws, in order (die A, die B).
@export var forced_rolls: Array[Vector2i] = []
## Extra speed multiplier (tests use it to run sequences fast).
@export var test_speed: float = 1.0
## Which game runs on the table (see Mode). Change at runtime with set_mode().
@export var mode: Mode = Mode.CRAPS
## Dice per throw in RUNNING_TOTAL mode (1..MAX_DICE). CRAPS always uses 2.
@export var total_dice_per_throw: int = 1
## Captures/tests: screen point where held dice go instead of the mouse.
var hold_point_override := Vector2.INF

var poc: PocTable
var roller: DiceRoller
var lines: DealerLines
var gesture: ThrowGesture
var phase: Phase = Phase.BET
var table_number: int = 1
var reduced_motion: bool = false
## Roll speed toggle: 0 = 1x, 1 = 2x, 2 = Instant (straight to the result).
var speed_mode: int = 0
const SPEED_NAMES: Array[String] = ["1x", "2x", "Instant"]
## Instant mode runs the reveal/resolve this many times faster.
const INSTANT_SPEED: float = 20.0
## The last throw's recording (tests read it).
var last_recording: ThrowRecording
## The faces the DiceRoller picked for the last throw.
var last_values: Array[int] = []

var _pass_type: BetType
var _rig: Array[int] = []
var _skip: bool = false
var _speed: float = 1.0
var _hitstop: bool = false
var _point_rolls: int = 0
var _big_bet_taunted: bool = false
var _low_soul_taunted: bool = false
var _soul_shown: int = 0
var _hand_shake: float = 0.0
var _rattle_t: float = 0.0
var _t: float = 0.0
var _fx_rng := RandomNumberGenerator.new()
var _felt_chips: Array[Chip3D] = []
var _bank_chips: Array[Chip3D] = []
var _play_t: float = -1.0
var _contact_i: int = 0
var _remap_from: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _remap_to: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY]
var _last_hover: bool = false
var _last_impact: Array[float] = [-1.0, -1.0]
var _rest_sent: Array[bool] = [false, false]
## Flick timestamps come from the real clock (Time.get_ticks_usec), so a
## slow frame or a hitch can't inflate the flick speed (the game delta is
## capped at max_physics_steps_per_frame physics steps below ~7.5 fps).
## Tests and offline recorders (--fixed-fps) can set a Callable returning
## seconds to drive their own clock.
var flick_clock: Callable = Callable()
var _tumble_sent: Array[bool] = [false, false]
var running_total: RunningTotal
var total_hud: RunningTotalHud
## Next die in the loadout to throw (RUNNING_TOTAL mode cycles the loadout).
var _loadout_i: int = 0

# Nodes (built in code).
var world_env: WorldEnvironment
var camera: CameraRig
var table: Table3DBuilder
var sim: DiceSim
var dice: Array[DieVisual] = []
var puck: Puck3D
var dealer: Dealer3D
var lamp: Lamp3D
var rim_light: DirectionalLight3D
var fx_root: Node3D
var chips_root: Node3D
var hand_glow: MeshInstance3D
## Physical stand-ins so the dice bounce off the puck and the bet stack.
var puck_body: StaticBody3D
var bet_body: StaticBody3D
var hud: CanvasLayer
## Which renderer the table builds its fog / SSAO for ("" = the one running).
## Tests set it before add_child to build the Mobile / Compatibility
## fallbacks headless.
var render_method: String = ""
var grade: ColorRect
var soul_meter: SoulMeter
var stack: BankrollStack
var bubble: DealerBubble
var sum_text: TableScene.PopText
var banner_layer: Node2D
var why_label: Label
var target_label: Label
var rolls_label: Label
var table_label: Label
var hand_label: Label
var help_label: Label
var info_box: VBoxContainer
var end_layer: CanvasLayer
var end_title: Label
var end_body: Label
var end_button: Button
var debug_panel: PanelContainer
var debug_seed: LineEdit
var debug_force: CheckBox
var debug_a: SpinBox
var debug_b: SpinBox
var debug_reduced: CheckBox
var debug_speed: OptionButton
## The table's SfxManager. Typed Node so tests can swap in a plain stand-in
## (only play() / has_event(), or the play_throw / play_impact hooks).
var sfx: Node
## The event surface (TableEvents): plain signals for the VFX / audio side.
var events: TableEvents


func _ready() -> void:
	events = TableEvents.new()
	add_child(events)
	if tuning == null:
		tuning = TuningData.new()
	if starting_dice.is_empty():
		var d6 := load("res://resources/dice/standard_d6.tres") as DieData
		starting_dice = [d6, d6]
	if bet_catalog == null:
		bet_catalog = load("res://resources/bets/bet_catalog.tres") as BetCatalog
	_pass_type = bet_catalog.find(&"pass")
	reduced_motion = tuning.reduced_motion
	speed_mode = tuning.roll_speed_mode
	gesture = ThrowGesture.new(tuning)
	sfx = SfxManager.new()
	add_child(sfx)
	_build_world()
	_build_hud()
	_build_end_screen()
	_build_debug_panel()
	running_total = RunningTotal.new(tuning.total_target_line)
	total_hud = RunningTotalHud.new()
	total_hud.stop_pressed.connect(func() -> void: stop_total())
	hud.add_child(total_hud)
	set_mode(mode)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	restart(rng_seed)


# --- Public API (tests, captures, debug) ----------------------------------------

## Switches between the craps table and the running-total groundwork.
## `per_throw` (RUNNING_TOTAL only) = dice per throw, default 1.
func set_mode(m: Mode, per_throw: int = -1) -> void:
	mode = m
	if per_throw > 0:
		total_dice_per_throw = clampi(per_throw, 1, MAX_DICE)
	_loadout_i = 0
	_set_dice_count(dice_per_throw())
	if running_total != null:
		running_total.reset()
		total_hud.set_line(running_total.target_line)
		total_hud.show_total(running_total, true)
		total_hud.visible = mode == Mode.RUNNING_TOTAL


## Running-total mode: bank the total now (placeholder Stop; how a stop
## pays waits for the Burn Line spec). Returns the stopped total, or -1.
func stop_total() -> int:
	if mode != Mode.RUNNING_TOTAL or phase != Phase.BET or running_total.count() == 0:
		return -1
	var final_total := running_total.stop()
	total_hud.show_total(running_total, true)
	total_hud.show_stopped(final_total)
	sfx.play(&"chip_place", 0.8)
	_set_why("Stopped at %d (line %d). Scoring comes with the Burn Line rules." % [final_total, running_total.target_line])
	total_stopped.emit(final_total)
	return final_total


## Starts a fresh RUN at table 1 with full Soul. seed -1 = random.
func restart(seed_value: int = DiceRoller.RANDOM_SEED) -> void:
	rng_seed = seed_value
	roller = DiceRoller.new(seed_value)
	_fx_rng.seed = roller.rng.seed + 99
	lines = DealerLines.from_json_file(dealer_lines_path, roller.rng.seed + 7)
	table_number = 1
	_start_table(-1)


## Doc v0.4 section 12: Next Table = same stake/target/rolls, Soul carries over.
func next_table() -> void:
	if poc.soul <= 0:
		restart(DiceRoller.RANDOM_SEED if rng_seed == DiceRoller.RANDOM_SEED else rng_seed + 1)
		return
	table_number += 1
	_start_table(poc.soul)


func _start_table(carry_soul: int) -> void:
	poc = PocTable.new(tuning, carry_soul)
	for c in _felt_chips:
		c.queue_free()
	_felt_chips.clear()
	for n in fx_root.get_children():
		n.queue_free()
	for n in banner_layer.get_children():
		n.queue_free()
	_rig.clear()
	_point_rolls = 0
	_big_bet_taunted = false
	_low_soul_taunted = false
	_soul_shown = poc.soul
	soul_meter.setup(poc.soul, tuning.soul_max)
	stack.chip_value = tuning.chip_value
	stack.target_coin = poc.target()
	stack.show_coin(poc.bankroll.coin, 0.0)
	_sync_bank_pile()
	puck.is_on = false
	puck.position = _puck_off()
	puck.disc.rotation_degrees = Vector3.ZERO
	table.felt_print.highlighted_point = 0
	table.felt_print.refresh()
	end_layer.visible = false
	(grade.material as ShaderMaterial).set_shader_parameter("desaturate", 0.0)
	(grade.material as ShaderMaterial).set_shader_parameter("danger_vignette", 0.0)
	for i in dice.size():
		dice[i].global_transform = Transform3D(Basis.IDENTITY, hand_spot(i))
		dice[i].faces.basis = DieVisual.remap_basis(1, 6 if i == 0 else 5)
		dice[i].visible = true
	sum_text.visible = false
	camera.snap_home()
	phase = Phase.BET
	_play_t = -1.0
	Engine.time_scale = 1.0
	_set_why(("Table %d. " % table_number if table_number > 1 else "") + "Click the Pass Line (or your bankroll) to bet %d-%d Coin, then grab the dice and flick them." % [tuning.min_bet, tuning.max_bet])
	_refresh_hud()


## Adds one chip to a bet (only the Pass Line exists on this table).
func place(bet_id: StringName = &"pass") -> String:
	if bet_id != &"pass":
		return "Only the Pass Line is on this table."
	return _add_chip()


## Takes the Pass bet down (before the come-out only).
func take_down(bet_id: StringName = &"pass") -> String:
	if bet_id != &"pass":
		return "Only the Pass Line is on this table."
	return _take_down()


## Forces the next throw's faces (debug / tests).
func rig_next_roll(a: int, b: int) -> void:
	_rig = [a, b]


## Rigs the next throw with one value per die (any dice count).
func rig_next_values(values: Array[int]) -> void:
	_rig = values.duplicate()


func is_busy() -> bool:
	return phase != Phase.BET and phase != Phase.OVER


## Can the dice be thrown right now? Returns "" or the reason.
func can_throw() -> String:
	if mode == Mode.RUNNING_TOTAL:
		return "" if phase == Phase.BET or phase == Phase.HELD else "The dice are still rolling."
	if poc.is_over():
		return "The table is over."
	if phase != Phase.BET and phase != Phase.HELD:
		return "The dice are still rolling."
	if not poc.table.craps.has_point() and poc.table.stake_on(&"pass") < tuning.min_bet:
		return "Bet at least %d on the Pass Line first." % tuning.min_bet
	return ""


## Throws the dice with a release velocity in screen px/s (1920x1080 space).
## drag = how far the mouse moved since the grab; -1 means "enough".
## A weak or tiny flick drops the dice back into the hand (returns false,
## no roll used). A strong one starts the roll and returns true.
## release_pos is the screen point of the release (default: over the hand).
func throw(velocity: Vector2, release_pos: Vector2 = Vector2.INF, drag: float = -1.0) -> bool:
	var reason := can_throw()
	if reason != "":
		_refuse_throw(reason)
		return false
	var d := tuning.min_throw_drag if drag < 0.0 else drag
	if not ThrowGesture.is_throw(velocity, d, tuning):
		_drop_back()
		return false
	if release_pos == Vector2.INF:
		release_pos = camera.cam.unproject_position(HAND)
	_play_roll(velocity, release_pos)
	return true


## Keyboard / accessibility throw: a good default flick from the hand.
func quick_throw() -> bool:
	var v := QUICK_THROW.rotated(_fx_rng.randf_range(-0.12, 0.12)) * _fx_rng.randf_range(0.9, 1.1)
	return throw(v)


func request_roll() -> bool:
	return quick_throw()


## Click-to-skip: plays the rest of this roll faster (tuning.fast_roll_speed).
func skip() -> void:
	if (phase == Phase.ROLL or phase == Phase.REVEAL or phase == Phase.RESOLVE) and not _skip:
		_skip = true
		_apply_speed()


## 1x / 2x / Instant (T key, debug panel).
func set_speed_mode(mode: int) -> void:
	speed_mode = clampi(mode, 0, 2)
	if debug_speed != null:
		debug_speed.select(speed_mode)
	_set_why("Roll speed: %s." % SPEED_NAMES[speed_mode])


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	camera.reduced_motion = on
	lamp.reduced_motion = on
	dealer.reduced_motion = on
	soul_meter.reduced = on
	soul_meter.particle_scale = tuning.reduced_motion_particles if on else 1.0
	for d in dice:
		d.highlight = 1.0 if on else 0.0
	if debug_reduced != null:
		debug_reduced.set_pressed_no_signal(on)
	_set_why("Reduced motion %s." % ("ON: no shake, hit-stop, camera moves or cracks; fewer particles; brighter dice" if on else "OFF"))


## Where die i waits in the hand.
func hand_spot(i: int) -> Vector3:
	var n := maxi(dice.size(), 1)
	var x := (float(i) - float(n - 1) * 0.5) * HAND_GAP
	return HAND + Vector3(x, tuning.die_size * 0.5, 0)


## The point on a horizontal plane (height y) under a screen position.
func screen_to_plane(p: Vector2, y: float = 0.0) -> Vector3:
	var from := camera.cam.project_ray_origin(p)
	var dir := camera.cam.project_ray_normal(p)
	if absf(dir.y) < 0.0001:
		return Vector3(from.x, y, from.z)
	var t := (y - from.y) / dir.y
	return from + dir * t


# --- Building the scene ------------------------------------------------------------

func _build_world() -> void:
	Engine.physics_ticks_per_second = tuning.physics_hz
	world_env = WorldEnvironment.new()
	world_env.environment = _make_environment()
	add_child(world_env)
	camera = CameraRig.new()
	camera.name = "CameraRig"
	add_child(camera)
	camera.setup(tuning)
	table = Table3DBuilder.new()
	table.build(self, tuning)
	lamp = Lamp3D.new()
	lamp.name = "Lamp"
	add_child(lamp)
	rim_light = DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.light_color = Palette.BURGUNDY
	rim_light.light_energy = 0.6
	rim_light.shadow_enabled = false
	rim_light.rotation_degrees = Vector3(-20, 180, 0)
	add_child(rim_light)
	var fill := OmniLight3D.new()
	fill.name = "Fill"
	fill.light_color = Palette.EMBER
	fill.light_energy = 0.15
	fill.omni_range = 3.0
	fill.position = Vector3(1.6, 0.4, 0.8)
	add_child(fill)
	_build_fog_and_smoke()
	dealer = Dealer3D.new()
	dealer.name = "Dealer"
	add_child(dealer)
	fx_root = Node3D.new()
	fx_root.name = "Fx"
	add_child(fx_root)
	chips_root = Node3D.new()
	chips_root.name = "Chips"
	add_child(chips_root)
	puck = Puck3D.new()
	puck.name = "Puck"
	puck.position = _puck_off()
	add_child(puck)
	# Ember glow under the hand when you can throw.
	hand_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.22)
	q.orientation = PlaneMesh.FACE_Y
	hand_glow.mesh = q
	hand_glow.material_override = Toon.fx(Color(Palette.EMBER, 0.5), 1.0, 0, true)
	hand_glow.position = HAND + Vector3(0, 0.003, 0)
	add_child(hand_glow)
	puck_body = _cyl_body("PuckCollider", Puck3D.RADIUS, Puck3D.THICK, &"puck")
	bet_body = _cyl_body("BetCollider", Chip3D.RADIUS, Chip3D.THICK, &"chip")
	sim = DiceSim.new()
	sim.name = "DiceSim"
	add_child(sim)
	sim.setup(tuning)
	# Throw sound. The Sound Designer's SfxManager.play_throw(flick_speed_px_s)
	# once it lands on this branch; until then the fixed dice_shake. The speed
	# is the raw flick in game (canvas) px/s, the same value launch_for() uses.
	thrown.connect(func(speed: float) -> void:
		events.dice_thrown.emit(speed)
		if sfx.has_method("play_throw"):
			sfx.call("play_throw", speed)
		else:
			sfx.play(&"dice_shake"))
	_set_dice_count(2)


## How many dice a throw uses right now.
func dice_per_throw() -> int:
	return 2 if mode == Mode.CRAPS else clampi(total_dice_per_throw, 1, MAX_DICE)


## Adds or removes visible dice so there are `n` (physics bodies follow on
## demand in DiceSim). Per-die bookkeeping is resized to match.
func _set_dice_count(n: int) -> void:
	while dice.size() > n:
		var d: DieVisual = dice.pop_back()
		d.queue_free()
	while dice.size() < n:
		var i := dice.size()
		var d := DieVisual.new(tuning.die_size)
		d.name = "Die%d" % i
		d.die_id = i
		d.impact.connect(_on_die_impact)
		d.settled.connect(_on_die_settled)
		add_child(d)
		dice.append(d)
	for i in n:
		var data := _die_data_for(i)
		dice[i].material = data.material if data != null else "bone"
		dice[i].global_transform = Transform3D(Basis.IDENTITY, hand_spot(i))
	_remap_from.resize(n)
	_remap_to.resize(n)
	_last_impact.resize(n)
	_rest_sent.resize(n)
	_tumble_sent.resize(n)
	_remap_from.fill(Quaternion.IDENTITY)
	_remap_to.fill(Quaternion.IDENTITY)
	if sim != null:
		sim.ensure_bodies(n)


## The DieData thrown as die i on the next throw (craps: the starting pair;
## running total: the next dice in the loadout, in order, wrapping around).
func _die_data_for(i: int) -> DieData:
	if starting_dice.is_empty():
		return null
	if mode == Mode.CRAPS:
		return starting_dice[mini(i, starting_dice.size() - 1)]
	return starting_dice[(_loadout_i + i) % starting_dice.size()]


func _cyl_body(n: String, radius: float, height: float, surface: StringName) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.set_meta("surface", surface)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.5
	mat.bounce = 0.3
	b.physics_material_override = mat
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	b.add_child(cs)
	add_child(b)
	return b


## Moves the puck/bet colliders to match what's on the felt (before a throw).
func _sync_colliders() -> void:
	puck_body.position = puck.position
	var n := _felt_chips.size()
	var cs := bet_body.get_child(0) as CollisionShape3D
	cs.disabled = n == 0
	var h := maxf(Chip3D.THICK + Chip3D.STEP * (n - 1), Chip3D.THICK)
	(cs.shape as CylinderShape3D).height = h
	bet_body.position = Table3DBuilder.BET_SPOT + Vector3(0, h * 0.5, 0)


func _make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#050405")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#1A080C")
	e.ambient_light_energy = 0.25
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.tonemap_white = 6.0
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color("#0E0B0C")
	e.fog_density = 0.12
	e.fog_sky_affect = 0.0
	# Volumetric fog is Forward+ only; Compatibility (web) and Mobile warn
	# every table if it's on (QA full run pass 1, Minor 9).
	e.volumetric_fog_enabled = has_volumetric_fog(render_method)
	e.volumetric_fog_density = 0.012
	e.volumetric_fog_albedo = Color("#3A3032")
	e.volumetric_fog_emission = Color.BLACK
	e.volumetric_fog_anisotropy = 0.6
	e.volumetric_fog_length = 12.0
	e.volumetric_fog_detail_spread = 2.0
	# SSAO: Forward+ only too; Mobile and Compatibility warn (#103 N5).
	e.ssao_enabled = is_forward_plus(render_method)
	e.ssao_radius = 0.25
	e.ssao_intensity = 1.6
	e.ssao_power = 1.5
	e.ssao_detail = 0.5
	e.ssao_horizon = 0.06
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_strength = 1.0
	e.glow_bloom = 0.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 1.0
	e.glow_hdr_scale = 2.0
	for lvl in 7:
		e.set_glow_level(lvl, 1.0 if lvl in [1, 2, 3] else 0.0)
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.05
	return e


## Is `method` ("" = the renderer running now) Forward+?
static func is_forward_plus(method: String = "") -> bool:
	if method == "":
		method = RenderingServer.get_current_rendering_method()
	return method == "forward_plus"


## Can this renderer draw volumetric fog (FogVolume / FogMaterial)? Only
## Forward+; the Compatibility renderer can't even compile a fog shader.
static func has_volumetric_fog(method: String = "") -> bool:
	return is_forward_plus(method)


func _build_fog_and_smoke() -> void:
	if has_volumetric_fog(render_method):
		# Smoke swirling in the lamp cone (Forward+ volumetric fog).
		var fv := FogVolume.new()
		fv.name = "LampHaze"
		fv.size = Vector3(1.4, 1.2, 1.4)
		fv.position = Vector3(0, 0.75, -0.05)
		var fm := FogMaterial.new()
		fm.density = 0.04
		var noise := NoiseTexture3D.new()
		var fnl := FastNoiseLite.new()
		fnl.frequency = 0.05
		noise.noise = fnl
		noise.width = 32
		noise.height = 32
		noise.depth = 32
		fm.density_texture = noise
		fv.material = fm
		add_child(fv)
	else:
		# Fallback cone for renderers without volumetric fog (Mobile/Compatibility).
		var cone := MeshInstance3D.new()
		cone.name = "LampConeFallback"
		cone.mesh = Toon.cylinder(0.55, 1.0, 24, 0.05)
		cone.material_override = Toon.fx(Color("#FFB070", 0.05), 1.0, 1, true)
		cone.position = Vector3(0, 0.85, -0.05)
		add_child(cone)
	# Two big soft smoke sheets drifting slowly.
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 6
	smoke.lifetime = 8.0
	smoke.preprocess = 8.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(1.2, 0.2, 0.6)
	smoke.position = Vector3(0, 0.55, -0.2)
	smoke.direction = Vector3(1, 0, 0)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 0.02
	smoke.initial_velocity_max = 0.04
	smoke.gravity = Vector3.ZERO
	smoke.color = Color("#3A3032", 0.06)
	var sq := QuadMesh.new()
	sq.size = Vector2(1.5, 1.5)
	var sm := ShaderMaterial.new()
	sm.shader = Fx3D._mix_shader()
	sm.set_shader_parameter("energy", 1.0)
	sq.material = sm
	smoke.mesh = sq
	add_child(smoke)


func _build_hud() -> void:
	# Post pass: vignette / danger tint / desaturate (above table, below HUD).
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	grade = ColorRect.new()
	grade.size = Vector2(1920, 1080)
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/grade.gdshader") as Shader
	gmat.set_shader_parameter("vignette", 0.3)
	gmat.set_shader_parameter("grain", 0.02)
	grade.material = gmat
	post.add_child(grade)

	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	banner_layer = Node2D.new()
	banner_layer.position = BANNER_POS
	hud.add_child(banner_layer)
	sum_text = TableScene.PopText.new()
	sum_text.visible = false
	hud.add_child(sum_text)

	soul_meter = SoulMeter.new()
	soul_meter.position = Vector2(60, 250)
	soul_meter.heartbeat.connect(func() -> void: sfx.play(&"heartbeat", 1.0, -4.0, 0.0))
	hud.add_child(soul_meter)

	stack = BankrollStack.new()
	stack.add_chip_requested.connect(func() -> void: _add_chip())
	stack.take_down_requested.connect(func() -> void: _take_down())
	hud.add_child(stack)

	bubble = DealerBubble.new()
	bubble.position = Vector2(1060, 70)
	bubble.visible = false
	hud.add_child(bubble)

	var info := VBoxContainer.new()
	info_box = info
	info.position = Vector2(1700, 40)
	info.custom_minimum_size = Vector2(200, 0)
	info.add_theme_constant_override("separation", 0)
	hud.add_child(info)
	table_label = _hud_label("TABLE 1", 26, Palette.BONE, true)
	info.add_child(table_label)
	info.add_child(_hud_label("TARGET", 24, Palette.BRASS))
	target_label = _hud_label("40", 64, Palette.BONE, true)
	info.add_child(target_label)
	info.add_child(_hud_label("ROLLS LEFT", 24, Palette.BRASS))
	rolls_label = _hud_label("12", 64, Palette.BONE, true)
	info.add_child(rolls_label)

	hand_label = _hud_label("", 28, Palette.EMBER, true)
	hand_label.size = Vector2(320, 40)
	hud.add_child(hand_label)

	why_label = Label.new()
	why_label.position = Vector2(380, 990)
	why_label.size = Vector2(1220, 80)
	why_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	why_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why_label.label_settings = Palette.label_settings(30, Palette.BONE, 6)
	why_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(why_label)

	var help := Label.new()
	help_label = help
	help.position = Vector2(24, 14)
	help.size = Vector2(460, 120)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.label_settings = Palette.label_settings(20, Color(Palette.BONE, 0.75), 4)
	help.text = "Click Pass Line / bankroll: +%d chip   Right-click: take down\nGrab the dice, drag and flick to throw   Space: quick throw\nClick during a roll: fast-forward   T: speed 1x/2x/Instant   R: reduced motion   F1: debug" % tuning.chip_value
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(help)


func _hud_label(text: String, size: int, color: Color, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = Palette.label_settings(size, color, 7, display)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_end_screen() -> void:
	end_layer = CanvasLayer.new()
	end_layer.layer = 20
	end_layer.visible = false
	add_child(end_layer)
	var dim := ColorRect.new()
	dim.color = Color(Palette.PIT_BLACK, 0.72)
	dim.size = Vector2(1920, 1080)
	end_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.ink_box(Palette.OXBLOOD, 24, 6, Palette.BRASS))
	panel.position = Vector2(560, 250)
	panel.custom_minimum_size = Vector2(800, 560)
	end_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	end_title = _hud_label("TABLE CLEARED", 88, Palette.BRASS, true)
	box.add_child(end_title)
	end_body = _hud_label("", 36, Palette.BONE)
	box.add_child(end_body)
	end_button = Button.new()
	end_button.text = "NEXT TABLE"
	end_button.custom_minimum_size = Vector2(380, 96)
	end_button.add_theme_font_override("font", Palette.display_font())
	end_button.add_theme_font_size_override("font_size", 44)
	end_button.add_theme_color_override("font_color", Palette.PIT_BLACK)
	end_button.add_theme_color_override("font_hover_color", Palette.PIT_BLACK)
	end_button.add_theme_stylebox_override("normal", Palette.ink_box(Palette.BRASS, 18, 5))
	end_button.add_theme_stylebox_override("hover", Palette.ink_box(Palette.BRASS_HI, 18, 5))
	end_button.add_theme_stylebox_override("pressed", Palette.ink_box(Palette.EMBER, 18, 5))
	end_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end_button.pressed.connect(next_table)
	box.add_child(end_button)


func _build_debug_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	debug_panel = PanelContainer.new()
	debug_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.92), 12, 3, Palette.BRASS))
	debug_panel.position = Vector2(20, 140)
	debug_panel.visible = false
	layer.add_child(debug_panel)
	var v := VBoxContainer.new()
	debug_panel.add_child(v)
	var title := Label.new()
	title.text = "DEBUG (F1)"
	v.add_child(title)
	var row := HBoxContainer.new()
	v.add_child(row)
	var sl := Label.new()
	sl.text = "Seed"
	row.add_child(sl)
	debug_seed = LineEdit.new()
	debug_seed.custom_minimum_size = Vector2(140, 0)
	debug_seed.placeholder_text = "-1 = random"
	row.add_child(debug_seed)
	var rs := Button.new()
	rs.text = "Restart"
	rs.pressed.connect(func() -> void:
		var txt := debug_seed.text.strip_edges()
		restart(int(txt) if txt.is_valid_int() else DiceRoller.RANDOM_SEED))
	row.add_child(rs)
	var frow := HBoxContainer.new()
	v.add_child(frow)
	debug_force = CheckBox.new()
	debug_force.text = "Force next roll"
	frow.add_child(debug_force)
	debug_a = SpinBox.new()
	debug_a.min_value = 1
	debug_a.max_value = 6
	debug_a.value = 3
	frow.add_child(debug_a)
	debug_b = SpinBox.new()
	debug_b.min_value = 1
	debug_b.max_value = 6
	debug_b.value = 4
	frow.add_child(debug_b)
	debug_reduced = CheckBox.new()
	debug_reduced.text = "Reduced motion"
	debug_reduced.toggled.connect(set_reduced_motion)
	v.add_child(debug_reduced)
	var srow := HBoxContainer.new()
	v.add_child(srow)
	var spl := Label.new()
	spl.text = "Roll speed (T)"
	srow.add_child(spl)
	debug_speed = OptionButton.new()
	for n in SPEED_NAMES:
		debug_speed.add_item(n)
	debug_speed.select(speed_mode)
	debug_speed.item_selected.connect(set_speed_mode)
	srow.add_child(debug_speed)


func _on_viewport_resized() -> void:
	# Phones (portrait, or a short side of 500 px or less) get the phone
	# framing so dice stay >= tuning.min_die_px; desktop keeps the spec camera.
	if DisplayServer.get_name() == "headless":
		return  # tests pick their own framing (see tests/test_table_3d.gd)
	var px := Vector2(get_window().size)
	if px.y > px.x or minf(px.x, px.y) <= 500.0:
		fit_phone(px)


## Phone framing: the view centers between the hand and the landing zone and
## dollies in until every on-screen resting die is >= tuning.min_die_px.
## (The table's far corners crop; a real phone layout is a later step.)
func fit_phone(size: Vector2) -> float:
	var zone := Vector3(0, tuning.die_size * 0.5, 0)
	return camera.fit_dice(size, zone, HAND, rest_spots(), [hand_spot(0), hand_spot(1), zone])


## Where dice wait or come to rest: the hand and a grid over the felt.
func rest_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = [hand_spot(0), hand_spot(1)]
	for x in [-0.45, 0.0, 0.45]:
		for z in [-0.4, -0.12, 0.12, 0.4]:
			spots.append(Vector3(x, tuning.die_size * 0.5, z))
	return spots


# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		var p := mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if phase == Phase.ROLL or phase == Phase.REVEAL or phase == Phase.RESOLVE:
				skip()
			elif phase == Phase.BET and _hand_contains(p):
				_grab(p)
			elif phase == Phase.BET and _pass_contains(p):
				_add_chip()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and phase == Phase.HELD:
			var v := gesture.release(p, flick_time())
			phase = Phase.BET
			throw(v, p, gesture.drag_distance())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and phase == Phase.BET and _pass_contains(p):
			_take_down()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		var hover := _pass_contains(mm.position)
		if hover != _last_hover:
			_last_hover = hover
			table.felt_print.pass_hover = hover
			table.felt_print.refresh()
		if phase == Phase.HELD:
			gesture.move(mm.position, flick_time())
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE, KEY_ENTER:
				if phase == Phase.ROLL or phase == Phase.REVEAL or phase == Phase.RESOLVE:
					skip()
				elif phase == Phase.OVER:
					next_table()
				elif phase == Phase.BET:
					quick_throw()
			KEY_UP, KEY_EQUAL, KEY_KP_ADD:
				_add_chip()
			KEY_DOWN, KEY_MINUS, KEY_BACKSPACE:
				_take_down()
			KEY_R:
				set_reduced_motion(not reduced_motion)
			KEY_T:
				set_speed_mode((speed_mode + 1) % 3)
			KEY_S:
				stop_total()
			KEY_F1:
				debug_panel.visible = not debug_panel.visible


func _hand_contains(p: Vector2) -> bool:
	var w := screen_to_plane(p, tuning.die_size * 0.5)
	if Vector2(w.x - HAND.x, w.z - HAND.z).length() < 0.16:
		return true
	for d in dice:
		if d.global_position.distance_to(w) < 0.09:
			return true
	return false


func _pass_contains(p: Vector2) -> bool:
	var w := screen_to_plane(p)
	return Table3DBuilder.pass_contains(w.x, w.z)


## Seconds on the flick clock (real time unless flick_clock is set).
func flick_time() -> float:
	if flick_clock.is_valid():
		return float(flick_clock.call())
	return Time.get_ticks_usec() / 1000000.0


func _grab(p: Vector2) -> void:
	var reason := can_throw()
	if reason != "":
		_refuse_throw(reason)
		return
	phase = Phase.HELD
	gesture.press(p, flick_time())
	sfx.play(&"dice_grab")
	_set_why("Flick to throw! (A slow release drops them back in your hand.)")


func _process(delta: float) -> void:
	_t += delta
	_hand_shake = maxf(_hand_shake - delta, 0.0)
	if phase == Phase.HELD:
		_update_held(delta)
	elif phase == Phase.BET and _hand_shake > 0.0:
		for i in dice.size():
			dice[i].global_position = hand_spot(i) + Vector3(_fx_rng.randf_range(-0.008, 0.008), 0, 0)
	elif phase == Phase.ROLL and _play_t >= 0.0:
		_update_playback(delta)
	# HUD bits anchored to the 3D scene.
	var come_out := not poc.table.craps.has_point()
	var stake := poc.table.stake_on(&"pass")
	var fp := table.felt_print
	var bettable := phase == Phase.BET and come_out and not poc.is_over()
	var locked := not come_out and stake > 0
	if fp.pass_bettable != bettable or fp.pass_has_bet != (stake > 0) or fp.pass_locked != locked:
		fp.pass_bettable = bettable
		fp.pass_has_bet = stake > 0
		fp.pass_locked = locked
		fp.refresh()
	var ready := (phase == Phase.BET or phase == Phase.HELD) and can_throw() == ""
	var glow := hand_glow.material_override as ShaderMaterial
	var a := (0.35 + 0.2 * (0.5 + 0.5 * sin(_t * TAU / 1.2))) if ready else 0.0
	glow.set_shader_parameter("tint", Color(Palette.EMBER, a))
	hand_label.text = "GRAB & FLICK" if ready and phase == Phase.BET else ("BET FIRST" if phase == Phase.BET and not poc.is_over() else "")
	var hp := camera.cam.unproject_position(HAND + Vector3(0, 0, 0.1))
	hand_label.position = hp - Vector2(hand_label.size.x * 0.5, -8)
	var head := camera.cam.unproject_position(dealer.head_anchor.global_position)
	# Beside the dealer's head, kept on screen.
	bubble.position = Vector2(clampf(head.x + 80.0, 40.0, 1920.0 - DealerBubble.WIDTH - 260.0), maxf(head.y + 10.0, 70.0))


func _update_held(delta: float) -> void:
	var m := get_viewport().get_mouse_position() if hold_point_override == Vector2.INF else hold_point_override
	var w := screen_to_plane(m, HOLD_Y)
	var lim := Table3DBuilder.FELT_HALF - Vector2(0.06, 0.06)
	w.x = clampf(w.x, -lim.x, lim.x)
	w.z = clampf(w.z, 0.0, lim.y)
	for i in dice.size():
		var d := dice[i]
		var target := w + (DIE_SPREAD if i == 1 else -DIE_SPREAD) * 0.9
		d.global_position = d.global_position.lerp(target, minf(delta * 22.0, 1.0))
		# Rattle in the fist: a constant small tumble.
		var spin := Basis(Vector3(1, 0.4 * (i * 2 - 1), 0.3).normalized(), delta * 7.0)
		d.global_transform.basis = (spin * d.global_transform.basis).orthonormalized()
	_rattle_t -= delta
	if _rattle_t <= 0.0:
		_rattle_t = 0.22
		sfx.play(&"dice_shake", 1.0, -8.0)


# --- Betting ---------------------------------------------------------------------------

func _add_chip() -> String:
	if phase != Phase.BET or poc.is_over():
		return "Wait for the dice."
	if poc.table.craps.has_point():
		return _refuse_bet("The Pass Line is locked while the Point is on.")
	var stake := poc.table.stake_on(&"pass")
	if stake + tuning.chip_value > tuning.max_bet:
		return _refuse_bet("Table max is %d Coin." % tuning.max_bet)
	var err := poc.place_bet(_pass_type, tuning.chip_value)
	if err != "":
		return _refuse_bet(err)
	var chip := Chip3D.make(tuning.chip_value)
	chip.position = _bank_top()
	chips_root.add_child(chip)
	var i := _felt_chips.size()
	_felt_chips.append(chip)
	_sync_bank_pile()
	_fly(chip, _stack_spot(i), tuning.chip_place_time, 0.0, 0.10)
	sfx.play(&"chip_place", 1.0 + 0.03 * i, 0.0, 0.02)
	stack.show_coin(poc.bankroll.coin, 0.15)
	var new_stake := poc.table.stake_on(&"pass")
	if new_stake >= tuning.max_bet and tuning.max_bet % 25 == 0:
		_merge_chips()
	_set_why("Pass Line: %d Coin. %s" % [new_stake, "Grab the dice and flick!" if new_stake >= tuning.min_bet else ""])
	if new_stake >= tuning.dealer_big_bet_threshold and not _big_bet_taunted:
		_big_bet_taunted = true
		_taunt(&"big_bet")
	_refresh_hud()
	return ""


## At 25 the five red chips collapse into one green 25 (poc_3d.md 4).
func _merge_chips() -> void:
	var old := _felt_chips.duplicate()
	_felt_chips.clear()
	var big := Chip3D.make(25)
	big.position = _stack_spot(0)
	big.scale = Vector3.ZERO
	chips_root.add_child(big)
	_felt_chips.append(big)
	var tw := big.create_tween()
	tw.tween_interval(tuning.chip_place_time + 0.12)
	tw.tween_property(big, "scale", Vector3.ONE * 1.15, 0.08)
	tw.tween_property(big, "scale", Vector3.ONE, 0.08)
	for c in old:
		var tc := (c as Chip3D).create_tween()
		tc.tween_interval(tuning.chip_place_time)
		tc.tween_property(c, "scale", Vector3.ZERO, 0.12)
		tc.tween_callback((c as Chip3D).queue_free)


func _take_down() -> String:
	if phase != Phase.BET or poc.is_over():
		return "Wait for the dice."
	if poc.table.stake_on(&"pass") <= 0:
		return "No bet to take down."
	var err := poc.clear_bet(&"pass")
	if err != "":
		return _refuse_bet(err)
	_collect_felt_chips(0.25, 0.03)
	stack.show_coin(poc.bankroll.coin, 0.3)
	_set_why("Bet taken down.")
	_refresh_hud()
	return ""


func _refuse_bet(reason: String) -> String:
	stack.refuse_shake()
	for c in _felt_chips:
		var tw := c.create_tween()
		var x := c.position.x
		tw.tween_property(c, "position:x", x + 0.008, 0.04)
		tw.tween_property(c, "position:x", x - 0.008, 0.08)
		tw.tween_property(c, "position:x", x, 0.04)
	sfx.play(&"chip_refuse", 0.8, 0.0, 0.0)
	_set_why(reason)
	return reason


func _refuse_throw(reason: String) -> void:
	_hand_shake = 0.25
	sfx.play(&"chip_refuse", 0.7, 0.0, 0.0)
	_set_why(reason)


## Weak flick: the dice fall back into the hand, nothing is rolled.
func _drop_back() -> void:
	phase = Phase.BET
	for i in dice.size():
		var d := dice[i]
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", hand_spot(i), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sfx.play(&"dice_drop", 0.9)
	_set_why("Too soft! Flick harder to throw the dice.")
	dropped_back.emit()


# --- The roll ----------------------------------------------------------------------

## Turns the flick (screen px/s at a screen point) into world launch
## velocities and spins for both dice. Public so tests can check the mapping.
func launch_for(velocity: Vector2, release_pos: Vector2) -> Dictionary:
	var p0 := screen_to_plane(release_pos)
	var p1 := screen_to_plane(release_pos + velocity * 0.05)
	var dir := Vector2(p1.x - p0.x, p1.z - p0.z)
	var c3 := _dice_center()
	var start := Vector2(c3.x, c3.z)
	var aim := (Vector2(AIM_AT.x, AIM_AT.z) - start).normalized()
	if dir.length() < 0.0001:
		dir = aim
	dir = dir.normalized()
	# Keep it within the aim cone so every throw reaches the backboard.
	var cone := deg_to_rad(tuning.throw_aim_cone_deg)
	var ang := clampf(aim.angle_to(dir), -cone, cone)
	dir = aim.rotated(ang)
	var k := clampf((velocity.length() - tuning.min_throw_speed) / maxf(tuning.max_throw_speed - tuning.min_throw_speed, 1.0), 0.0, 1.0)
	var speed := lerpf(tuning.throw_speed_min_mps, tuning.throw_speed_max_mps, k)
	var lin: Array[Vector3] = []
	var spin: Array[Vector3] = []
	var n := dice.size()
	for i in n:
		# Fan the dice out a little: -1..1 across the hand (0 for one die).
		var f := 0.0 if n == 1 else (float(i) - float(n - 1) * 0.5) / (float(n - 1) * 0.5)
		var d := dir.rotated(deg_to_rad(4.0 * f))
		var s := speed * (1.0 + 0.04 * f)
		lin.append(Vector3(d.x * s, tuning.throw_up_mps, d.y * s))
		var axis := Vector3(_fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1), _fx_rng.randf_range(-1, 1))
		if axis.length() < 0.1:
			axis = Vector3.RIGHT
		spin.append(axis.normalized() * _fx_rng.randf_range(tuning.throw_spin_min, tuning.throw_spin_max))
	return {"lin": lin, "spin": spin, "speed": speed}


## Middle of the visible dice.
func _dice_center() -> Vector3:
	var c := Vector3.ZERO
	for d in dice:
		c += d.global_position
	return c / float(maxi(dice.size(), 1))


func _pick_values() -> Array[int]:
	var values: Array[int] = []
	if mode == Mode.RUNNING_TOTAL:
		# One value per die in this throw, from the seeded roller.
		if _rig.size() >= dice.size():
			values = _rig.slice(0, dice.size())
			_rig.clear()
			return values
		var throw_dice: Array[DieData] = []
		for i in dice.size():
			throw_dice.append(_die_data_for(i))
		return DiceRoller.face_values(roller.roll_dice(throw_dice))
	if not _rig.is_empty():
		values = _rig.duplicate()
		_rig.clear()
	elif debug_force != null and debug_force.button_pressed:
		values = [int(debug_a.value), int(debug_b.value)]
	elif not forced_rolls.is_empty():
		var f: Vector2i = forced_rolls.pop_front()
		values = [f.x, f.y]
	else:
		values = DiceRoller.face_values(roller.roll_dice(starting_dice))
	return values


func _play_roll(velocity: Vector2, release_pos: Vector2) -> void:
	phase = Phase.ROLL
	_skip = false
	_apply_speed()
	# The result is decided NOW, at release, by the seeded roller.
	var values := _pick_values()
	if mode == Mode.RUNNING_TOTAL:
		await _play_total_roll(values, velocity, release_pos)
		return
	var point_before := poc.table.craps.point
	var report := poc.roll(values)
	if report.rejected:
		_set_why(report.explanation)
		_drop_back()
		return
	last_values = values
	throw_started.emit()
	thrown.emit(velocity.length())
	_set_why("")
	sum_text.visible = false

	await _throw_dice(values, velocity, release_pos)

	# REVEAL: hold, punch, the sum pops in the outcome color.
	phase = Phase.REVEAL
	dice_landed.emit(values)
	var mid := _dice_center()
	dealer.glance(mid.x)
	camera.follow(mid, tuning.cam_reveal_time)
	await _wait(tuning.reveal_hold)
	_punch_dice()
	await _wait(tuning.sum_pop_delay)
	var r := report.table_report.roll
	var col := Palette.BONE
	if r.is_win():
		col = Palette.BRASS_HI
	elif r.is_loss():
		col = Palette.DANGER
	sum_text.position = camera.cam.unproject_position(mid + Vector3(0, 0.16, -0.05))
	sum_text.pop(str(r.total), col, reduced_motion)
	events.dice_settled.emit()
	sfx.play(&"dice_settle", 1.0, -3.0)
	await _wait(maxf(0.6 - tuning.reveal_hold - tuning.sum_pop_delay, 0.05))
	_set_why(report.explanation)
	outcome_shown.emit(report)

	phase = Phase.RESOLVE
	await _resolve(report, point_before, mid)

	if report.table_ended:
		await _end_table()
		phase = Phase.OVER
		Engine.time_scale = 1.0
		sequence_finished.emit()
		return

	# RESET: camera home, dice slide back to the hand, sum fades.
	phase = Phase.RESET
	camera.go_home(tuning.cam_return_time)
	var rt := tuning.reset_time
	var st := sum_text.create_tween()
	st.tween_property(sum_text, "modulate:a", 0.0, rt)
	for i in dice.size():
		var d := dice[i]
		var tw := d.create_tween()
		tw.tween_method(_arc_die.bind(d, d.global_position, hand_spot(i)), 0.0, 1.0, rt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _wait(maxf(rt, tuning.cam_return_time) + 0.1)
	_refresh_hud()
	phase = Phase.BET
	_skip = false
	Engine.time_scale = 1.0
	sequence_finished.emit()


## The physical throw shared by both modes: simulate the real dice fast
## during the wind-up, remap faces to `values` (seeded), play it back and
## settle. Returns once every die shows its value.
func _throw_dice(values: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
	# Throw the real physics dice (fast, during the wind-up) and record it.
	var launch := launch_for(velocity, release_pos)
	var starts: Array[Transform3D] = []
	for d in dice:
		var tr := d.global_transform
		tr.origin.y = maxf(tr.origin.y, tuning.die_size * 0.75)
		starts.append(tr)
	_sync_colliders()
	_windup()
	var real_start := Time.get_ticks_msec()
	var rec: ThrowRecording = await sim.simulate(starts, launch["lin"], launch["spin"], _fx_rng.randi())
	last_recording = rec
	# Face remap: pick the inner rotation that puts the wanted face where
	# the physical top face ended up; blend into it during the first
	# tumble frames so nothing pops (the dice spin 15-35 rad/s there).
	for i in dice.size():
		var want := DieVisual.remap_basis(rec.up_values[i], values[i], _fx_rng.randf_range(0.0, TAU))
		var visual_now := dice[i].faces.global_transform.basis.orthonormalized()
		var start_body := starts[i].basis.orthonormalized()
		_remap_from[i] = (start_body.inverse() * visual_now).get_rotation_quaternion()
		_remap_to[i] = want.get_rotation_quaternion()
	# Let the wind-up finish in real time (masks the simulation).
	var waited := (Time.get_ticks_msec() - real_start) / 1000.0
	if waited < tuning.windup_time:
		await get_tree().create_timer(tuning.windup_time - waited, true, false, true).timeout
	_play_t = 0.0
	_contact_i = 0
	_last_impact.fill(-1.0)
	_rest_sent.fill(false)
	_tumble_sent.fill(false)
	if speed_mode == 2:
		_play_t = rec.duration()  # Instant: straight to the result
		_contact_i = rec.contacts.size()
	while _play_t >= 0.0:
		await get_tree().process_frame
	await _settle_wobble()
	for i in dice.size():
		dice[i].settled.emit(i, dice[i].up_value())


## RUNNING_TOTAL mode: throw, add each die to the total, count the HUD up,
## then the dice come back to the hand. Stop is a separate action.
func _play_total_roll(values: Array[int], velocity: Vector2, release_pos: Vector2) -> void:
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
	events.dice_settled.emit()
	sfx.play(&"dice_settle", 1.0, -3.0)
	for i in values.size():
		var data := _die_data_for(i)
		running_total.add(values[i], data.display_name if data != null else "Die")
	_loadout_i = (_loadout_i + values.size()) % maxi(starting_dice.size(), 1)
	total_hud.set_line(running_total.target_line)
	total_hud.show_total(running_total, speed_mode == 2)
	sum_text.position = camera.cam.unproject_position(mid + Vector3(0, 0.16, -0.05))
	sum_text.pop("+%d" % _sum(values), Palette.BONE, reduced_motion)
	await _wait(0.45)
	phase = Phase.RESET
	camera.go_home(tuning.cam_return_time)
	var rt := tuning.reset_time
	var st := sum_text.create_tween()
	st.tween_property(sum_text, "modulate:a", 0.0, rt)
	for i in dice.size():
		var d := dice[i]
		dice[i].material = _die_data_for(i).material if _die_data_for(i) != null else "bone"
		var tw := d.create_tween()
		tw.tween_method(_arc_die.bind(d, d.global_position, hand_spot(i)), 0.0, 1.0, rt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _wait(maxf(rt, tuning.cam_return_time) + 0.1)
	_set_why("Total %d. Throw again or Stop (S)." % running_total.total)
	phase = Phase.BET
	_skip = false
	Engine.time_scale = 1.0
	sequence_finished.emit()


static func _sum(values: Array[int]) -> int:
	var t := 0
	for v in values:
		t += v
	return t


func _arc_die(p: float, d: DieVisual, from: Vector3, to: Vector3) -> void:
	d.global_position = from.lerp(to, p) + Vector3(0, 0.06 * sin(PI * p), 0)


## The 0.12 s wind-up: dice dip in the hand (real time, so the physics warp
## doesn't speed it up).
func _windup() -> void:
	for d in dice:
		var tw := d.create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(d, "scale", Vector3(1.08, 0.86, 1.08), tuning.windup_time * 0.5)
		tw.tween_property(d, "scale", Vector3.ONE, tuning.windup_time * 0.5)


## Moves the visible dice along the recording. Contacts play their sounds.
func _update_playback(delta: float) -> void:
	var rec := last_recording
	_play_t += delta
	var t := minf(_play_t, rec.duration())
	for i in rec.count():
		dice[i].global_transform = rec.sample(i, t)
		var k := clampf(t / 0.08, 0.0, 1.0)
		dice[i].faces.basis = Basis(_remap_from[i].slerp(_remap_to[i], k))
	while _contact_i < rec.contacts.size() and (rec.contacts[_contact_i]["t"] as float) <= t:
		_on_contact(rec.contacts[_contact_i])
		_contact_i += 1
	for i in rec.count():
		if not _tumble_sent[i] and rec.tumble_end_t[i] >= 0.0 and t >= rec.tumble_end_t[i]:
			_tumble_sent[i] = true
			dice[i].tumble_ending.emit(i, rec.tumble_end_speed[i])
		if not _rest_sent[i] and rec.rest_t[i] >= 0.0 and t >= rec.rest_t[i]:
			_rest_sent[i] = true
			dice[i].rest.emit(i)
	if _play_t >= rec.duration():
		_play_t = -1.0


## A recorded contact reached its time in the playback: the die emits its
## impact signal (silent under impact_min_speed, throttled per die).
func _on_contact(c: Dictionary) -> void:
	var speed: float = c["speed"]
	var i: int = c["die"]
	if speed < tuning.impact_min_speed:
		return
	if _last_impact[i] >= 0.0 and _play_t - _last_impact[i] < tuning.impact_min_interval:
		return
	_last_impact[i] = _play_t
	var kind := String(c["kind"])
	dice[i].impact.emit(i, kind, speed, float(c.get("impulse", 0.0)), int(c.get("other", -1)), dice[i].material)
	var at := dice[i].global_position
	if kind == "felt" and speed > 0.6:
		Fx3D.burst(fx_root, Vector3(at.x, 0.01, at.z), _n(6), [Color("#2E5A54", 0.4), Color("#2E5A54", 0.0)], Vector2(0.05, 0.2), 80.0, -0.5, Vector2(1.0, 2.0), 0.35, 1.0, false)


## Impact sound. Uses the Sound Designer's SfxManager.play_impact(kind,
## speed_mps, material, die_id) once it exists; until then the current SFX
## events. Already filtered by _on_contact (impact_min_speed floor,
## impact_min_interval per die).
func _on_die_impact(die_id: int, surface: String, speed_mps: float, _impulse: float, _other_id: int, material: String) -> void:
	if surface == "rail" or surface == "backboard":
		_camera_shake(3.0 * clampf(speed_mps / 2.5, 0.0, 1.0), 0.1)
	if events != null:
		events.die_impact.emit(StringName(surface), speed_mps, StringName(material), event_id(dice[die_id]) if die_id >= 0 and die_id < dice.size() else die_id)
	if sfx.has_method("play_impact"):
		sfx.call("play_impact", StringName(surface), speed_mps, StringName(material), die_id)
		return
	var strength := clampf(speed_mps / 2.5, 0.0, 1.0)
	match surface:
		"rail", "backboard":
			sfx.play(&"rim_hit", 0.9 + strength * 0.2, -12.0 + strength * 10.0)
		"die":
			sfx.play(&"dice_hit", 1.25 + strength * 0.2, -12.0 + strength * 8.0)
		"chip", "puck":
			sfx.play(&"chip_place", 0.9 + strength * 0.2, -10.0 + strength * 8.0)
		_:
			sfx.play(&"dice_hit", 0.8 + strength * 0.4, -12.0 + strength * 9.0)


## A die's id on the event surface (TableEvents): its place in the starting
## handful (stays put when the active dice change); else its die_id.
func event_id(d: DieVisual) -> int:
	return int(d.get_meta(&"handful_id", d.die_id)) if d != null else -1


## The die with this event id (TableEvents), or null.
func die_by_id(id: int) -> DieVisual:
	for c in get_children():
		if c is DieVisual and event_id(c) == id:
			return c
	return null


func _on_die_settled(_die_id: int, _face: int) -> void:
	pass  # The reveal plays dice_settle once for the pair (see _play_roll).


## Settle wobble (spec: 0.12 s, damped +-2 degrees around a horizontal axis).
func _settle_wobble() -> void:
	if reduced_motion or speed_mode == 2:
		return
	var base: Array[Basis] = []
	for d in dice:
		base.append(d.global_transform.basis)
	var t := 0.0
	var dur := tuning.settle_wobble_time
	while t < dur:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / dur, 0.0, 1.0)
		var a := deg_to_rad(tuning.settle_wobble_deg) * sin(k * TAU * 1.5) * (1.0 - k)
		for i in dice.size():
			dice[i].global_transform.basis = Basis(Vector3.RIGHT.rotated(Vector3.UP, i * 1.3), a) * base[i]
	for i in dice.size():
		dice[i].global_transform.basis = base[i]


func _punch_dice() -> void:
	if reduced_motion:
		return
	for d in dice:
		var tw := d.create_tween()
		tw.tween_property(d, "scale", Vector3.ONE * 1.12, tuning.reveal_punch_time * 0.5)
		tw.tween_property(d, "scale", Vector3.ONE, tuning.reveal_punch_time * 0.5)


func _resolve(report: PocRollReport, point_before: int, center: Vector3) -> void:
	var r := report.table_report.roll
	var payout := _pass_payout(report)
	var pulse_at := center + Vector3(0, 0.15, 0)
	match r.outcome:
		RollResult.Outcome.NATURAL_WIN:
			_point_rolls = 0
			_camera_shake(tuning.shake_natural_px, 0.15)
			_hit_stop(tuning.hitstop_natural_ms)
			_sparks(center, 40)
			Fx3D.light_pulse(fx_root, pulse_at, Palette.BRASS_HI, 4.0, 0.5)
			_lamp_boost(1.15, 0.3)
			if not reduced_motion:
				Fx3D.starburst(fx_root, center, Palette.BRASS_HI)
			_banner("NATURAL!", "", Palette.BURGUNDY, Palette.BRASS_HI, tuning.resolve_natural, true, 120, false, r.total)
			sfx.play(&"win_big")
			_dealer(&"sulk", &"natural")
			_settle_chips(payout)
			await _wait(tuning.resolve_natural)
		RollResult.Outcome.POINT_HIT:
			_point_rolls = 0
			_camera_shake(tuning.shake_point_hit_px, 0.2)
			_hit_stop(tuning.hitstop_point_hit_ms)
			_sparks(center, 56)
			Fx3D.ring(fx_root, puck.position, Palette.BRASS_HI)
			Fx3D.light_pulse(fx_root, pulse_at, Palette.BRASS_HI, 5.0, 0.6)
			puck.flash_glow()
			_banner("POINT HIT!", "", Palette.BURGUNDY, Palette.BRASS_HI, tuning.resolve_point_hit, true, 120, false, r.total)
			sfx.play(&"win_big", 1.1)
			_dealer(&"sulk", &"point_hit")
			_settle_chips(payout)
			await _wait(0.35)
			table.felt_print.highlighted_point = 0
			table.felt_print.refresh()
			puck.turn_off(_puck_off(), tuning, reduced_motion)
			await _wait(tuning.resolve_point_hit - 0.35)
		RollResult.Outcome.CRAPS_LOSS:
			var sub := {2: "SNAKE EYES", 3: "ACE-DEUCE", 12: "BOXCARS"}.get(r.total, "") as String
			_camera_shake(tuning.shake_craps_px, 0.2)
			_hit_stop(tuning.hitstop_craps_ms)
			_embers(center, 24, 8)
			Fx3D.light_pulse(fx_root, pulse_at, Palette.DANGER, 2.0, 0.4)
			_lamp_boost(0.8, 0.2)
			_grade_pulse("danger_vignette", 0.15 if reduced_motion else 0.2, 0.8)
			_banner("CRAPS", sub, Palette.OXBLOOD, Palette.DANGER, tuning.resolve_craps, false, 120, false, r.total)
			sfx.play(&"seven_out", 1.3, -6.0)
			_dealer(&"gloat", &"craps")
			_settle_chips(payout)
			_burn_soul(report.soul_damage)
			await _wait(tuning.resolve_craps)
		RollResult.Outcome.POINT_SET:
			_point_rolls = 0
			_camera_shake(tuning.shake_point_set_px, 0.12)
			_banner("POINT %d" % r.point_after, "", Palette.UNDERFELT.darkened(0.3), Palette.BONE, tuning.resolve_point_set, false, 84)
			sfx.play(&"tension", 1.0, -6.0, 0.0)
			table.felt_print.highlighted_point = r.point_after
			table.felt_print.refresh()
			var target := Table3DBuilder.point_box_center(r.point_after) + Vector3(0, Puck3D.THICK * 0.5, 0)
			for k in 4:
				var at := puck.position.lerp(target, float(k) / 3.0)
				Fx3D.burst(fx_root, at, _n(3), [Color(Palette.BONE, 0.35), Color(Palette.BONE, 0.0)], Vector2(0.02, 0.1), 60.0, -0.2, Vector2(0.8, 1.6), 0.5, 1.0, false)
			puck.turn_on(r.point_after, target, tuning, reduced_motion)
			_dealer(&"", &"point_set")
			await _wait(tuning.resolve_point_set)
		RollResult.Outcome.SEVEN_OUT:
			var extra := maxi(_point_rolls - 1, 0)
			_point_rolls = 0
			# Silence beat, lamp dips, then impact.
			_lamp_boost(0.3, 0.4)
			lamp.swing(3.0)
			_duck_sfx(0.15)
			await _wait(0.15)
			var shake := tuning.shake_seven_out_px + minf(extra * tuning.escalate_shake_px, tuning.escalate_shake_cap)
			var stop := tuning.hitstop_seven_out_ms + mini(extra * tuning.escalate_hitstop_ms, tuning.escalate_hitstop_cap)
			var embers := 60 + mini(extra * tuning.escalate_embers, tuning.escalate_embers_cap)
			_camera_shake(shake, 0.35)
			_hit_stop(stop)
			camera.roll_tilt(tuning.cam_seven_out_tilt_deg, tuning.cam_tilt_time)
			_embers(center, embers, 20)
			# Felt "chunks": dark teal shards popping up.
			Fx3D.burst(fx_root, center, _n(8), [Color("#0B2724"), Color("#0B2724", 0.0)], Vector2(0.4, 0.8), 50.0, -6.0, Vector2(1.0, 1.6), 0.5, 1.0, false)
			Fx3D.light_pulse(fx_root, pulse_at, Palette.DANGER, 4.0, 0.5)
			_rim_flare()
			if not reduced_motion:
				Fx3D.cracks(fx_root, center, 4 + mini(extra, 2), _fx_rng)
			_grade_pulse("desaturate", 0.45, tuning.resolve_seven_out)
			_grade_pulse("danger_vignette", 0.15 if reduced_motion else 0.35, 0.8)
			puck.flash_danger()
			_banner("SEVEN OUT", "", Palette.DANGER_DARK, Palette.DANGER, tuning.resolve_seven_out, false, 130, true, r.total)
			sfx.play(&"seven_out")
			_dealer(&"gloat", &"seven_out")
			_settle_chips(payout)
			_burn_soul(report.soul_damage)
			await _wait(0.4)
			table.felt_print.highlighted_point = 0
			table.felt_print.refresh()
			puck.turn_off(_puck_off(), tuning, reduced_motion)
			await _wait(maxf(tuning.resolve_seven_out - 0.55, 0.1))
		_:
			if point_before != 0:
				_point_rolls += 1
			sfx.play(&"dice_hit", 0.7, -8.0)
			await _wait(tuning.resolve_no_decision)
	_refresh_hud()
	if poc.soul > 0 and poc.soul <= tuning.dealer_low_soul_threshold and not _low_soul_taunted:
		_low_soul_taunted = true
		await _wait(0.3)
		_taunt(&"low_soul")


func _pass_payout(report: PocRollReport) -> BetPayout:
	for p in report.table_report.payouts:
		if p.bet.id() == &"pass":
			return p
	return null


func _settle_chips(payout: BetPayout) -> void:
	if payout == null:
		return
	match payout.result:
		BetPayout.Result.WIN:
			await _pay_out(payout.profit)
		BetPayout.Result.LOSE:
			await _rake()
		BetPayout.Result.PUSH:
			_collect_felt_chips(tuning.collect_slide_time, 0.02)
	stack.show_coin(poc.bankroll.coin, tuning.countup_time)


## Payout chips slide from the dealer to beside the bet, then everything
## slides to your bankroll (poc_3d.md 4).
func _pay_out(profit: int) -> void:
	var values := ChipView.break_into_chips(profit)
	for i in values.size():
		var c := Chip3D.make(values[i])
		c.position = Table3DBuilder.PAYOUT_ORIGIN + Vector3(0, 0.02, 0)
		c.scale = Vector3.ZERO
		chips_root.add_child(c)
		var target := _stack_spot(i) + Vector3(0.075, 0, 0)
		var tw := c.create_tween()
		tw.tween_interval(tuning.payout_stagger * i)
		tw.tween_property(c, "scale", Vector3.ONE, 0.05)
		tw.tween_property(c, "position", target, tuning.payout_slide_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_felt_chips.append(c)
		sfx.play(&"chip_place", 1.1 + 0.03 * i, -4.0)
	await _wait(tuning.payout_slide_time + tuning.payout_stagger * values.size() + 0.15)
	sfx.play(&"chip_collect")
	_collect_felt_chips(tuning.collect_slide_time, 0.02)


func _collect_felt_chips(seconds: float, stagger: float) -> void:
	var chips := _felt_chips.duplicate()
	_felt_chips.clear()
	var to := _bank_top()
	for i in chips.size():
		var c := chips[i] as Chip3D
		var tw := c.create_tween()
		tw.tween_interval(stagger * i)
		tw.tween_property(c, "position", to, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(c.queue_free)
	get_tree().create_timer(seconds + stagger * chips.size() + 0.05, true, false, false).timeout.connect(_sync_bank_pile)


## The dealer's rake drags the lost chips off the far edge (poc_3d.md 4, 6).
func _rake() -> void:
	var chips := _felt_chips.duplicate()
	_felt_chips.clear()
	if chips.is_empty():
		return
	var rake := dealer.rake
	var spot := _stack_spot(0)
	var behind := spot + Vector3(0, 0, 0.06)
	var tw := rake.create_tween()
	tw.tween_method(func(p: float) -> void: dealer.rake_at(Table3DBuilder.RAKE_ENTRY.lerp(behind, p)), 0.0, 1.0, 0.14)
	await tw.finished
	var drop_to := Vector3(0, 0.0, -0.50)
	var tr := rake.create_tween()
	tr.tween_method(func(p: float) -> void: dealer.rake_at(behind.lerp(drop_to + Vector3(0, 0, 0.06), p)), 0.0, 1.0, tuning.rake_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tr.tween_interval(0.1)
	tr.tween_callback(dealer.rake_rest)
	for c in chips:
		var cv := c as Chip3D
		var tc := cv.create_tween()
		var off := Vector3(_fx_rng.randf_range(-0.04, 0.04), cv.position.y, _fx_rng.randf_range(-0.01, 0.01))
		tc.tween_property(cv, "position", drop_to + off, tuning.rake_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tc.tween_property(cv, "scale", Vector3.ONE * 0.8, 0.12)
		tc.parallel().tween_property(cv, "position:y", -0.2, 0.15)
		tc.tween_callback(cv.queue_free)
	sfx.play(&"chip_collect", 0.7, -2.0)


func _burn_soul(amount: int) -> void:
	if amount <= 0:
		return
	_soul_shown = maxi(_soul_shown - amount, 0)
	soul_meter.burn(amount, _soul_shown)
	sfx.play(&"soul_burn")


func _end_table() -> void:
	var won := poc.status == PocTable.Status.CLEARED
	await _wait(0.3)
	if puck.is_on:
		table.felt_print.highlighted_point = 0
		table.felt_print.refresh()
		puck.turn_off(_puck_off(), tuning, reduced_motion)
	if poc.final_penalty > 0:
		_burn_soul(poc.final_penalty)
	if not _felt_chips.is_empty():
		_collect_felt_chips(tuning.collect_slide_time, 0.02)
		sfx.play(&"chip_collect")
	var bonus := poc.clear_bonus_paid + poc.unused_roll_bonus_paid
	if won and bonus > 0:
		await _pay_out(bonus)
	stack.show_coin(poc.bankroll.coin, tuning.countup_time)
	_refresh_hud()
	_dealer(&"sulk" if won else &"gloat", &"table_win" if won else &"table_fail")
	if won:
		_banner("TABLE CLEARED", "", Palette.BURGUNDY, Palette.BRASS_HI, 1.4, true, 110)
		sfx.play(&"win_big", 0.9)
	await _wait(1.0)
	_show_end()
	table_finished.emit(poc.status)


func _show_end() -> void:
	var won := poc.status == PocTable.Status.CLEARED
	var run_over := poc.soul <= 0
	end_title.text = "RUN OVER" if run_over else ("TABLE CLEARED" if won else "TABLE FAILED")
	end_title.label_settings = Palette.label_settings(88, Palette.BRASS_HI if won else Palette.DANGER, 10, true)
	end_button.text = "RESTART" if run_over else "NEXT TABLE"
	var why := ""
	match poc.fail_reason:
		PocTable.FailReason.OUT_OF_ROLLS:
			why = "Out of rolls short of the target (-%d Soul)." % poc.final_penalty
		PocTable.FailReason.BUST:
			why = "Busted: not enough Coin for a bet (-%d Soul)." % poc.final_penalty
		PocTable.FailReason.SOUL_SPENT:
			why = "Your Soul burned out."
		_:
			why = "Reached %d Coin. Bonus +%d, unused rolls +%d." % [poc.target(), poc.clear_bonus_paid, poc.unused_roll_bonus_paid]
	var surplus := poc.coin_surplus()
	end_body.text = "Table %d: %s\n\nSoul lost: %d   (Soul left %d / %d)\nCoin surplus: %s%d   (bankroll %d)\nRolls used: %d / %d" % [
		table_number, why, poc.soul_lost(), poc.soul, tuning.soul_max, "+" if surplus >= 0 else "", surplus,
		poc.bankroll.coin, poc.rolls_used, poc.roll_limit()]
	end_layer.visible = true


# --- FX helpers -----------------------------------------------------------------

## Particle counts follow reduced motion (x0.3).
func _n(amount: int) -> int:
	return int(round(amount * (tuning.reduced_motion_particles if reduced_motion else 1.0)))


func _sparks(at: Vector3, amount: int) -> void:
	Fx3D.burst(fx_root, at + Vector3(0, 0.03, 0), _n(amount), [Palette.BRASS_HI, Palette.BRASS, Color(Palette.BRASS, 0.0)], Vector2(1.2, 2.5), 50.0, -6.0, Vector2(0.6, 1.2), 0.6, 2.0)


func _embers(at: Vector3, embers: int, soot: int) -> void:
	Fx3D.burst(fx_root, at + Vector3(0, 0.02, 0), _n(embers), [Palette.DANGER, Palette.EMBER, Color(Palette.SMOKE, 0.0)], Vector2(0.3, 0.8), 70.0, 0.4, Vector2(0.5, 1.0), 0.8, 2.0)
	Fx3D.burst(fx_root, at + Vector3(0, 0.02, 0), _n(soot), [Color(Palette.PIT_BLACK, 0.7), Color(Palette.PIT_BLACK, 0.0)], Vector2(0.05, 0.2), 60.0, 0.1, Vector2(3.0, 5.0), 1.2, 1.0, false)


func _lamp_boost(mult: float, seconds: float) -> void:
	if reduced_motion and mult < 1.0:
		mult = lerpf(1.0, mult, 0.5)
	var tw := lamp.create_tween()
	tw.tween_property(lamp, "boost", mult, 0.05)
	tw.tween_interval(seconds)
	tw.tween_property(lamp, "boost", 1.0, 0.25)


func _rim_flare() -> void:
	var tw := rim_light.create_tween()
	tw.tween_property(rim_light, "light_energy", 1.2, 0.05)
	tw.tween_interval(0.3)
	tw.tween_property(rim_light, "light_energy", 0.6, 0.3)


func _camera_shake(px: float, seconds: float) -> void:
	if not reduced_motion:
		camera.shake(px, seconds)


## Freezes the world briefly (Engine.time_scale 0.05), real-time timer.
func _hit_stop(ms: int) -> void:
	if reduced_motion or ms <= 0 or _hitstop or speed_mode == 2:
		return
	_hitstop = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	_hitstop = false
	Engine.time_scale = _speed


func _apply_speed() -> void:
	_speed = test_speed
	if reduced_motion:
		_speed /= maxf(tuning.reduced_motion_time_scale, 0.1)
	if _skip:
		_speed *= tuning.fast_roll_speed
	if speed_mode == 1:
		_speed *= 2.0
	elif speed_mode == 2:
		_speed *= INSTANT_SPEED
	if not _hitstop and not sim.running:
		Engine.time_scale = _speed


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0), true, false, false).timeout


func _banner(text: String, sub: String, ribbon: Color, text_col: Color, duration: float, rays: bool, size: int = 120, jitter: bool = false, badge: int = 0) -> void:
	for b in banner_layer.get_children():
		b.queue_free()
	sum_text.visible = false
	var b := Banner.new()
	b.badge = badge
	b.text = text
	b.subtext = sub
	b.ribbon_color = ribbon
	b.text_color = text_col
	b.text_size = size
	b.rays = rays and not reduced_motion
	b.jitter = jitter and not reduced_motion
	banner_layer.add_child(b)
	b.play(duration, reduced_motion)


func _grade_pulse(param: String, peak: float, seconds: float) -> void:
	var gm := grade.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: gm.set_shader_parameter(param, v), 0.0, peak, 0.1)
	tw.tween_method(func(v: float) -> void: gm.set_shader_parameter(param, v), peak, 0.0, seconds)


func _duck_sfx(seconds: float) -> void:
	var bus := AudioServer.get_bus_index(SfxManager.BUS_NAME)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, -30.0)
	await get_tree().create_timer(seconds, true, false, true).timeout
	AudioServer.set_bus_volume_db(bus, 0.0)


func _dealer(pose: StringName, event: StringName) -> void:
	if pose != &"":
		dealer.react(pose)
	_taunt(event)


func _taunt(event: StringName) -> void:
	var line := lines.pick(event) if lines != null else ""
	if line == "":
		return
	dealer.flare_eyes()
	bubble.say(line, 2.4, reduced_motion)
	sfx.play(&"dealer_taunt", 1.0, -3.0, 0.08)
	taunted.emit(event, line)


## A chip hop: straight line plus an arc, with a little spin.
func _fly(node: Node3D, to: Vector3, seconds: float, delay: float, arc: float) -> void:
	var from := node.position
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_arc_step.bind(node, from, to, arc), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "rotation:y", node.rotation.y + _fx_rng.randf_range(PI, TAU), seconds)
	tw.tween_property(node, "scale", Vector3(1.0, 0.8, 1.0), 0.02)
	tw.tween_property(node, "scale", Vector3.ONE, 0.04)


func _arc_step(p: float, node: Node3D, from: Vector3, to: Vector3, arc: float) -> void:
	node.position = from.lerp(to, p) + Vector3(0, arc * sin(PI * p), 0)


# --- Positions ---------------------------------------------------------------------

func _puck_off() -> Vector3:
	return Table3DBuilder.PUCK_OFF + Vector3(0, Puck3D.THICK * 0.5, 0)


func _stack_spot(i: int) -> Vector3:
	return Table3DBuilder.BET_SPOT + Vector3(0, Chip3D.THICK * 0.5 + Chip3D.STEP * i, 0)


func _bank_top() -> Vector3:
	return Table3DBuilder.BANKROLL + Vector3(0, Chip3D.THICK * 0.5 + Chip3D.STEP * _bank_chips.size(), 0)


## Your bankroll as a 3D chip pile on the near rail (max 12, spec 4).
func _sync_bank_pile() -> void:
	if poc == null:
		return
	@warning_ignore("integer_division")
	var n := mini(poc.bankroll.coin / maxi(tuning.chip_value, 1), 12)
	while _bank_chips.size() > n:
		_bank_chips.pop_back().queue_free()
	while _bank_chips.size() < n:
		var c := Chip3D.make(tuning.chip_value)
		var i := _bank_chips.size()
		c.position = Table3DBuilder.BANKROLL + Vector3(_fx_rng.randf_range(-0.0008, 0.0008), Chip3D.THICK * 0.5 + Chip3D.STEP * i, _fx_rng.randf_range(-0.0008, 0.0008))
		c.rotation.y = deg_to_rad(_fx_rng.randf_range(-25, 25))
		chips_root.add_child(c)
		_bank_chips.append(c)


func _set_why(text: String) -> void:
	why_label.text = text


func _refresh_hud() -> void:
	table_label.text = "TABLE %d" % table_number
	target_label.text = str(poc.target())
	rolls_label.text = str(poc.rolls_left())
	rolls_label.label_settings = Palette.label_settings(64, Palette.DANGER if poc.rolls_left() <= 3 else Palette.BONE, 7, true)
