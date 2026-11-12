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
	# Markers are shape-only and hide when the slot renders under 40 px.
	if size.x < 40.0 - 0.01:
		return
	var pad := maxf(2.0, 2.0 * _k)
	if _carved:
		var d := maxf(8.0, 8.0 * _k)
		var c := Vector2(size.x - pad - d * 0.5, pad + d * 0.5)
		draw_circle(c, d * 0.5, BRASS)
		draw_arc(c, d * 0.5, 0.0, TAU, 20, KEY, maxf(1.5, 1.5 * _k))
	if _rare:
		var s := maxf(10.0, 10.0 * _k)
		var o := Vector2(pad + s * 0.5, size.y - pad - s * 0.5)
		var h := s * 0.5
		var pts := PackedVector2Array([o + Vector2(0, -h), o + Vector2(h, 0), o + Vector2(0, h), o + Vector2(-h, 0)])
		draw_colored_polygon(pts, TAB)
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, KEY, maxf(1.0, 1.0 * _k), true)
