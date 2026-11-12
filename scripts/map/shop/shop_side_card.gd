## The shop's one floating card (PR C), adding two cards to PR B's item card:
## - the sell / inspect card for a bag die (HANDOFF_SPEC §3, shop_cards_v1 §4), and
## - the reroll card for the Reroll button.
## die_buy_flow_v1: swap preview, confirm only when it matters, RunDie strips.
class_name ShopSideCard
extends ShopCard

## die_buy_flow_v1 strings (design/strings_v1.md, "Bag of 5 swap" rows).
const SWAP_TEXT: Dictionary[String, String] = {
	"shop_swap_pick": "{Click|Tap} the die to give up.",
	"shop_swap_slot_hint": "{Click|Tap} to swap it for {new}.",
	"shop_swap_confirm": "Swap {old} for {new}?",
	"shop_swap_btn": "SWAP · {n} Embers",
	"shop_swap_cancel": "KEEP IT",
	"shop_swap_mods_warn": "Its carved faces go with it.",
	"shop_swap_rare_warn": "Rare die: its forge-carved faces go too.",
	"shop_swap_no_refund": "No refund: it's gone for the run.",
	"shop_swap_done": "{old} out, {new} in.",
	"shop_swap_exit": "{Click|Tap} the counter to keep your dice.",
	"shop_bag_carved_tag": "Carved",
	"event_swap_pick": "{Click|Tap} a die to give up for {new}.",
	"reward_keep_dice": "Keep my dice",
	"hud_dice_count": "YOUR DICE · {n}",
}

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


## {Click|Tap} -> Click on PC, Tap on a phone.
static func plat(text: String, touch: bool) -> String:
	return text.replace("{Click|Tap}", "Tap" if touch else "Click")


## SWAP · {n} Embers; a free event swap is just SWAP.
static func swap_btn(price: int) -> String:
	return SWAP_TEXT.shop_swap_btn.replace("{n}", str(price)) if price > 0 else "SWAP"


## Confirm if the given-up die is player-carved, rare, or this is a phone.
static func needs_confirm(p: RunProgress, die_i: int, touch: bool) -> bool:
	return touch or p.die_has_mods(die_i) or p.die_is_rare(die_i)


## "Swap {old} for {new}?", carved and/or rare warnings, then the no-refund line.
static func swap_lines(p: RunProgress, die_i: int, new_name: String) -> Array[String]:
	var out: Array[String] = [SWAP_TEXT.shop_swap_confirm.format({"old": p.die_name(die_i), "new": new_name})]
	if p.die_has_mods(die_i):
		out.append(SWAP_TEXT.shop_swap_mods_warn)
	if p.die_is_rare(die_i):
		out.append(SWAP_TEXT.shop_swap_rare_warn)
	out.append(SWAP_TEXT.shop_swap_no_refund)
	return out


## The inspect / sell card for bag slot `s`, or the swap card in swap mode.
func show_sell(s: BagSlot, pin: bool) -> void:
	if shop.swap_offer >= 0:
		show_swap(s, pin)
		return
	close()
	slot = s
	pinned = pin
	s.lift(true)
	var p := shop.screen.run.progress
	_frame()
	_title(p.die_name(s.die_i), "")
	_die_tags(p, s.die_i)
	_add_strip(DieCardInfo.from_run(p, s.die_i))
	var def := p.die_def(s.die_i)
	var bone := p.shape_data(DiceIds.DIE_BONE)
	var effect := def.description if def != null else (bone.description if bone != null else "")
	if effect != "":
		_line(effect, CREAM)
	# Sell lines only when the bag is above the starting floor.
	if p.dice.size() > p.data.starting_dice:
		var value := p.sell_value(s.die_i)
		if value > 0:
			_line(ShopCardStrings.fill("shop_card_sell_value", value), DIM)
			_button(ShopCardStrings.fill("shop_card_sell", value), true, GREY, sell)
	_open_at(s.get_global_rect())


