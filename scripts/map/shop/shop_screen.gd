## The visual Ember Shop (art/concept/shop_redesign/HANDOFF_SPEC.md): a wooden
## counter with shelves of goods, each with a brass price tag. Rules and prices
## stay in MapRunShop; this only lays the goods out and forwards clicks.
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
const LAYOUTS := {
	Layout.PC: {"top": 0.34, "bottom": 0.78, "art": 120.0, "per_shelf": [3, 5], "buttons": 0.85, "title": 32, "dealer": [0.38, 0.62, 70.0], "bag": [0.83, 110.0]},
	Layout.LANDSCAPE: {"top": 62.0, "bottom": 0.74, "art": 46.0, "per_shelf": [8], "buttons": 0.85, "title": 22, "dealer": [], "bag": [0.81, 40.0]},
	Layout.PORTRAIT: {"top": 170.0, "bottom": 0.775, "art": 58.0, "per_shelf": [3, 3, 3], "buttons": 0.9, "title": 16, "dealer": [0.25, 0.75, 64.0], "bag": [0.80, 50.0]},
}
## PC Sell / Swap, Reroll, Leave sizes (spec px); phones fit their text.
const PC_BUTTONS := [Vector2(180, 50), Vector2(210, 50), Vector2(190, 50)]
## Price numerals (spec px): 28 everywhere, so >= 24 real px on phones.
const NUM_PX := 28
## Slots in the bag row (RunData.max_dice is 6).
const BAG_SLOTS := 6
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
var bag_label: Label
## "Pick a die to sell." in sell mode (hidden otherwise).
var sell_hint: Label
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
	_build_counter(Rect2(0, top * k, vis.x, (spec.bottom * h - top) * k), spec)
	card = ShopSideCard.new(self)  # Before the bag and buttons: they connect to it.
	_add_bag(spec.bag[0] * vis.y, spec.bag[1] * k)
	_add_buttons(vis, spec.buttons * vis.y)
	add_child(card)


## A tap or click on empty counter closes the open card.
func _gui_input(e: InputEvent) -> void:
	if card != null and e is InputEventMouseButton and e.pressed:
		card.close()


func _rect(r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)
	return cr


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


## The wood counter, its brass rail, and one felt-and-brass shelf per row.
func _build_counter(r: Rect2, spec: Dictionary) -> void:
	_rect(r, WOOD)
	for x in range(0, int(r.size.x), int(maxf(40 * k, 8))):  # Wood grain.
		_rect(Rect2(x, r.position.y, 2 * k, r.size.y), GRAIN)
	_rect(Rect2(0, r.position.y, r.size.x, 6 * k), BRASS)  # The rail.
	var rows := _rows(ShopOffer.list(screen.run), spec.per_shelf)
	var tag_h := 34.0 * k
	var cell_h := r.size.y / rows.size()
	for j in rows.size():
		# Felt sits so the price tags hang just below its brass lip.
		var felt_y := r.position.y + (j + 1) * cell_h - tag_h - 16 * k
		var row_top := r.position.y + j * cell_h
		shelves.append(_rect(Rect2(14 * k, felt_y - 8 * k, r.size.x - 28 * k, 8 * k), FELT))
		_rect(Rect2(14 * k, felt_y, r.size.x - 28 * k, 4 * k), BRASS)
		_fill_shelf(rows[j], Rect2(14 * k, row_top, r.size.x - 28 * k, felt_y - row_top + 4 * k + tag_h), spec)


## Split offers into shelf rows: the first `per_shelf[0]` on row 1, and so
## on; the last row takes any extras. Empty rows are dropped.
static func _rows(offers: Array[ShopOffer], per_shelf: Array) -> Array:
	var out: Array = []
	var at := 0
	for j in per_shelf.size():
		var n: int = offers.size() - at if j == per_shelf.size() - 1 else per_shelf[j]
		var row := offers.slice(at, at + n)
		at += row.size()
		if not row.is_empty():
			out.append(row)
	return out if not out.is_empty() else [[]]


