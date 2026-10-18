## Flick speed must read right at any frame rate, time scale or hitch
## (QA on PR #13). The mouse really moves at a steady speed; input reaches
## the game in per-frame batches, and every event in a batch gets that
## frame's timestamp (what Table3D's game clock does). The measured speed
## must be non-zero and within 15% of the true speed.
##   godot --headless --path . --script res://tests/test_throw_gesture_timing.gd
extends SceneTree

const FPS_LIST: Array[float] = [8.0, 12.0, 15.0, 20.0, 30.0, 60.0, 144.0]
const HITCHES: Array[float] = [0.0, 0.08, 0.1, 0.12, 0.15]
const SPEEDS: Array[float] = [1500.0, 2600.0]
## How long the steady flick lasts before release (s).
const FLICK_TIME: float = 0.3
## Real mouse event spacing (s).
const EVENT_DT: float = 0.004

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	var t := TuningData.new()
	var worst := 0.0
	for speed in SPEEDS:
		for fps in FPS_LIST:
			for hitch in HITCHES:
				var got := flick_speed(t, speed, fps, hitch)
				var err := absf(got - speed) / speed
				worst = maxf(worst, err)
				check(got > 0.0 and err <= 0.15, "%.0f px/s flick at %.0f fps, %.0f ms hitch at release: read %.0f px/s (%.0f%% off)" % [speed, fps, hitch * 1000.0, got, err * 100.0])
				check(ThrowGesture.is_throw(Vector2(got, 0), speed * FLICK_TIME, t), "%.0f px/s flick at %.0f fps, %.0f ms hitch counts as a throw" % [speed, fps, hitch * 1000.0])
	# A slow drag stays a drop at every frame rate.
	for fps in FPS_LIST:
		var slow := flick_speed(t, 300.0, fps, 0.0)
		check(not ThrowGesture.is_throw(Vector2(slow, 0), 300.0 * FLICK_TIME, t), "300 px/s drag at %.0f fps is not a throw (read %.0f)" % [fps, slow])
	# A click (press and release in the same frame) is still zero.
	var g := ThrowGesture.new(t)
	g.press(Vector2(100, 100), 1.0)
	check(g.release(Vector2(100, 100), 1.0) == Vector2.ZERO, "same-frame click reads 0")
	print("worst flick speed error: %.1f%%" % (worst * 100.0))
	print("test_throw_gesture_timing: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Simulates one flick and returns the speed ThrowGesture reads (px/s).
## Frames tick at 1/fps; the release frame lasts `hitch` instead (if > 0).
func flick_speed(t: TuningData, speed: float, fps: float, hitch: float) -> float:
	var g := ThrowGesture.new(t)
	var frame_dt := 1.0 / fps
	var release_t := FLICK_TIME
	# Frame boundaries (in real time) up to and including the release frame.
	var frames: Array[float] = []
	var ft := 0.0
	var last_regular := release_t - hitch if hitch > 0.0 else release_t
	while ft < last_regular - 0.0001:
		ft += frame_dt
		frames.append(minf(ft, last_regular) if hitch > 0.0 else ft)
	if hitch > 0.0:
		frames.append(frames[frames.size() - 1] + hitch)
		release_t = frames[frames.size() - 1]
	else:
		release_t = frames[frames.size() - 1]
	# The mouse moves steadily from t=0 until release_t.
	g.press(Vector2.ZERO, 0.0)
	var ev := EVENT_DT
	for f in frames:
		while ev <= f + 0.00001:
			g.move(Vector2(speed * minf(ev, release_t), 0), f)
			ev += EVENT_DT
	return g.release(Vector2(speed * release_t, 0), release_t).length()
