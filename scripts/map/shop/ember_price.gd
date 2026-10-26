## An ember amount (AD): a round #C8783C coin ~0.8x the numeral's cap height,
## centred on the digits, a 4 px gap, then the number. Used by the shop's
## price tags and Embers total; PR B's item card reuses it.
class_name EmberPrice
extends HBoxContainer

const COIN := Color("#C8783C")
const CAP := 0.71  # The numeral font's cap height per px of font size.
const GAP_PX := 4.0  # Spec px between the coin and the number.

var coin: Control
var label: Label
## How far below the coin box's centre the disc is drawn (see setup).
var drop := 0.0


## Show `text` at `num_px` in `color`; `k` is design px per spec px.
func setup(text: String, num_px: int, color: Color, k: float) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", int(round(GAP_PX * k)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = RunTheme.label(text, num_px, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	coin = Control.new()
	coin.custom_minimum_size = Vector2.ONE * round(num_px * CAP * 0.8)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The label box is ascent + descent tall but digits sit on the baseline,
	# so move the disc from the box centre down to the middle of the digits.
	var font := label.get_theme_font("font")
	var asc := font.get_ascent(num_px)
	drop = asc - num_px * CAP / 2 - (asc + font.get_descent(num_px)) / 2
	coin.draw.connect(func() -> void: coin.draw_circle(coin.size / 2 + Vector2(0, drop), coin.size.x / 2, COIN, true, -1.0, true))
	add_child(coin)
	add_child(label)
