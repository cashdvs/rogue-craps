## The shop's one floating card (PR C), adding two cards to PR B's item card:
## - the sell card for a bag die (HANDOFF_SPEC §3, shop_cards_v1 §4), and
## - the reroll card for the Reroll button.
## It reuses ShopCard's look (plate, face strip, brass button, placement).
class_name ShopSideCard
extends ShopCard

## The bag slot whose sell card is open (null = none).
var slot: BagSlot
## True while the reroll card is open.
var reroll_open := false
## Clicked or tapped open: stays open when the mouse leaves.
var pinned := false


func close() -> void:
	if slot != null and is_instance_valid(slot):
		slot.lift(false)
	slot = null
	reroll_open = false
	pinned = false
	super()


## An item card replaces any open sell or reroll card.
func show_for(it: ShopItem) -> void:
	if slot != null or reroll_open:
		close()
	super(it)


## PC: the mouse left a slot or the Reroll button; close unless pinned.
func leave() -> void:
	if not pinned and (slot != null or reroll_open):
		close()


## The sell card for bag slot `s`: name, face strip, effect, then the sell
## value and button. Bone dice sell for 0, so they get neither.
func show_sell(s: BagSlot, pin: bool) -> void:
	close()
	slot = s
	pinned = pin
	s.lift(true)
	var p := shop.screen.run.progress
	var def := p.die_def(s.die_i)
	_frame()
	_title(p.die_name(s.die_i) if def != null else "Bone Die", "")
	var shown := def if def != null else SpecialDieData.new()  # Bone: plain 1-6.
	lines.add_child(_face_strip(shown))
	var bone := p.shape_data(DiceIds.DIE_BONE)
	var effect := def.description if def != null else (bone.description if bone != null else "")
	if effect != "":
		_line(effect, CREAM)
	var value := p.sell_value(s.die_i)
	if value > 0:
		_line(ShopCardStrings.fill("shop_card_sell_value", value), DIM)
		var floor_n := p.data.starting_dice
		var can := p.dice.size() > floor_n
		var text := ShopCardStrings.fill("shop_card_sell", value) if can else ShopCardStrings.fill("shop_card_cant_sell", floor_n)
		_button(text, can, GREY, sell)
	_open_at(s.get_global_rect())


## The sell button: sell the open slot's die and redraw the shop.
func sell() -> void:
	if slot == null:
		return
	var i := slot.die_i
	var screen := shop.screen
	close()
	if screen.run.sell_die(i):
		screen.refresh()


## The reroll card over `anchor` (the Reroll button): name and price (or
## Free), what it does, banked free rerolls, and a button that rerolls.
func show_reroll(anchor: Control, pin: bool) -> void:
	close()
	reroll_open = true
	pinned = pin
	var run := shop.screen.run
	var free := run.progress.free_rerolls
	var price := run.reroll_price()
	_frame()
	_title(ShopCardStrings.get_text("shop_card_reroll_name"), ShopCardStrings.get_text("shop_card_free") if free > 0 else str(price))
	_line(ShopCardStrings.get_text("shop_card_reroll"), CREAM)
	if free > 0:
		_line(ShopCardStrings.fill("shop_card_reroll_free", free), DIM)
	var short := price - run.progress.embers
	var ok := short <= 0
	_button(ShopCardStrings.get_text("shop_card_buy") if ok else ShopCardStrings.fill("shop_card_cant_afford", short), ok, RED, reroll)
	_open_at(anchor.get_global_rect())


## The reroll card's button (the only reroll on phones).
func reroll() -> void:
	var screen := shop.screen
	close()
	if screen.run.shop_reroll():
		screen.refresh()


## Clear the card and give it ShopCard's plate and width.
func _frame() -> void:
	for c in get_children():
		if c != _timer:
			remove_child(c)
			c.queue_free()
	var sb := _box(PLATE, 10, 16)
	sb.border_color = CREAM
	sb.set_border_width_all(maxi(1, int(2 * shop.k)))
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = WIDTH[shop.layout] * shop.k
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(6 * shop.k))
	add_child(lines)
	action = null


## Line 1: the name, and a price tag when `price` isn't "" (sell cards have none).
func _title(text: String, price: String) -> void:
	var row := HBoxContainer.new()
	lines.add_child(row)
	var title := RunTheme.label(text, _px(32), CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	if price != "":
		var tag := PriceTag.new()
		tag.setup(price, true, _px(32), shop.k * TEXT_SCALE[shop.layout])
		row.add_child(tag)


## One wrapped body line in colour `c`.
func _line(text: String, c: Color) -> void:
	var lab := RunTheme.label(text, _px(23), c)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size.x = (WIDTH[shop.layout] - 32.0) * shop.k
	lines.add_child(lab)


## The brass button; greyed in `off_color` when `ok` is false.
func _button(text: String, ok: bool, off_color: Color, on: Callable) -> void:
	action = RunTheme.button(text, _px(23))
	action.custom_minimum_size.y = 40 * shop.k * TEXT_SCALE[shop.layout]
	action.disabled = not ok
	var bs := _box(BRASS, 6, 0)
	action.add_theme_stylebox_override("normal", bs)
	action.add_theme_stylebox_override("hover", bs)
	action.add_theme_color_override("font_color", DARK)
	action.add_theme_color_override("font_disabled_color", off_color)
	action.pressed.connect(on)
	lines.add_child(action)


func _open_at(anchor: Rect2) -> void:
	visible = true
	reset_size()
	_place(anchor)
