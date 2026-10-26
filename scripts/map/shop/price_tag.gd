## The brass price tag under a counter item (HANDOFF_SPEC §2, §3): a dark
## plate with a brass border, an ember coin and the price in cream. The
## numerals turn red (#FF2E3E) when you can't afford the item.
class_name PriceTag
extends PanelContainer

const CREAM := Color("#E8DCC0")
const RED := Color("#FF2E3E")
const COIN := Color("#C8783C")
const BRASS := Color("#C9A24A")

var label: Label
var coin: Panel


## Build the tag. `num_px` is the numeral size; `scale_px` sizes the rest.
func setup(text: String, can_afford: bool, num_px: int, scale_px: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#16110D")
	sb.border_color = BRASS
	sb.set_border_width_all(maxi(1, int(2 * scale_px)))
	sb.set_corner_radius_all(int(4 * scale_px))
	sb.content_margin_left = 8 * scale_px
	sb.content_margin_right = 8 * scale_px
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(74, 34) * scale_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * scale_px))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	coin = Panel.new()  # A round ember coin: a panel with full corner radius.
	var cs := StyleBoxFlat.new()
	cs.bg_color = COIN
	cs.set_corner_radius_all(int(8 * scale_px))
	coin.add_theme_stylebox_override("panel", cs)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.custom_minimum_size = Vector2(12, 12) * scale_px
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	label = RunTheme.label(text, num_px, CREAM if can_afford else RED)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)


## True if the price shows red (can't afford).
func is_red() -> bool:
	return label.get_theme_color("font_color") == RED
