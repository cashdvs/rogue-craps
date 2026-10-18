## The POC table: one Pass Line table where FEEL is the point.
##
## Loop: click the chip stack (or the Pass Line) to stack 5-25 Coin, grab the
## two bone dice from your hand, drag and FLICK them onto the felt. They fly
## along the flick, bounce off the rim and settle on faces the seeded
## DiceRoller picked at the moment of release. Then the reveal, the moment
## (Natural / Craps / Point / Seven-out), chips paid or raked, Soul burned,
## and the Dealer across the table has something to say about it.
##
## The rules live in PocTable (pure logic, tested); this script only directs
## what you see and hear. Timings and thresholds come from TuningData.
## Layout follows art/concept/poc_feel.md in 1920x1080 design space.
class_name TableScene
extends Node2D

signal throw_started
signal dropped_back
signal dice_landed(values: Array[int])
signal outcome_shown(report: PocRollReport)
signal sequence_finished
signal table_finished(status: PocTable.Status)
signal taunted(event: StringName, line: String)

enum Phase { BET, HELD, ROLL, REVEAL, RESOLVE, RESET, OVER }

const FELT_RECT := TablePainter.FELT_RECT
const HAND := Vector2(1780, 870)
const HAND_RECT := Rect2(1630, 780, 290, 190)
const DIE_SPREAD := Vector2(66, 0)
## Dice come to rest in here (keeps them off the point row and Pass Line).
const REST_RECT := Rect2(560, 545, 800, 150)
const PASS_SPOT := Vector2(660, 812)
const PAYOUT_SPAWN := Vector2(960, 200)
const RAKE_TARGET := Vector2(960, 160)
const OFF_PUCK := Vector2(380, 225)
## Spec says (960, 470); raised so the ribbon doesn't hide the dice faces.
const BANNER_POS := Vector2(960, 400)
const DEALER_POS := Vector2(960, 62)
const QUICK_THROW := Vector2(-2300, -1250)

@export var starting_dice: Array[DieData] = []
@export var bet_catalog: BetCatalog
@export var tuning: TuningData
@export var dealer_lines_path: String = "res://resources/dealer/dealer_lines.json"
## -1 = random each launch (see DiceRoller.RANDOM_SEED).
@export var rng_seed: int = DiceRoller.RANDOM_SEED
## Debug: totals forced for the next throws, in order (die A, die B).
@export var forced_rolls: Array[Vector2i] = []
## Captures/tests: where held dice go instead of following the mouse.
var hold_point_override := Vector2.INF
## Extra speed multiplier (tests use it to run sequences fast).
@export var test_speed: float = 1.0

var poc: PocTable
var roller: DiceRoller
var lines: DealerLines
var gesture: ThrowGesture
var phase: Phase = Phase.BET
## Tables played this run (Soul carries between them).
var table_number: int = 1
var reduced_motion: bool = false

var _pass_type: BetType
var _dice: Array[DieView] = []
var _felt_chips: Array[ChipView] = []
var _rig: Array[int] = []
var _skip: bool = false
var _speed: float = 1.0
var _hitstop: bool = false
var _point_rolls: int = 0
var _big_bet_taunted: bool = false
var _low_soul_taunted: bool = false
var _soul_shown: int = 0
var _pending: int = 0
var _bulb: float = 1.0
var _bulb_dip: float = 0.0
var _bulb_mute: bool = false
var _hand_shake: float = 0.0
var _rattle_t: float = 0.0
var _t: float = 0.0
var _fx_rng := RandomNumberGenerator.new()

# Nodes (built in code).
var camera: ShakeCamera
var world: Node2D
var felt: ColorRect
var markings: TablePainter
var puck: PuckView
var plaque: RulePlaque
var chips_layer: Node2D
var dice_layer: Node2D
var fx_layer: Node2D
var banner_layer: Node2D
var dealer_body: DealerView
var dealer_hands: DealerView
var bubble: DealerBubble
var hand_glow: HandGlow
var sum_text: PopText
var light: ColorRect
var grade: ColorRect
var hud: CanvasLayer
var soul_meter: SoulMeter
var stack: BankrollStack
var why_label: Label
var target_label: Label
var rolls_label: Label
var help_label: Label
var end_layer: CanvasLayer
var end_title: Label
var end_body: Label
var end_button: Button
var table_label: Label
var debug_panel: PanelContainer
var debug_seed: LineEdit
var debug_force: CheckBox
var debug_a: SpinBox
var debug_b: SpinBox
var debug_reduced: CheckBox
var debug_rule: CheckBox
var sfx: SfxManager


func _ready() -> void:
	if tuning == null:
		tuning = TuningData.new()
	if starting_dice.is_empty():
		var d6 := load("res://resources/dice/standard_d6.tres") as DieData
		starting_dice = [d6, d6]
	if bet_catalog == null:
		bet_catalog = load("res://resources/bets/bet_catalog.tres") as BetCatalog
	_pass_type = bet_catalog.find(&"pass")
	reduced_motion = tuning.reduced_motion
	gesture = ThrowGesture.new(tuning)
	sfx = SfxManager.new()
	add_child(sfx)
	_build_world()
	_build_hud()
	_build_end_screen()
	_build_debug_panel()
	restart(rng_seed)


