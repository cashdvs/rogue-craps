## One item on a shelf (HANDOFF_SPEC §5): its icon above a price tag.
## PR A: clicking it buys (emits `buy`). It already emits `focus_item` on
## hover / tap so PR B's ShopCard can listen without changing this file.
## PR D adds the RARE chip and plinth here, reading `offer.rare`.
class_name ShopItem
extends VBoxContainer

## The mouse moved onto (or a finger tapped) this item.
signal focus_item(item: ShopItem)
## The player clicked to buy this item.
signal buy(offer: ShopOffer)

var offer: ShopOffer
var icon: ShopIcon
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
	icon = ShopIcon.new()
	icon.setup(o, art_px)
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
