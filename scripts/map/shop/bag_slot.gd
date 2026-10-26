## One slot of the bag row under the counter (HANDOFF_SPEC §2-3, PR C): a
## small box showing one of your dice, or empty when the bag has room.
## Hover (PC) opens the sell card; a click or tap pins it open.
class_name BagSlot
extends Control

## The slot asks the shop to open its sell card. `pinned` = clicked or tapped
## (stays open), not just hovered (closes when the mouse leaves).
signal opened(slot: BagSlot, pinned: bool)
## The mouse left the slot (PC).
signal left(slot: BagSlot)

const BOX := Color("#1E1712")
const EDGE := Color("#5A4A3A")
const CREAM := Color("#E8DCC0")

## Which die in run.progress.dice this shows (-1 = an empty slot).
var die_i := -1
## The die picture (a ShopIcon, null when empty). Tests read it.
var icon: ShopIcon
var lifted := false
var _k := 1.0


## Build slot `i` of the bag at `px` square (design px); k = design px per spec px.
func setup(run: MapRun, i: int, px: float, k: float) -> void:
	_k = k
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	die_i = i if i < run.progress.dice.size() else -1
	if die_i < 0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # Nothing to sell here.
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	mouse_exited.connect(func() -> void: left.emit(self))


func _gui_input(e: InputEvent) -> void:
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
	if click or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
		accept_event()
		opened.emit(self, true)


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