# --- Public API (tests, captures, debug) ----------------------------------------

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
	poc.soul_changed.connect(_on_soul_changed)
	for c in _felt_chips:
		c.queue_free()
	_felt_chips.clear()
	for n in fx_layer.get_children():
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
	puck.is_on = false
	puck.position = OFF_PUCK
	puck.scale = Vector2.ONE
	markings.highlighted_point = 0
	plaque.rule = poc.rule
	plaque.visible = tuning.table_rule_enabled and tuning.table_rule != null
	plaque.queue_redraw()
	end_layer.visible = false
	(grade.material as ShaderMaterial).set_shader_parameter("desaturate", 0.0)
	(grade.material as ShaderMaterial).set_shader_parameter("danger_vignette", 0.0)
	for i in _dice.size():
		var d := _dice[i]
		d.position = _hand_spot(i)
		d.rotation = 0.0
		d.h = 0.0
		d.modulate.a = 1.0
		d.shown_value = 6 if i == 0 else 5
	sum_text.visible = false
	phase = Phase.BET
	Engine.time_scale = 1.0
	_set_why(("Table %d. " % table_number if table_number > 1 else "") + "Click your chip stack (or the Pass Line) to bet %d-%d Coin, then grab the dice and flick them." % [tuning.min_bet, tuning.max_bet])
	_refresh_hud()


## Adds one chip to a bet (only the Pass Line exists on this table).
## Returns "" on success, else why it was refused.
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


## Is the table animating (input other than skip is ignored)?
func is_busy() -> bool:
	return phase != Phase.BET and phase != Phase.OVER


## Can the dice be thrown right now? Returns "" or the reason.
func can_throw() -> String:
	if poc.is_over():
		return "The table is over."
	if phase != Phase.BET and phase != Phase.HELD:
		return "The dice are still rolling."
	if not poc.table.craps.has_point() and poc.table.stake_on(&"pass") < tuning.min_bet:
		return "Bet at least %d on the Pass Line first." % tuning.min_bet
	return ""


## Throws the dice with a release velocity (px/s in 1920x1080 space).
## drag = how far the mouse moved since the grab; -1 means "enough".
## A weak or tiny flick drops the dice back into the hand: returns false and
## no roll is used. A strong one starts the roll and returns true.
func throw(velocity: Vector2, release_pos: Vector2 = HAND, drag: float = -1.0) -> bool:
	var reason := can_throw()
	if reason != "":
		_refuse_throw(reason)
		return false
	var d := tuning.min_throw_drag if drag < 0.0 else drag
	if not ThrowGesture.is_throw(velocity, d, tuning):
		_drop_back()
		return false
	_play_roll(velocity, release_pos)
	return true


## Keyboard / accessibility throw: a good default flick from the hand.
func quick_throw() -> bool:
	var v := QUICK_THROW.rotated(_fx_rng.randf_range(-0.12, 0.12)) * _fx_rng.randf_range(0.9, 1.1)
	return throw(v, HAND)


## Kept for older callers: same as quick_throw().
func request_roll() -> bool:
	return quick_throw()


## Click-to-skip: plays the rest of this roll at fast_roll_speed.
func skip() -> void:
	if (phase == Phase.REVEAL or phase == Phase.RESOLVE) and not _skip:
		_skip = true
		_apply_speed()


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	camera.disabled = on
	soul_meter.reduced = on
	soul_meter.particle_scale = tuning.reduced_motion_particles if on else 1.0
	if debug_reduced != null:
		debug_reduced.set_pressed_no_signal(on)
	_set_why("Reduced motion %s." % ("ON: no shake or hit-stop, fewer particles, faster" if on else "OFF"))


# --- Building the scene ------------------------------------------------------------

