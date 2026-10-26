## The floating item card (shop redesign PR B, HANDOFF_SPEC §3-§4 and
## design/shop_cards_v1.md §3-§4). One card is reused for every item:
##   line 1: name · RARE chip · price
##   line 2: face strip (dice) or the item's token (mods, Seals)
##   lines 3-4: effect and a dim rule line
##   line 5: Buy, or a greyed button with the one reason you can't buy.
## PC: hovering an item for 150 ms opens it above the item. Phone: the first
## tap opens it, and only its Buy button buys (ShopScreen.touch_mode).
class_name ShopCard
extends PanelContainer

const PLATE := Color("#141210", 0.97)
const CREAM := Color("#E8DCC0")
const DIM := Color("#968C78")
const BRASS := Color("#C9A24A")
const DARK := Color("#141210")
const RED := Color("#FF2E3E")
const GREY := Color("#AAA08C")
## How long the mouse must rest on an item before its card opens (PC).
const HOVER_DELAY := 0.15
## Card width in spec px, and the text scale, per ShopScreen.Layout.
const WIDTH := {ShopScreen.Layout.PC: 380.0, ShopScreen.Layout.LANDSCAPE: 330.0, ShopScreen.Layout.PORTRAIT: 366.0}
const TEXT_SCALE := {ShopScreen.Layout.PC: 1.0, ShopScreen.Layout.LANDSCAPE: 0.72, ShopScreen.Layout.PORTRAIT: 0.85}

var shop: ShopScreen
## The item the card is showing (null = closed).
var item: ShopItem
## The item the mouse is resting on, waiting for HOVER_DELAY.
var _waiting: ShopItem
var _timer: Timer
var lines: VBoxContainer
## Line 5: Buy, or the greyed blocker. Tests press / read it.
var action: Button
## The blocker id on line 5 ("" = Buy).
var blocker_id: StringName = &""


func _init(owner_shop: ShopScreen) -> void:
	shop = owner_shop
	top_level = true  # Floats over the counter; never moves the layout.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HOVER_DELAY
	_timer.timeout.connect(func() -> void: if _waiting != null: show_for(_waiting))
	add_child(_timer)


## PC: the mouse rested on `it`; open its card after HOVER_DELAY.
func hover(it: ShopItem) -> void:
	_waiting = it
	_timer.start()


## PC: the mouse left `it`; cancel the wait and close its card.
func unhover(it: ShopItem) -> void:
	if _waiting == it:
		_waiting = null
		_timer.stop()
	if item == it:
		close()


func close() -> void:
	if item != null and is_instance_valid(item):
		item.lift(false)
	item = null
	visible = false


## Why `o` can't be bought right now, as a strings id ("" = it can).
## Only one reason shows, in this order: bag full > no free face >
## can't afford > Seal not usable (HANDOFF_SPEC §3).
static func blocker(o: ShopOffer, screen: RunScreen) -> StringName:
	var run := screen.run
	if o.kind == ShopOffer.Kind.DIE and not run.progress.can_add_die():
		return &"shop_card_bag_full"
	if o.kind == ShopOffer.Kind.MOD and o.price_lo < 0:
		return &"shop_card_no_free_face"
	if run.progress.embers < o.price_lo:
		return &"shop_card_cant_afford"
	var seal := o.kind == ShopOffer.Kind.SEAL or o.kind == ShopOffer.Kind.RARE_SEAL
	if seal and not screen._seal_possible(o.id):
		return &"shop_card_seal_unusable"
	return &""


## Fill the card for `it` and float it above (or, near the top, below) it.
func show_for(it: ShopItem) -> void:
	if item != null and item != it and is_instance_valid(item):
		item.lift(false)
	item = it
	it.lift(true)
	_build(it.offer)
	visible = true
	reset_size()
	_place(it.get_global_rect())


## The size of spec px `px` on this layout (k, and the phone text scale).
func _px(px: float) -> int:
	return maxi(8, int(px * shop.k * TEXT_SCALE[shop.layout]))


func _build(o: ShopOffer) -> void:
	for c in get_children():
		if c != _timer:
			remove_child(c)
			c.queue_free()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PLATE
	sb.border_color = CREAM
	sb.set_border_width_all(maxi(1, int(2 * shop.k)))
	sb.set_corner_radius_all(int(10 * shop.k))
	sb.set_content_margin_all(16 * shop.k)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = WIDTH[shop.layout] * shop.k
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(6 * shop.k))
	add_child(lines)
	_title_row(o)
	for l in _body(o):
		var text: String = l[0]
		var lab := RunTheme.label(text, _px(23), l[1])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Wrapping needs a known width, or the label wraps every word.
		lab.custom_minimum_size.x = (WIDTH[shop.layout] - 32.0) * shop.k
		lines.add_child(lab)
	_action_row(o)


