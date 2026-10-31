## Layer 1 of the Bonfire HUD (see bonfire_hud.gd for the whole picture).
## Holds the HUD's signals, constants and variables, and builds every label,
## button and panel once in _init. The HUD script is split into a chain:
##   BonfireHudBuild -> BonfireHudGoal -> BonfireHud (the real node).
## Only BonfireHud is ever created; the layers just keep each file short.
@abstract
class_name BonfireHudBuild
extends Control


# Declared here, written in a later layer (the chain ends at BonfireHud).
# "@abstract" only promises the function exists so this file can call it.
@abstract func press_leave() -> void
@abstract func refresh(run: BonfireRun, can_act: bool) -> void
@abstract func _refresh_rules(run: BonfireRun) -> void
@abstract func _place_rules() -> void
@abstract func callout(at: Vector2, text: String = "doesn't score") -> void


signal bank_pressed
signal throw_pressed
signal restart_pressed
## Run mode: the end panel's CONTINUE (hand the outcome back to the run).
signal continue_pressed
## A cleared table: the player taps Leave table (between hands only).
signal leave_pressed

var coin_label: Label
var points_label: Label
## The bounty cards' home: a 2 x 2 grid of BountyCards in the top-right
## corner (PC and phone landscape). Hidden in phone portrait, where the goal
## readout at the top shows the same thing.
var checklist_panel: Control
## "CLAIM ALL 3 · 5 hands" over the cards.
var card_header: Label
## Bounty id -> a hidden Label with the bounty's mark ("[x] Triple"): the
## same text the old checklist showed, kept for tests and screen readers.
var bounty_rows: Dictionary = {}
var hands_label: Label
var pot_label: Label
var throw_label: Label
## Under the pot preview: what changed the numbers ("Hot Hand +1 mult ·
## Hellfire x1.5").
var notes_label: Label
## The Hot Hand bust risk (empty unless the hand is hot).
var risk_label: Label
## Set by Bonfire3D before each refresh (it knows which dice will be thrown).
var rethrow_prompt: String = ""
## Design px per pt: 2.0 on PC (the Art Director's UI scale), bigger on a
## phone so the cards keep their 136 x 72 pt size (Bonfire3D sets it).
var ui_pt_px: float = 2.0
var mult_label: Label
var result_label: Label
var bank_button: Button
## "LEAVE TABLE": shown between hands once the table is cleared (Bonfire3D
## decides when; see Bonfire3D.can_leave_now).
var leave_button: Button
## The "TABLE CLEARED" banner shown at the clearing bank (ClearedBanner).
var cleared_banner: ClearedBanner
var throw_button: Button
## Why the THROW / BANK button is greyed out (QA full run pass 1): a small
## caption just above THROW (a child of the button, outside the column's
## layout) plus the buttons' tooltips. Empty while the buttons work.
var action_reason: Label
var end_panel: PanelContainer
var end_title: Label
var end_body: Label
var restart_button: Button
var continue_button: Button
## Active table rules (twists / boss cheats / special dice): name + one line.
var rules_panel: PanelContainer
var rules_box: VBoxContainer
## Juice / onboarding (bonfire_map_events_juice.md sections 3-4).
var countup: BonfireCountUp
var tutorial: BonfireTutorial
## Bounty id -> its BountyCard.
var bounty_cards: Dictionary = {}
## Phone portrait only: the goal + bounty readout near the top (see
## portrait_goal_hud.gd). Hidden on PC and phone landscape.
var portrait_goal: PortraitGoalHud
var _stamps: Dictionary = {}
var _pending_stamps: Dictionary = {}
var _pulse: Array = []
var _t: float = 0.0
## Top-left of the THROW / BANK column (1920x1080 design px). Kept clear of
## the hand (bottom-right) at 16:9, phone landscape and phone portrait.
const BUTTONS_POS := Vector2(184, 790)


