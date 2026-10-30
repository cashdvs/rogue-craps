## Target HUD v2.1 goal plate (art/concept/hud_target_oct30/v2/HANDOFF_SPEC.md,
## handoff/table_goals_v1_pr1.md §4). One dark plate, 1 px brass hairline:
##   TARGET 300                 [chip] [chip]
##   120 ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ (4 px fill bar)
##   180 to go · 3 hands left    (or "PASSED · 2 hands left  +10")
## Reads a TableGoalState, redraws on `changed`; works out to_go / passed. Icon-only chips (max 2):
## a 150 ms hover or a tap opens a name card. SEALS ("SEALS · 4"): a borderless button outside the plate.
class_name TargetPlate
extends PanelContainer

signal seals_pressed

const CREAM := Palette.BONE
const BAR_FULL := Color("#F0CC72")
const MAX_CHIPS: int = 2
const HOVER_S: float = 0.15

## Design px per spec px (the HUD sets it: PC 1.2, phone = ui_pt_px).
var unit: float = 1.2
## Plate width in spec px (PC 540, phone 510).
var width_spec: float = 540.0
## Inner padding in spec px (PC 16, phone 12).
var pad_spec: float = 16.0
var goal: TableGoalState

var target_label := Label.new()
var target_value := Label.new()
var chip_row := HBoxContainer.new()
var banked_value := Label.new()
var bar := Control.new()
var line3 := Label.new()
var line3_extra := Label.new()
var seals_chip := Button.new()
var card := PanelContainer.new()
var card_label := Label.new()
var _hover := Timer.new()
var _hover_chip: GoalIcon
var _miss_soul: int = -1


## Thousands separators; above 99,999 one decimal plus k (12,400 stays; 123,456 -> "123.5k").
static func fmt(n: int) -> String:
	if n > 99999:
		return "%.1fk" % (n / 1000.0)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Line 3 text: goal_to_go / _one_hand, or goal_passed / _one_hand once banked >= target.
static func status_text(target: int, banked: int, hands_left: int) -> String:
	var one := hands_left == 1
	if banked >= target:
		return GoalStrings.get_text("goal_passed_one_hand" if one else "goal_passed").format({"h": hands_left})
	var id := "goal_to_go_one_hand" if one else "goal_to_go"
	return GoalStrings.get_text(id).format({"n": fmt(target - banked), "h": hands_left})


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.name = "Rows"
	add_child(v)
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(row1)
	target_label.text = GoalStrings.get_text("goal_target_label")
	target_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(target_label)
	row1.add_child(target_value)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(gap)
	chip_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(chip_row)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	row2.add_child(banked_value)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(_draw_bar)
	row2.add_child(bar)
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	row3.add_child(line3)
	row3.add_child(line3_extra)
	seals_chip.flat = true
	seals_chip.top_level = true
	seals_chip.focus_mode = Control.FOCUS_NONE
	seals_chip.pressed.connect(seals_pressed.emit)
	add_child(seals_chip)
	card.top_level = true
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_label)
	add_child(card)
	_hover.one_shot = true
	_hover.wait_time = HOVER_S
	_hover.timeout.connect(func() -> void: _open_card(_hover_chip))
	add_child(_hover)
	restyle()


## Follow `g` (redraws on its `changed`).
func bind(g: TableGoalState) -> void:
	if goal != null and goal.changed.is_connected(refresh):
		goal.changed.disconnect(refresh)
	goal = g
	if g != null:
		g.changed.connect(refresh)
	refresh()


## Sizes and colours for the current `unit` (call after changing it).
func restyle() -> void:
	var u := unit
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PIT_BLACK, 0.85)
	sb.border_color = Palette.BRASS
	sb.set_border_width_all(maxi(1, roundi(u * 0.84)))  # 1 screen px hairline
	sb.set_content_margin_all(pad_spec * u)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = width_spec * u
	target_label.label_settings = _ls(12 * u, Color(CREAM, 0.5))
	target_value.label_settings = _ls(26 * u, CREAM)
	target_value.label_settings.font = Palette.display_font()  # the one big element
	banked_value.label_settings = _ls(13 * u, Palette.BRASS_HI)
	line3.label_settings = _ls(12 * u, Color(CREAM, 0.6))
	line3_extra.label_settings = _ls(12 * u, Palette.BRASS_HI)
	seals_chip.add_theme_font_override("font", Palette.number_font())
	seals_chip.add_theme_font_size_override("font_size", roundi(14 * u))
	seals_chip.add_theme_color_override("font_color", Palette.BRASS_HI)
	card_label.label_settings = _ls(14 * u, CREAM)
	card.add_theme_stylebox_override("panel", sb)
	bar.custom_minimum_size = Vector2(0, 4 * u)
	chip_row.add_theme_constant_override("separation", roundi(12 * u))
	get_node("Rows").add_theme_constant_override("separation", roundi(2 * u))
	for row in [target_label.get_parent(), banked_value.get_parent(), line3.get_parent()]:
		(row as HBoxContainer).add_theme_constant_override("separation", roundi(8 * u))
	refresh()