## Line 1: name, the RARE chip for anything rare, and the price at the right.
func _title_row(o: ShopOffer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * shop.k))
	lines.add_child(row)
	var name_text := ShopCardText.say(&"shop_card_soul_name") if o.kind == ShopOffer.Kind.SOUL else o.display_name
	var title := RunTheme.label(name_text, _px(32), CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	if o.rare:
		var chip := Label.new()
		chip.text = "RARE"
		chip.add_theme_font_size_override("font_size", _px(16))
		chip.add_theme_color_override("font_color", DARK)
		var cs := StyleBoxFlat.new()
		cs.bg_color = BRASS
		cs.set_corner_radius_all(int(4 * shop.k))
		cs.content_margin_left = 6 * shop.k
		cs.content_margin_right = 6 * shop.k
		chip.add_theme_stylebox_override("normal", cs)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
	var tag := PriceTag.new()
	tag.setup(o.price_text(), o.affordable(shop.screen.run.progress.embers), _px(32), shop.k * TEXT_SCALE[shop.layout])
	row.add_child(tag)


## Lines 2-4 by item type (shop_cards_v1 §3). Line 2 for dice is the face
## strip; mods and Seals show their counter token. Returns [text, colour].
func _body(o: ShopOffer) -> Array:
	var run := shop.screen.run
	var out: Array = []
	match o.kind:
		ShopOffer.Kind.DIE:
			var d: SpecialDieData = run.shop_dice[o.index]
			var n := d.faces.size()
			if n > 8:  # d10+: a range line instead of a strip.
				out.append([ShopCardText.say(&"shop_card_faces_range", n), CREAM])
				out.append([ShopCardText.say(&"shop_card_shape_rule"), DIM])
			else:
				lines.add_child(_face_strip(d))
				if n != 6:
					out.append([ShopCardText.say(&"shop_card_shape", n), DIM])
			out.append([d.description, CREAM])
			if d.is_rare():
				out.append([EconomyStrings.SHOP_RARE_TAG, DIM])
		ShopOffer.Kind.MOD:
			lines.add_child(_token(o))
			out.append([run.shop_mods[o.index].description, CREAM])
			out.append([ShopCardText.say(&"shop_card_mod_pick"), DIM])
		ShopOffer.Kind.SEAL:
			lines.add_child(_token(o))
			out.append([SealText.describe(o.id), CREAM])
			out.append([ShopCardText.say(&"shop_card_seal"), DIM])
		ShopOffer.Kind.RARE_SEAL:
			out.append([SealText.describe(o.id), CREAM])
			out.append([ShopCardText.say(&"shop_card_seal_rare"), DIM])
		ShopOffer.Kind.SOUL:
			out.append([ShopCardText.say(&"shop_card_soul", run.data.shop_soul_amount), CREAM])
	return out


## The counter token (mod icon / Seal combo mark) at 42 spec px.
func _token(o: ShopOffer) -> Control:
	var icon := ShopIcon.new()
	icon.setup(o, _px(42))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return icon


## Line 2 for d4 / d6 / d8: one bone face per face with its value. A carved
## face gets its mod's first letter as a corner badge; a rare die's
## forge-carved face also gets a brass lock dot (PR D draws the final pip).
func _face_strip(d: SpecialDieData) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", int(4 * shop.k))
	var presets: Dictionary = d.preset_mods if d is DieShape else {}
	for v: int in d.faces:
		var face := PanelContainer.new()
		var fs := StyleBoxFlat.new()
		fs.bg_color = CREAM
		fs.set_corner_radius_all(int(5 * shop.k))
		face.add_theme_stylebox_override("panel", fs)
		face.custom_minimum_size = Vector2.ONE * _px(42)
		var num := RunTheme.label(str(v), _px(22), DARK)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.add_child(num)
		var mod: String = String(presets.get(v, ""))
		if mod != "":
			var badge := RunTheme.label(mod.left(1).to_upper(), _px(13), BRASS, true)
			badge.name = "Badge"
			face.add_child(badge)  # Top-left corner (Container keeps it at 0,0).
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if d.is_rare():
				var lock := ColorRect.new()
				lock.name = "Lock"
				lock.color = BRASS
				lock.custom_minimum_size = Vector2.ONE * _px(8)
				lock.size_flags_horizontal = Control.SIZE_SHRINK_END
				lock.size_flags_vertical = Control.SIZE_SHRINK_END
				face.add_child(lock)
		strip.add_child(face)
	return strip


## Line 5: brass Buy, or the blocker greyed (red only for can't-afford).
func _action_row(o: ShopOffer) -> void:
	blocker_id = blocker(o, shop.screen)
	var short := o.price_lo - shop.screen.run.progress.embers
	var text := ShopCardText.say(&"shop_card_buy") if blocker_id == &"" else ShopCardText.say(blocker_id, short)
	action = RunTheme.button(text, _px(23))
	action.custom_minimum_size.y = 40 * shop.k * TEXT_SCALE[shop.layout]
	action.disabled = blocker_id != &""
	var bs := StyleBoxFlat.new()
	bs.bg_color = BRASS
	bs.set_corner_radius_all(int(6 * shop.k))
	action.add_theme_stylebox_override("normal", bs)
	action.add_theme_stylebox_override("hover", bs)
	action.add_theme_color_override("font_color", DARK)
	action.add_theme_color_override("font_disabled_color", RED if blocker_id == &"shop_card_cant_afford" else GREY)
	action.pressed.connect(buy)
	lines.add_child(action)


## The card's Buy: the only way to buy on a phone. Mods hand off to the
## face picker inside ShopOffer.buy, which shows per-die prices.
func buy() -> void:
	if item == null or blocker(item.offer, shop.screen) != &"":
		return
	var o := item.offer
	close()
	o.buy(shop.screen)


## Centre the card above `anchor`, clamped 8 px inside the screen; if it
## would leave the top, flip it below the item instead.
func _place(anchor: Rect2) -> void:
	var vis := get_viewport().get_visible_rect().size
	var gap := 10 * shop.k
	var pos := Vector2(anchor.get_center().x - size.x / 2.0, anchor.position.y - size.y - gap)
	if pos.y < 8 * shop.k:
		pos.y = anchor.end.y + gap
	pos.x = clampf(pos.x, 8 * shop.k, vis.x - size.x - 8 * shop.k)
	pos.y = clampf(pos.y, 8 * shop.k, maxf(8 * shop.k, vis.y - size.y - 8 * shop.k))
	global_position = pos