func _init() -> void:
	name = "BonfireHud"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_label = _label(40, Palette.EMBER, Vector2(1560, 24), Vector2(340, 50))
	points_label = _label(26, Palette.BONE, Vector2(1560, 72), Vector2(340, 34))
	hands_label = _label(30, Palette.BONE, Vector2(1560, 108), Vector2(340, 40))
	checklist_panel = Control.new()
	checklist_panel.name = "BountyCards"
	checklist_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(checklist_panel)
	card_header = Label.new()
	card_header.name = "CardHeader"
	card_header.label_settings = Palette.label_settings(30, Palette.BRASS_HI, 6, true)
	card_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checklist_panel.add_child(card_header)
	pot_label = _label(64, Palette.BRASS_HI, Vector2(560, 860), Vector2(800, 80))
	# x 520-1400: clear of the bottom-left THROW / BANK column (ends at x 494).
	# Heights are the fonts' real line heights, so the three lines stack
	# without overlapping (930-980, 982-1016, 1018-1060).
	throw_label = _label(36, Palette.EMBER, Vector2(520, 930), Vector2(880, 50))
	notes_label = _label(24, Palette.BONE, Vector2(520, 982), Vector2(880, 34))
	notes_label.name = "PotNotes"
	risk_label = _label(30, Palette.BRASS_HI, Vector2(520, 1018), Vector2(880, 42))
	risk_label.name = "RethrowRisk"
	mult_label = _label(34, Color("#FF2E3E"), Vector2(1260, 880), Vector2(260, 60))
	result_label = _label(64, Palette.BRASS_HI, Vector2(460, 380), Vector2(1000, 90))
	result_label.modulate.a = 0.0
	# The refused-die callout ("doesn't score"), placed over the die.
	callout_label = _label(40, Palette.BONE, Vector2.ZERO, Vector2(420, 56))
	callout_label.name = "Callout"
	callout_label.modulate.a = 0.0
	var col := VBoxContainer.new()
	# Bottom-left, beside the Soul meter: the hand of dice sits bottom-right,
	# and buttons over it ate the grab (QA full run pass 1, M1).
	col.position = BUTTONS_POS
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	throw_button = _button("Throw", 32, Palette.BURGUNDY)
	throw_button.custom_minimum_size = Vector2(310, 84)
	throw_button.pressed.connect(func() -> void: throw_pressed.emit())
	col.add_child(throw_button)
	action_reason = Label.new()
	action_reason.name = "ActionReason"
	action_reason.label_settings = Palette.label_settings(20, Palette.BONE, 4, true)
	action_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_reason.position = Vector2(0, -32)
	action_reason.size = Vector2(310, 28)
	action_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_button.add_child(action_reason)
	bank_button = _button("Bank", 36, Color("#3C6A34"))
	bank_button.custom_minimum_size = Vector2(310, 84)
	bank_button.pressed.connect(func() -> void: bank_pressed.emit())
	col.add_child(bank_button)
	leave_button = _button(LEAVE_TEXT, 32, Palette.FELT_DARK)
	leave_button.name = "LeaveButton"
	leave_button.custom_minimum_size = Vector2(310, 84)
	leave_button.visible = false
	leave_button.pressed.connect(press_leave)
	col.add_child(leave_button)
	rules_panel = PanelContainer.new()
	rules_panel.name = "RulesPanel"
	rules_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.8)))
	# Right column, under the bounty checklist (placed in _refresh_rules).
	rules_panel.position = Vector2(1580, 380)
	rules_panel.custom_minimum_size = Vector2(310, 0)
	rules_panel.size = Vector2(310, 0)
	rules_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules_panel.visible = false
	add_child(rules_panel)
	checklist_panel.resized.connect(_place_rules)
	rules_box = VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 6)
	rules_panel.add_child(rules_box)
	# Added before the end panel so the end screen draws over it.
	portrait_goal = PortraitGoalHud.new()
	add_child(portrait_goal)
	end_panel = PanelContainer.new()
	end_panel.add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.94)))
	end_panel.position = Vector2(560, 300)
	end_panel.custom_minimum_size = Vector2(800, 360)
	end_panel.visible = false
	add_child(end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	end_panel.add_child(box)
	end_title = Label.new()
	end_title.label_settings = Palette.label_settings(64, Palette.BRASS_HI, 8, true)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_title)
	end_body = Label.new()
	end_body.label_settings = Palette.label_settings(28, Palette.BONE, 5)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(end_body)
	restart_button = _button("Restart", 34, Palette.BURGUNDY)
	restart_button.custom_minimum_size = Vector2(360, 80)
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_button)
	continue_button = _button("Continue", 34, Palette.FELT_DARK)
	continue_button.custom_minimum_size = Vector2(360, 80)
	continue_button.visible = false
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(continue_button)
	countup = BonfireCountUp.new()
	add_child(countup)
	move_child(countup, end_panel.get_index())
	# Over the table, under the end panel and the tutorial.
	cleared_banner = ClearedBanner.new()
	add_child(cleared_banner)
	move_child(cleared_banner, end_panel.get_index())
	tutorial = BonfireTutorial.new()
	add_child(tutorial)


## While a pot counts up, the HUD numbers show the values from before the
## commit (Bonfire3D sets this; the run state underneath is already final):
## {embers, points, pot_from, pot_add}. The pot counts up with the count-up.
var display_hold: Dictionary = {}


## The Bonfire3D above this HUD, found once in _ready (null standalone).
var _table: Bonfire3D


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is Bonfire3D):
		n = n.get_parent()
	_table = n as Bonfire3D