func _build_world() -> void:
	camera = ShakeCamera.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	var backdrop := ColorRect.new()
	backdrop.size = Vector2(3000, 1800)
	backdrop.position = Vector2(-540, -360)
	var bmat := ShaderMaterial.new()
	bmat.shader = load("res://shaders/backdrop.gdshader") as Shader
	backdrop.material = bmat
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(backdrop)

	dealer_body = DealerView.new()
	dealer_body.part = DealerView.Part.BODY
	dealer_body.position = DEALER_POS
	dealer_body.scale = Vector2(0.75, 0.75)
	world.add_child(dealer_body)

	var rim := TablePainter.new()
	rim.mode = TablePainter.Mode.RIM
	world.add_child(rim)

	felt = ColorRect.new()
	felt.position = FELT_RECT.position
	felt.size = FELT_RECT.size
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://shaders/felt.gdshader") as Shader
	fmat.set_shader_parameter("rect_size", FELT_RECT.size)
	felt.material = fmat
	world.add_child(felt)

	markings = TablePainter.new()
	markings.mode = TablePainter.Mode.MARKINGS
	world.add_child(markings)

	plaque = RulePlaque.new()
	plaque.position = Vector2(1470, 300)
	plaque.rect = Rect2(0, 0, 160, 150)
	world.add_child(plaque)

	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	puck = PuckView.new()
	puck.position = OFF_PUCK
	world.add_child(puck)
	chips_layer = Node2D.new()
	world.add_child(chips_layer)

	dealer_hands = DealerView.new()
	dealer_hands.part = DealerView.Part.HANDS
	dealer_hands.position = DEALER_POS
	dealer_hands.scale = Vector2(0.75, 0.75)
	world.add_child(dealer_hands)

	hand_glow = HandGlow.new()
	hand_glow.position = HAND
	world.add_child(hand_glow)

	dice_layer = Node2D.new()
	world.add_child(dice_layer)
	for i in 2:
		var d := DieView.new()
		d.set_cosmetic_seed(1000 + i)
		d.position = _hand_spot(i)
		d.impact.connect(_on_die_impact)
		d.wall_hit.connect(_on_die_wall_hit)
		d.settled.connect(_on_die_settled)
		dice_layer.add_child(d)
		_dice.append(d)

	sum_text = PopText.new()
	sum_text.position = Vector2(960, 300)
	sum_text.visible = false
	world.add_child(sum_text)

	# Bulb light (additive) over the table.
	light = ColorRect.new()
	light.size = Vector2(1920, 1080)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lmat := ShaderMaterial.new()
	lmat.shader = load("res://shaders/bulb_light.gdshader") as Shader
	lmat.set_shader_parameter("bulb_pos", Vector2(960, -80))
	lmat.set_shader_parameter("screen_size", Vector2(1920, 1080))
	lmat.set_shader_parameter("strength", 0.16)
	lmat.set_shader_parameter("cone_width", 0.75)
	light.material = lmat
	world.add_child(light)

	banner_layer = Node2D.new()
	banner_layer.position = BANNER_POS
	world.add_child(banner_layer)

	# Post pass: vignette / danger tint / desaturate (above table, below HUD).
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	grade = ColorRect.new()
	grade.size = Vector2(1920, 1080)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/grade.gdshader") as Shader
	grade.material = gmat
	post.add_child(grade)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)

	soul_meter = SoulMeter.new()
	soul_meter.position = Vector2(60, 250)
	soul_meter.heartbeat.connect(func() -> void: sfx.play(&"heartbeat", 1.0, -4.0, 0.0))
	hud.add_child(soul_meter)

	stack = BankrollStack.new()
	stack.add_chip_requested.connect(func() -> void: _add_chip())
	stack.take_down_requested.connect(func() -> void: _take_down())
	hud.add_child(stack)

	bubble = DealerBubble.new()
	bubble.position = Vector2(1010, 56)
	bubble.visible = false
	hud.add_child(bubble)

	var info := VBoxContainer.new()
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

	why_label = Label.new()
	why_label.position = Vector2(380, 972)
	why_label.size = Vector2(1220, 96)
	why_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	why_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why_label.label_settings = Palette.label_settings(30, Palette.BONE, 6)
	why_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(why_label)

	help_label = Label.new()
	help_label.position = Vector2(24, 14)
	help_label.size = Vector2(420, 120)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.label_settings = Palette.label_settings(20, Color(Palette.BONE, 0.75), 4)
	help_label.text = "Click stack / Pass Line: +%d chip   Right-click: take down\nGrab the dice, drag and flick to throw   Space: quick throw\nClick during a roll: fast-forward   R: reduced motion   F1: debug" % tuning.chip_value
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(help_label)


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
	var again := Button.new()
	end_button = again
	again.text = "NEXT TABLE"
	again.custom_minimum_size = Vector2(380, 96)
	again.add_theme_font_override("font", Palette.display_font())
	again.add_theme_font_size_override("font_size", 44)
	again.add_theme_color_override("font_color", Palette.PIT_BLACK)
	again.add_theme_color_override("font_hover_color", Palette.PIT_BLACK)
	again.add_theme_stylebox_override("normal", Palette.ink_box(Palette.BRASS, 18, 5))
	again.add_theme_stylebox_override("hover", Palette.ink_box(Palette.BRASS_HI, 18, 5))
	again.add_theme_stylebox_override("pressed", Palette.ink_box(Palette.EMBER, 18, 5))
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(next_table)
	box.add_child(again)


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
	debug_rule = CheckBox.new()
	debug_rule.text = "Hot Seven rule (restarts)"
	debug_rule.button_pressed = tuning.table_rule_enabled
	debug_rule.toggled.connect(func(on: bool) -> void:
		tuning.table_rule_enabled = on
		restart(rng_seed))
	v.add_child(debug_rule)


# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		var p := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if phase == Phase.REVEAL or phase == Phase.RESOLVE:
				skip()
			elif phase == Phase.BET and _hand_contains(p):
				_grab(p)
			elif phase == Phase.BET and _pass_contains(p):
				_add_chip()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and phase == Phase.HELD:
			var now := Time.get_ticks_msec() / 1000.0
			var v := gesture.release(p, now)
			phase = Phase.BET
			throw(v, p, gesture.drag_distance())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and phase == Phase.BET and _pass_contains(p):
			_take_down()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		var p := get_global_mouse_position()
		markings.pass_hover = _pass_contains(p)
		hand_glow.hover = _hand_contains(p)
		if phase == Phase.HELD:
			gesture.move(p, Time.get_ticks_msec() / 1000.0)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_SPACE, KEY_ENTER:
				if phase == Phase.REVEAL or phase == Phase.RESOLVE:
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
			KEY_F1:
				debug_panel.visible = not debug_panel.visible


func _hand_contains(p: Vector2) -> bool:
	if HAND_RECT.has_point(p):
		return true
	for d in _dice:
		if d.position.distance_to(p) < 90.0:
			return true
	return false


