## The visual Ember Shop (art/concept/shop_redesign/HANDOFF_SPEC.md): a wooden
## counter with shelves of goods, each with a brass price tag. Rules and prices
## stay in MapRunShop; this only lays the goods out and forwards clicks.
## A matte counter pad (ShopCounterPad) sits behind each good that has room.
## Smiles (DealerBackdrop) stands behind the rail. The one card (ShopSideCard)
## shows items (PR B), bag dice to sell and the reroll (PR C); PR D adds the rare chip.
class_name ShopScreen
extends Control

enum Layout { PC, LANDSCAPE, PORTRAIT }

const WOOD := Color("#2E1E16")
const GRAIN := Color("#462E20")
const FELT := Color("#407A56")
const BRASS := Color("#C9A24A")
const CREAM := Color("#E8DCC0")

## Per layout, in spec px (§2): counter top (px, or a fraction of the height
## when < 1) and bottom, art size, items per shelf, buttons row y, title size,
## and the dealer box: left and right edge (fractions of the width) and its
## top in spec px; [] = no dealer (landscape has no room); and the bag row:
## its top (a fraction of the height) and slot size in spec px.
## Portrait (PR E): the counter starts at 214, not 170, so Smiles' band grows
## from 106 to 150 px tall (its top stays at 64, under the Ember total). The
## shelves give up their spare gap to pay for it; the bag and buttons stay put.
const LAYOUTS := {
	Layout.PC: {"top": 0.34, "bottom": 0.78, "art": 120.0, "per_shelf": [3, 5], "buttons": 0.85, "title": 32, "dealer": [0.38, 0.62, 70.0], "bag": [0.83, 110.0]},
	Layout.LANDSCAPE: {"top": 62.0, "bottom": 0.74, "art": 46.0, "per_shelf": [8], "buttons": 0.85, "title": 22, "dealer": [], "bag": [0.81, 40.0]},
	Layout.PORTRAIT: {"top": 214.0, "bottom": 0.775, "art": 58.0, "per_shelf": [3, 3, 3], "buttons": 0.9, "title": 16, "dealer": [0.25, 0.75, 64.0], "bag": [0.80, 50.0]},
}
## PC Sell / Swap, Reroll, Leave sizes (spec px); phones fit their text.
const PC_BUTTONS := [Vector2(180, 50), Vector2(210, 50), Vector2(190, 50)]
## Price numerals (spec px): 28 everywhere, so >= 24 real px on phones.
const NUM_PX := 28
## Tests: pretend the window is this many real pixels (0 = the real window).
var window_override := Vector2i.ZERO

var screen: RunScreen
var layout: Layout = Layout.PC
## Design px per spec px: 1 on PC; on phones design px per real px, so phone
## spec sizes are real pixels.
var k: float = 1.0
var items: Array[ShopItem] = []
var shelves: Array[Control] = []
var embers_label: Label
## "Prices on this floor: N% above Floor 1." under the title (Floors 2-3 only).
var floor_note: Label
var reroll_button: Button
var leave_button: Button
var sell_button: Button
var dealer: DealerBackdrop
## The one floating card (items, sell, reroll), rebuilt with the shop.
var card: ShopSideCard
## The bag row's slots, one per die plus empty ones.
var bag: Array[BagSlot] = []
## Sell mode (after Sell / Swap): the bag lifts and the hint shows. It lasts
## until you leave, so it survives the rebuild after each sale.
var selling := false
## Swap mode (bag5_sacrifice_v1 §1): the die offer being bought with a full
## bag; the bag lifts and a slot pick opens the swap card. -1 = off.
var swap_offer := -1
var bag_label: Label
## "Pick a die to sell." in sell mode (hidden otherwise).
var sell_hint: Label
## Second swap-mode hint: click the counter to keep your dice.
var exit_hint: Label
## "{old} out, {new} in." after a swap, shown for about 2 s.
var done_line := ""
var _done_timer: Timer
## Phone layouts (landscape / portrait): taps select, only the card buys.
var touch_mode := false
## Tests force touch on (1) or off (0); -1 asks the device. Any phone or
## tablet with a touchscreen gets the lift-then-Buy card, whatever its aspect.
var touch_override := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(func() -> void: if visible and screen != null: build(screen))