## The run's Embers before this table (TableSetup.run_embers), so EMBERS
## shows the player's balance; 0 for the sandbox or without the field.
func _run_embers() -> int:
	var st: TableSetup = _table.setup if _table != null else null
	return int(st.get("run_embers")) if st != null and "run_embers" in st else 0


## Seconds the "Leave? Tap again" question waits for the second tap.
const LEAVE_CONFIRM_S: float = 2.0
const LEAVE_TEXT := "Leave table"
const LEAVE_ASK_TEXT := "Leave? Tap again"
## When the first tap came (seconds on leave_clock), -1 = not asked.
var _leave_asked_at: float = -1.0
## Seconds for the confirm window (tests can swap in a fake clock).
var leave_clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0


## Why THROW / BANK can't be pressed right now ({throw, bank}; "" = it can,
## or the table is busy rolling / counting).
static func action_reasons(run: BonfireRun, can_act: bool) -> Dictionary:
	var out := {"throw": "", "bank": ""}
	if not can_act or run.is_over() or run.forfeited:
		return out
	if run.state == BonfireRun.State.PICK:
		var combo_why := ""
		if not run.can_continue():
			combo_why = "Pot a lit die first" if run.potted.is_empty() else "Not a combo yet: pot ONE combo"
		out["bank"] = combo_why
		if combo_why != "":
			out["throw"] = combo_why
		elif run.is_hot() and not run.hot_hand_allowed():
			out["throw"] = "No Hot Hand at this table: bank it"
	else:
		out["bank"] = "Throw, then pot a combo to bank"
	return out


## The cards' top-right corner (design px): under the Ember / points / hands
## lines, at the screen's right edge.
const CARDS_RIGHT := 1906.0
const CARDS_TOP := 150.0


## Phone landscape: the cards at 0.72 of their PC pt size (9.4 pt title caps),
## so the grid takes ~24% of the width instead of a third.
const PHONE_LANDSCAPE_CARDS := 0.72
var card_mult: float = 1.0


# --- Juice / onboarding -------------------------------------------------------------

const STAMP_STAGGER := 0.12
var _last_stamp_at: float = -10.0
var _stamp_queue: int = 0
## Pending cards whose ghost is crumbling (bust), so refresh leaves them be.
var _crumbling: Dictionary = {}


## A die that can't join the combo: a short "doesn't score" callout over it
## (at `at`, canvas px), which rises a little and fades.
var callout_label: Label


## The banner's text (ClearedBanner.TEXT).
const CLEARED_TEXT := ClearedBanner.TEXT


## Where the bank / bust banner sits (design px): its usual height, and in
## portrait this far under the goal readout.
const RESULT_Y := 380.0
const RESULT_GAP := 40.0


func _label(px: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	l.label_settings = Palette.label_settings(px, col, 6, true)
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String, px: int, fill: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px)
	b.add_theme_stylebox_override("normal", Palette.ink_box(fill))
	b.add_theme_stylebox_override("hover", Palette.ink_box(fill.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", Palette.ink_box(fill.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", Palette.ink_box(Color(fill, 0.4)))
	b.focus_mode = Control.FOCUS_NONE
	return b


## Crack lines and Soul drips over the Soul meter for ~1.2 s.
class FlaskCrack:
	extends Control
	var rect: Rect2
	var reduced: bool = false
	var _age: float = 0.0
	var _lines: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		position = Vector2.ZERO
		size = Vector2(1920, 1080)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var c := rect.get_center() + Vector2(0, -rect.size.y * 0.2)
		for k in 5:
			var pts := PackedVector2Array([c])
			var p := c
			var dir := Vector2.from_angle(rng.randf_range(0, TAU))
			for j in 4:
				p += dir * rect.size.x * rng.randf_range(0.18, 0.32)
				dir = dir.rotated(rng.randf_range(-0.7, 0.7))
				p = p.clamp(rect.position, rect.end)
				pts.append(p)
			_lines.append(pts)

	func _process(delta: float) -> void:
		_age += delta / maxf(Engine.time_scale, 0.001)
		queue_redraw()
		if _age > 1.3:
			queue_free()

	func _draw() -> void:
		var a := clampf(1.3 - _age, 0.0, 1.0)
		var grow := clampf(_age / 0.2, 0.0, 1.0)
		for pts: PackedVector2Array in _lines:
			var n := maxi(2, int(pts.size() * grow))
			draw_polyline(pts.slice(0, n), Color(Palette.SOUL_CORE, a), 3.0)
		if not reduced:
			for k in 3:
				var x := rect.position.x + rect.size.x * (0.3 + 0.2 * k)
				var y := rect.end.y + _age * (140.0 + 40.0 * k)
				draw_circle(Vector2(x, y), 5.0, Color(Palette.SOUL_FLAME, a))