## Place a row's items in equal cells, icons resting on the felt.
func _fill_shelf(row: Array, area: Rect2, spec: Dictionary) -> void:
	if row.is_empty():
		return
	var cell := area.size.x / row.size()
	var embers := screen.run.progress.embers
	for i in row.size():
		var it := ShopItem.new()
		it.setup(row[i], embers, spec.art * k, int(NUM_PX * k), k)
		add_child(it)
		it.size = it.get_combined_minimum_size()
		it.position = Vector2(area.position.x + cell * (i + 0.5) - it.size.x / 2.0, area.end.y - it.size.y)
		it.touch_mode = touch_mode
		it.tooltip_text = ""  # The hover card replaces the native tooltip.
		it.buy.connect(func(o: ShopOffer) -> void: card.close(); o.buy(screen))
		it.focus_item.connect(_on_focus)
		it.unfocus_item.connect(func(x: ShopItem) -> void: if not touch_mode: card.unhover(x))
		items.append(it)


## PC hover waits HOVER_DELAY; a phone tap opens the card at once.
func _on_focus(it: ShopItem) -> void:
	if touch_mode:
		if card.item != it:
			card.show_for(it)
	else:
		card.hover(it)


func _add_buttons(vis: Vector2, y: float) -> void:
	var run := screen.run
	var pc := layout == Layout.PC
	var px := int((26 if pc else 24) * k)
	var reroll_text := "Reroll  %d" % run.reroll_price() if run.progress.free_rerolls == 0 else ShopSideCard.reroll_label(true)  # Same words as the card's button; the card shows how many are left.
	sell_button = _button("Sell / Swap", px, func() -> void: selling = not selling; card.close(); build(screen))
	reroll_button = _button(reroll_text, px, _on_reroll_pressed)
	reroll_button.disabled = not touch_mode and run.progress.embers < run.reroll_price()
	reroll_button.mouse_entered.connect(func() -> void: if not touch_mode: card.show_reroll(reroll_button, false))
	reroll_button.mouse_exited.connect(card.leave)
	leave_button = _button("Leave", px, func() -> void: selling = false; run.leave())
	# PC: Sell / Swap sits right of the bag row; phones put all three in one row.
	var row: Array[Button] = [sell_button, reroll_button, leave_button]
	if pc:
		row.pop_front()
		sell_button.custom_minimum_size = PC_BUTTONS[0] * k
		sell_button.size = sell_button.get_combined_minimum_size()
		var last := bag[BAG_SLOTS - 1]
		sell_button.position = Vector2(last.position.x + last.size.x + 30 * k, last.position.y + (last.size.y - sell_button.size.y) / 2.0)
	if layout == Layout.PORTRAIT:  # Three equal buttons across the width, 8 px gaps.
		var gap := 8 * k
		var w := (vis.x - 32 * k - 2 * gap) / 3.0
		for i in row.size():
			row[i].custom_minimum_size = Vector2(0, 44 * k)
			row[i].clip_text = true
			row[i].position = Vector2(16 * k + i * (w + gap), y)
			row[i].size = Vector2(w, row[i].get_combined_minimum_size().y)
		return
	var x := vis.x - (40 if pc else 16) * k
	for i in range(row.size() - 1, -1, -1):
		var b := row[i]
		b.custom_minimum_size = PC_BUTTONS[i + 1] * k if pc else Vector2(0, 44 * k)  # +1: Sell / Swap is PC_BUTTONS[0].
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
	if screen.run.shop_reroll():
		screen.refresh()


## The bag row: "YOUR DICE n/6", the sell-mode hint, and six slots of
## `px` design px from top `y`. Sell mode lifts the row 10 spec px.
func _add_bag(y: float, px: float) -> void:
	var p := screen.run.progress
	if selling:
		y -= 10 * k
	var x := (40 if layout == Layout.PC else 16) * k
	var gap := (10 if layout == Layout.PC else 8) * k
	var label_px := int((20 if layout == Layout.PC else 14) * k)
	bag_label = RunTheme.label("YOUR DICE  %d/%d" % [p.dice.size(), p.data.max_dice], label_px, CREAM)
	bag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bag_label.position = Vector2(x, y - label_px * 1.5)
	add_child(bag_label)
	sell_hint = RunTheme.label(ShopCardStrings.get_text("shop_hint_pick_sell"), label_px, BRASS)
	sell_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	sell_hint.position = Vector2(x + bag_label.get_combined_minimum_size().x + 16 * k, bag_label.position.y)
	sell_hint.visible = selling
	add_child(sell_hint)
	for i in BAG_SLOTS:
		var s := BagSlot.new()
		s.setup(screen.run, i, px, k)
		s.position = Vector2(x + i * (px + gap), y)
		s.opened.connect(func(slot: BagSlot, pin: bool) -> void: card.show_sell(slot, pin or touch_mode))
		s.left.connect(func(_slot: BagSlot) -> void: card.leave())
		add_child(s)
		bag.append(s)