## Pick PC / landscape / portrait from the real window shape, and k.
func pick_layout() -> void:
	var win := Vector2(window_override if window_override != Vector2i.ZERO else get_window().size)
	var vis := get_viewport().get_visible_rect().size
	layout = Layout.PORTRAIT if win.y > win.x else (Layout.LANDSCAPE if win.x / win.y > 1.9 else Layout.PC)
	k = vis.y / 1080.0 if layout == Layout.PC else vis.x / win.x


## (Re)build the whole shop for `s`'s run.
func build(s: RunScreen) -> void:
	screen = s
	for c in get_children():
		if c == _done_timer:
			continue
		remove_child(c)
		c.queue_free()
	items.clear()
	shelves.clear()
	bag.clear()
	dealer = null
	pick_layout()
	touch_mode = touch_override == 1 if touch_override >= 0 else DisplayServer.is_touchscreen_available()
	var vis := get_viewport().get_visible_rect().size
	var spec: Dictionary = LAYOUTS[layout]
	var h := vis.y / k  # Screen height in spec px.
	var top: float = spec.top if spec.top >= 1.0 else spec.top * h
	_add_header(vis, spec.title)
	if not spec.dealer.is_empty():  # Before the counter, so it stands behind the rail.
		dealer = DealerBackdrop.new()
		add_child(dealer)
		var d: Array = spec.dealer
		dealer.setup(Rect2(d[0] * vis.x, d[2] * k, (d[1] - d[0]) * vis.x, (top - d[2]) * k), k)
	ShopShelves.build_counter(self, Rect2(0, top * k, vis.x, (spec.bottom * h - top) * k), spec)
	card = ShopSideCard.new(self)  # Before the bag and buttons: they connect to it.
	_add_bag(spec.bag[0] * vis.y, spec.bag[1] * k)
	_add_buttons(vis, spec.buttons * vis.y)
	add_child(card)


## A tap or click on empty counter closes the open card, or exits swap mode for free.
func _gui_input(e: InputEvent) -> void:
	if card == null or not (e is InputEventMouseButton and e.pressed):
		return
	if swap_offer >= 0:
		exit_swap()
	else:
		card.close()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or swap_offer < 0:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		exit_swap()
		get_viewport().set_input_as_handled()


## Enter (or re-target) swap mode for die offer `index`. Nothing is paid.
func enter_swap(index: int) -> void:
	selling = false
	var same := swap_offer == index
	swap_offer = index
	if not same:
		build(screen)
	_show_pending_offer()


## Leave swap mode without paying; the bag and offer stay as they were.
func exit_swap() -> void:
	if swap_offer < 0:
		return
	swap_offer = -1
	if card != null:
		card.close()
	build(screen)


## Pay and swap `die_i` for the pending offer, then show the done line.
func commit_swap(die_i: int) -> void:
	if swap_offer < 0 or die_i < 0:
		return
	var run := screen.run
	var offer := swap_offer
	var old_name := run.progress.die_name(die_i)
	var new_name := run.shop_dice[offer].display_name
	swap_offer = -1
	if card != null:
		card.close()
	run.buy_die(offer, die_i)
	done_line = ShopSideCard.SWAP_TEXT.shop_swap_done.format({"old": old_name, "new": new_name})
	build(screen)
	if _done_timer == null:
		_done_timer = Timer.new()
		_done_timer.one_shot = true
		_done_timer.timeout.connect(func() -> void:
			done_line = ""
			var n := get_node_or_null("DoneLine")
			if n != null:
				n.visible = false)
		add_child(_done_timer)
	_done_timer.start(2.0)


func _show_pending_offer() -> void:
	if card == null or swap_offer < 0:
		return
	for it in items:
		if it.offer.kind == ShopOffer.Kind.DIE and it.offer.index == swap_offer:
			card.show_for(it)
			return


