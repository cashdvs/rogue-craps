## The visual Ember Shop (art/concept/shop_redesign/HANDOFF_SPEC.md): a wooden
## counter with shelves of goods, each with a brass price tag. Rules and prices
## stay in MapRunShop; this only lays the goods out and forwards clicks.
## Later PRs slot in: A2 the dealer behind the rail and real icons, B (in) a ShopCard
## on hover (PC) or the first tap (phones), C the bag row under the counter, D the rare chip.
class_name ShopScreen
extends Control

enum Layout { PC, LANDSCAPE, PORTRAIT }

const WOOD := Color("#2E1E16")
const GRAIN := Color("#462E20")
const FELT := Color("#407A56")
const BRASS := Color("#C9A24A")
const CREAM := Color("#E8DCC0")

## Per layout, in spec px (§2): counter top (px, or a fraction of the height
## when < 1) and bottom, art size, items per shelf, buttons row y, title size.
const LAYOUTS := {
	Layout.PC: {"top": 0.34, "bottom": 0.78, "art": 120.0, "per_shelf": [3, 5], "buttons": 0.85, "title": 32},
	Layout.LANDSCAPE: {"top": 62.0, "bottom": 0.74, "art": 46.0, "per_shelf": [8], "buttons": 0.85, "title": 22},
	Layout.PORTRAIT: {"top": 170.0, "bottom": 0.775, "art": 58.0, "per_shelf": [3, 3, 3], "buttons": 0.9, "title": 16},
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
var reroll_button: Button
var leave_button: Button
var sell_button: Button
## The one floating item card (PR B), rebuilt with the shop.
var card: ShopCard
## Phone layouts (landscape / portrait): taps select, only the card buys.
var touch_mode := false


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
	pick_layout()
	touch_mode = layout != Layout.PC
	var vis := get_viewport().get_visible_rect().size
	var spec: Dictionary = LAYOUTS[layout]
	var h := vis.y / k  # Screen height in spec px.
	var top: float = spec.top if spec.top >= 1.0 else spec.top * h
	_add_header(vis, spec.title)
	_build_counter(Rect2(0, top * k, vis.x, (spec.bottom * h - top) * k), spec)
	_add_buttons(vis, spec.buttons * vis.y)
	card = ShopCard.new(self)
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
	var reroll_text := "Reroll  %d" % run.reroll_price() if run.progress.free_rerolls == 0 else "Free reroll (%d)" % run.progress.free_rerolls
	sell_button = _button("Sell / Swap", px, func() -> void: screen.shop_list = true; screen.refresh())
	reroll_button = _button(reroll_text, px, func() -> void: run.shop_reroll(); screen.refresh())
	reroll_button.disabled = run.progress.embers < run.reroll_price()
	leave_button = _button("Leave", px, func() -> void: run.leave())
	var row: Array[Button] = [sell_button, reroll_button, leave_button]
	var x := vis.x - (40 if pc else 16) * k
	for i in range(row.size() - 1, -1, -1):
		var b := row[i]
		b.custom_minimum_size = PC_BUTTONS[i] * k if pc else Vector2(0, 44 * k)
		b.size = b.get_combined_minimum_size()
		x -= b.size.x
		b.position = Vector2(x, y)
		x -= (20 if pc else 12) * k


func _button(text: String, px: int, on: Callable) -> Button:
	var b := RunTheme.button(text, px)
	b.pressed.connect(on)
	add_child(b)
	return b
