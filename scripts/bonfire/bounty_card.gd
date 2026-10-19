## One bounty card (Art Director's readability pack, assets/ui/readability/
## bounty/): a brass-edged parchment card with the bounty's name and its mini
## dice, which shows the bounty's state (how_bonfire_plays.md section 4):
##   open     the plain card;
##   pending  landed this hand but not banked yet: a faint oxblood "PENDING"
##            ghost stamp and the line "PENDING · bank to lock";
##   claimed  banked: the burgundy wax CLAIMED seal stamps in and stays.
##
## Everything inside is laid out in the art's own @4x texture pixels
## (544 x 288 = 136 x 72 pt), then the whole card is scaled by `pt_px / 4`,
## so one number (design px per pt) sizes it for PC or phone.
class_name BountyCard
extends Control

const DIR := "res://assets/ui/readability/bounty/"
## The card in texture px (@4x), and its 9-slice margin.
const CARD_SIZE := Vector2(544, 288)
const NINE := 44
## Title: Barlow Condensed Bold, cap 10 pt (font 14.3 pt), Pit Black,
## baseline 22 pt from the top. Icon row from 34 pt: 20 pt dice, 3 pt gap,
## 12 x 20 pt run arrows.
const TITLE_FONT_PX := 57
const TITLE_BASELINE := 88.0
const ICON_TOP := 136.0
const ICON_PX := 80.0
const ICON_GAP := 12.0
const ARROW_SIZE := Vector2(48, 80)
## The pending line under the dice ("PENDING · bank to lock"), oxblood.
const PENDING_TEXT := "PENDING · bank to lock"
const PENDING_FONT_PX := 48
const OXBLOOD := Color("#3B0D14")
## The wax seal: 512 x 384 art, shown at 0.8x (its cap stays >= 9.2 pt).
## 0.62: the wax sits over the dice row and clears the title (it hangs a
## little over the bottom edge, like the mock).
const SEAL_SCALE := 0.62
## Stamp-in keys (stamp_claimed_stampin_keys.json): 0.045 s per frame, the
## impact at frame 2 (0.09 s). The seal art is already drawn at -10 deg, so
## the rotation here is relative to that.
const STAMP_FRAME := 0.045
const STAMP_KEYS := [
	{"scale": Vector2(1.60, 1.60), "alpha": 0.0, "rot": -6.0},
	{"scale": Vector2(1.25, 1.25), "alpha": 0.85, "rot": -2.0},
	{"scale": Vector2(1.14, 0.82), "alpha": 1.0, "rot": 0.0},
	{"scale": Vector2(0.95, 1.06), "alpha": 1.0, "rot": 0.0},
	{"scale": Vector2(1.02, 0.98), "alpha": 1.0, "rot": 0.0},
	{"scale": Vector2(1.00, 1.00), "alpha": 1.0, "rot": 0.0},
]

## Emitted at the stamp's impact frame (0.09 s): the bounty-stamp sound.
signal stamp_impact(id: StringName)

var bounty_id: StringName = &""
var title: Label
var icons: Control
var ghost: TextureRect
var pending_label: Label
var seal: TextureRect
## "open", "pending" or "claimed" (tests read it).
var state: String = "open"