## Miss end state (Systems Dev's flow calls the HUD): "Missed:" red, then
## "-5 Soul" in Soul cyan. soul < 0 clears it.
func show_miss(soul: int) -> void:
	_miss_soul = soul
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var g := goal
	var target := g.target if g != null else 0
	var banked := g.banked if g != null else 0
	var hands := g.hands_left if g != null else 0
	target_value.text = fmt(target)
	banked_value.text = fmt(banked)
	line3_extra.visible = false
	line3.label_settings.font_color = Color(CREAM, 0.6)
	if _miss_soul >= 0:
		var parts := GoalStrings.get_text("goal_miss").format({"s": _miss_soul}).split(": ", true, 1)
		line3.text = parts[0] + ":"
		line3.label_settings.font_color = Palette.DANGER
		line3_extra.text = parts[1] if parts.size() > 1 else ""
		line3_extra.label_settings.font_color = Palette.SOUL_FLAME
		line3_extra.visible = true
	else:
		line3.text = status_text(target, banked, hands)
		if target > 0 and banked >= target:
			line3_extra.text = GoalStrings.get_text("goal_over").format({"n": fmt(banked - target)})
			line3_extra.label_settings.font_color = Palette.BRASS_HI
			line3_extra.visible = banked > target
	_build_chips(g.bounties if g != null else [])
	var seals := g.seals if g != null else 0
	seals_chip.text = GoalStrings.get_text("hud_seals_chip").format({"n": seals})
	seals_chip.visible = visible and seals > 0  # no empty chip
	bar.queue_redraw()


## Fill 0..1 of the bar (banked / target, clamped).
func fill() -> float:
	if goal == null or goal.target <= 0:
		return 0.0
	return clampf(float(goal.banked) / goal.target, 0.0, 1.0)


## The fill colour: brass, brighter brass (#F0CC72) once full.
func bar_color() -> Color:
	return BAR_FULL if fill() >= 1.0 else Palette.BRASS


func _draw_bar() -> void:
	bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(Palette.BRASS, 0.2))
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * fill(), bar.size.y)), bar_color())


# One icon chip per bounty (max 2; none when the list is empty).
func _build_chips(list: Array) -> void:
	for c in chip_row.get_children():
		chip_row.remove_child(c)
		c.queue_free()
	for b: Dictionary in list.slice(0, MAX_CHIPS):
		var chip := GoalIcon.new()
		chip.icon_id = b.get("icon_id", &"")
		chip.lit = b.get("lit", true)
		chip.tooltip_text = ""  # our own 150 ms card instead of the slow tooltip
		chip.set_meta(&"text", String(b.get("text", "")))
		chip.custom_minimum_size = Vector2.ONE * 24 * unit
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_entered.connect(func() -> void:
			_hover_chip = chip
			_hover.start())
		chip.mouse_exited.connect(func() -> void:
			_hover.stop()
			card.visible = false)
		chip.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
				if card.visible: card.visible = false
				else: _open_card(chip))
		chip_row.add_child(chip)
		var badge := String(b.get("badge", ""))  # e.g. Ledger "+5%"
		if badge != "":
			var l := Label.new()
			l.text = badge
			l.label_settings = _ls(13 * unit, Palette.BRASS_HI)
			chip_row.add_child(l)


## Shows the name card under `chip`.
func _open_card(chip: GoalIcon) -> void:
	if chip == null or not is_instance_valid(chip):
		return
	card_label.text = String(chip.get_meta(&"text", ""))
	card.reset_size()
	card.global_position = chip.global_position + Vector2(0, chip.size.y + 8 * unit)
	card.visible = true


func _ls(px: float, col: Color) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = Palette.number_font()
	s.font_size = roundi(px)
	s.font_color = col
	return s
