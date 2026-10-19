## Phone-portrait goal readout: a panel near the top of the screen with the
## table goal (what the Hearth goal plaque shows) and the bounty checklist
## (what the bounty cards show), so a portrait player can see what to aim for
## even though the far rail and its plaque are off screen.
##
## Only shown when the screen is taller than wide (BonfireHud.set_portrait).
## In portrait it replaces the bounty cards (BonfireHud hides them), so the
## cards' feedback plays here instead:
##   - pulse(ids): rows the current selection could claim glow;
##   - stamp(id): a "CLAIMED" stamp slams onto a row when its bounty is banked;
##   - lost(ids): on a bust, rows that were pending flash red.
## On PC and phone landscape it stays hidden and the cards do all this.
## It never takes clicks (mouse_filter IGNORE).
##
## Each row: the bounty's mini dice icons (DiceIcons, as on the cards) and a
## mark that follows the run live:
##   [ ] open      [?] landed this hand, bank to claim      [x] claimed
##
## Sizes are in the HUD's design pixels. The game stretches a 1920 px wide
## canvas over the screen, so on a 390 px wide phone one design pixel is
## 390 / 1920 = 0.203 screen pixels: 56 design px text = ~11.4 px on screen.
class_name PortraitGoalHud
extends PanelContainer

## Where the panel's top-left corner sits (design px): just right of the
## help text / combo list. The panel is as wide as its longest line
## (~630 px), so its right edge stays well left of the pot row, which runs
## down the right side of the screen in portrait.
const TOP_LEFT := Vector2(500, 14)
## Text sizes (design px). On a 390 px wide phone: title ~12.2 px, the goal
## line ~11.4 px, rows ~11.4 px.
const TITLE_PX := 60
const GOAL_LINE_PX := 56
const ROW_PX := 56
## Mini dice, scaled with the text (the cards use 18 px dice with 22 px text).
const ICON_PX := 46.0

## Row colours: claimed (green), pending (ember), open (bone).
const CLAIMED_COLOR := Color("#9FE08A")
## How long the CLAIMED stamp stays before fading (seconds).
const STAMP_HOLD := 1.1

var title_label: Label
var progress_label: Label
var list: VBoxContainer
## Bounty id -> its row label (tests read the text: "[x] Triple" etc.).
var rows: Dictionary = {}
## Bounty id -> the whole row (icons + label), for the pulse and flashes.
var cells: Dictionary = {}
## Ids currently pulsing (the selection could claim them).
var pulsing: Array = []
## Every id that got a CLAIMED stamp this table, and every id that flashed
## "lost" on a bust (tests read these).
var stamped: Array = []
var lost_flashed: Array = []
## Bounty id -> its stamp label while it is on screen.
var _stamps: Dictionary = {}
var _t: float = 0.0


func _init() -> void:
	name = "PortraitGoalHud"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = TOP_LEFT
	add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.72), 14, 4, Palette.BRASS))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# Line 1: "TABLE 1 GOAL". Line 2: "0/3 claimed  -  5 hands left".
	title_label = Label.new()
	title_label.label_settings = Palette.label_settings(TITLE_PX, Palette.BRASS_HI, 8, true)
	box.add_child(title_label)
	progress_label = Label.new()
	progress_label.label_settings = Palette.label_settings(GOAL_LINE_PX, Palette.BONE, 6)
	box.add_child(progress_label)
	# Then one row per bounty.
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(list)


## Rebuilds the rows if the goal changed, then updates every mark from the
## run. Called from BonfireHud.refresh, so it is live with the bounty cards.
func refresh(run: BonfireRun) -> void:
	var bounties := run.all_bounties()
	if rows.size() != bounties.size() or (not bounties.is_empty() and not rows.has(bounties[0].id)):
		_build_rows(bounties)
	# The goal line: the same goal the plaque stands for.
	var claimed := run.goal.required.size() - run.unticked_required()
	title_label.text = "%s GOAL" % run.goal.display_name.to_upper()
	progress_label.text = "%d/%d claimed  -  %d hands left" % [claimed, run.goal.required.size(), run.hands_left]
	for b: BountyData in bounties:
		var l: Label = rows[b.id]
		var bonus := run.goal.bonus.has(b)
		var mark := "[ ]"
		var col := Palette.BONE if not bonus else Color(Palette.BONE, 0.7)
		if run.is_ticked(b):
			mark = "[x]"
			col = CLAIMED_COLOR
		elif run.is_pending(b):
			mark = "[?]"
			col = Palette.EMBER
		l.text = "%s %s%s" % [mark, b.display_name, ("  +%d" % b.bonus_embers) if bonus else ""]
		l.label_settings.font_color = col


