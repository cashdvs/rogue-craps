## The clock the game really uses for flicks (QA on #20): with flick_clock
## left unset, Table3D.flick_time() is the wall clock (Time.get_ticks_usec)
## and ignores Engine.time_scale, so a flick measures the same at any game
## speed. (The flick tests in test_table_3d.gd inject their own clock.)
##
## Robust under load: every flick_time() read is bracketed by two
## Time.get_ticks_usec() reads, so the check is "inside the bracket" (plus a
## small slack) however slow the machine is, never a fixed-duration guess.
## The real wait runs frames until the wall clock passes WAIT_S; the game clock that
## time_scale does slow down / speed up is read from _process deltas, to
## show the scale really was in effect.
##   godot --headless --path . --script res://tests/test_flick_clock.gd
extends SceneTree

## Real seconds to wait at each time scale.
const WAIT_S := 0.4
## Allowed slack (s) around the bracket: float rounding of usec -> s.
const SLACK_S := 0.002

var _passed: int = 0
var _failed: int = 0
## Game time (scaled process deltas) since the last reset.
var _game_t: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _process(delta: float) -> bool:
	_game_t += delta
	return false


## flick_time() read between two wall-clock reads: [before_s, flick_s, after_s].
func _bracketed(s: Table3D) -> Array[float]:
	var before := Time.get_ticks_usec() / 1000000.0
	var f := s.flick_time()
	var after := Time.get_ticks_usec() / 1000000.0
	return [before, f, after]


func _run() -> void:
	var s := (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	root.add_child(s)
	await process_frame
	check(not s.flick_clock.is_valid(), "flick_clock is unset (the game's real clock)")
	var old_scale := Engine.time_scale
	for ts in [1.0, 0.25, 3.0]:
		Engine.time_scale = ts
		await process_frame
		var a := _bracketed(s)
		check(a[1] >= a[0] - SLACK_S and a[1] <= a[2] + SLACK_S, "time scale %.2f: flick_time() is Time.get_ticks_usec (%.6f in [%.6f, %.6f])" % [ts, a[1], a[0], a[2]])
		_game_t = 0.0
		# A real-time wait: keep running frames until the wall clock says
		# WAIT_S passed (a timer counts frame deltas, which can drift from
		# the wall clock on a loaded machine).
		var start_us := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start_us < int(WAIT_S * 1000000.0):
			await process_frame
		var b := _bracketed(s)
		var game := _game_t
		check(b[1] >= b[0] - SLACK_S and b[1] <= b[2] + SLACK_S, "time scale %.2f: still the wall clock after the wait" % ts)
		# The flick delta must sit inside the wall-clock deltas around it.
		var d_flick := b[1] - a[1]
		var d_min := b[0] - a[2]
		var d_max := b[2] - a[0]
		print("  time scale %.2f: flick delta %.4f s, wall %.4f-%.4f s, game clock %.4f s" % [ts, d_flick, d_min, d_max, game])
		check(d_flick >= d_min - SLACK_S and d_flick <= d_max + SLACK_S, "time scale %.2f: flick delta %.3f s follows the wall clock (%.3f-%.3f s)" % [ts, d_flick, d_min, d_max])
		check(d_flick >= WAIT_S - SLACK_S, "time scale %.2f: flick delta %.3f s >= the %.1f s real wait" % [ts, d_flick, WAIT_S])
		# time_scale was really in effect on the game clock (loose bounds: the
		# scaled frames around the wait aren't exactly the wait).
		if ts < 1.0:
			check(game < d_flick * 0.6, "time scale %.2f slowed the game clock (%.3f s) but not the flick clock (%.3f s)" % [ts, game, d_flick])
		elif ts > 1.0:
			check(game > d_flick * 1.8, "time scale %.2f sped up the game clock (%.3f s) but not the flick clock (%.3f s)" % [ts, game, d_flick])
	Engine.time_scale = old_scale
	check(is_equal_approx(Engine.time_scale, old_scale), "time_scale restored (%.2f)" % Engine.time_scale)
	print("test_flick_clock: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
