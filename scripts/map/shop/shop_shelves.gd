## The shop counter and its shelves: wood, felt, items, and matte pads.
## Split out of ShopScreen so that file stays under the ~400-line cap.
class_name ShopShelves
extends RefCounted


## A coloured rect parented to `shop`, ignoring the mouse.
static func rect(shop: ShopScreen, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop.add_child(cr)
	return cr


## The wood counter, its brass rail, and one felt-and-brass shelf per row.
static func build_counter(shop: ShopScreen, r: Rect2, spec: Dictionary) -> void:
	var k := shop.k
	rect(shop, r, shop.WOOD)
	for x in range(0, int(r.size.x), int(maxf(40 * k, 8))):  # Wood grain.
		rect(shop, Rect2(x, r.position.y, 2 * k, r.size.y), shop.GRAIN)
	rect(shop, Rect2(0, r.position.y, r.size.x, 6 * k), shop.BRASS)  # The rail.
	var shelf_rows := ShopShelves.rows(ShopOffer.list(shop.screen.run), spec.per_shelf)
	var tag_h := 34.0 * k
	var cell_h := r.size.y / shelf_rows.size()
	for j in shelf_rows.size():
		# Felt sits so the price tags hang just below its brass lip.
		var felt_y := r.position.y + (j + 1) * cell_h - tag_h - 16 * k
		var row_top := r.position.y + j * cell_h
		shop.shelves.append(rect(shop, Rect2(14 * k, felt_y - 8 * k, r.size.x - 28 * k, 8 * k), shop.FELT))
		rect(shop, Rect2(14 * k, felt_y, r.size.x - 28 * k, 4 * k), shop.BRASS)
		fill_shelf(shop, shelf_rows[j], Rect2(14 * k, row_top, r.size.x - 28 * k, felt_y - row_top + 4 * k + tag_h), spec)


## Split offers into shelf rows: the first `per_shelf[0]` on row 1, and so
## on; the last row takes any extras. Empty rows are dropped.
static func rows(offers: Array[ShopOffer], per_shelf: Array) -> Array:
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
static func fill_shelf(shop: ShopScreen, row: Array, area: Rect2, spec: Dictionary) -> void:
	if row.is_empty():
		return
	var k := shop.k
	var cell := area.size.x / row.size()
	var embers := shop.screen.run.progress.embers
	var chip_x := -1.0  # Leftmost chip item centre; shelf title sits above it.
	var row_items: Array[ShopItem] = []
	for i in row.size():
		var it := ShopItem.new()
		it.setup(row[i], embers, spec.art * k, int(shop.NUM_PX * k), k)
		shop.add_child(it)
		it.size = it.get_combined_minimum_size()
		it.position = Vector2(area.position.x + cell * (i + 0.5) - it.size.x / 2.0, area.end.y - it.size.y)
		it.touch_mode = shop.touch_mode
		row_items.append(it)
		it.tooltip_text = ""  # The hover card replaces the native tooltip.
		it.buy.connect(func(o: ShopOffer) -> void: shop.card.close(); o.buy(shop.screen))
		it.focus_item.connect(shop._on_focus)
		it.unfocus_item.connect(func(x: ShopItem) -> void: if not shop.touch_mode: shop.card.unhover(x))
		shop.items.append(it)
		if row[i].kind == ShopOffer.Kind.CHIP and chip_x < 0.0:
			chip_x = it.position.x + it.size.x * 0.5
	if chip_x >= 0.0:
		var title := RunTheme.label(ChipStrings.get_text("chip_shelf_label"), int(14 * k), shop.BRASS, true)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shop.add_child(title)
		var tw: float = title.get_theme_font(&"font").get_string_size(
			title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size(&"font_size")).x
		title.position = Vector2(chip_x - tw * 0.5, area.position.y - 4.0 * k)
		title.name = "ChipShelfTitle"
	place_pads(shop, row_items, cell)


## Matte pads behind this row. Omitted when the slot, a price tag, the brass
## rail or a neighbour pad cannot take one. Goods themselves are not moved.
static func place_pads(shop: ShopScreen, row_items: Array[ShopItem], cell: float) -> void:
	for it in row_items:  # Tags and icons need their laid-out rects first.
		it.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var blockers := pad_blockers(shop)
	var placed: Array[Rect2] = []
	for it in row_items:
		var pad := ShopCounterPad.attach(it.icon as ShopIcon, cell, shop.k, blockers, placed, false)
		if pad != null:
			placed.append(Rect2(it.icon.global_position + pad.position, pad.size))


## Global rects a pad must not cross: brass rails, price tags, RARE chips,
## and the CHIPS shelf title.
static func pad_blockers(shop: ShopScreen) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var shelf := ChipStrings.get_text("chip_shelf_label")
	for c in shop.get_children():
		if c is ColorRect and (c as ColorRect).color == shop.BRASS:
			out.append((c as ColorRect).get_global_rect())
		elif c is Label and (c as Label).text == shelf:
			out.append((c as Label).get_global_rect())
	for it in shop.items:
		out.append(it.tag.get_global_rect())
		var rare := it.find_child("RareChip", false, false)
		if rare is Control:
			out.append((rare as Control).get_global_rect())
	return out