func _pass_contains(p: Vector2) -> bool:
	return TablePainter.pass_contains(p) or p.distance_to(PASS_SPOT) < 50.0


func _grab(p: Vector2) -> void:
	var reason := can_throw()
	if reason != "":
		_refuse_throw(reason)
		return
	phase = Phase.HELD
	gesture.press(p, Time.get_ticks_msec() / 1000.0)
	sfx.play(&"dice_grab")
	_set_why("Flick to throw! (A slow release drops them back in your hand.)")


func _process(delta: float) -> void:
	_t += delta
	_hand_shake = maxf(_hand_shake - delta, 0.0)
	# Held dice follow the mouse with a rattle.
	if phase == Phase.HELD:
		var m := get_global_mouse_position() if hold_point_override == Vector2.INF else hold_point_override
		for i in _dice.size():
			var d := _dice[i]
			var target := m + (DIE_SPREAD if i == 1 else -DIE_SPREAD)
			d.position = d.position.lerp(target, minf(delta * 22.0, 1.0))
			d.rotation = sin(_t * 31.0 + i * 2.0) * 0.12
			d.h = 0.18
			if _fx_rng.randf() < delta * 14.0:
				d.shown_value = _fx_rng.randi_range(1, 6)
		_rattle_t -= delta
		if _rattle_t <= 0.0:
			_rattle_t = 0.22
			sfx.play(&"dice_shake", 1.0, -8.0)
	elif phase == Phase.BET and _hand_shake > 0.0:
		for i in _dice.size():
			_dice[i].position = _hand_spot(i) + Vector2(_fx_rng.randf_range(-6, 6), 0)
	# Bulb flicker -> felt + light shaders.
	var flick := 1.0
	if not _bulb_mute and not reduced_motion:
		if _fx_rng.randf() < delta * 0.35:
			_bulb = _fx_rng.randf_range(0.6, 0.85)
		_bulb = move_toward(_bulb, 1.0, delta * 2.5)
		flick = _bulb + sin(_t * 23.0) * 0.015
	_bulb_dip = move_toward(_bulb_dip, 0.0, delta * 0.8)
	flick *= 1.0 - _bulb_dip
	(felt.material as ShaderMaterial).set_shader_parameter("flicker", flick)
	(light.material as ShaderMaterial).set_shader_parameter("flicker", flick)
	# HUD states.
	var come_out := not poc.table.craps.has_point()
	var stake := poc.table.stake_on(&"pass")
	markings.pass_bettable = phase == Phase.BET and come_out and not poc.is_over()
	markings.pass_has_bet = stake > 0
	markings.pass_locked = not come_out and stake > 0
	hand_glow.ready_to_throw = (phase == Phase.BET or phase == Phase.HELD) and can_throw() == ""
	hand_glow.label = "GRAB & FLICK" if hand_glow.ready_to_throw else ("BET FIRST" if phase == Phase.BET and not poc.is_over() else "")


# --- Betting ---------------------------------------------------------------------------

func _add_chip() -> String:
	if phase != Phase.BET or poc.is_over():
		return "Wait for the dice."
	if poc.table.craps.has_point():
		return _refuse_bet("The Pass Line is locked while the Point is on.")
	var stake := poc.table.stake_on(&"pass")
	if stake + tuning.chip_value > tuning.max_bet:
		return _refuse_bet("Table max is %d Coin." % tuning.max_bet)
	var from := stack.top_chip_global()
	var err := poc.place_bet(_pass_type, tuning.chip_value)
	if err != "":
		return _refuse_bet(err)
	var chip := ChipView.new()
	chip.value = tuning.chip_value
	chip.position = from
	chips_layer.add_child(chip)
	var i := _felt_chips.size()
	_felt_chips.append(chip)
	_fly(chip, _stack_spot(i), tuning.chip_place_time, 0.0, 40.0)
	sfx.play(&"chip_place", 1.0 + 0.03 * i, 0.0, 0.02)
	stack.show_coin(poc.bankroll.coin, 0.15)
	var new_stake := poc.table.stake_on(&"pass")
	_set_why("Pass Line: %d Coin. %s" % [new_stake, "Grab the dice and flick!" if new_stake >= tuning.min_bet else ""])
	if new_stake >= tuning.dealer_big_bet_threshold and not _big_bet_taunted:
		_big_bet_taunted = true
		_taunt(&"big_bet")
	_refresh_hud()
	return ""


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
		tw.tween_property(c, "position:x", c.position.x + 6.0, 0.04)
		tw.tween_property(c, "position:x", c.position.x - 6.0, 0.08)
		tw.tween_property(c, "position:x", c.position.x, 0.04)
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
	for i in _dice.size():
		var d := _dice[i]
		var tw := d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "position", _hand_spot(i), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "rotation", 0.0, 0.2)
		tw.tween_property(d, "h", 0.0, 0.2)
	sfx.play(&"dice_drop", 0.9)
	_set_why("Too soft! Flick harder to throw the dice.")
	dropped_back.emit()


# --- The roll ----------------------------------------------------------------------