## Swap-mode card: PC plain dice get a preview (click commits); carved, rare,
## or phone dice get a pinned confirm with old -> new strips.
func show_swap(s: BagSlot, pin: bool) -> void:
	close()
	slot = s
	pinned = pin
	s.lift(true)
	var run := shop.screen.run
	var p := run.progress
	var offer: SpecialDieData = run.shop_dice[shop.swap_offer]
	var new_name := offer.display_name
	var old_info := DieCardInfo.from_run(p, s.die_i)
	var new_info := SwapPreview.from_def(p, offer)
	var confirm := pin and needs_confirm(p, s.die_i, shop.touch_mode)
	_frame()
	if confirm:
		_title(SWAP_TEXT.shop_swap_confirm.format({"old": p.die_name(s.die_i), "new": new_name}), "")
		_die_tags(p, s.die_i)
		var max_w: float = (WIDTH[shop.layout] - 32.0) * shop.k
		lines.add_child(SwapPreview.make(old_info, new_info, _face_px(), shop.k, max_w, shop.touch_mode))
		for t in swap_lines(p, s.die_i, new_name).slice(1):
			_line(t, RED if t in [SWAP_TEXT.shop_swap_mods_warn, SWAP_TEXT.shop_swap_rare_warn] else DIM)
		_button(swap_btn(run.die_price(shop.swap_offer)), true, GREY, swap)
		var cancel := RunTheme.button(SWAP_TEXT.shop_swap_cancel, _px(23))
		cancel.pressed.connect(func() -> void: shop.exit_swap())
		lines.add_child(cancel)
	else:
		_title(p.die_name(s.die_i), "")
		_die_tags(p, s.die_i)
		_add_strip(old_info)
		_line(plat(SWAP_TEXT.shop_swap_slot_hint, shop.touch_mode).format({"new": new_name}), DIM)
		_line(ShopCardStrings.fill("shop_card_price", run.die_price(shop.swap_offer)), DIM)
	_open_at(s.get_global_rect())


## The SWAP button: pay, give up the open slot's die, take the offer.
func swap() -> void:
	if slot == null:
		return
	shop.commit_swap(slot.die_i)


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
	_line(ShopCardStrings.fill("shop_card_reroll", run.data.reroll_step), CREAM)
	if free > 0:
		_line(ShopCardStrings.fill("shop_card_reroll_free", free), DIM)
	var short := price - run.progress.embers
	var ok := short <= 0
	_button(reroll_label(free > 0) if ok else ShopCardStrings.fill("shop_card_cant_afford", short), ok, RED, reroll)
	# Portrait: sit on the YOUR DICE label like the sell card, never over the bag.
	if shop.layout == ShopScreen.Layout.PORTRAIT and shop.bag_label != null:
		var top := shop.bag_label.get_global_rect().position.y
		_open_at(Rect2(Vector2(get_viewport().get_visible_rect().size.x / 2.0, top + 10 * shop.k), Vector2.ZERO))
	else:
		_open_at(anchor.get_global_rect())


## The reroll card's button (the only reroll on phones).
func reroll() -> void:
	var screen := shop.screen
	shop.swap_offer = -1
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


## RARE chip and/or "Carved" on the card only, at 11 px or larger.
func _die_tags(p: RunProgress, die_i: int) -> void:
	var rare := p.die_is_rare(die_i)
	var carved := p.die_has_mods(die_i)
	if not rare and not carved:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * shop.k))
	var pt := maxi(11, _px(16))
	if rare:
		row.add_child(RareMarks.chip(pt, shop.k * TEXT_SCALE[shop.layout]))
	if carved:
		var lab := RunTheme.label(SWAP_TEXT.shop_bag_carved_tag, pt, BRASS, true)
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(lab)
	lines.add_child(row)


func _face_px() -> float:
	return maxf(24.0, float(_px(42)))


func _add_strip(info: DieCardInfo) -> void:
	var max_w: float = (WIDTH[shop.layout] - 32.0) * shop.k
	lines.add_child(SwapPreview.face_strip(info, _face_px(), shop.k, max_w, shop.touch_mode))


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


## The reroll card's button: "Reroll", or "Reroll free" when it costs nothing.
static func reroll_label(free: bool) -> String:
	var name := ShopCardStrings.get_text("shop_card_reroll_name")
	return name + " " + ShopCardStrings.get_text("shop_card_free").to_lower() if free else name
