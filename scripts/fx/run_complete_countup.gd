## RUN COMPLETE count-up (one_floor_v1, #225 screen): the Embers line counts
## up ("Embers left: {n} x{mult} = +{pts}"), then the Final score ticks up from the
## points banked. Both lines use the Ember UI colour (Palette.EMBER, #E8622A)
## with no glow: glow is for dice only. Reduced motion jumps straight to the
## final values; any tap, click or key press finishes it instantly.
##
## Feel layer only: it rewrites two existing Labels and never touches scoring.
class_name RunCompleteCountup
extends Node

signal finished

## Delay before the Embers line starts (s).
const START_DELAY: float = 0.2
## Embers line count-up length (s).
const EMBERS_TIME: float = 0.6
## Pause between the Embers line landing and the Final score starting (s).
const GAP: float = 0.15
## Final score tick-up length (s).
const TOTAL_TIME: float = 0.6
const TUNING_PATH := "res://resources/tuning/poc_tuning.tres"

var embers_label: Label
var total_label: Label
var reduced_motion: bool = false
var embers: int = 0
var mult: int = 0
## Embers line target points (RunSummary.ember_points).
var ember_pts: int = 0
## Final score shown before the tick-up (points banked).
var start_total: int = 0
## Final score target (RunSummary.final_score).
var final_total: int = 0
var elapsed: float = 0.0
var done: bool = false
## Which line is moving: &"wait", &"embers", &"total" or &"done" (for tests).
var phase: StringName = &"wait"
var _e: float = 0.0
var _t: float = 0.0


## Add a count-up under [param parent] that animates [param embers_lbl] and
## [param total_lbl] for [param run] (RunSummary rows). Returns the node.
static func attach(parent: Node, run: MapRun, embers_lbl: Label, total_lbl: Label, reduced: bool = default_reduced_motion()) -> RunCompleteCountup:
	var c := RunCompleteCountup.new()
	c.setup(embers_lbl, total_lbl, run.progress.embers, run.data.ember_score_mult, RunSummary.ember_points(run),
		run.run_points, RunSummary.final_score(run), reduced)
	parent.add_child(c)
	return c


## Reduced-motion flag from the shared TuningData (false if it can't load).
static func default_reduced_motion() -> bool:
	var t := load(TUNING_PATH) as TuningData if ResourceLoader.exists(TUNING_PATH) else null
	return t != null and t.reduced_motion


## Bind the labels and the values to land on (no scoring here: [param pts] and
## [param final] come from RunSummary); shows the start frame, or the end if
## [param reduced]. The Final score ticks from [param from_total] to [param final].
func setup(embers_lbl: Label, total_lbl: Label, embers_left: int, score_mult: int, pts: int, from_total: int, final: int, reduced: bool) -> void:
	embers_label = embers_lbl
	total_label = total_lbl
	embers = embers_left
	mult = score_mult
	ember_pts = pts
	start_total = from_total
	final_total = final
	reduced_motion = reduced
	for l: Label in [embers_label, total_label]:
		if l != null:
			l.add_theme_color_override("font_color", Palette.EMBER)
	if reduced_motion:
		finish()
	else:
		_show(0.0, 0.0)


## Total length of the animation in seconds (0 with reduced motion).
func duration() -> float:
	return 0.0 if reduced_motion else START_DELAY + EMBERS_TIME + GAP + TOTAL_TIME


## Jump to the final values now (skip / reduced motion). Safe to call twice.
func finish() -> void:
	if done:
		return
	done = true
	phase = &"done"
	elapsed = duration()
	_show(1.0, 1.0)
	set_process(false)
	finished.emit()


## Step the animation by [param dt] seconds (also what _process calls).
func advance(dt: float) -> void:
	if done:
		return
	elapsed += dt
	var e := clampf((elapsed - START_DELAY) / EMBERS_TIME, 0.0, 1.0)
	var t := clampf((elapsed - START_DELAY - EMBERS_TIME - GAP) / TOTAL_TIME, 0.0, 1.0)
	phase = &"wait" if elapsed < START_DELAY else (&"embers" if e < 1.0 else &"total")
	if t >= 1.0:
		finish()
	else:
		_show(e, t)


## Embers count currently shown on the Embers line.
func shown_embers() -> int:
	return _ease_int(embers, _e)


## Final score currently shown.
func shown_total() -> int:
	return start_total + _ease_int(final_total - start_total, _t)


## Embers points currently shown on the Embers line.
func shown_ember_pts() -> int:
	return _ease_int(ember_pts, _e)



func _show(e: float, t: float) -> void:
	_e = e
	_t = t
	if embers_label != null:
		embers_label.text = RunSummary.embers_line(shown_embers(), shown_ember_pts(), mult)
	if total_label != null:
		total_label.text = RunSummary.text("run_complete_total", {"n": shown_total()})


static func _ease_int(v: int, k: float) -> int:
	return v if k >= 1.0 else int(floor(v * (1.0 - pow(1.0 - k, 2.0))))


func _process(dt: float) -> void:
	advance(dt)


func _input(event: InputEvent) -> void:
	if done or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey or event is InputEventJoypadButton:
		finish()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
