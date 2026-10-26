## One item on a shelf (HANDOFF_SPEC §5): its icon above a price tag.
## Clicking buys (emits `buy`); it also emits `focus_item` for PR B's card.
## PR D adds the RARE chip and plinth here, reading `offer.rare`.
class_name ShopItem
extends VBoxContainer

## The mouse moved onto (or a finger tapped) this item.
signal focus_item(item: ShopItem)
## The player clicked to buy this item.
signal buy(offer: ShopOffer)

var offer: ShopOffer
## The picture. PR A: a bone disc with the first letter; PR A2 swaps in
## ShopIcon (3D dice and glyph tokens) here.
var icon: Control
var tag: PriceTag


## Build the item. `art_px` is the icon size, `num_px` the price numeral
## size and `k` the design-px-per-spec-px scale (all in design px).
func setup(o: ShopOffer, embers: int, art_px: float, num_px: int, k: float) -> void:
	offer = o
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", int(6 * k))
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = o.display_name
	icon = _stand_in(o, art_px)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	tag = PriceTag.new()
	tag.setup(o.price_text(), o.affordable(embers) or o.price_lo < 0, num_px, k)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(tag)
	mouse_entered.connect(func() -> void: focus_item.emit(self))


func _gui_input(e: InputEvent) -> void:
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if click or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		focus_item.emit(self)
		buy.emit(offer)
		accept_event()


## A bone disc with the item's first letter on it.
static func _stand_in(o: ShopOffer, px: float) -> Control:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E8DCC0")
	sb.set_corner_radius_all(int(px / 2))
	var l := RunTheme.label(o.display_name.left(1).to_upper(), int(px * 0.5), Color("#1E1712"), true)
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(px, px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
