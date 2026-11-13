## The brass "CHIPS" label on a shelf row (chips_3d shelf title).
## It used to sit 4 spec px above the row, centred on the first chip. On the
## top shelf that put the word through the brass rail, so only the bottoms of
## the letters showed. It now sits inside the row, just under that rail, and
## moves aside (or steps the font down) if a tall good would cover it.
class_name ShopShelfLabel
extends RefCounted


## Add the label for `chip` inside `area`. `shop` is the counter it hangs on.
static func place(shop: ShopScreen, chip: ShopItem, area: Rect2) -> Label:
	var title := RunTheme.label(ChipStrings.get_text("chip_shelf_label"), int(14 * shop.k), ShopScreen.BRASS, true)
	title.name = "ChipShelfTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = false
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := title.get_theme_font(&"font")
	var fs := title.get_theme_font_size(&"font_size")
	var min_fs := maxi(8, int(round(11.0 * shop.k)))
	# 1 px under the rail so the rect does not touch the brass.
	var top := _rail_bottom(shop, area) + 1.0
	var band := Rect2(area.position.x, top, area.size.x, maxf(0.0, area.end.y - top))
	var ts := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(band.position.x, band.position.y)
	var found := false
	while fs >= min_fs:
		ts = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var try_pos := _find_pos(shop, chip, band, ts)
		if try_pos.x >= 0.0:
			pos = try_pos
			found = true
			break
		fs -= 1
	if not found:
		fs = min_fs
		ts = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var x := chip.position.x + chip.size.x * 0.5 - ts.x * 0.5
		x = clampf(x, band.position.x, maxf(band.position.x, band.end.x - ts.x))
		pos = Vector2(x, band.position.y)
	title.add_theme_font_size_override(&"font_size", fs)
	title.custom_minimum_size = ts
	title.size = ts
	title.position = pos
	shop.add_child(title)
	return title


## Bottom of the full-width counter rail when this row is the top shelf.
## Lower shelves start at their own top: the rail is only on the counter's lip.
static func _rail_bottom(shop: ShopScreen, area: Rect2) -> float:
	var bottom := area.position.y
	for c in shop.get_children():
		if c is ColorRect and (c as ColorRect).color == ShopScreen.BRASS:
			var r := (c as ColorRect).get_rect()
			var on_lip := r.position.x <= 1.0 and r.position.y <= area.position.y + 0.5 and r.end.y >= area.position.y - 0.5
			if on_lip:
				bottom = maxf(bottom, r.end.y)
	return bottom


## Prefer centred on the chip. If that covers a good, slide along the row.
static func _find_pos(shop: ShopScreen, chip: ShopItem, band: Rect2, ts: Vector2) -> Vector2:
	if ts.x > band.size.x or ts.y > band.size.y or band.size.y < 1.0:
		return Vector2(-1, -1)
	var preferred := chip.position.x + chip.size.x * 0.5 - ts.x * 0.5
	preferred = clampf(preferred, band.position.x, band.end.x - ts.x)
	var y := band.position.y
	if _clear(shop, Rect2(preferred, y, ts.x, ts.y)):
		return Vector2(preferred, y)
	var step := maxf(4.0, shop.k * 2.0)
	var best := Vector2(-1, -1)
	var best_d := 1.0e20
	var x := band.position.x
	while x <= band.end.x - ts.x + 0.01:
		if _clear(shop, Rect2(x, y, ts.x, ts.y)):
			var d := absf(x - preferred)
			if d < best_d:
				best_d = d
				best = Vector2(x, y)
		x += step
	return best


## True when `r` misses the goods, their tags, other labels and the brass.
static func _clear(shop: ShopScreen, r: Rect2) -> bool:
	for it in shop.items:
		if r.intersects(it.get_rect()):
			return false
	for c in shop.get_children():
		if c is Label and r.intersects((c as Label).get_rect()):
			return false
		if c is ColorRect and (c as ColorRect).color == ShopScreen.BRASS and r.intersects((c as ColorRect).get_rect()):
			return false
	return true