func _play_roll(velocity: Vector2, release_pos: Vector2) -> void:
	phase = Phase.ROLL
	_skip = false
	_apply_speed()
	# The result is decided NOW, at release, by the seeded roller.
	var values: Array[int] = []
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
	var point_before := poc.table.craps.point
	var report := poc.roll(values)
	if report.rejected:
		_set_why(report.explanation)
		phase = Phase.BET
		_drop_back()
		return

	throw_started.emit()
	sfx.play(&"dice_shake")
	_set_why("")
	sum_text.visible = false
	# Plan both paths from the flick, then animate toward the chosen faces.
	var speed := clampf(velocity.length(), tuning.min_throw_speed, tuning.max_throw_speed)
	var k := (speed - tuning.min_throw_speed) / maxf(tuning.max_throw_speed - tuning.min_throw_speed, 1.0)
	var throw_time := lerpf(tuning.throw_time_slow, tuning.throw_time_fast, k)
	var bounds := FELT_RECT.grow(-70.0)
	var paths: Array[PackedVector2Array] = []
	for i in 2:
		var v := velocity.rotated(deg_to_rad(-4.0 if i == 0 else 4.0)) * (0.96 if i == 0 else 1.04)
		var start := _dice[i].position if release_pos.distance_to(_dice[i].position) < 400.0 else release_pos
		paths.append(ThrowGesture.plan_path(start, v, bounds, REST_RECT, tuning))
	_separate_rest(paths)
	_pending = 2
	for i in 2:
		var d := _dice[i]
		if i == 1:
			await _wait(tuning.die_b_delay)
		d.throw_along(paths[i], values[i], tuning, reduced_motion, throw_time)
	while _pending > 0:
		await get_tree().process_frame
	# REVEAL: hold (bulb steady), punch, the sum pops in the outcome color.
	phase = Phase.REVEAL
	dice_landed.emit(values)
	_bulb_mute = true
	await _wait(tuning.reveal_hold)
	for d in _dice:
		d.punch(tuning.reveal_punch_time)
	await _wait(tuning.sum_pop_delay)
	var r := report.table_report.roll
	var col := Palette.BONE
	if r.is_win():
		col = Palette.BRASS_HI
	elif r.is_loss():
		col = Palette.DANGER
	sum_text.pop(str(r.total), col, reduced_motion)
	sfx.play(&"dice_settle", 1.0, -3.0)
	await _wait(maxf(0.6 - tuning.reveal_hold - tuning.sum_pop_delay, 0.05))
	_bulb_mute = false
	_set_why(report.explanation)
	outcome_shown.emit(report)

	# RESOLVE: the moment.
	phase = Phase.RESOLVE
	await _resolve(report, point_before)

	if report.table_ended:
		await _end_table()
		phase = Phase.OVER
		Engine.time_scale = 1.0
		sequence_finished.emit()
		return

	# RESET: dice slide back to the hand, sum fades.
	phase = Phase.RESET
	var rt := tuning.reset_time
	var st := sum_text.create_tween()
	st.tween_property(sum_text, "modulate:a", 0.0, rt)
	for i in _dice.size():
		var d := _dice[i]
		var tw := d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "position", _hand_spot(i), rt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(d, "rotation", 0.0, rt)
		tw.tween_property(d, "modulate:a", 0.6, rt * 0.5)
		tw.chain().tween_property(d, "modulate:a", 1.0, 0.15)
	await _wait(rt + 0.15)
	_refresh_hud()
	phase = Phase.BET
	_skip = false
	Engine.time_scale = 1.0
	hand_glow.pop()
	sequence_finished.emit()


