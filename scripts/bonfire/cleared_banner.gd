## The "TABLE CLEARED" banner (how_bonfire_plays.md section 4: "TABLE
## CLEARED: chase the bonus or Leave table"), built from the Art Director's
## six layers (assets/ui/readability/banner/), drawn in order:
##   01 tails, 02 ribbon, 03 brass frame, 04 ember glow (Add blend),
##   05 text, 06 sparkles
## plus a line under it: "chase the bonus or Leave table".
##
## Motion (1x, 1.8 s; 2x halves every time):
##   0.00-0.22 drop in from 140 pt above, ease-out back (8 pt overshoot)
##   0.22      impact: `impact` signal (thud + a light shake)
##   0.22-0.30 squash x 1.06, y 0.92;  0.30-0.40 elastic settle to 1.0
##   0.18-0.40 glow alpha 0 -> 1.3 (peak 0.26) -> 1.0
##   0.30-1.10 sparkles pop 0 -> 1 -> 0, 0.35 s each, 0.08 s apart, +45 deg
##   1.10-1.50 hold, glow 1.0 -> 0.8;  1.50-1.80 exit: rise 24 pt, 0.96, fade
## Tap (skip()) jumps to 1.50. Instant: static for 0.6 s, then a 0.15 s fade.
## It never takes input (mouse_filter IGNORE), so the table stays playable.
class_name ClearedBanner
extends Control

## Fires once at the impact (0.22 s at 1x): Bonfire3D plays the thud/shake.
signal impact

const DIR := "res://assets/ui/readability/banner/"
const LAYERS := ["table_cleared_01_tails", "table_cleared_02_ribbon", "table_cleared_03_brass_frame",
	"table_cleared_04_ember_glow_ADD", "table_cleared_05_text", "table_cleared_06_sparkles"]
## The art: 1074 x 336 px at @3x = 358 x 112 pt.
const ART_SIZE := Vector2(1074, 336)
const ART_SCALE := 3.0
const TOTAL := 1.8
const EXIT_AT := 1.5
const SUBLINE := "chase the bonus or Leave table"
## Tests read this (the banner's words, heading first).
const TEXT := "TABLE CLEARED\n" + SUBLINE

## The words on the banner (tests / captures).
var text: String = ""
## Design px per pt (BonfireHud.ui_pt_px); the art is drawn at pt_px / 3.
var pt_px: float = 2.0
## Where the banner's centre rests (design px).
var rest_center := Vector2(960, 560)
var art: Control
var layers: Array[TextureRect] = []
var glow: TextureRect
var sparkles: TextureRect
var subline: Label
## Seconds into the motion at 1x; -1 = not showing.
var t: float = -1.0
var speed: float = 1.0
var instant: bool = false
var _impact_sent: bool = false


func _init() -> void:
	name = "ClearedBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	art = Control.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = ART_SIZE
	art.pivot_offset = ART_SIZE * 0.5
	add_child(art)
	for id in LAYERS:
		var r := TextureRect.new()
		r.name = id
		var p: String = DIR + id + ".png"
		r.texture = load(p) as Texture2D if ResourceLoader.exists(p) else null
		r.size = ART_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if id.ends_with("_ADD"):
			# The ember glow adds light on top (Add blend).
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			r.material = m
			glow = r
		if id.ends_with("sparkles"):
			sparkles = r
			r.pivot_offset = ART_SIZE * 0.5
		art.add_child(r)
		layers.append(r)
	subline = Label.new()
	subline.name = "Subline"
	subline.text = SUBLINE
	subline.label_settings = Palette.label_settings(60, Palette.BONE, 10)
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subline.size = Vector2(ART_SIZE.x * 1.4, 80)
	subline.position = Vector2(-ART_SIZE.x * 0.2, ART_SIZE.y * 0.93)
	art.add_child(subline)


