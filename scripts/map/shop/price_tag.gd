## The brass price tag under a counter item (HANDOFF_SPEC §2-3): an EmberPrice
## (coin and number) in cream; red when you can't afford it, grey for a "-" tag.
class_name PriceTag
extends PanelContainer

const CREAM := Color("#E8DCC0")
const RED := Color("#FF2E3E")
const GREY := Color("#8A8478")
const BRASS := Color("#C9A24A")

var label: Label
var price: EmberPrice


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
	price = EmberPrice.new()
	price.setup(text, num_px, GREY if text == "-" else (CREAM if can_afford else RED), scale_px)
	add_child(price)
	label = price.label


## True if the price shows red (can't afford).
func is_red() -> bool:
	return label.get_theme_color("font_color") == RED