## One row per bounty: its mini dice icons + a label.
func _build_rows(bounties: Array) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	rows.clear()
	cells.clear()
	_stamps.clear()
	stamped.clear()
	lost_flashed.clear()
	pulsing.clear()
	for b: BountyData in bounties:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 14)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icons := DiceIcons.new()
		icons.die_px = ICON_PX
		icons.set_values(DiceIcons.pattern(b))
		icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(icons)
		var l := Label.new()
		# Each label gets its own LabelSettings so its colour can change alone.
		l.label_settings = Palette.label_settings(ROW_PX, Palette.BONE, 6)
		cell.add_child(l)
		list.add_child(cell)
		rows[b.id] = l
		cells[b.id] = cell
	reset_size()


# --- Feedback (in portrait this stands in for the bounty cards) -------------------

## The rows the current selection could claim pulse (others stop).
func pulse(ids: Array) -> void:
	pulsing = ids.duplicate()
	for id in cells:
		if not pulsing.has(id):
			(cells[id] as Control).modulate = Color.WHITE


func _process(delta: float) -> void:
	# Real time, so the pulse keeps its speed in 2x / slow motion.
	_t += delta / maxf(Engine.time_scale, 0.001)
	for id in pulsing:
		var c: Control = cells.get(id)
		if c != null:
			var k := 0.5 + 0.5 * sin(_t * 9.0)
			c.modulate = Color(1.0 + 0.5 * k, 1.0 + 0.25 * k, 1.0, 1.0)


## A bounty was just banked: the row flashes and a CLAIMED stamp slams onto
## its right end, then fades (the row stays green with [x]).
func stamp(id: StringName, reduced: bool = false) -> void:
	var cell: Control = cells.get(id)
	if cell == null or _stamps.has(id):
		return
	stamped.append(id)
	_flash_row(cell, Color(2.0, 2.0, 1.2))
	var l := Label.new()
	l.text = "CLAIMED"
	l.label_settings = Palette.label_settings(40, Palette.BRASS_HI, 6, true)
	l.add_theme_stylebox_override("normal", Palette.ink_box(Color("#8E0F1C"), 10, 4, Palette.BRASS_HI))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.rotation = -0.12
	# On a free layer over the panel (a container would lay the stamp out
	# like a row), at the row's right end.
	_stamp_layer().add_child(l)
	l.position = Vector2(size.x - 300.0, cell.global_position.y - global_position.y)
	_stamps[id] = l
	var tw := l.create_tween().set_ignore_time_scale(true)
	if not reduced:
		l.pivot_offset = Vector2(120, 30)
		l.scale = Vector2.ONE * 2.2
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(STAMP_HOLD)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		_stamps.erase(id)
		l.queue_free())


## A bust: the rows that were pending flash red (their [?] goes back to [ ]).
func lost(ids: Array) -> void:
	for id in ids:
		var cell: Control = cells.get(id)
		if cell != null:
			lost_flashed.append(id)
			_flash_row(cell, Color(2.0, 0.5, 0.45))


## A plain Control over the whole panel that the stamps sit on.
func _stamp_layer() -> Control:
	var layer := get_node_or_null("StampLayer") as Control
	if layer == null:
		layer = Control.new()
		layer.name = "StampLayer"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	return layer


## Has a stamp on screen right now (tests).
func has_stamp(id: StringName) -> bool:
	return _stamps.has(id)


## Tints a row, then eases it back to normal.
func _flash_row(cell: Control, tint: Color) -> void:
	cell.modulate = tint
	var tw := cell.create_tween().set_ignore_time_scale(true)
	tw.tween_property(cell, "modulate", Color.WHITE, 0.6)
