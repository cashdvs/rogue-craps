## The floating item card (PR B; HANDOFF_SPEC §3-4, shop_cards_v1 §3-4). PC: opens
## after 150 ms of hover. Phone: the first tap opens it, and only its Buy buys.
class_name ShopCard
extends PanelContainer

const PLATE := Color("#141210", 0.97)
const CREAM := Color("#E8DCC0")
const DIM := Color("#968C78")
const BRASS := Color("#C9A24A")
const DARK := Color("#141210")
const RED := Color("#FF2E3E")
const GREY := Color("#AAA08C")
const HOVER_DELAY := 0.15  # PC: seconds of hover before the card opens.
## Card width in spec px, and the text scale, per ShopScreen.Layout.
const WIDTH := {ShopScreen.Layout.PC: 380.0, ShopScreen.Layout.LANDSCAPE: 330.0, ShopScreen.Layout.PORTRAIT: 366.0}
const TEXT_SCALE := {ShopScreen.Layout.PC: 1.0, ShopScreen.Layout.LANDSCAPE: 0.72, ShopScreen.Layout.PORTRAIT: 0.85}

var shop: ShopScreen
var item: ShopItem  # Showing this item (null = closed).
var _waiting: ShopItem  # Hovered, waiting for HOVER_DELAY.
var _timer: Timer
var lines: VBoxContainer
var action: Button  # Line 5: Buy or the greyed blocker.
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

## Why `o` can't be bought, as a strings id ("" = it can). Order: bag full > no free face > can't afford > Seal not usable.
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
	var sb := _box(PLATE, 10, 16)
	sb.border_color = CREAM
	sb.set_border_width_all(maxi(1, int(2 * shop.k)))
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
		lab.custom_minimum_size.x = (WIDTH[shop.layout] - 32.0) * shop.k  # Wrap needs a width.
		lines.add_child(lab)
	_action_row(o)

