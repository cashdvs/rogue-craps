## One slot of the bag row under the counter (HANDOFF_SPEC §2-3, PR C): a
## small box showing one of your dice, or empty when the bag has room.
## Hover (PC) opens the sell / inspect card; a click or tap pins it open.
## die_buy_flow_v1: a carved pip and a rare diamond tab; a click-up on a
## plain die in swap mode can commit (ShopScreen).
class_name BagSlot
extends Control

## The slot asks the shop to open its card. `pinned` = clicked or tapped
## (stays open), not just hovered (closes when the mouse leaves).
signal opened(slot: BagSlot, pinned: bool)
## The mouse left the slot (PC).
signal left(slot: BagSlot)
## Mouse-up (or touch up) on the same slot that was pressed.
signal clicked(slot: BagSlot)

const BOX := Color("#1E1712")
const EDGE := Color("#5A4A3A")
const CREAM := Color("#E8DCC0")
const TAB := Color("#ECE2C8")
const KEY := Color("#1A1614")
const BRASS := Color("#C9A24A")

## Which die in run.progress.dice this shows (-1 = an empty slot).
var die_i := -1
## The die picture (a ShopIcon, null when empty). Tests read it.
var icon: ShopIcon
var lifted := false
var _k := 1.0
var _carved := false
var _rare := false
var _armed := false


## Build slot `i` of the bag at `px` square (design px); k = design px per spec px.
func setup(run: MapRun, i: int, px: float, k: float) -> void:
	_k = k
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	die_i = i if i < run.progress.dice.size() else -1
	_carved = false
	_rare = false
	if die_i < 0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # Nothing to sell here.
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	_carved = run.progress.die_has_mods(die_i)
	var def := run.progress.die_def(die_i)
	_rare = def != null and def.is_rare()
	# Draw the die with the shop's own icon rig, from its special id or shape.
	var d := run.progress.dice[die_i]
	var id := d.special_id if d.special_id != &"" else d.shape
	var o := ShopOffer._make(ShopOffer.Kind.DIE, die_i, id, run.progress.die_name(die_i), DiceIds.body_key(id), 0)
	icon = ShopIcon.new()
	icon.setup(o, px * 0.84)
	icon.size = icon.custom_minimum_size
	icon.position = Vector2.ONE * px * 0.08
	add_child(icon)
	mouse_entered.connect(func() -> void: opened.emit(self, false))
	mouse_exited.connect(func() -> void: _armed = false; left.emit(self))


func _gui_input(e: InputEvent) -> void:
	var down: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	var up: bool = e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	var touch := e is InputEventScreenTouch
	if down or (touch and (e as InputEventScreenTouch).pressed):
		accept_event()
		_armed = true
		opened.emit(self, true)
	elif (up or (touch and not (e as InputEventScreenTouch).pressed)) and _armed:
		accept_event()
		_armed = false
		clicked.emit(self)


## Raise the slot 10 spec px with a cream edge while its sell card is open.
func lift(on: bool) -> void:
	if on == lifted:
		return
	lifted = on
	position.y += -10.0 * _k if on else 10.0 * _k
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BOX)
	draw_rect(r, CREAM if lifted else EDGE, false, maxf(1.0, 2.0 * _k))
	# Markers are shape-only in logical px and hide when the slot is under 40 px.
	# Sizes scale with the slot (k); keylines are a filled under-shape so they stay visible.
	if size.x < 40.0 - 0.01:
		return
	var pad := 3.0 * _k
	if _carved:
		var d := 8.0 * _k
		var kw := 1.5 * _k
		var outer := d * 0.5 + kw
		var c := Vector2(size.x - pad - outer, pad + outer)
		draw_circle(c, outer, KEY)
		draw_circle(c, d * 0.5, BRASS)
	if _rare:
		var h := 10.0 * _k * 0.5
		var kw := 1.0 * _k
		var o := Vector2(pad + h + kw, size.y - pad - h - kw)
		var kh := h + kw
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -kh), o + Vector2(kh, 0), o + Vector2(0, kh), o + Vector2(-kh, 0)]), KEY)
		draw_colored_polygon(PackedVector2Array([o + Vector2(0, -h), o + Vector2(h, 0), o + Vector2(0, h), o + Vector2(-h, 0)]), TAB)