## Title, Ember plate, and the floor-price note.
func _add_header(vis: Vector2, title_px: int) -> void:
	var title := RunTheme.label("The Ember Shop", int(title_px * k), CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.position = Vector2(20, 14) * k
	add_child(title)
	var plate := PriceTag.new()
	plate.setup(str(screen.run.progress.embers), true, int(40 * k), k)
	plate.custom_minimum_size = Vector2(190, 48) * k
	plate.position = Vector2(vis.x - 202 * k, 10 * k)
	add_child(plate)
	embers_label = plate.label
	floor_note = null
	var pct := screen.run.floor_price_percent()
	if pct > 0:  # Floor 1 has no markup, so no note.
		# Small line under the title, left of the Ember plate: clear of the
		# dealer and the counter rail on PC, landscape and portrait.
		var note := EconomyStrings.shop_floor_price_note(pct)
		if layout == Layout.PORTRAIT:  # Narrow: break after "floor:" so it reads as two clean lines.
			note = note.replace(": ", ":\n")
		floor_note = RunTheme.label(note, int(maxf(12.0, title_px * 0.6) * k), CREAM)
		floor_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		floor_note.position = Vector2(20, 18 + title_px * 1.25) * k
		floor_note.size.x = plate.position.x - 28 * k
		add_child(floor_note)


## Kept so existing tests can call ShopScreen._rows.
static func _rows(offers: Array[ShopOffer], per_shelf: Array) -> Array:
	return ShopShelves.rows(offers, per_shelf)


func _on_focus(it: ShopItem) -> void:
	if touch_mode:
		if card.item != it:
			card.show_for(it)
		_maybe_enter_swap(it)
	else:
		card.hover(it)


## Phone: opening a die card at a full bag also enters swap mode (no extra Buy tap).
func _maybe_enter_swap(it: ShopItem) -> void:
	var o := it.offer
	if o.kind != ShopOffer.Kind.DIE or screen.run.progress.can_add_die():
		return
	if not o.affordable(screen.run.progress.embers) or swap_offer == o.index:
		return
	enter_swap(o.index)


func _add_buttons(vis: Vector2, y: float) -> void:
	var run := screen.run
	var pc := layout == Layout.PC
	var px := int((26 if pc else 24) * k)
	var reroll_text := "Reroll  %d" % run.reroll_price() if run.progress.free_rerolls == 0 else ShopSideCard.reroll_label(true)  # Same words as the card's button; the card shows how many are left.
	sell_button = _button("Sell / Swap", px, func() -> void: selling = not selling; swap_offer = -1; card.close(); build(screen))
	reroll_button = _button(reroll_text, px, _on_reroll_pressed)
	reroll_button.disabled = not touch_mode and run.progress.embers < run.reroll_price()
	reroll_button.mouse_entered.connect(func() -> void: if not touch_mode: card.show_reroll(reroll_button, false))
	reroll_button.mouse_exited.connect(card.leave)
	leave_button = _button("Leave", px, func() -> void: selling = false; swap_offer = -1; run.leave())
	var at_floor := run.progress.dice.size() <= run.progress.data.starting_dice
	sell_button.visible = not at_floor
	# PC: Sell / Swap sits right of the bag row when selling is possible.
	var row: Array[Button] = []
	if not at_floor:
		row.append(sell_button)
	row.append_array([reroll_button, leave_button] as Array[Button])
	if pc:
		# Size even when hidden so the PC spec (180x50) still holds.
		sell_button.custom_minimum_size = PC_BUTTONS[0] * k
		sell_button.size = sell_button.get_combined_minimum_size()
		if not at_floor:
			var last := bag[bag.size() - 1]
			sell_button.position = Vector2(last.position.x + last.size.x + 30 * k, last.position.y + (last.size.y - sell_button.size.y) / 2.0)
		row = [reroll_button, leave_button]
	if layout == Layout.PORTRAIT:  # Equal buttons across the width, 8 px gaps.
		var gap := 8 * k
		var n := row.size()
		var w := (vis.x - 32 * k - (n - 1) * gap) / float(n)
		for i in n:
			row[i].custom_minimum_size = Vector2(0, 44 * k)
			row[i].clip_text = true
			row[i].position = Vector2(16 * k + i * (w + gap), y)
			row[i].size = Vector2(w, row[i].get_combined_minimum_size().y)
		return
	var x := vis.x - (40 if pc else 16) * k
	for i in range(row.size() - 1, -1, -1):
		var b := row[i]
		# PC right-side buttons use the Reroll / Leave sizes (PC_BUTTONS[1], [2]).
		var pi := (1 if b == reroll_button else 2) if pc else -1
		b.custom_minimum_size = PC_BUTTONS[pi] * k if pc else Vector2(0, 44 * k)
		b.size = b.get_combined_minimum_size()
		x -= b.size.x
		b.position = Vector2(x, y)
		x -= (20 if pc else 12) * k


func _button(text: String, px: int, on: Callable) -> Button:
	var b := RunTheme.button(text, px)
	b.pressed.connect(on)
	add_child(b)
	return b


## PC: Reroll rerolls (its card opened on hover). Phone: the first tap opens
## the card, and only the card's button rerolls.
func _on_reroll_pressed() -> void:
	if touch_mode:
		if not card.reroll_open:
			card.show_reroll(reroll_button, true)
		return
	card.close()
	swap_offer = -1
	if screen.run.shop_reroll():
		screen.refresh()


## The bag row: "YOUR DICE · 5", sell/swap hints, and max_dice slots of `px` from `y`. Sell mode lifts the row 10 spec px.
func _add_bag(y: float, px: float) -> void:
	var p := screen.run.progress
	if selling or swap_offer >= 0:
		y -= 10 * k
	var x := (40 if layout == Layout.PC else 16) * k
	var gap := (10 if layout == Layout.PC else 8) * k
	var label_px := int((20 if layout == Layout.PC else 14) * k)
	bag_label = RunTheme.label(ShopSideCard.SWAP_TEXT.hud_dice_count.replace("{n}", str(p.dice.size())), label_px, CREAM)
	bag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bag_label.position = Vector2(x, y - label_px * 1.5)
	add_child(bag_label)
	var T := ShopSideCard.SWAP_TEXT
	var hint := ShopSideCard.plat(T.shop_swap_pick, touch_mode) if swap_offer >= 0 else ShopCardStrings.get_text("shop_hint_pick_sell")
	sell_hint = RunTheme.label(hint, label_px, BRASS)
	sell_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	var lw := bag_label.get_theme_font(&"font").get_string_size(bag_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_px).x
	sell_hint.position = Vector2(x + lw + 24 * k, bag_label.position.y)
	sell_hint.visible = selling or swap_offer >= 0
	add_child(sell_hint)
	exit_hint = RunTheme.label(ShopSideCard.plat(T.shop_swap_exit, touch_mode), label_px, BRASS)
	exit_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	var hw := sell_hint.get_theme_font(&"font").get_string_size(sell_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_px).x
	exit_hint.position = Vector2(sell_hint.position.x + hw + 16 * k, bag_label.position.y)
	exit_hint.visible = swap_offer >= 0 and not touch_mode  # Phone: only the give-up hint, at normal size.
	add_child(exit_hint)
	if done_line != "":
		var done := RunTheme.label(done_line, label_px, BRASS)
		done.name = "DoneLine"
		done.autowrap_mode = TextServer.AUTOWRAP_OFF
		done.position = Vector2(x, bag_label.position.y - label_px * 1.3)
		add_child(done)
	for i in p.data.max_dice:  # 5 (bag5_sacrifice_v1)
		var slot := BagSlot.new()
		slot.setup(screen.run, i, px, k)
		slot.position = Vector2(x + i * (px + gap), y)
		slot.opened.connect(func(b: BagSlot, pin: bool) -> void: card.show_sell(b, pin or touch_mode))
		slot.left.connect(func(_b: BagSlot) -> void: card.leave())
		slot.clicked.connect(_on_bag_clicked)
		add_child(slot)
		bag.append(slot)


## PC: a mouse-up on a plain uncarved, non-rare die in swap mode commits at once.
func _on_bag_clicked(slot: BagSlot) -> void:
	if swap_offer < 0 or touch_mode or slot.die_i < 0:
		return
	if not ShopSideCard.needs_confirm(screen.run.progress, slot.die_i, false):
		commit_swap(slot.die_i)
