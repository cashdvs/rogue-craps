## Hand candle row (world_props_v1 §2.1 + AD rulings, CONFLICTS_133 #5): up to CANDLE_CAP sockets on
## the near rail, left side. One LIT candle per remaining hand; invariant: lit candles == hands_left.
##   negative hands_delta (Ashmouth, Baron Vig): one empty socket per missing hand, with a cold stub
##   positive hands_delta (Odds Bodkin, elite twists): the extra candle rises in with a brass ring
##   hand spent (bank / bust): the rightmost lit candle snuffs with a smoke curl; bust adds a gutter drip
##   last hand (hands_left == 1): the last flame gutters (~half bright, uneven flicker, a thin smoke
##     wisp); it restores when a hand is added (hands_left = n / add_hands)
##   more than CANDLE_CAP hands (v2, GD Oct 22): all 8 lit + the brass ring on the 8th candle = "more
##     than shown"; no text. Spends above 8 snuff nothing; the cue ring goes when hands_left reaches 8.
##   table end: all candles out
## Visual only (art): no gameplay, no signals into the game. Godot Dev calls the hooks below.
##   row.table_start(goal_hands, hands_delta)   # table_started; goal_hands already includes the delta
##   row.spend(bust)                            # bank (false) / bust (true): hands_left -= 1 on the row
##   row.hands_left = n                         # snap (no animation) e.g. on load (raises hands if n > hands)
##   row.add_hands(n)                           # a hand was added mid-table: snap + restore the gutter
##   row.table_end()                            # all out
##   row.reduced_motion = true                  # every clip cuts to its end state
##   row.light_level()                          # 0..1 lit share, to slave the CandleBounce lights to
@tool
class_name CandleRow
extends Node3D

const CANDLE_CAP := 8                     # world_props_v1 §2.1 display constant
const HEIGHTS := [1.0, 0.93, 1.06, 0.96, 1.03, 0.9, 1.08, 0.97]
const SPINS := [0.0, 0.7, 1.9, 2.6, 4.1, 0.4, 3.3, 5.2]

@export_range(0, 99) var hands: int = 4:
	set(v):
		hands = maxi(v, 0)
		_layout()
@export_range(-8, 8) var hands_delta: int = 0:
	set(v):
		hands_delta = v
		_layout()
@export_range(0, 99) var hands_left: int = 4:
	set(v):
		v = maxi(v, 0)
		if v > hands and not _quiet:
			hands_left = v
			hands = v  # a hand beyond the goal (added mid-table): lays out + snaps
			return
		hands_left = mini(v, hands)
		if not _quiet:
			_snap()
@export var reduced_motion: bool = false


func _ready() -> void:
	_layout()


func candle(i: int) -> CandleRowCandle:
	return get_node_or_null("Sockets/Socket%d/Candle" % (i + 1)) as CandleRowCandle


func socket(i: int) -> Marker3D:
	return get_node_or_null("Sockets/Socket%d" % (i + 1)) as Marker3D


## table_started: goal_hands = goal.hands (includes hands_delta). All real candles lit; gifts rise in.
func table_start(goal_hands: int, delta: int) -> void:
	hands_delta = delta
	hands = goal_hands
	hands_left = hands
	for i in CANDLE_CAP:
		var c := candle(i)
		if c != null and c.state == CandleRowCandle.State.LIT:
			c.reset_lit()
			if _is_gift(i):
				c.rise = 0.0
				c.heat = 0.0
				c.rise_in(reduced_motion)
	_last_hand()


## A hand was spent (bank or bust): the rightmost lit candle snuffs.
func spend(bust := false) -> void:
	if hands_left <= 0:
		return
	if hands_left > CANDLE_CAP:
		hands_left_quiet(hands_left - 1)  # still all 8 lit; the cue ring leaves at 8
		_rings()
		return
	var i := hands_left - 1
	hands_left_quiet(hands_left - 1)
	var c := candle(i)
	if c != null:
		c.gutter_loop(false)
		c.snuff(bust, reduced_motion)
	_last_hand()


## table_end: every candle out.
func table_end() -> void:
	for i in mini(hands_left, CANDLE_CAP):
		var c := candle(i)
		if c != null:
			c.gutter_loop(false)
			c.snuff(false, reduced_motion)
	hands_left_quiet(0)
	_rings()


## A hand was added mid-table (n > 0): the candle lights again, the gutter clears.
func add_hands(n := 1) -> void:
	hands_left = hands_left + n


func lit_count() -> int:
	return hands_left


func light_level() -> float:
	return float(mini(hands_left, CANDLE_CAP)) / float(CANDLE_CAP)


## "More than shown" cue is up (hands_left > CANDLE_CAP).
func over_cap() -> bool:
	return hands_left > CANDLE_CAP


## Set hands_left without touching the candles (the clips finish the visual change).
func hands_left_quiet(n: int) -> void:
	_quiet = true
	hands_left = n
	_quiet = false


var _quiet := false


func _is_gift(i: int) -> bool:
	return hands_delta > 0 and hands <= CANDLE_CAP and i < hands and i >= hands - hands_delta


func _layout() -> void:
	var stubs := maxi(-hands_delta, 0)
	for i in CANDLE_CAP:
		var c := candle(i)
		if c == null:
			continue
		c.height = HEIGHTS[i]
		c.spin = SPINS[i]
		c.drip = 0.0
		c.bead = 0.0
		c.gutter_loop(false)
		if i < mini(hands, CANDLE_CAP):
			c.state = CandleRowCandle.State.LIT
		elif i < mini(hands + stubs, CANDLE_CAP):
			c.state = CandleRowCandle.State.STUB
		else:
			c.state = CandleRowCandle.State.EMPTY
	_rings()
	_snap()


func _rings() -> void:
	var used := 0
	for k in 2:
		var r := get_node_or_null("GiftRing%d" % (k + 1)) as Node3D
		if r != null:
			r.visible = false
	for i in CANDLE_CAP:
		if _is_gift(i) and used < 2:
			var r := get_node_or_null("GiftRing%d" % (used + 1)) as Node3D
			var s := socket(i)
			if r != null and s != null:
				_ring_on(r, s)
			used += 1
	if hands_left > CANDLE_CAP:  # the "more than shown" cue: the ring on the 8th candle
		var r := get_node_or_null("GiftRing1") as Node3D
		var s := socket(CANDLE_CAP - 1)
		if r != null and s != null:
			_ring_on(r, s)


func _ring_on(r: Node3D, s: Node3D) -> void:
	r.position = s.position + Vector3(0, 0.008 * s.scale.y, 0)  # collar a little up the wax, clear of the plate
	r.scale = s.scale
	r.visible = true


func _snap() -> void:
	for i in mini(hands, CANDLE_CAP):
		var c := candle(i)
		if c == null:
			continue
		c.state = CandleRowCandle.State.LIT if i < hands_left else CandleRowCandle.State.COLD
		c.heat = 1.0
		c.wisp = 0.0
	_rings()
	_last_hand()


func _last_hand() -> void:
	for i in mini(hands, CANDLE_CAP):
		var c := candle(i)
		if c != null and c.state == CandleRowCandle.State.LIT:
			c.gutter_loop(hands_left == 1 and i == 0, reduced_motion)