## A flat box in `c` with corner radius and side margin in spec px.
func _box(c: Color, radius: float, margin: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(int(radius * shop.k))
	b.set_content_margin_all(margin * shop.k)
	return b

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
		var chip := RunTheme.label("RARE", _px(16), DARK)
		chip.add_theme_stylebox_override("normal", _box(BRASS, 4, 6))
		chip.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
	var tag := PriceTag.new()
	tag.setup(o.price_text(), o.affordable(shop.screen.run.progress.embers), _px(32), shop.k * TEXT_SCALE[shop.layout])
	row.add_child(tag)

## Lines 2-4 by item type (shop_cards_v1 §3) as [text, colour]; adds strip / token.
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
		ShopOffer.Kind.SEAL, ShopOffer.Kind.RARE_SEAL:
			if not o.rare:
				lines.add_child(_token(o))
			out.append([SealText.describe(o.id), CREAM])
			out.append([ShopCardText.say(&"shop_card_seal_rare" if o.rare else &"shop_card_seal"), DIM])
		ShopOffer.Kind.SOUL:
			out.append([ShopCardText.say(&"shop_card_soul", run.data.shop_soul_amount), CREAM])
	return out

## The counter token (mod icon / Seal combo mark) at 42 spec px.
func _token(o: ShopOffer) -> Control:
	var icon := ShopIcon.new()
	icon.setup(o, _px(42))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return icon

## Line 2 (d4-d8): pip faces; carved ones get a mod disc, pre-carved a lock.
func _face_strip(d: SpecialDieData) -> Control:
	var strip := HBoxContainer.new()
	strip.name = "FaceStrip"
	strip.add_theme_constant_override("separation", int(6 * shop.k))  # 3 px+ on screen even at 1024x576.
	var presets: Dictionary = d.preset_mods if d is DieShape else {}
	for v: int in d.faces:
		var face := Control.new()
		face.custom_minimum_size = Vector2.ONE * _px(42)
		face.draw.connect(_draw_face.bind(face, v))
		var mod: String = String(presets.get(v, ""))
		if mod != "":
			_corner(face, "ModIcon", 0.0, mod)
			if d.is_rare():
				_corner(face, "Lock", 1.0, mod)
		strip.add_child(face)
	return strip

static func pips(v: int) -> Array:  # Pip spots: DiceIcons' 1-6, plus 7 and 8.
	var extra := {7: [Vector2.ZERO], 8: [Vector2(0, -1), Vector2(0, 1)]}
	return DiceIcons.PIPS[6] + extra[v] if v > 6 else DiceIcons.PIPS.get(v, [])

func _draw_face(f: Control, v: int) -> void:
	var s := f.size.x
	f.draw_rect(Rect2(Vector2.ZERO, f.size), CREAM)
	for p: Vector2 in pips(v):
		f.draw_circle(Vector2.ONE * s / 2.0 + p * s * 0.27, s * 0.085, DARK)

## A small named marker in the face's top-right (y=0) or bottom-right (y=1).
func _corner(face: Control, id: String, y: float, mod: String) -> void:
	var m := Control.new()
	m.name = id
	var px := _px(16)
	m.position = Vector2(_px(42) - px, y * (_px(42) - px))
	m.draw.connect(_draw_lock.bind(m, px) if id == "Lock" else _draw_mod_disc.bind(m, px, mod))
	face.add_child(m)

func _draw_mod_disc(m: Control, px: float, mod: String) -> void:  # Stand-in until A2.
	m.draw_circle(Vector2.ONE * px / 2, px / 2, BRASS)
	m.draw_circle(Vector2.ONE * px / 2, px * 0.38, CREAM)
	m.draw_string(RunTheme.title_font, Vector2(px * 0.28, px * 0.72), mod.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(px * 0.55), DARK)

func _draw_lock(m: Control, px: float) -> void:  # Padlock: shackle arc over a body.
	m.draw_arc(Vector2(px / 2, px * 0.42), px * 0.22, PI, TAU, 12, DARK, px * 0.12)
	m.draw_rect(Rect2(px * 0.18, px * 0.42, px * 0.64, px * 0.5), DARK)

## Line 5: brass Buy, or the blocker greyed (red only for can't-afford).
func _action_row(o: ShopOffer) -> void:
	blocker_id = blocker(o, shop.screen)
	var short := o.price_lo - shop.screen.run.progress.embers
	var text := ShopCardText.say(&"shop_card_buy") if blocker_id == &"" else ShopCardText.say(blocker_id, short)
	action = RunTheme.button(text, _px(23))
	action.custom_minimum_size.y = 40 * shop.k * TEXT_SCALE[shop.layout]
	action.disabled = blocker_id != &""
	var bs := _box(BRASS, 6, 0)
	action.add_theme_stylebox_override("normal", bs)
	action.add_theme_stylebox_override("hover", bs)
	action.add_theme_color_override("font_color", DARK)
	action.add_theme_color_override("font_disabled_color", RED if blocker_id == &"shop_card_cant_afford" else GREY)
	action.pressed.connect(buy)
	lines.add_child(action)

## The card's Buy (the only buy on phones); mods open the face picker in ShopOffer.buy.
func buy() -> void:
	if item == null or blocker(item.offer, shop.screen) != &"":
		return
	var o := item.offer
	close()
	o.buy(shop.screen)

## Centre the card above `anchor` (below if no room), clamped 8 px inside the screen.
func _place(anchor: Rect2) -> void:
	var vis := get_viewport().get_visible_rect().size
	var gap := 10 * shop.k
	var pos := Vector2(anchor.get_center().x - size.x / 2.0, anchor.position.y - size.y - gap)
	if pos.y < 8 * shop.k:
		pos.y = anchor.end.y + gap
	pos.x = clampf(pos.x, 8 * shop.k, vis.x - size.x - 8 * shop.k)
	pos.y = clampf(pos.y, 8 * shop.k, maxf(8 * shop.k, vis.y - size.y - 8 * shop.k))
	global_position = pos