## One of the card art textures in assets/ui/readability/bounty/ by file
## name, or null if it is missing (the card then draws plain).
static func tex(file: String) -> Texture2D:
	var p := DIR + file
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD_SIZE
	custom_minimum_size = CARD_SIZE
	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.texture = tex("card_frame.png")
	frame.patch_margin_left = NINE
	frame.patch_margin_right = NINE
	frame.patch_margin_top = NINE
	frame.patch_margin_bottom = NINE
	frame.size = CARD_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	title = Label.new()
	title.name = "Title"
	var ls := LabelSettings.new()
	ls.font = Palette.number_font()
	ls.font_size = TITLE_FONT_PX
	ls.font_color = Palette.PIT_BLACK
	title.label_settings = ls
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Baseline at 88 px: a Barlow line box puts the baseline ~0.8 em down.
	title.position = Vector2(30, TITLE_BASELINE - TITLE_FONT_PX * 0.98)
	title.size = Vector2(CARD_SIZE.x - 60, TITLE_FONT_PX * 1.2)
	add_child(title)
	ghost = TextureRect.new()
	ghost.name = "PendingGhost"
	ghost.texture = tex("stamp_pending_oxblood_25pct.png")
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = Vector2(480, 200)
	ghost.pivot_offset = ghost.size * 0.5
	ghost.position = Vector2(CARD_SIZE.x * 0.5, ICON_TOP + ICON_PX * 0.5) - ghost.size * 0.5
	ghost.rotation_degrees = -6.0
	ghost.visible = false
	add_child(ghost)
	icons = Control.new()
	icons.name = "Icons"
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icons)
	pending_label = Label.new()
	pending_label.name = "PendingLine"
	pending_label.text = PENDING_TEXT
	var pl := LabelSettings.new()
	pl.font = Palette.number_font()
	pl.font_size = PENDING_FONT_PX
	pl.font_color = OXBLOOD
	pending_label.label_settings = pl
	pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pending_label.position = Vector2(24, ICON_TOP + ICON_PX + 4)
	pending_label.size = Vector2(CARD_SIZE.x - 48, PENDING_FONT_PX * 1.15)
	pending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_label.visible = false
	add_child(pending_label)
	seal = TextureRect.new()
	seal.name = "ClaimedSeal"
	seal.texture = tex("stamp_claimed.png")
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.size = Vector2(512, 384)
	seal.pivot_offset = seal.size * 0.5
	# Hangs over the card's lower right, like the Art Director's
	# card_pair6_claimed example.
	seal.position = Vector2(CARD_SIZE.x * 0.64, CARD_SIZE.y * 0.72) - seal.size * 0.5
	seal.scale = Vector2.ONE * SEAL_SCALE
	seal.visible = false
	add_child(seal)


## Sets the card for a bounty: its title and mini dice.
func setup(b: BountyData, bonus: bool) -> void:
	bounty_id = b.id
	name = "Card_%s" % b.id
	title.text = b.display_name.to_upper() + (("  +%d" % b.bonus_embers) if bonus else "")
	tooltip_text = b.description
	for c in icons.get_children():
		icons.remove_child(c)
		c.queue_free()
	var is_run := b.kind == BountyData.Kind.RUN or b.kind == BountyData.Kind.STRAIGHT_5
	var vals := DiceIcons.pattern(b)
	var parts: Array = []
	for i in vals.size():
		if is_run and i > 0:
			parts.append("arrow")
		# A run can be any run, so its dice show "?" (the Art Director's run card).
		parts.append("any" if is_run else str(vals[i]))
	var w := 0.0
	for p in parts:
		w += (ARROW_SIZE.x if p == "arrow" else ICON_PX) + ICON_GAP
	w -= ICON_GAP
	var x := (CARD_SIZE.x - w) * 0.5
	for p in parts:
		var r := TextureRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		if p == "arrow":
			r.texture = tex("icon_run_arrow.png")
			r.size = ARROW_SIZE
		else:
			r.texture = tex("icon_die_%s.png" % p)
			r.size = Vector2(ICON_PX, ICON_PX)
		r.position = Vector2(x, ICON_TOP)
		x += r.size.x + ICON_GAP
		icons.add_child(r)


## open / pending / claimed. `animate`: the seal stamps in (else it just appears).
func set_state(s: String, animate: bool = true) -> void:
	if s == state:
		return
	var was := state
	state = s
	ghost.visible = s == "pending"
	pending_label.visible = s == "pending"
	if s == "claimed":
		seal.visible = true
		if animate and was != "claimed":
			_stamp_in()
		else:
			_seal_rest()
	else:
		seal.visible = false


func _seal_rest() -> void:
	seal.scale = Vector2.ONE * SEAL_SCALE
	seal.rotation_degrees = 0.0
	seal.modulate.a = 1.0


## The 6-key stamp-in (0.27 s), real time so 2x / slow motion don't change it.
func _stamp_in(delay: float = 0.0) -> void:
	var k0: Dictionary = STAMP_KEYS[0]
	seal.scale = (k0["scale"] as Vector2) * SEAL_SCALE
	seal.rotation_degrees = float(k0["rot"])
	seal.modulate.a = float(k0["alpha"])
	var tw := seal.create_tween().set_ignore_time_scale(true)
	if delay > 0.0:
		tw.tween_interval(delay)
	for i in range(1, STAMP_KEYS.size()):
		var k: Dictionary = STAMP_KEYS[i]
		tw.tween_property(seal, "scale", (k["scale"] as Vector2) * SEAL_SCALE, STAMP_FRAME)
		tw.parallel().tween_property(seal, "rotation_degrees", float(k["rot"]), STAMP_FRAME)
		tw.parallel().tween_property(seal, "modulate:a", float(k["alpha"]), STAMP_FRAME)
		if i == 2:
			tw.tween_callback(func() -> void: stamp_impact.emit(bounty_id))