## Keeps the two dice from resting on top of each other.
func _separate_rest(paths: Array[PackedVector2Array]) -> void:
	var a := paths[0][paths[0].size() - 1]
	var b := paths[1][paths[1].size() - 1]
	if a.distance_to(b) >= 140.0:
		return
	var dir := (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var mid := (a + b) * 0.5
	a = mid - dir * 75.0
	b = mid + dir * 75.0
	a = a.clamp(REST_RECT.position, REST_RECT.end)
	b = b.clamp(REST_RECT.position, REST_RECT.end)
	if a.distance_to(b) < 140.0:
		b = a + Vector2(150, 0) if a.x < REST_RECT.end.x - 150.0 else a - Vector2(150, 0)
	paths[0][paths[0].size() - 1] = a
	paths[1][paths[1].size() - 1] = b


func _resolve(report: PocRollReport, point_before: int) -> void:
	var r := report.table_report.roll
	var payout := _pass_payout(report)
	var center := (_dice[0].position + _dice[1].position) * 0.5
	match r.outcome:
		RollResult.Outcome.NATURAL_WIN:
			_point_rolls = 0
			_win_fx(center, 24, tuning.shake_natural_px, 0.15, tuning.hitstop_natural_ms)
			_banner("NATURAL!", "", Palette.BURGUNDY, Palette.BRASS_HI, tuning.resolve_natural, true)
			sfx.play(&"win_big")
			_dealer(&"sulk", &"natural")
			_settle_chips(payout, report)
			await _wait(tuning.resolve_natural)
		RollResult.Outcome.POINT_HIT:
			_point_rolls = 0
			_win_fx(center, 40, tuning.shake_point_hit_px, 0.2, tuning.hitstop_point_hit_ms)
			_ring(puck.position)
			_banner("POINT HIT!", "", Palette.BURGUNDY, Palette.BRASS_HI, tuning.resolve_point_hit, true)
			sfx.play(&"win_big", 1.1)
			_dealer(&"sulk", &"point_hit")
			_settle_chips(payout, report)
			await _wait(0.35)
			markings.highlighted_point = 0
			puck.turn_off(OFF_PUCK, tuning, reduced_motion)
			await _wait(tuning.resolve_point_hit - 0.35)
		RollResult.Outcome.CRAPS_LOSS:
			var sub := {2: "SNAKE EYES", 3: "ACE-DEUCE", 12: "BOXCARS"}.get(r.total, "") as String
			_loss_fx(center, 16, 8, tuning.shake_craps_px, 0.2, tuning.hitstop_craps_ms, 0.2)
			_banner("CRAPS", sub, Palette.OXBLOOD, Palette.DANGER, tuning.resolve_craps, false)
			sfx.play(&"seven_out", 1.3, -6.0)
			_dealer(&"gloat", &"craps")
			_settle_chips(payout, report)
			_burn_soul(report.soul_damage)
			await _wait(tuning.resolve_craps)
		RollResult.Outcome.POINT_SET:
			_point_rolls = 0
			_camera_shake(tuning.shake_point_set_px, 0.12)
			_banner("POINT %d" % r.point_after, "", Palette.UNDERFELT.darkened(0.3), Palette.BONE, tuning.resolve_point_set, false, 84)
			sfx.play(&"tension", 1.0, -6.0, 0.0)
			markings.highlighted_point = r.point_after
			var target := TablePainter.point_box_center(r.point_after)
			_dust_trail(puck.position, target)
			puck.turn_on(r.point_after, target, tuning, reduced_motion)
			_dealer(&"", &"point_set")
			await _wait(tuning.resolve_point_set)
		RollResult.Outcome.SEVEN_OUT:
			var extra := maxi(_point_rolls - 1, 0)
			_point_rolls = 0
			# Silence beat, bulb dips, then impact.
			_bulb_dip = 0.7
			_duck_sfx(0.15)
			await _wait(0.15)
			var shake := tuning.shake_seven_out_px + minf(extra * tuning.escalate_shake_px, tuning.escalate_shake_cap)
			var stop := tuning.hitstop_seven_out_ms + mini(extra * tuning.escalate_hitstop_ms, tuning.escalate_hitstop_cap)
			var embers := 36 + mini(extra * tuning.escalate_embers, tuning.escalate_embers_cap)
			_loss_fx(center, embers, 16, shake, 0.35, stop, 0.35)
			_cracks(center)
			_grade_pulse("desaturate", 0.45, tuning.resolve_seven_out)
			puck.flash_danger()
			_banner("SEVEN OUT", "", Palette.DANGER_DARK, Palette.DANGER, tuning.resolve_seven_out, false, 130, true)
			sfx.play(&"seven_out")
			_dealer(&"gloat", &"seven_out")
			_settle_chips(payout, report)
			_burn_soul(report.soul_damage)
			await _wait(0.4)
			markings.highlighted_point = 0
			puck.turn_off(OFF_PUCK, tuning, reduced_motion)
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


## Chips for the Pass bet: paid and collected, raked, or pushed back.
func _settle_chips(payout: BetPayout, _report: PocRollReport) -> void:
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


func _pay_out(profit: int) -> void:
	var values := ChipView.break_into_chips(profit)
	for i in values.size():
		var c := ChipView.new()
		c.value = values[i]
		c.position = PAYOUT_SPAWN
		c.modulate.a = 0.0
		chips_layer.add_child(c)
		var target := _stack_spot(i) + Vector2(80, 0)
		var tw := c.create_tween()
		tw.tween_interval(tuning.payout_stagger * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.05)
		tw.tween_property(c, "position", target, tuning.payout_slide_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_felt_chips.append(c)
		sfx.play(&"chip_place", 1.1 + 0.03 * i, -4.0)
	await _wait(tuning.payout_slide_time + tuning.payout_stagger * values.size() + 0.15)
	sfx.play(&"chip_collect")
	_collect_felt_chips(tuning.collect_slide_time, 0.02)


## All chips on the felt slide into the bankroll stack.
func _collect_felt_chips(seconds: float, stagger: float) -> void:
	var chips := _felt_chips.duplicate()
	_felt_chips.clear()
	var to := stack.top_chip_global()
	for i in chips.size():
		var c := chips[i] as ChipView
		var tw := c.create_tween()
		tw.tween_interval(stagger * i)
		tw.tween_property(c, "position", to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)


## Brass rake drags the lost chips to the house (poc_feel.md 3).
func _rake() -> void:
	var chips := _felt_chips.duplicate()
	_felt_chips.clear()
	if chips.is_empty():
		return
	var rake := Rake.new()
	rake.position = PASS_SPOT + Vector2(0, -110)
	rake.modulate.a = 0.0
	fx_layer.add_child(rake)
	var tw := rake.create_tween()
	tw.tween_property(rake, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(rake, "position", PASS_SPOT + Vector2(0, 40), 0.12)
	await tw.finished
	var tr := rake.create_tween()
	tr.tween_property(rake, "position", RAKE_TARGET + Vector2(0, 40), tuning.rake_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tr.tween_property(rake, "modulate:a", 0.0, 0.15)
	tr.tween_callback(rake.queue_free)
	for c in chips:
		var cv := c as ChipView
		var tc := cv.create_tween()
		tc.tween_property(cv, "position", RAKE_TARGET + Vector2(_fx_rng.randf_range(-30, 30), _fx_rng.randf_range(-10, 10)), tuning.rake_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tc.tween_property(cv, "modulate:a", 0.0, 0.15)
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
		markings.highlighted_point = 0
		puck.turn_off(OFF_PUCK, tuning, reduced_motion)
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

func _win_fx(at: Vector2, sparks: int, shake_px: float, shake_s: float, stop_ms: int) -> void:
	_camera_shake(shake_px, shake_s)
	_hit_stop(stop_ms)
	_burst(at, sparks, [Palette.BRASS_HI, Palette.BRASS, Color(Palette.EMBER, 0.0)], 300.0, 900.0, Vector2(0, 900), 4.0, 9.0, 0.8)
	var fm := felt.material as ShaderMaterial
	fm.set_shader_parameter("flash", 0.25)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: fm.set_shader_parameter("flash", v), 0.25, 0.0, 0.12)


func _loss_fx(at: Vector2, embers: int, soot: int, shake_px: float, shake_s: float, stop_ms: int, vignette: float) -> void:
	_camera_shake(shake_px, shake_s)
	_hit_stop(stop_ms)
	_burst(at, embers, [Palette.DANGER, Palette.EMBER, Color(Palette.SMOKE, 0.0)], 150.0, 520.0, Vector2(0, -260), 4.0, 8.0, 1.1)
	_burst(at, soot, [Color(Palette.PIT_BLACK, 0.7), Color(Palette.PIT_BLACK, 0.0)], 40.0, 140.0, Vector2(0, -60), 12.0, 24.0, 1.4)
	_grade_pulse("danger_vignette", minf(vignette, 0.15) if reduced_motion else vignette, 0.8)


func _camera_shake(px: float, seconds: float) -> void:
	if not reduced_motion:
		camera.shake(px, seconds)


## Freezes the world briefly (Engine.time_scale 0.05), real-time timer.
func _hit_stop(ms: int) -> void:
	if reduced_motion or ms <= 0 or _hitstop:
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
	if not _hitstop:
		Engine.time_scale = _speed


## Scaled wait (follows hit-stop and fast-forward).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0), true, false, false).timeout


func _burst(at: Vector2, amount: int, colors: Array[Color], v_min: float, v_max: float, gravity: Vector2, s_min: float, s_max: float, life: float) -> void:
	var n := int(round(amount * (tuning.reduced_motion_particles if reduced_motion else 1.0)))
	if n <= 0:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.spread = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.damping_min = 80.0
	p.damping_max = 200.0
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	if colors.size() > 2:
		g.add_point(0.45, colors[1])
	p.color_ramp = g
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5, true, false, true).timeout.connect(p.queue_free)


func _banner(text: String, sub: String, ribbon: Color, text_col: Color, duration: float, rays: bool, size: int = 120, jitter: bool = false) -> void:
	for b in banner_layer.get_children():
		b.queue_free()
	var b := Banner.new()
	b.text = text
	b.subtext = sub
	b.ribbon_color = ribbon
	b.text_color = text_col
	b.text_size = size
	b.rays = rays and not reduced_motion
	b.jitter = jitter and not reduced_motion
	banner_layer.add_child(b)
	b.play(duration, reduced_motion)


func _ring(at: Vector2) -> void:
	var ring := Ring.new()
	ring.position = at
	fx_layer.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "radius", 220.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.tween_callback(ring.queue_free)


func _cracks(at: Vector2) -> void:
	if reduced_motion:
		return
	var fm := felt.material as ShaderMaterial
	var st := create_tween()
	st.tween_method(func(v: float) -> void: fm.set_shader_parameter("scorch", v), 1.0, 0.0, 1.6)
	for i in 5:
		var line := Line2D.new()
		line.width = 5.0
		line.default_color = Palette.DANGER
		var grad := Gradient.new()
		grad.set_color(0, Palette.DANGER)
		grad.set_color(1, Color(Palette.OXBLOOD, 0.6))
		line.gradient = grad
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		var pts := PackedVector2Array([at])
		var dir := Vector2.from_angle(TAU * float(i) / 5.0 + _fx_rng.randf_range(-0.4, 0.4))
		var p := at
		var length := _fx_rng.randf_range(120.0, 260.0)
		var steps := 7
		for s in steps:
			p += dir.rotated(_fx_rng.randf_range(-0.6, 0.6)) * (length / steps)
			pts.append(p)
		fx_layer.add_child(line)
		var tw := line.create_tween()
		tw.tween_method(_grow_line.bind(line, pts), 0.0, 1.0, 0.25)
		tw.tween_interval(0.6)
		tw.tween_property(line, "modulate:a", 0.0, 0.8)
		tw.tween_callback(line.queue_free)


func _grow_line(p: float, line: Line2D, pts: PackedVector2Array) -> void:
	var n := clampi(int(ceil(p * (pts.size() - 1))) + 1, 2, pts.size())
	line.points = pts.slice(0, n)


func _dust_trail(from: Vector2, to: Vector2) -> void:
	for i in 4:
		var at := from.lerp(to, float(i) / 3.0)
		_burst(at, 5, [Color(Palette.BONE, 0.35), Color(Palette.BONE, 0.0)], 10.0, 60.0, Vector2(0, -20), 2.0, 4.0, 0.9)


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
		dealer_body.react(pose)
		dealer_hands.react(pose)
	_taunt(event)


func _taunt(event: StringName) -> void:
	var line := lines.pick(event) if lines != null else ""
	if line == "":
		return
	dealer_body.eye_glow = 1.0
	bubble.say(line, 2.4, reduced_motion)
	sfx.play(&"dealer_taunt", 1.0, -3.0, 0.08)
	taunted.emit(event, line)


func _fly(node: Node2D, to: Vector2, seconds: float, delay: float, arc: float) -> void:
	var from := node.position
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_arc_step.bind(node, from, to, arc), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _arc_step(p: float, node: Node2D, from: Vector2, to: Vector2, arc: float) -> void:
	node.position = from.lerp(to, p) + Vector2(0, -arc * sin(PI * p))


func _on_die_impact(die: DieView, strength: float) -> void:
	sfx.play(&"dice_hit", 0.8 + strength * 0.4, -10.0 + strength * 8.0)
	if strength >= 0.5:
		_burst(die.position + Vector2(0, 40), 6, [Color(Palette.BONE, 0.3), Color(Palette.BONE, 0.0)], 30.0, 120.0, Vector2.ZERO, 3.0, 6.0, 0.5)


func _on_die_wall_hit(die: DieView, at: Vector2) -> void:
	sfx.play(&"rim_hit")
	_camera_shake(3.0, 0.1)
	_burst(at, 8, [Color(Palette.RIM_WOOD_HI, 0.8), Color(Palette.RIM_WOOD, 0.0)], 60.0, 220.0, Vector2(0, 200), 3.0, 6.0, 0.5)
	die.h = maxf(die.h, 0.0)


func _on_die_settled(_die: DieView) -> void:
	_pending -= 1


func _on_soul_changed(_new_soul: int, _delta: int, _reason: String) -> void:
	pass  # Visuals are driven by the roll sequence (_burn_soul) for timing.


# --- HUD -------------------------------------------------------------------------

func _hand_spot(i: int) -> Vector2:
	return HAND + (DIE_SPREAD if i == 1 else -DIE_SPREAD)


func _stack_spot(i: int) -> Vector2:
	return PASS_SPOT + Vector2(0, ChipView.STACK_STEP * i)


func _set_why(text: String) -> void:
	why_label.text = text


func _refresh_hud() -> void:
	table_label.text = "TABLE %d" % table_number
	target_label.text = str(poc.target())
	rolls_label.text = str(poc.rolls_left())
	rolls_label.label_settings = Palette.label_settings(64, Palette.DANGER if poc.rolls_left() <= 3 else Palette.BONE, 7, true)


# --- Small drawn helpers ----------------------------------------------------------

## The big sum number that pops after the dice settle.
class PopText extends Node2D:
	var text: String = ""
	var color: Color = Palette.BONE

	func pop(t: String, c: Color, reduced: bool) -> void:
		text = t
		color = c
		visible = true
		modulate.a = 1.0
		queue_redraw()
		if reduced:
			scale = Vector2.ONE
			return
		scale = Vector2(0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.15)

	func _draw() -> void:
		Palette.draw_ink_text(self, Vector2.ZERO, text, 140, color, 16, true)


## Expanding brass shockwave ring (point hit).
class Ring extends Node2D:
	var radius: float = 50.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Palette.BRASS_HI, 8.0, true)
		draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 64, Color(Palette.BONE, 0.5), 3.0, true)


## The croupier's brass rake.
class Rake extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(0, 0), Vector2(220, -700), Palette.PIT_BLACK, 14.0)
		draw_line(Vector2(0, 0), Vector2(220, -700), Palette.RIM_WOOD_HI, 8.0)
		draw_line(Vector2(-90, 0), Vector2(90, 0), Palette.PIT_BLACK, 18.0)
		draw_line(Vector2(-86, 0), Vector2(86, 0), Palette.BRASS, 10.0)
		draw_line(Vector2(-80, -3), Vector2(80, -3), Palette.BRASS_HI, 2.0)


## Ember glow under the dice in your hand: pulses when you can throw.
class HandGlow extends Node2D:
	var ready_to_throw: bool = false
	var hover: bool = false
	var label: String = ""
	var _t: float = 0.0
	var _pop: float = 0.0

	func pop() -> void:
		_pop = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_pop = maxf(_pop - delta * 3.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		var r := Vector2(150, 90) * (1.0 + 0.08 * _pop)
		if ready_to_throw:
			var a := 0.25 + 0.15 * (0.5 + 0.5 * sin(_t * TAU / 1.2)) + (0.15 if hover else 0.0)
			for i in 6:
				var k := 1.0 + float(i) * 0.06
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(r.x * k / 100.0, r.y * k / 100.0))
				draw_circle(Vector2.ZERO, 100.0, Color(Palette.EMBER, a * 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(r.x / 100.0, r.y / 100.0))
		draw_arc(Vector2.ZERO, 100.0, 0.0, TAU, 48, Color(Palette.EMBER if ready_to_throw else Palette.BONE, 0.7 if ready_to_throw else 0.25), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if label != "":
			Palette.draw_ink_text(self, Vector2(0, 118), label, 28, Palette.EMBER if ready_to_throw else Palette.BONE, 6, true)
