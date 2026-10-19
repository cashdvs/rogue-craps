## Phone-portrait goal readout: a small panel near the top of the screen with
## the table goal (what the Hearth goal plaque shows) and the bounty checklist
## (what the bounty cards show), so a portrait player can see what to aim for
## even though the far rail and its plaque are off screen.
##
## Only shown when the screen is taller than wide (BonfireHud.set_portrait);
## on PC and phone landscape the plaque and the bounty cards are in view, so
## this stays hidden. It never takes clicks (mouse_filter IGNORE).
##
## Each row: the bounty's mini dice icons (DiceIcons, as on the cards) and a
## mark that follows the run live:
##   [ ] open      [?] landed this hand, bank to claim      [x] claimed
class_name PortraitGoalHud
extends PanelContainer

## Where the panel sits in the HUD's 1920x1080 design space: top centre,
## between the help text / combo list (left) and the Embers block (right).
const TOP_LEFT := Vector2(470, 14)
const WIDTH := 1080.0
## Text sizes (design px; a 390 pt-wide phone shows them at ~1/5 size).
const TITLE_PX := 40
const ROW_PX := 34
const ICON_PX := 30.0

## Mark colours: claimed (green), pending (ember), open (bone).
const CLAIMED_COLOR := Color("#9FE08A")

var title_label: Label
var progress_label: Label
var grid: GridContainer
## Bounty id -> its row label (tests read the text: "[x] Triple" etc.).
var rows: Dictionary = {}


func _init() -> void:
	name = "PortraitGoalHud"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = TOP_LEFT
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.72), 10, 3, Palette.BRASS))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# Line 1: "TABLE 1 GOAL" on the left, "1/3 claimed - 4 hands left" on the right.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	title_label = Label.new()
	title_label.label_settings = Palette.label_settings(TITLE_PX, Palette.BRASS_HI, 6, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	progress_label = Label.new()
	progress_label.label_settings = Palette.label_settings(TITLE_PX - 6, Palette.BONE, 5)
	head.add_child(progress_label)
	# Then the bounties, two per row to keep the panel short.
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)


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


## One cell per bounty: its mini dice icons + a label.
func _build_rows(bounties: Array) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	rows.clear()
	for b: BountyData in bounties:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icons := DiceIcons.new()
		icons.die_px = ICON_PX
		icons.set_values(DiceIcons.pattern(b))
		icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(icons)
		var l := Label.new()
		# Each label gets its own LabelSettings so its colour can change alone.
		l.label_settings = Palette.label_settings(ROW_PX, Palette.BONE, 4)
		cell.add_child(l)
		grid.add_child(cell)
		rows[b.id] = l
	reset_size()
