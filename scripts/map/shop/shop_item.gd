## One item on a shelf (HANDOFF_SPEC §5): its icon above a price tag.
## PC: click buys, hover / leave emit focus_item / unfocus_item. Phone: a tap only focuses.
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
## The picture: a ShopIcon (3D die or glyph token).
var icon: Control
var tag: PriceTag
## Phone layout (set by ShopScreen; taps arrive as mouse clicks too).
var touch_mode := false
var lifted := false
var _hairline: ReferenceRect
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
	icon = ShopIcon.new()
	(icon as ShopIcon).setup(o, art_px)
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


## Lift the item 10 spec px with a cream hairline while its card is open.
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
