## One item on a shelf (HANDOFF_SPEC §5): its icon above a price tag.
## PC: clicking it buys (emits `buy`); hovering emits `focus_item` and
## leaving emits `unfocus_item` (ShopCard opens after 150 ms).
## Phone (`touch_mode`): a tap only emits `focus_item`; the card's Buy buys.
## PR D adds the RARE chip and plinth here, reading `offer.rare`.
class_name ShopItem
extends VBoxContainer

## The mouse moved onto (or a finger tapped) this item.
signal focus_item(item: ShopItem)
## The player clicked to buy this item.
signal buy(offer: ShopOffer)
## The mouse left this item (PC).
signal unfocus_item(item: ShopItem)

var offer: ShopOffer
## The picture. PR A: a bone disc with the first letter; PR A2 swaps in
## ShopIcon (3D dice and glyph tokens) here.
var icon: Control
var tag: PriceTag
## Phone layouts: taps select only, they never buy (shop_cards_v1 §4).
## Set by ShopScreen. Phones also send a mouse click per tap, so this goes
## by layout, not by event type.
var touch_mode := false
## True while lifted (its card is open).
var lifted := false
var _hairline: ReferenceRect
## Design px per spec px (from setup).
var _k := 1.0


## Build the item. `art_px` is the icon size, `num_px` the price numeral
## size and `k` the design-px-per-spec-px scale (all in design px).
func setup(o: ShopOffer, embers: int, art_px: float, num_px: int, k: float) -> void:
	offer = o
	_k = k
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
	mouse_exited.connect(func() -> void: unfocus_item.emit(self))
	_hairline = ReferenceRect.new()  # 2 px cream outline while lifted.
	_hairline.border_color = Color("#E8DCC0")
	_hairline.border_width = maxf(1.0, 2.0 * k)
	_hairline.editor_only = false
	_hairline.visible = false
	_hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hairline.top_level = true
	add_child(_hairline)


## Lift the item 10 spec px with a cream hairline (its card is open), or
## set it back down.
func lift(on: bool) -> void:
	if on == lifted:
		return
	lifted = on
	position.y += -10.0 * _k if on else 10.0 * _k
	_hairline.visible = on
	if on:
		_hairline.global_position = icon.global_position
		_hairline.size = icon.size


func _gui_input(e: InputEvent) -> void:
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if click or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		accept_event()
		if touch_mode:
			focus_item.emit(self)  # First tap selects; tapping again does nothing more.
		else:
			buy.emit(offer)


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