## Starts the banner. speed 2.0 = the 2x roll speed; instant = static.
func play(speed_mult: float = 1.0, is_instant: bool = false) -> void:
	text = TEXT
	speed = maxf(speed_mult, 0.01)
	instant = is_instant
	t = 0.0
	_impact_sent = false
	visible = true
	modulate.a = 1.0
	_apply()


## A tap skips to the exit (1.50 s).
func skip() -> void:
	if t >= 0.0 and t < EXIT_AT and not instant:
		t = EXIT_AT
		if not _impact_sent:
			_impact_sent = true
		_apply()


func is_playing() -> bool:
	return t >= 0.0


func _process(delta: float) -> void:
	if t < 0.0:
		return
	# Real time (the HUD ignores slow motion), then the roll speed.
	t += delta / maxf(Engine.time_scale, 0.001) * speed
	_apply()


## Poses every layer for time t.
func _apply() -> void:
	var k := pt_px / ART_SCALE
	art.scale = Vector2.ONE * k
	var center := rest_center
	var sx := 1.0
	var sy := 1.0
	var alpha := 1.0
	var glow_a := 1.0
	var spark := 0.0
	var spark_rot := 0.0
	if instant:
		# Static for 0.6 s, then a 0.15 s fade.
		alpha = 1.0 if t < 0.6 else clampf(1.0 - (t - 0.6) / 0.15, 0.0, 1.0)
		if t >= 0.75:
			_finish()
			return
	else:
		if t < 0.22:
			# Drop from 140 pt above, ease-out back (overshoot ~8 pt).
			var f := t / 0.22
			var back := 1.0 + 2.70158 * pow(f - 1.0, 3) + 1.70158 * pow(f - 1.0, 2)
			center.y = rest_center.y - 140.0 * pt_px * (1.0 - back)
		elif t < 0.30:
			var f := (t - 0.22) / 0.08
			sx = lerpf(1.0, 1.06, f)
			sy = lerpf(1.0, 0.92, f)
		elif t < 0.40:
			var f := (t - 0.30) / 0.10
			var el := 1.0 - cos(f * PI * 2.5) * exp(-4.0 * f)
			sx = lerpf(1.06, 1.0, el)
			sy = lerpf(0.92, 1.0, el)
		if t >= 0.22 and not _impact_sent:
			_impact_sent = true
			impact.emit()
		if t < 0.18:
			glow_a = 0.0
		elif t < 0.26:
			glow_a = lerpf(0.0, 1.3, (t - 0.18) / 0.08)
		elif t < 0.40:
			glow_a = lerpf(1.3, 1.0, (t - 0.26) / 0.14)
		elif t < 1.10:
			glow_a = 1.0
		else:
			glow_a = lerpf(1.0, 0.8, clampf((t - 1.10) / 0.40, 0.0, 1.0))
		# 7 sparkles share one layer: it pops 7 times, 0.08 s apart.
		if t >= 0.30 and t < 1.10:
			var local := fmod(t - 0.30, 0.08 * 7.0)
			spark = sin(clampf(local / 0.35, 0.0, 1.0) * PI)
			spark_rot = 45.0 * clampf((t - 0.30) / 0.80, 0.0, 1.0)
		if t >= EXIT_AT:
			var f := clampf((t - EXIT_AT) / (TOTAL - EXIT_AT), 0.0, 1.0)
			center.y = rest_center.y - 24.0 * pt_px * f
			sx = lerpf(1.0, 0.96, f)
			sy = sx
			alpha = 1.0 - f
		if t >= TOTAL:
			_finish()
			return
	art.position = center - ART_SIZE * 0.5
	art.scale = Vector2(sx, sy) * k
	modulate.a = alpha
	if glow != null:
		glow.modulate.a = glow_a if not instant else 1.0
	if sparkles != null:
		sparkles.modulate.a = 1.0 if instant else clampf(spark, 0.0, 1.0)
		sparkles.scale = Vector2.ONE * (1.0 if instant else maxf(spark, 0.001))
		sparkles.rotation_degrees = spark_rot


func _finish() -> void:
	t = -1.0
	modulate.a = 0.0
	visible = false
